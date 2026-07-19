# Dota 2: nunca entra en pantalla completa y desajusta la resolución del monitor (Wayland + NVIDIA)

> **Estado:** solución confirmada. Forzar el backend de vídeo de SDL a Wayland nativo elimina el cambio de modo del monitor. La corrección vive en las opciones de lanzamiento de Steam y sobrevive a actualizaciones del juego y del cliente.

## Síntoma

Al lanzar **Dota 2** en una sesión **Wayland con GPU NVIDIA**, el juego **cambia la resolución del escritorio** y queda descuadrado. Nunca aparece en pantalla completa real, y a menudo la resolución del escritorio **sigue mal incluso después de cerrar el juego**.

```
Lanzar Dota 2
  ↳ el monitor cambia de modo, la imagen queda descuadrada / con partes fuera de pantalla
  ↳ al salir del juego, el escritorio a veces queda en la resolución equivocada
```

## Quién está afectado

| Factor | Valor |
|--------|-------|
| Sesión gráfica | **Wayland** (GNOME/Mutter, KDE, etc.) |
| GPU | **NVIDIA** con driver propietario |
| Juego / motor | Dota 2 y otros títulos **Source 2 / SDL** que corren bajo **XWayland** |
| Backend de vídeo | SDL cae a **X11 (XWayland)** por defecto |

**No afecta** a sesiones X11 reales (el modeset lo maneja el propio servidor X y GNOME lo restaura), ni a configuraciones donde SDL ya usa Wayland nativo.

Ver [`casos/`](./casos/) para configuraciones específicas confirmadas.

## Causa raíz

El binario nativo de Dota 2 usa **SDL**, que en una sesión Wayland arranca por defecto sobre **XWayland** (backend `x11`).

1. **Modeset heredado de X11:** al pedir pantalla completa, Dota intenta cambiar el **modo real del monitor** (resolución/refresh) como haría en un servidor X11 clásico.
2. **XWayland no puede cambiar el modo real:** en Wayland el modeset lo controla el compositor, no la aplicación. XWayland emula el cambio de modo de forma imperfecta y **ni Mutter ni el driver NVIDIA restauran limpio** el modo original al salir.

Resultado: la resolución del escritorio queda desajustada y el juego nunca ocupa la pantalla como debería.

## Soluciones que NO funcionan (anti-patrones)

- **Cambiar sólo "Modo de pantalla" dentro de Dota** (Pantalla completa ↔ Sin bordes) sin tocar el backend: sigue corriendo bajo XWayland → sigue intentando el modeset roto.
- **Poner el escritorio manualmente a otra resolución** antes de jugar: no evita que el juego haga su propio cambio de modo.
- **Bajar la resolución en el juego:** cualquier resolución distinta a la nativa fuerza un modeset; el problema es el cambio de modo en sí, no el valor.
- **Modo "Sin bordes" (borderless):** a veces oculta el síntoma pero deja el escritorio y el escalado mal alineados.

## Solución

Forzar SDL a **Wayland nativo**. En Wayland la aplicación **no puede** hacer modeset: en vez de cambiar el modo del monitor, hace fullscreen del compositor a la resolución nativa. Se elimina el cambio de modo de raíz.

### Paso 1 — Opciones de lanzamiento

Steam → clic derecho en **Dota 2** → **Propiedades** → **General** → **Opciones de lanzamiento**:

```
SDL_VIDEODRIVER=wayland %command% -fullscreen -w <ANCHO> -h <ALTO>
```

Sustituir `<ANCHO>`/`<ALTO>` por la resolución nativa del monitor (p. ej. `1920` y `1080`).

- `SDL_VIDEODRIVER=wayland` → backend Wayland nativo (no XWayland), que es el que hacía el modeset roto.
- `-fullscreen -w -h` → el juego pide exactamente la resolución nativa; no hay cambio de modo.

### Paso 2 — Configuración de vídeo en Dota

Dentro del juego → **Configuración → Vídeo**:

- **Modo de pantalla: Pantalla completa** (no "Sin bordes")
- **Resolución:** la nativa del monitor (igual que en el Paso 1)

### Plan B — gamescope (si SDL nativo falla)

Si Dota no arranca con Wayland nativo (SDL antiguo empaquetado con el juego) o el síntoma persiste, envolverlo en **gamescope**, que crea un monitor virtual aislado:

```
gamescope -W <ANCHO> -H <ALTO> -r <HZ> -f -- %command%
```

En NVIDIA serie 50, si gamescope da pantalla negra, forzar el backend SDL:

```
gamescope --backend sdl -W <ANCHO> -H <ALTO> -r <HZ> -f -- %command%
```

## Verificación

```bash
./verify-fix.sh
```

Resultado esperado, con Dota **abierto**:

- El proceso de Dota tiene `SDL_VIDEODRIVER=wayland` en su entorno.
- El proceso carga `libwayland-client` (backend Wayland nativo activo).
- La resolución del monitor **no cambia** respecto al escritorio.

Validación real definitiva: **lanzar Dota, confirmar pantalla completa correcta, salir y comprobar que el escritorio queda en su resolución nativa.**

## Por qué sobrevive a actualizaciones

| Capa | Garantía |
|------|----------|
| Opciones de lanzamiento (Steam) | Se guardan en `localconfig.vdf` del usuario (local + Steam Cloud); ni una actualización de Steam ni de Dota las tocan. |
| `SDL_VIDEODRIVER` | Variable de entorno estándar de SDL; no depende de la versión del juego. |
| `-fullscreen -w -h` | Argumentos estándar del motor Source; estables entre versiones. |

Si un driver NVIDIA futuro arregla el modeset de XWayland, quitar la variable es trivial y reversible.

## Diagnóstico si vuelve a fallar

1. **Confirmar que la variable llega al proceso** (con Dota abierto):
   ```bash
   pid=$(pgrep -x dota2 | head -1)
   tr '\0' '\n' < /proc/$pid/environ | grep SDL_VIDEODRIVER
   ```
2. **Confirmar backend Wayland** (debe cargar libwayland, no sólo libX11):
   ```bash
   grep -c libwayland-client /proc/$pid/maps
   ```
3. **Si el juego no arranca** con Wayland nativo: el SDL empaquetado es demasiado viejo → usar el **Plan B (gamescope)**.
4. **Restaurar el escritorio** si quedó en mala resolución tras un lanzamiento previo: GNOME → Configuración → Pantallas → seleccionar la resolución nativa.

## Casos confirmados

| # | Distro | GPU / Driver | Monitor |
|---|--------|--------------|---------|
| 001 | Bazzite 44 | NVIDIA RTX 5070 Ti / 610.43.03 | 1920×1080 @ 165 Hz |

## Referencias técnicas

- [SDL — variable de entorno `SDL_VIDEODRIVER`](https://wiki.libsdl.org/SDL2/FAQUsingSDL)
- [Arch Wiki — Gaming en Wayland / XWayland](https://wiki.archlinux.org/title/Gaming)
- [gamescope — Valve](https://github.com/ValveSoftware/gamescope)
- [XWayland y cambios de modo (freedesktop)](https://wayland.freedesktop.org/xserver.html)

## Contribuir

Ver [`CONTRIBUTING.md`](../../../CONTRIBUTING.md) en la raíz del repositorio.
