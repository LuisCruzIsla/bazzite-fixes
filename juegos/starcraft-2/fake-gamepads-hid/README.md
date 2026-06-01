# StarCraft II: dispositivos HID detectados como mandos virtuales

> **Estado:** solución confirmada y validada, sobrevive a suspend/resume y actualizaciones.
> Las cuatro capas descritas a continuación eliminan el problema de forma persistente.

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

> **Síntoma relacionado pero distinto:** si el **cuadro de captura de hotkeys** en el menú de teclas rápidas no detecta ninguna pulsación (o detecta siempre la misma tecla equivocada), el problema **no es éste**. Es un debug multi-capa que puede involucrar hasta 5 capas (XKB desync, Xalia de Proton 10, IBus, toggle keys atascados, además del Steam Input que sí cubre este fix). Ver el meta-documento [`../hotkey-capture-debug-multicapa/`](../hotkey-capture-debug-multicapa/) que orquesta las 5 capas. Los fixes son complementarios — el wrapper de este problema cubre las capas 1-3.

## Causa raíz

Tres capas independientes contribuyen al problema. **Las guías comunes parchean sólo una y por eso fallan intermitentemente o tras suspend/resume:**

1. **Kernel/udev:** dispositivos HID con múltiples interfaces reciben el flag `ID_INPUT_JOYSTICK=1` heurísticamente.
2. **Steam Input (`libextest.so`):** Steam inyecta esta librería vía `LD_PRELOAD` en procesos lanzados desde Steam (Battle.net Launcher y sus hijos, incluido SC2). Intercepta HID raw y emite gamepads virtuales **dentro del proceso**, evadiendo cualquier filtro a nivel kernel.
3. **Wine/Proton:** la regeneración del prefix (al actualizar Battle.net o al reiniciar Proton) borra las claves `HKCU\Software\Wine\DirectInput\Joysticks\*` con `Disabled=Y`.

La capa de Steam Input es la causa más persistente y suele pasar desapercibida porque opera dentro del binario, no en el sistema. **Y se reactiva sola tras suspend o tras una actualización de Steam, incluso si "Steam Input" está marcado como desactivado en propiedades del juego.**

## Soluciones que NO funcionan (anti-patrones)

- Detener `input-remapper.service` — no tiene relación con el problema.
- Scripts monitor en bucle que paran servicios cada N segundos.
- `WINEDLLOVERRIDES=xinput1_3=` solo — Proton regenera el prefix y se pierde.
- Modificar `user.reg` directamente — Wine lo reescribe.
- **Desactivar Steam Input sólo desde la UI de Steam** — funciona temporalmente, pero se reactiva tras suspend/resume o al actualizarse Steam. No es solución definitiva.

## Solución completa (cuatro capas redundantes)

### Capa 1: Regla udev (nivel kernel, persistente)

Crear `/etc/udev/rules.d/99-sc2-disable-fake-gamepads.rules` con los VID:PID de **tus** dispositivos problemáticos:

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

### Capa 2: Wrapper que strip `libextest.so` (la más importante)

Steam puede reactivar Steam Input por su cuenta. Para no depender de la UI, interceptamos el `LD_PRELOAD` justo antes de que el juego arranque y eliminamos `libextest.so` quirúrgicamente — sin tocar `gameoverlayrenderer.so` (overlay de Steam) que va en la misma variable.

Copiar [`strip-extest.sh`](./strip-extest.sh) a tu PATH local:

```bash
mkdir -p ~/.local/bin
cp strip-extest.sh ~/.local/bin/strip-extest.sh
chmod +x ~/.local/bin/strip-extest.sh
```

Después, en **Steam → Battle.net → Propiedades → Opciones de inicio**, anteponer la ruta del wrapper a `%command%`:

```
... /home/<TU_USUARIO>/.local/bin/strip-extest.sh %command%
```

(Las variables de entorno de la Capa 3 van antes — ver siguiente sección.)

Una vez aplicado el wrapper, **es irrelevante** si Steam Input aparece como "habilitado" o "desactivado" en propiedades del juego — el wrapper neutraliza `libextest` independientemente.

### Capa 3: Variables de entorno en launch options de Steam

Las launch options completas, combinando Capa 2 y 3:

```
PROTON_NO_XINPUT=1 PROTON_NO_UDEV_JOYSTICK=1 SDL_JOYSTICK_DISABLED=1 SDL_JOYSTICK_HIDAPI=0 SDL_GAMECONTROLLER_IGNORE_DEVICES=0xVVVV/0xPPPP,... /home/<TU_USUARIO>/.local/bin/strip-extest.sh %command%
```

Reemplaza `0xVVVV/0xPPPP` por tus VID:PID en mayúscula hexadecimal, y `<TU_USUARIO>` por tu usuario.

| Variable | Función |
|----------|---------|
| `PROTON_NO_XINPUT=1` | Proton no expone API XInput al juego |
| `PROTON_NO_UDEV_JOYSTICK=1` | Proton no usa detección udev para joysticks |
| `SDL_JOYSTICK_DISABLED=1` | SDL ignora el subsistema joystick |
| `SDL_JOYSTICK_HIDAPI=0` | SDL no usa la ruta HIDAPI |
| `SDL_GAMECONTROLLER_IGNORE_DEVICES` | Lista negra explícita por VID/PID |

Las env vars y el `LD_PRELOAD` limpio se heredan automáticamente del Battle.net launcher a SC2_x64 — no hace falta configurar nada dentro del launcher de Battle.net.

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
- Sin `libextest.so` cargado en procesos Battle.net ni SC2
- Variables `PROTON_*` y `SDL_*` heredadas en SC2
- Mandos reales (Xbox, PS) siguen apareciendo como `/dev/input/js0`

## Por qué esto sobrevive a actualizaciones y suspend/resume

| Capa | Lo que sobrevive |
|------|------------------|
| udev rule | Actualizaciones de Battle.net, regeneración del prefix, cambios de Proton, suspend/resume |
| Wrapper strip-extest | Reactivaciones de Steam Input por suspend, actualizaciones de Steam, sync de Steam Cloud |
| Launch options | Permanece a menos que se editen |
| `userdef.reg` | Wine lo respeta al regenerar `user.reg` automáticamente |

Las cuatro capas son redundantes a propósito: si una falla (por ejemplo una actualización de Proton cambia el comportamiento de las env vars), las otras siguen activas.

## Diagnóstico si vuelve a fallar

1. Verificar que ningún proceso de Battle.net o SC2 tenga `libextest` cargado:
   ```bash
   for pid in $(pgrep -f "Battle.net.exe|SC2_x64"); do
     grep -l "libextest" /proc/$pid/maps 2>/dev/null && echo "PID $pid: TIENE libextest"
   done
   ```
   Si alguno tiene → el wrapper no se ejecutó. Verificar las launch options en Steam.

2. Verificar regla udev:
   ```bash
   udevadm info -q property -n /dev/input/event<N> | grep JOYSTICK
   ```

3. Verificar registro Wine:
   ```bash
   grep "Joysticks" <prefix>/user.reg
   ```

4. Verificar que el wrapper limpia correctamente:
   ```bash
   tr '\0' '\n' < /proc/$(pgrep -f Battle.net.exe | head -1)/environ | grep LD_PRELOAD
   ```
   No debe contener `libextest`.

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
