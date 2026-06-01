# StarCraft II: cuadro de captura de hotkeys no detecta o detecta erróneamente

> **Estado:** solución confirmada — guía de debug multi-capa con 5 capas acumulativas

## Síntoma

Al abrir **StarCraft II → Opciones → Hotkeys → Vincular tecla rápida**, el cuadro de captura no detecta teclas correctamente. La sintomatología **varía según cuántas capas estén activas**:

| Cuántas capas interfieren | Síntoma típico |
|---------------------------|----------------|
| Una o más capas 1-4 activas | "No detecta nada" / cuadro vacío al pulsar |
| Capa 5 sola activa | "Detecta siempre la misma tecla equivocada" (típicamente `Bloq Num` o `Bloq Mayús`) |
| `Alt+Tab` arregla intermitentemente | Probablemente capas 3 o 4 (focus refresca el grab) |

> **Nota crítica:** este documento NO trata el problema de "dispositivos HID detectados como mandos virtuales" — ese es un síntoma **distinto** del menú de hotkeys. Ver [`../fake-gamepads-hid/`](../fake-gamepads-hid/) si el cuadro te muestra "Botón de mando X" en vez de la tecla.

## Quién está afectado

- **Distro:** Bazzite 44+ (también Fedora Atomic, SteamOS, otras con GNOME Wayland)
- **Juego:** StarCraft II vía Battle.net en Steam con Proton **10.0+**
- **Locale:** cualquiera que active IBus por defecto (típicamente cualquier `es_*`, `fr_*`, `de_*` etc. en Fedora-based)
- **Hardware:** cualquier teclado, especialmente TKL/60% sin LEDs visibles para toggle keys

Ver [`casos/`](./casos/) para configuraciones específicas confirmadas.

## Causa raíz — las 5 capas

El cuadro de captura de hotkeys usa polling del bitmap de `XQueryKeymap` (traducido desde `GetAsyncKeyState` por Wine). Cualquiera de **5 capas independientes** puede romper el polling. Las capas son acumulativas — eliminar 4 puede no resolver el síntoma si la quinta sigue activa. El **cambio de naturaleza del síntoma** al arreglar una capa suele indicar que se ha destapado otra.

| # | Capa | Tecnología | Documentación |
|---|------|------------|---------------|
| 1 | **Steam Input** | `libextest.so` via `LD_PRELOAD` inyecta gamepad virtual; bitmap contaminado | [`../fake-gamepads-hid/`](../fake-gamepads-hid/) (capa 2 de ese fix) |
| 2 | **XWayland keymap desync** | Mutter deja XWayland en `us` plain con 2+ input sources GNOME | [`../../../sistema/xwayland-keymap-desync/`](../../../sistema/xwayland-keymap-desync/) |
| 3 | **Xalia (Proton 10+)** | Proxy AT-SPI intercepta input para accesibilidad | [`../../../sistema/proton-xalia-input-grab/`](../../../sistema/proton-xalia-input-grab/) |
| 4 | **IBus (`ibus-x11`)** | `XGrabKey` sobre XWayland consume teclas antes que Wine | [`../../../sistema/ibus-x11-keygrab/`](../../../sistema/ibus-x11-keygrab/) |
| 5 | **Toggle keys atascados** | NumLock/CapsLock con bit permanente en bitmap | [`../../../sistema/toggle-keys-polling-mask/`](../../../sistema/toggle-keys-polling-mask/) |

## Soluciones que NO funcionan (anti-patrones)

- **Resetear bindings de SC2** — no toca ninguna de las 5 capas.
- **Reinstalar Proton / cambiar a Proton-GE** — algunas versiones evitan Xalia (capa 3) pero las otras 4 siguen activas.
- **Reasignar todos los hotkeys uno por uno con paciencia** — el polling sigue roto al guardar.
- **Ejecutar SC2 como root o con `sudo`** — sigue interceptado por las mismas capas.
- **Cambiar el layout XKB del sistema sin más** — solo arregla la capa 2; las otras 4 siguen.

## Solución completa

La solución es **arreglar las 5 capas en orden**. Cada una tiene su propia documentación detallada — este documento es solo el índice de orquestación.

### Capa 1 — Steam Input

Wrapper `~/.local/bin/strip-extest.sh` que filtra `libextest.so` del `LD_PRELOAD` antes del `exec` de Proton. Ver [`../fake-gamepads-hid/strip-extest.sh`](../fake-gamepads-hid/strip-extest.sh) y el README de ese problema.

### Capa 2 — XWayland keymap desync

Mantener **una sola** input source en GNOME (`Configuración → Teclado → Distribuciones de teclado`). Si necesitas 2+, el wrapper de capa 1 incluye un `setxkbmap` que sincroniza al lanzar. Ver [`../../../sistema/xwayland-keymap-desync/`](../../../sistema/xwayland-keymap-desync/).

### Capa 3 — Xalia

El wrapper exporta `PROTON_USE_XALIA=0`. Si no usas el wrapper, añadir esa variable al inicio de las launch options de Steam. Ver [`../../../sistema/proton-xalia-input-grab/`](../../../sistema/proton-xalia-input-grab/).

### Capa 4 — IBus

Desactivado globalmente con override de autostart + `environment.d` + toggle script para activar a demanda. Ver [`../../../sistema/ibus-x11-keygrab/`](../../../sistema/ibus-x11-keygrab/).

### Capa 5 — Toggle keys

Verificar `cat /sys/class/leds/input*::numlock/brightness` y `input*::capslock/brightness`. Si alguna está en `1`, apagarla físicamente o con `xdotool key Num_Lock` / `Caps_Lock`. Ver [`../../../sistema/toggle-keys-polling-mask/`](../../../sistema/toggle-keys-polling-mask/).

## Verificación end-to-end

Ejecutar con SC2 lanzado:

```bash
./verify-fix.sh
```

Internamente invoca los scripts de cada capa. Resultado esperado:

```
[OK] Capa 1 — libextest no inyectado en SC2_x64.exe
[OK] Capa 2 — layout XKB sincronizado (us+altgr-intl)
[OK] Capa 3 — xalia.exe no corriendo, PROTON_USE_XALIA=0 en environ
[OK] Capa 4 — IBus desactivado, sin procesos ibus-*
[OK] Capa 5 — toggle keys (NumLock/CapsLock) en 0
```

## Por qué sobrevive a actualizaciones

Cada capa tiene su propio mecanismo de persistencia documentado en sus respectivos README. Resumen:

| Capa | Persistencia | Tras qué evento puede romperse |
|------|--------------|--------------------------------|
| 1 | Wrapper en `~/.local/bin/` | El usuario edita el wrapper |
| 2 | Una sola input source en GNOME + wrapper | El usuario añade otra input source |
| 3 | `export PROTON_USE_XALIA=0` en wrapper | Proton 11+ podría requerir nueva variable |
| 4 | Override en `~/.config/autostart/` + `environment.d` | Distro renombra el `.desktop` system-wide |
| 5 | Estado de firmware del teclado | Aplastar tecla por accidente, BIOS con default on |

## Diagnóstico si vuelve a fallar

Empezar siempre por la **capa 5** (más barato verificar):

```bash
# Capa 5 — locks activos
for led in /sys/class/leds/input*::{numlock,capslock,scrolllock}; do
  test -e "$led" && echo "$(basename $led)=$(cat $led/brightness)"
done
```

Si todos los locks están en 0, continuar con capa 4 → 3 → 2 → 1. El orden inverso es el más probable: las capas 1 y 2 son las más estables, las 3-5 son las que más fácilmente se reactivan.

## Casos confirmados

| # | Distro | Proton | Hardware |
|---|--------|--------|----------|
| [001](./casos/001-bazzite44-proton10.md) | Bazzite 44 | 10.0-4 | RTX 5070 Ti + HyperX Alloy Origins Core TKL |

## Historial del problema

Este problema tiene **historial conocido en SC2 desde Proton 9+**, pero la sintomatología cambió con Proton 10 al introducirse Xalia (capa 3 nueva). Los reportes en foros y ProtonDB suelen cubrir solo 1-2 capas y por eso "el fix funciona pero se rompe de nuevo" es un patrón recurrente.

## Referencias

- Cada capa enlaza a documentación upstream relevante en su propio README.
- Análisis multi-capa similar para "fake gamepads": [`../fake-gamepads-hid/`](../fake-gamepads-hid/).

## Contribuir

Ver [`CONTRIBUTING.md`](../../../CONTRIBUTING.md) en la raíz.
