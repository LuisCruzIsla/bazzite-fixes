# 001 — Bazzite 44 + Kingston HyperX Alloy Origins Core (TKL) + SC2

- **Confirmado por:** [@LuisCruzIsla](https://github.com/LuisCruzIsla)
- **Fecha:** 2026-06-01
- **Estado:** Fix funciona

## Entorno

| Componente | Versión |
|------------|---------|
| Distro | Bazzite 44 |
| Compositor | GNOME Wayland (Mutter) |
| Teclado | Kingston HyperX Alloy Origins Core (TKL, sin numpad físico) |
| VID:PID | 0951:16e6 |
| App afectada | StarCraft II + Proton 10.0-4 (cuadro de captura de hotkeys) |

## Síntoma exacto observado

Tras resolver las otras 4 capas del debug multi-capa (Steam Input, XKB desync, Xalia, IBus), el cuadro de captura de hotkeys de SC2 **detectaba "Bloq Num" en cada captura** sin importar qué tecla presionara el usuario.

Estado de los LEDs lock antes del fix:

```
input21::numlock=1
input21::capslock=1
input7::numlock=1
input7::capslock=1
```

Los dos devices (`input7` = "Kingston HyperX Alloy Origins Core" y `input21` = mismo teclado vía otro endpoint) reportaban los locks activos. ScrollLock estaba en 0 (no afectaba).

## Aplicación del fix

El teclado es TKL — sin numpad físico, sin tecla `Bloq Num` visible. Combinación correcta para el HyperX Alloy Origins Core 80%:

- **NumLock:** no hay tecla dedicada en este modelo. Se desactivó vía software con `xdotool key Num_Lock` con foco fuera de SC2.
- **CapsLock:** tecla física estándar (sobre Shift izquierdo), apagada con una pulsación.

## Validación

Estado post-fix:

```
input21::numlock=0
input7::numlock=0
input21::capslock=0
input7::capslock=0
input21::scrolllock=0
input7::scrolllock=0
```

Tras esto el cuadro de captura de SC2 detectó correctamente `A` al presionar A, `Q` al presionar Q, etc.

## Salida de `check-locks.sh`

```
=== Estado de toggle keys (NumLock, CapsLock, ScrollLock) ===

[OK] input21::numlock=0
[OK] input21::capslock=0
[OK] input21::scrolllock=0
[OK] input7::numlock=0
[OK] input7::capslock=0
[OK] input7::scrolllock=0

[OK] Ninguna toggle key activa. Polling de teclado limpio.
```

## Notas adicionales

- El Kingston HyperX Alloy Origins Core (TKL) expone **dos devices kbd** en `/proc/bus/input/devices`: el teclado principal (`event6`/`input7`) y un "Keypad" virtual para teclas embebidas (`event7`/`input21`). Ambos reportan estado lock por separado pero el firmware los mantiene sincronizados.
- Este modelo no tiene LEDs visibles para Num/Caps/Scroll Lock en el chasis (los teclados HyperX TKL básicos los omiten). Por eso el estado lock pasó desapercibido durante el debug.
- Para detectar el estado lock sin LEDs visibles, el método más rápido es leer `/sys/class/leds/input*::numlock/brightness`.
- Esta es la **capa 5** del análisis multi-capa de SC2 documentado en `juegos/starcraft-2/hotkey-capture-debug-multicapa/`.
