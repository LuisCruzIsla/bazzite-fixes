# XWayland: layout de teclado desincronizado del compositor Wayland

> **Estado:** workaround confirmado. La causa raíz vive en Mutter; el workaround sincroniza XWayland a mano y sobrevive a la sesión.

## Síntoma

Una aplicación XWayland (típicamente un juego Proton/Wine) **no detecta pulsaciones de teclado** en componentes que hacen *polling* del estado del teclado en tiempo real — el caso más visible son los **cuadros de captura de hotkeys** en menús de opciones:

```
Vincular tecla rápida:
  [ Oprime la tecla deseada ]
  ↳ (no detecta nada al pulsar teclas reales)
```

La jugabilidad normal **sí** funciona: caminar, escribir en chat, etc. Sólo fallan los menús de bind y los componentes que llaman a `GetAsyncKeyState`, `XQueryKeymap` o equivalentes Win32/X11 sobre el estado actual.

Diagnóstico rápido — el layout que reporta XWayland no coincide con el que GNOME tiene activo:

```bash
setxkbmap -query | grep -E 'layout|variant'
# layout:     us
# (sin variant)

gsettings get org.gnome.desktop.input-sources sources
# [('xkb', 'us+altgr-intl'), ('xkb', 'latam')]
```

XWayland está en `us` plano mientras GNOME usa `us+altgr-intl` (o cualquier otra variante). Las pulsaciones se entregan con keysyms del layout activo, pero el polling pregunta por VKs sobre el mapeo `us` → no match → cero detección.

## Quién está afectado

- **Compositor:** GNOME / Mutter en sesión **Wayland**
- **Distro:** Bazzite, Fedora Workstation, Fedora Atomic, Ubuntu con GNOME — cualquiera con Mutter ≥ 45 (reportado en 45, 46, 47)
- **Configuración disparadora:** GNOME con **2 o más input sources** configurados en `org.gnome.desktop.input-sources sources` (Settings → Keyboard → Input Sources)
- **Aplicación afectada:** clientes XWayland que usen polling del keymap (`GetAsyncKeyState`, `XQueryKeymap`, `XkbGetState`). Frecuente en:
  - RTS/MOBA con menú de hotkeys (StarCraft II, Warcraft III: Reforged, Dota 2 menús legacy)
  - Juegos Win32 vía Proton/Wine que reasignan binds con polling
  - Emuladores y herramientas legacy de input remap

**No afecta** a apps Wayland nativas (GTK/Qt/Electron modernos) ni a la cola normal de eventos `WM_KEYDOWN` — por eso el grueso de la jugabilidad funciona.

Ver carpeta [`casos/`](./casos/) para configuraciones específicas confirmadas.

## Causa raíz

Cuando GNOME tiene 2+ input sources, Mutter no propaga consistentemente el primero al servidor XWayland al iniciar la sesión. El estado queda desincronizado entre dos componentes:

1. **Wayland (Mutter):** entrega eventos con keysyms del layout activo en GNOME (p. ej. `us+altgr-intl`).
2. **XWayland (servidor X embebido):** mantiene su propio `XkbDesc`. Si Mutter no le envía el `xkb_keymap` correcto, queda en el default (`us` plano).

Las apps X reciben keysyms correctos en sus eventos, pero al consultar el **estado** del teclado con `XQueryKeymap`/`GetAsyncKeyState` obtienen el mapeo desincronizado → cero coincidencias para teclas que existen en la variante real.

Issue upstream relacionado: [mutter#1697](https://gitlab.gnome.org/GNOME/mutter/-/issues/1697) (XWayland keymap sync con múltiples layouts).

## Soluciones que NO funcionan (anti-patrones)

- **Cambiar el layout en GNOME → volver a cambiarlo:** a veces dispara la sincronización, a veces no. No reproducible.
- **Reiniciar la aplicación afectada:** XWayland es del servidor de sesión, no del proceso cliente. Persiste.
- **Cerrar sesión y volver a entrar:** el desync se reintroduce con probabilidad alta si sigues teniendo 2+ input sources.
- **Reducir a un solo input source en GNOME:** funciona pero pierde el switcher de layouts. Sólo aceptable si nunca usas el segundo idioma.
- **`xmodmap`:** modifica el mapping de keycodes pero no resuelve la divergencia del `XkbDesc` que ven las APIs modernas.

## Solución (workaround)

Forzar a XWayland al layout correcto con `setxkbmap`. Tres niveles según tu caso:

### Nivel A — Fix manual de la sesión actual

```bash
setxkbmap <layout> -variant <variant>
# Ejemplo:
setxkbmap us -variant altgr-intl
```

Aplica inmediatamente al servidor XWayland. Dura hasta cerrar sesión.

Para averiguar el layout/variant correcto:

```bash
gsettings get org.gnome.desktop.input-sources sources
# [('xkb', 'us+altgr-intl'), ('xkb', 'latam')]
#               ^^^^^^^^^^^   ← lo que va tras el '+' es el variant
```

### Nivel B — Wrapper antes de lanzar el juego (recomendado para apps puntuales)

Encierra el `exec` del juego en un wrapper que sincronice XWayland justo antes:

```bash
#!/bin/bash
if [ -n "$DISPLAY" ] && command -v setxkbmap >/dev/null 2>&1; then
  setxkbmap us -variant altgr-intl 2>/dev/null || true
fi
exec "$@"
```

Script listo para copiar: [`sync-xkb-layout.sh`](./sync-xkb-layout.sh). Edita el `setxkbmap` con tu layout/variant.

En Steam → Propiedades → Opciones de inicio:

```
/home/<TU_USUARIO>/.local/bin/sync-xkb-layout.sh %command%
```

Si ya usas otro wrapper (p. ej. el `strip-extest.sh` del fix de SC2 — ver [juegos/starcraft-2/fake-gamepads-hid/](../../juegos/starcraft-2/fake-gamepads-hid/)), añade el bloque `setxkbmap` dentro de ese wrapper en vez de encadenar dos.

### Nivel C — Autostart en la sesión (recomendado si te afecta de forma generalizada)

Crea `~/.config/autostart/sync-xkb-layout.desktop`:

```ini
[Desktop Entry]
Type=Application
Name=Sync XWayland keymap
Exec=/bin/bash -c "sleep 5 && setxkbmap us -variant altgr-intl"
X-GNOME-Autostart-enabled=true
NoDisplay=true
```

El `sleep 5` da tiempo a Mutter a terminar de inicializar XWayland antes de imponer el layout. Ajusta layout/variant a los tuyos.

## Verificación

```bash
./verify-fix.sh
```

O a mano — los dos comandos deben coincidir:

```bash
setxkbmap -query | grep -E '^(layout|variant):'
gsettings get org.gnome.desktop.input-sources sources
```

## Diagnóstico si vuelve a fallar

1. **Confirmar el desync:**
   ```bash
   setxkbmap -query
   gsettings get org.gnome.desktop.input-sources sources
   ```

2. **Verificar que el wrapper se ejecutó** (para Nivel B). En un terminal mientras el juego está abierto:
   ```bash
   pgrep -f "<nombre_juego>" | while read pid; do
     cat /proc/$pid/status | grep -E '^(Name|PPid)'
   done
   ```
   El padre debe ser tu wrapper o el árbol de Steam.

3. **Verificar autostart** (para Nivel C):
   ```bash
   journalctl --user -b | grep -i xkb
   ```

4. **Si setxkbmap reporta el layout correcto pero el juego sigue fallando** — el problema NO es éste. Buscar en otra capa (env vars del Wine prefix, dead keys, focus stealing).

## Casos confirmados

| # | Distro | Compositor | Aplicación afectada |
|---|--------|-----------|---------------------|
| 001 | Bazzite 43 | GNOME Wayland (Mutter 47) | StarCraft II — menú de teclas rápidas |

## Referencias técnicas

- [mutter#1697 — XWayland keymap not synced with multiple layouts](https://gitlab.gnome.org/GNOME/mutter/-/issues/1697)
- [setxkbmap(1)](https://www.x.org/releases/X11R7.6/doc/man/man1/setxkbmap.1.xhtml)
- [XKB extension overview](https://www.x.org/releases/X11R7.5/doc/input/XKB-Config.html)
- Win32 `GetAsyncKeyState` traducción Wine → XQueryKeymap

## Contribuir

Ver [`CONTRIBUTING.md`](../../CONTRIBUTING.md) en la raíz del repositorio.
