# NumLock/CapsLock atascados enmascaran el polling de teclado en juegos y apps

> **Estado:** solución confirmada (chequeo trivial, fácil de pasar por alto)

## Síntoma

Cuadros de captura de hotkeys (juegos RTS/MOBA/FPS, AutoHotkey en Wine, herramientas de macros) reportan **siempre la misma tecla** sin importar qué presione el usuario. Síntoma típico:

```
Vincular tecla rápida:
  → Tecleas A     → muestra "Bloq Num"
  → Tecleas Q     → muestra "Bloq Num"
  → Tecleas Esc   → muestra "Bloq Num"
```

A menudo se confunde con un bug de driver, layout o de la app misma. La causa real es trivial pero invisible si los LEDs del teclado no son visibles a simple vista.

## Quién está afectado

- **Distro:** cualquier distro Linux (X11 o XWayland)
- **Hardware:** cualquier teclado con teclas `NumLock`, `CapsLock` o `ScrollLock` en estado "lock on"
- **Apps afectadas:** cualquier app que use polling de bitmap de estado del teclado (`GetAsyncKeyState` en Win32 traducido por Wine a `XQueryKeymap`, o equivalente directo en X11)
- **Apps que NO se ven afectadas:** las que reciben input por cola de eventos (`WM_KEYDOWN`, `XKeyPress`) — la mayoría de aplicaciones de escritorio

Ver [`casos/`](./casos/) para configuraciones específicas.

## Causa raíz

`XQueryKeymap` devuelve un bitmap de **256 bits** con el estado de cada Virtual Key Code. Una toggle key (NumLock = `VK_NUMLOCK` 0x90, CapsLock = `VK_CAPITAL` 0x14, ScrollLock = `VK_SCROLL` 0x91) que esté en estado "lock on" deja su bit permanentemente activo en el bitmap, independientemente de qué otra tecla se presione.

Las apps que polean el bitmap buscando "qué tecla acaba de presionarse" suelen iterar el bitmap y reportar el primer bit activo encontrado. Si encuentran el bit de NumLock o CapsLock activo, lo reportan en vez de la tecla que el usuario realmente quería capturar.

Esto se enmascara fácilmente con otras capas que interfieren con el polling (input methods, proxies AT-SPI, Steam Input). Solo se nota una vez resueltas esas capas — antes, el síntoma suele ser "no detecta nada" en lugar de "detecta la tecla equivocada".

## Soluciones que NO funcionan (anti-patrones)

- **Cambiar el layout de teclado en GNOME** — no afecta el estado de las toggle keys.
- **Reiniciar el juego o cerrar sesión** — el estado de las toggle keys se persiste en el firmware del teclado, no en software.
- **`setxkbmap us`** — sólo reconfigura el layout, no toca el modifier state.
- **Bind del cuadro de captura a `Esc`** — Esc también muestra "Bloq Num" porque el polling encuentra el bit lock antes.

## Solución

### Paso 1 — Verificar el estado de los LEDs lock

```bash
for led in /sys/class/leds/input*::numlock /sys/class/leds/input*::capslock /sys/class/leds/input*::scrolllock; do
  test -e "$led" && echo "$(basename $led)=$(cat $led/brightness 2>/dev/null)"
done
```

Cualquier valor `=1` significa que esa tecla está en estado "lock on".

### Paso 2 — Apagar las toggle keys

Por hardware (recomendado, más fiable):

- **NumLock:** presiona la tecla `NumLock` / `Bloq Num`. En teclados TKL sin numpad físico, suele ser `Fn + N`, `Fn + Tab` o `Fn + Pause` (varía por modelo).
- **CapsLock:** presiona `CapsLock` / `Bloq Mayús` (sobre Shift izquierdo).
- **ScrollLock:** presiona `ScrollLock` / `Bloq Despl` (fila superior, junto a Pause).

Por software (alternativa si la tecla física no existe o no responde):

```bash
xdotool key Num_Lock
xdotool key Caps_Lock
xdotool key Scroll_Lock
```

Nota: `xdotool` envía el evento al cliente con foco actual. Si el juego/app que polea el teclado tiene el foco, puede consumir el evento sin propagar el cambio de estado — minimizar la app primero, ejecutar `xdotool`, verificar con el script y volver a la app.

### Paso 3 — Re-verificar

Repetir el comando del paso 1. Todos los valores deben ser `0`.

## Verificación

```bash
./check-locks.sh
```

Resultado esperado:

- Todos los LEDs lock en `0`.
- Mensaje de OK por cada device de teclado detectado.

## Por qué sobrevive a actualizaciones

El estado lock se persiste en el firmware del teclado entre reboots. Una vez apagado, suele permanecer así hasta que el usuario lo reactive — pero hay excepciones:

| Trigger | ¿Reactiva locks? |
|---------|------------------|
| Reinicio del sistema | Depende del firmware/BIOS (algunos restauran "NumLock on" al boot) |
| Suspend/resume | Generalmente no, pero algunos teclados RGB sí |
| Aplastar la tecla por accidente | Sí — el toggle es por una sola pulsación |
| Apps que envían `Num_Lock` programáticamente | Sí (raro) |

Si el firmware/BIOS reactiva NumLock al boot, configurar BIOS o usar `numlockx off` (de `brew install numlockx`) en un autostart de la sesión.

## Diagnóstico si vuelve a fallar

```bash
# Estado actual
for led in /sys/class/leds/input*::{numlock,capslock,scrolllock}; do
  test -e "$led" && echo "$(basename $led)=$(cat $led/brightness)"
done

# Modifier mask que ve el servidor X
xset q 2>&1 | grep -iE "led mask|lock"

# Tecla físicamente presionada (para detectar atasques de hardware)
sudo evtest /dev/input/eventN   # N = device del teclado, ver con cat /proc/bus/input/devices
```

Si una toggle key vuelve a activarse sola sin pulsación física, investigar:

1. Otro dispositivo HID conectado (mouse Logitech con macro, gamepad, accesorios con "media keys") que esté emitiendo el evento.
2. Software de macros en background (input-remapper, Solaar para Logitech, etc.).
3. BIOS con "Boot NumLock state = on" — desactivar.

## Casos confirmados

| # | Distro | Hardware |
|---|--------|----------|
| [001](./casos/001-bazzite44-hyperx-sc2.md) | Bazzite 44 | Kingston HyperX Alloy Origins Core (TKL) + SC2 |

## Referencias

- Xlib spec — `XQueryKeymap`
- Win32 API — `GetAsyncKeyState`
- Microsoft docs — Virtual-Key Codes (0x14 VK_CAPITAL, 0x90 VK_NUMLOCK)

## Contribuir

Ver [`CONTRIBUTING.md`](../../CONTRIBUTING.md) en la raíz.
