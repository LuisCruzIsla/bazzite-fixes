# 001 — Bazzite 44 + StarCraft II + Proton 10.0-4

- **Confirmado por:** [@LuisCruzIsla](https://github.com/LuisCruzIsla)
- **Fecha:** 2026-06-01
- **Estado:** Fix funciona

## Entorno

| Componente | Versión |
|------------|---------|
| Distro | Bazzite 44 (`bazzite-gnome-nvidia-open:stable`, build 44.20260515) |
| Kernel | 6.19.x |
| Compositor | GNOME Wayland (Mutter) |
| Proton | 10.0-4 |
| Juego | StarCraft II (Battle.net via Steam, AppID 3990503939) |
| Hardware | Ryzen 9 5900X + RTX 5070 Ti + 16 GB RAM |
| Teclado | Kingston HyperX Alloy Origins Core (TKL) |

## Síntoma exacto observado

Al abrir **StarCraft II → Opciones → Hotkeys → Vincular tecla rápida**, el cuadro de captura de la tecla no detecta ninguna pulsación. Pulsar `Alt+Tab` al desktop y volver a la ventana del juego permitía capturar 1-2 teclas antes de que el polling volviera a fallar.

Proceso de Xalia confirmado activo:

```
PID 104518 \\?\Z:\...\Proton 10.0\files\share\wine/../xalia/xalia.exe
```

Variables relevantes en `/proc/$SC2_PID/environ`:

```
PROTON_USE_XALIA=1
XALIA_SUPPORTED_ONLY=1
```

## Aplicación del fix

Se aplicó **Opción 2 (wrapper local)** combinada con un wrapper existente para Steam Input (`strip-extest.sh`). Añadida la línea:

```bash
export PROTON_USE_XALIA=0
```

justo antes del `exec "$@"` final del wrapper en `~/.local/bin/strip-extest.sh`.

Launch options de Steam quedaron:

```
PROTON_NO_XINPUT=1 PROTON_NO_UDEV_JOYSTICK=1 SDL_JOYSTICK_DISABLED=1 SDL_JOYSTICK_HIDAPI=0 SDL_GAMECONTROLLER_IGNORE_DEVICES=0x046D/0x0AAA,0x046D/0xC539,0x0951/0x16E6 /home/<user>/.local/bin/strip-extest.sh %command%
```

(No fue necesario añadir `PROTON_USE_XALIA=0` también en launch options porque el wrapper ya lo exporta — redundancia opcional.)

## Validación

Prueba inmediata sin reiniciar SC2:

```bash
pkill -f xalia.exe
```

Tras matar Xalia, el cuadro de captura de hotkeys empezó a detectar teclas correctamente en la sesión activa. Confirmado que el problema era exclusivamente Xalia.

Cierre/reapertura de SC2 con el wrapper actualizado: Xalia ya no aparece en `pgrep -af xalia.exe` durante toda la sesión.

## Salida de `verify-fix.sh`

```
=== Verificación: Proton Xalia desactivada ===

[OK] xalia.exe NO está corriendo

Proceso del juego detectado: PID=144377 name=SC2_x64.exe
[OK] PROTON_USE_XALIA=0 está presente en el entorno del juego
```

## Notas adicionales

- Este fix se complementa con `juegos/starcraft-2/hotkey-capture-debug-multicapa/` que documenta las 5 capas totales del problema del cuadro de hotkeys de SC2. Xalia es la **capa 3**.
- Xalia no afecta el juego en partida — solo a los menús que polean estado de teclado.
- El usuario no usa accesibilidad AT-SPI con juegos, así que desactivar Xalia es seguro.
