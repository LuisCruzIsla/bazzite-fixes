# Caso 001 — Bazzite 43 + Logitech PRO X + Kingston HyperX

**Confirmado por:** [@LuisCruzIsla](https://github.com/LuisCruzIsla)
**Fecha:** 2026-05-27
**Estado:** Fix funciona en producción.

## Entorno

| Componente | Versión |
|------------|---------|
| Distro | Bazzite 43 (Fedora Atomic) |
| Escritorio | GNOME |
| Kernel | 6.17 |
| GPU | NVIDIA RTX 5070 Ti |
| CPU | AMD Ryzen 9 5900X |
| RAM | 16 GB |
| Runtime principal | Steam + Proton 10.0-4 |
| Runtime alterno | Lutris + GE-Proton10-34 (umu) |

## Dispositivos HID problemáticos detectados como mandos

| Dispositivo | VID:PID | Naturaleza real |
|-------------|---------|-----------------|
| Logitech G PRO X Gaming Headset | `046d:0aaa` | Audio + controles multimedia |
| Logitech Lightspeed Receiver (G703) | `046d:c539` | Receptor inalámbrico ratón |
| Kingston HyperX Alloy Origins Core | `0951:16e6` | Teclado mecánico |

## Mandos reales conectados que NO deben verse afectados

| Dispositivo | VID:PID | Conexión |
|-------------|---------|----------|
| Xbox Wireless Controller | `045e:028e` | Bluetooth |

Verificado tras aplicar fix: el Xbox sigue apareciendo como `/dev/input/js0` y funcionando en otros juegos.

## Aplicación de las cuatro capas en este caso

### Capa 1 — udev rule

```udev
SUBSYSTEM=="input", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="0aaa", ENV{ID_INPUT_JOYSTICK}="0"
SUBSYSTEM=="input", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="c539", ENV{ID_INPUT_JOYSTICK}="0"
SUBSYSTEM=="input", ATTRS{idVendor}=="0951", ATTRS{idProduct}=="16e6", ENV{ID_INPUT_JOYSTICK}="0"
```

### Capa 2 — Steam Input

Desactivado para Battle.net (Propiedades → Mando → Desactivar Steam Input).

### Capa 3 — Launch options

```
PROTON_NO_XINPUT=1 PROTON_NO_UDEV_JOYSTICK=1 SDL_JOYSTICK_DISABLED=1 SDL_JOYSTICK_HIDAPI=0 SDL_GAMECONTROLLER_IGNORE_DEVICES=0x046D/0x0AAA,0x046D/0xC539,0x0951/0x16E6 %command%
```

### Capa 4 — userdef.reg

```reg
[Software\\Wine\\DirectInput] 1778565438
"DisableInput"=dword:00000001
"MouseWarpOverride"="enable"

[Software\\Wine\\DirectInput\\Joysticks\\Kingston HyperX Alloy Origins Core] 1779337668
"Disabled"="Y"

[Software\\Wine\\DirectInput\\Joysticks\\Logitech PRO X] 1778565438
"Disabled"="Y"

[Software\\Wine\\DirectInput\\Joysticks\\Logitech USB Receiver] 1779337451
"Disabled"="Y"

[Software\\Wine\\DirectInput\\Joysticks\\Logitech G PRO X Gaming Headset] 1778565438
"Disabled"="Y"
```

## Salida de verificación

```
Logitech PRO X        → event12  ID_INPUT_JOYSTICK=0
Logitech PRO X Cons.  → event11  ID_INPUT_JOYSTICK=0
Kingston HyperX       → event6-10 ID_INPUT_JOYSTICK=0
Xbox Wireless Ctrl    → event23  ID_INPUT_JOYSTICK=1 (intacto, funciona)
SC2 sin libextest.so cargado
Menú de teclas rápidas: muestra letras del teclado correctamente
```

## Notas adicionales del proceso

- Antes de la solución definitiva se intentaron parches con `sc2-monitor.sh` que detenía `input-remapper.service` en bucle — completamente irrelevante al problema.
- La capa 2 (Steam Input/extest) fue la que faltaba para que el fix dejara de ser intermitente.
- El fix sobrevivió a una actualización de Battle.net (2.51.5.17438) sin necesidad de re-aplicarlo.
