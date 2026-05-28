# StarCraft II: dispositivos HID detectados como mandos virtuales

> **Estado:** solución confirmada y validada.
> Las cuatro capas descritas a continuación eliminan el problema y sobreviven a actualizaciones de Battle.net, regeneraciones del prefix de Proton y reinicios.

## Síntoma

Al abrir el menú de **Teclas rápidas** en StarCraft II, al reasignar un atajo el juego muestra `Botón de mando X` en lugar de la tecla del teclado pulsada:

```
Vincular tecla rápida:
  Botón de mando 7
  [ Bloq Num ]   [ Agregar alternativa ]
  Oprime la tecla deseada
```

Ocurre **sin tener un gamepad físico conectado**. Dispositivos como el headset, el receptor inalámbrico del ratón o el teclado mecánico son interpretados como mandos virtuales.

## Quién está afectado

Cualquier combinación de:

- **Distro:** Bazzite, SteamOS, Fedora Atomic/Silverblue, Arch + gamemode, otras con Proton/Wine reciente
- **Launcher:** Steam, Lutris, Heroic con runtime Proton
- **Hardware:** dispositivos HID que expongan múltiples interfaces (consumer control, keypad, mouse en un mismo USB) — típicamente headsets gaming, teclados con controles multimedia, receptores inalámbricos
- **Juego:** StarCraft II (Battle.net), reportado también ocasionalmente en otros títulos que usan DirectInput

Ver carpeta [`casos/`](./casos/) para hardware específico confirmado.

## Causa raíz

Tres capas independientes contribuyen al problema. **Las guías comunes parchean sólo una y por eso fallan intermitentemente:**

1. **Kernel/udev:** dispositivos HID con múltiples interfaces reciben el flag `ID_INPUT_JOYSTICK=1` heurísticamente.
2. **Wine/Proton:** la regeneración del prefix (al actualizar Battle.net o al reiniciar Proton) borra las claves `HKCU\Software\Wine\DirectInput\Joysticks\*` con `Disabled=Y`.
3. **Steam Input (`extest`):** Steam inyecta `libextest.so` vía `LD_PRELOAD` en procesos lanzados desde Steam. Intercepta HID raw y emite gamepads virtuales **dentro del proceso del juego**, evadiendo cualquier filtro a nivel kernel.

La tercera capa es la causa más persistente y suele pasar desapercibida porque opera dentro del binario, no en el sistema.

## Soluciones que NO funcionan (anti-patrones)

- Detener `input-remapper.service` — no tiene relación con el problema.
- Scripts monitor en bucle que paran servicios cada N segundos.
- `WINEDLLOVERRIDES=xinput1_3=` solo — Proton regenera el prefix y se pierde.
- Modificar `user.reg` directamente — Wine lo reescribe.

## Solución completa (cuatro capas redundantes)

### Capa 1: Regla udev (nivel kernel, persistente)

Crear `/etc/udev/rules.d/99-sc2-disable-fake-gamepads.rules` con los VID:PID de **tus** dispositivos problemáticos. Ejemplo y plantilla genérica:

```udev
# Reemplaza los VID:PID por los tuyos (lsusb)
SUBSYSTEM=="input", ATTRS{idVendor}=="VVVV", ATTRS{idProduct}=="PPPP", ENV{ID_INPUT_JOYSTICK}="0"
```

Plantilla lista para copiar: [`99-sc2-disable-fake-gamepads.rules`](./99-sc2-disable-fake-gamepads.rules) (incluye los VID:PID del caso 001 — adáptalos).

Recargar sin reiniciar:

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=input
```

**VID a NUNCA incluir** (son mandos reales, los desactivarías):

| VID | Fabricante |
|-----|------------|
| `045e` | Microsoft (Xbox) |
| `054c` | Sony (DualShock/DualSense) |
| `057e` | Nintendo (Pro Controller) |
| `28de` | Valve (Steam Controller) |
| `0079`, `0810` | Mandos genéricos USB |

### Capa 2: Desactivar Steam Input para Battle.net

**Lo más importante y lo que falta en todas las guías de foros:**

1. Abre **Steam** (sin lanzar nada).
2. Click derecho sobre **Battle.net** en biblioteca → **Propiedades**.
3. Pestaña **Mando** (o **Controller**).
4. Cambia de **Habilitar Steam Input** a **Desactivar Steam Input**.

Esto impide que `libextest.so` se inyecte vía `LD_PRELOAD` en la cadena `Battle.net Launcher → Battle.net.exe → SC2_x64.exe`.

### Capa 3: Variables de entorno en launch options de Steam

Click derecho sobre **Battle.net** → **Propiedades** → **Opciones de inicio**:

```
PROTON_NO_XINPUT=1 PROTON_NO_UDEV_JOYSTICK=1 SDL_JOYSTICK_DISABLED=1 SDL_JOYSTICK_HIDAPI=0 SDL_GAMECONTROLLER_IGNORE_DEVICES=0xVVVV/0xPPPP,... %command%
```

Reemplaza `0xVVVV/0xPPPP` por tus VID:PID en mayúscula hexadecimal.

| Variable | Función |
|----------|---------|
| `PROTON_NO_XINPUT=1` | Proton no expone API XInput al juego |
| `PROTON_NO_UDEV_JOYSTICK=1` | Proton no usa detección udev para joysticks |
| `SDL_JOYSTICK_DISABLED=1` | SDL ignora el subsistema joystick |
| `SDL_JOYSTICK_HIDAPI=0` | SDL no usa la ruta HIDAPI |
| `SDL_GAMECONTROLLER_IGNORE_DEVICES` | Lista negra explícita por VID/PID |

Las env vars se heredan automáticamente del Battle.net launcher a SC2_x64 — no hace falta configurarlas dentro del launcher de Battle.net.

### Capa 4: Persistir las claves de Wine en `userdef.reg`

Wine usa `userdef.reg` del prefix como **plantilla** al regenerar `user.reg`. Las claves aquí sobreviven a la regeneración tras actualizaciones de Battle.net.

Editar `<prefix>/userdef.reg` (típicamente `~/Games/battlenet/pfx/userdef.reg` con Lutris, o `~/.steam/steam/steamapps/compatdata/<appid>/pfx/userdef.reg` con Steam-Proton) y añadir al final el contenido de [`userdef-snippet.reg`](./userdef-snippet.reg) — ajustando los nombres exactos que Wine asigna a tus dispositivos.

Para descubrir los nombres reales tras lanzar el juego una vez:

```bash
grep "Joysticks" <prefix>/user.reg
```

## Verificación

Tras aplicar las cuatro capas, ejecutar:

```bash
./verify-fix.sh
```

Resultado esperado:

- Todos los HID problemáticos con `JOYSTICK=0`
- Sin `libextest.so` cargado en procesos SC2
- Mandos reales (Xbox, PS) siguen apareciendo como `/dev/input/js0`

## Por qué esto sobrevive a actualizaciones

| Capa | Lo que sobrevive |
|------|------------------|
| udev rule | Actualizaciones de Battle.net, regeneración del prefix, cambios de Proton |
| Steam Input off | Permanece hasta que el usuario lo reactive manualmente |
| Launch options | Permanece a menos que se editen |
| `userdef.reg` | Wine lo respeta al regenerar `user.reg` automáticamente |

Las cuatro capas son redundantes a propósito: si una falla (por ejemplo una actualización de Proton cambia el comportamiento de las env vars), las otras siguen activas.

## Diagnóstico si vuelve a fallar

1. Verificar que `extest` no esté inyectado:
   ```bash
   pgrep -af SC2_x64 | grep -o "libextest"
   ```
   Si aparece → Steam Input se reactivó. Repetir Capa 2.

2. Verificar regla udev:
   ```bash
   udevadm info -q property -n /dev/input/event<N> | grep JOYSTICK
   ```

3. Verificar registro Wine:
   ```bash
   grep "Joysticks" <prefix>/user.reg
   ```

## Casos confirmados

Listado en [`casos/`](./casos/). Cada archivo documenta una combinación específica de hardware/distro/runtime donde el fix se validó. Si confirmas el fix en otra configuración, abre un PR añadiendo `casos/NNN-distro-hardware.md`.

| # | Distro | Runtime | Hardware HID problemático |
|---|--------|---------|---------------------------|
| 001 | Bazzite 43 | Steam + Proton 10.0-4 | Logitech PRO X, Logitech Lightspeed, Kingston HyperX |

## Referencias técnicas

- ProtonDB notes sobre `PROTON_NO_UDEV_JOYSTICK`
- Wine wiki sobre `DirectInput` y `userdef.reg`
- SDL docs sobre `SDL_GAMECONTROLLER_IGNORE_DEVICES`
- `extest` source: https://gitlab.steamos.cloud/holo/extest

## Contribuir

Ver [`CONTRIBUTING.md`](../../../CONTRIBUTING.md) en la raíz del repositorio.
