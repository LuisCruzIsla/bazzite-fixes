# Caso 001 — Bazzite 43 + Logitech PRO X + Kingston HyperX

**Confirmado por:** [@LuisCruzIsla](https://github.com/LuisCruzIsla)
**Fecha inicial:** 2026-05-27
**Última validación:** 2026-05-27 (post suspend/resume, con Capa 2 wrapper)
**Estado:** Fix funciona y sobrevive a suspend.

## Historia del caso

La primera versión del fix tenía la Capa 2 implementada como "desactivar Steam Input en propiedades del juego" desde la UI de Steam. Funcionó hasta que el equipo se suspendió: al despertar, Steam reactivó automáticamente la inyección de `libextest.so` aunque la UI seguía marcando "Steam Input desactivado". El menú de teclas rápidas volvió a mostrar "Botón de mando X".

Diagnóstico: `grep libextest /proc/<pid_battlenet>/maps` mostró que la librería estaba cargada en todos los procesos Battle.net pese a la configuración. La Capa 2 fue reemplazada por un wrapper que strip `libextest` del `LD_PRELOAD` antes de ejecutar `%command%` — solución definitiva que no depende de un toggle de Steam que puede resetearse.

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
| Battle.net | 2.51.5.17438 |

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

`/etc/udev/rules.d/99-sc2-disable-fake-gamepads.rules`:

```udev
SUBSYSTEM=="input", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="0aaa", ENV{ID_INPUT_JOYSTICK}="0"
SUBSYSTEM=="input", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="c539", ENV{ID_INPUT_JOYSTICK}="0"
SUBSYSTEM=="input", ATTRS{idVendor}=="0951", ATTRS{idProduct}=="16e6", ENV{ID_INPUT_JOYSTICK}="0"
```

### Capa 2 — Wrapper strip-extest

`~/.local/bin/strip-extest.sh` copiado desde el repo y marcado ejecutable.

### Capa 3 — Launch options (Steam → Battle.net → Propiedades → Opciones de inicio)

```
PROTON_NO_XINPUT=1 PROTON_NO_UDEV_JOYSTICK=1 SDL_JOYSTICK_DISABLED=1 SDL_JOYSTICK_HIDAPI=0 SDL_GAMECONTROLLER_IGNORE_DEVICES=0x046D/0x0AAA,0x046D/0xC539,0x0951/0x16E6 /home/lcruzisl/.local/bin/strip-extest.sh %command%
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

## Salida de verificación (tras Capa 2 wrapper)

```
=== Capa 1: udev rule activa para HID problemáticos ===
  [OK] event6      [0951:16e6] Kingston HyperX Alloy Origins Core         JOYSTICK=0
  [OK] event10     [0951:16e6] Kingston HyperX Alloy Origins Core         JOYSTICK=0
  [OK] event11     [046d:0aaa] Logitech PRO X Consumer Control            JOYSTICK=0
  [OK] event12     [046d:0aaa] Logitech PRO X                             JOYSTICK=0
  [OK] event2      [046d:c539] Logitech G703 LS                           JOYSTICK=0

=== Capa 2: wrapper strip-extest activo ===
  [OK] Sin libextest cargado en ningún proceso Battle.net/SC2

=== Capa 3: env vars heredadas en SC2 ===
  [OK] PROTON_NO_XINPUT                = 1
  [OK] PROTON_NO_UDEV_JOYSTICK         = 1
  [OK] SDL_JOYSTICK_DISABLED           = 1
  [OK] SDL_JOYSTICK_HIDAPI             = 0

=== Mando real (si aplica) ===
  [OK] js0: Xbox Wireless Controller
```

## Notas adicionales del proceso

- Antes de la solución definitiva se intentaron parches con `sc2-monitor.sh` que detenía `input-remapper.service` en bucle — completamente irrelevante al problema.
- La primera Capa 2 ("desactivar Steam Input en UI") fue insuficiente: Steam la reactivó tras una suspensión del equipo. Tuvo que reemplazarse por un wrapper que strip `libextest.so` del `LD_PRELOAD` para ser robusta.
- El fix actual sobrevive a suspend/resume, actualizaciones de Battle.net y reaperturas de Steam.
- Si Steam Cloud sincroniza una configuración nueva que vuelva a activar Steam Input, el wrapper sigue protegiendo — Steam Input puede quedarse "activo" en la UI sin afectar al juego.
