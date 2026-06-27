# Vesktop / Discord: pantalla negra al compartir pantalla en NVIDIA

> **Estado:** solución confirmada. Desactivar la aceleración por hardware del cliente Electron fuerza la captura por software y elimina los frames negros. El fix sobrevive a actualizaciones del Flatpak.

## Síntoma

Al compartir pantalla (monitor entero) desde Vesktop, Discord Flatpak u otro cliente Electron/Chromium en una sesión **Wayland con GPU NVIDIA**, lo que ven los demás se pone **negro de forma intermitente**. La interfaz del cliente se ve bien; sólo el contenido capturado sale negro.

```
Compartir pantalla → "Pantalla completa 1"
  ↳ los demás ven un rectángulo negro (a veces sí, a veces no)
```

No hay ningún error en los logs de `xdg-desktop-portal`, `pipewire`, `wireplumber`, Mutter ni del propio cliente. La negociación de captura "tiene éxito" — pero el frame entregado es negro.

## Quién está afectado

| Factor | Valor |
|--------|-------|
| Sesión gráfica | **Wayland** (GNOME/Mutter, KDE, etc.) |
| GPU | **NVIDIA** con driver propietario |
| Cliente | Vesktop, Discord (Flatpak/nativo), WebCord — cualquier app **Electron/Chromium** que capture vía `getDisplayMedia` |
| Portal | `xdg-desktop-portal-*` con backend PipeWire |

**No afecta** a sesiones X11 reales (usan captura XSHM/XComposite), ni a GPUs AMD/Intel (cuya importación DMA-BUF en Chromium funciona).

Ver [`casos/`](./casos/) para configuraciones específicas confirmadas.

## Causa raíz

En una sesión Wayland, Chromium captura la pantalla a través del **portal PipeWire**, que entrega los frames como buffers **DMA-BUF** (memoria de GPU, zero-copy).

1. **Portal / PipeWire:** publica el frame del monitor como DMA-BUF con modificadores de la GPU.
2. **Proceso GPU de Chromium:** intenta importar ese DMA-BUF para componer el frame. **En NVIDIA esta importación falla de forma silenciosa** → entrega un frame en negro. No lanza error, por eso no aparece en ningún log.

El carácter intermitente viene de la negociación de modificadores: según el estado de la GPU el import unas veces resuelve y otras devuelve negro.

## Soluciones que NO funcionan (anti-patrones)

- **Forzar XWayland** en el cliente (`ELECTRON_OZONE_PLATFORM_HINT=x11`, `DISPLAY=:0`, quitar el socket Wayland): **probado, NO sirve.** En una sesión Wayland, Chromium captura por el portal PipeWire **aunque la app corra en XWayland** — el path de captura es idéntico. La captura X11 legacy (XSHM) sólo existe en una sesión X11 real.
- **Quitar sólo el socket Wayland** (`--nosocket=wayland`): Electron en ozone "auto" intenta Wayland primero, no encuentra el socket y se cierra con `Failed to initialize Wayland platform → Exiting`. No hace fallback a X11.
- **Cambiar la opción de captura dentro del cliente:** ya viene correcta (`WebRTCPipeWireCapturer` activo). El problema no es de configuración del capturer.
- **Reiniciar el portal / PipeWire:** no hay nada roto que reiniciar; la captura funciona, sólo el frame es negro.

## Solución

Desactivar la **aceleración por hardware** del cliente Electron (`--disable-gpu`). Sin proceso GPU usando NVIDIA, Chromium negocia con el portal buffers de **software/SHM** en vez de DMA-BUF, y el frame deja de salir negro.

Vesktop 1.6.5 no expone esta opción en su config, así que se pasa el flag por los lanzadores. Como Vesktop puede arrancar por dos rutas (autostart minimizado y menú de aplicaciones), hay que cubrir ambas. Los dos lanzadores reenvían argumentos a `vesktop.bin`.

### Paso 1 — Autostart (arranque minimizado en login)

Editar `~/.config/autostart/dev.vencord.Vesktop.desktop` y añadir `--disable-gpu` al final del `Exec`:

```ini
Exec=flatpak run --command=/app/bin/vesktop/vesktop.bin dev.vencord.Vesktop --enable-speech-dispatcher --start-minimized --disable-gpu
```

### Paso 2 — Lanzador del menú

El `.desktop` del menú lo exporta el Flatpak en `/var/lib/flatpak/exports/share/applications/` (de sólo lectura). Crear un override de usuario que lo pise:

```bash
cp /var/lib/flatpak/exports/share/applications/dev.vencord.Vesktop.desktop \
   ~/.local/share/applications/dev.vencord.Vesktop.desktop
```

Editar el `Exec` del override para insertar `--disable-gpu` tras el ID de la app:

```ini
Exec=/usr/bin/flatpak run --branch=stable --arch=x86_64 --command=startvesktop --file-forwarding dev.vencord.Vesktop --disable-gpu @@u %U @@
```

Refrescar la base de datos de aplicaciones:

```bash
update-desktop-database ~/.local/share/applications
```

### Paso 3 — Reiniciar el cliente

```bash
flatpak kill dev.vencord.Vesktop
flatpak run dev.vencord.Vesktop &
```

> **Discord Flatpak / otros clientes:** el principio es el mismo. Si el cliente expone *Settings → Advanced → Hardware Acceleration*, basta con desactivarlo desde la UI (persiste en su config). Si no, pasar `--disable-gpu` por el `.desktop` como aquí.

**Trade-off:** la app pierde aceleración GPU para todo (UI y vídeo se renderizan por CPU). Para un cliente de chat es aceptable; sube algo el uso de CPU.

## Verificación

```bash
./verify-fix.sh
```

Resultado esperado:
- Los dos lanzadores contienen `--disable-gpu`.
- El proceso GPU del cliente (si existe) **no carga librerías NVIDIA** → render por software.

Comprobación manual del proceso GPU en software:

```bash
for d in /proc/[0-9]*; do
  tr '\0' ' ' < "$d/cmdline" 2>/dev/null | grep -q "vesktop.bin.*type=gpu-process" && gpid=${d#/proc/}
done
grep -ic nvidia /proc/$gpid/maps   # debe ser 0
```

La validación real definitiva: **compartir el monitor entero y confirmar que no vuelve el negro.**

## Por qué sobrevive a actualizaciones

| Capa | Garantía |
|------|----------|
| `~/.config/autostart/*.desktop` | Archivo de usuario; las actualizaciones del Flatpak no lo tocan. |
| `~/.local/share/applications/*.desktop` | Override de usuario; tiene prioridad sobre el `.desktop` exportado por el Flatpak y persiste a `flatpak update`. |
| Flag `--disable-gpu` | Es un switch estándar de Chromium/Electron; no depende de la versión de Vesktop. |

Si una actualización de NVIDIA arregla la importación DMA-BUF, quitar el flag es trivial y reversible (ver Diagnóstico).

## Diagnóstico si vuelve a fallar

1. **Confirmar que el flag llega al proceso:**
   ```bash
   grep -h '^Exec=' ~/.config/autostart/dev.vencord.Vesktop.desktop \
                     ~/.local/share/applications/dev.vencord.Vesktop.desktop
   ```
2. **Confirmar render software** (el gpu-process no debe cargar `nvidia`): ver bloque de Verificación.
3. **Si el override del menú no se aplica:** `update-desktop-database ~/.local/share/applications` y reabrir desde el menú, no desde una instancia ya viva en bandeja.
4. **Para revertir** (probar si un driver nuevo ya lo arregló): quitar `--disable-gpu` de ambos `.desktop`, o borrar el override del menú y restaurar el autostart.

## Casos confirmados

| # | Distro | GPU / Driver | Cliente |
|---|--------|--------------|---------|
| 001 | Bazzite 44 | NVIDIA RTX 5070 Ti / 610.43.02 | Vesktop 1.6.5 (Flatpak) |

## Referencias técnicas

- [xdg-desktop-portal — ScreenCast](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.ScreenCast.html)
- [Chromium — WebRTC PipeWire capturer](https://chromium.googlesource.com/chromium/src/+/main/docs/ozone_overview.md)
- [PipeWire — DMA-BUF sharing](https://docs.pipewire.org/page_dma_buf.html)
- Electron — `app.disableHardwareAcceleration()` / flag `--disable-gpu`

## Contribuir

Ver [`CONTRIBUTING.md`](../../CONTRIBUTING.md) en la raíz del repositorio.
