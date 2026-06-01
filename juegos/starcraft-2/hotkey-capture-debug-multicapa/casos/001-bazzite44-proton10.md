# 001 — Bazzite 44 + StarCraft II + Proton 10.0-4

- **Confirmado por:** [@LuisCruzIsla](https://github.com/LuisCruzIsla)
- **Fecha:** 2026-06-01
- **Estado:** Las 5 capas aplicadas y validadas

## Entorno

| Componente | Versión |
|------------|---------|
| Distro | Bazzite 44 (`bazzite-gnome-nvidia-open:stable`, build 44.20260515) |
| Compositor | GNOME Wayland (Mutter), kernel 6.19.x |
| Proton | 10.0-4 |
| Juego | StarCraft II (Battle.net via Steam, AppID 3990503939) |
| Hardware | Ryzen 9 5900X + RTX 5070 Ti + 16 GB RAM |
| Teclado | Kingston HyperX Alloy Origins Core (TKL, sin numpad físico, sin LEDs visibles para locks) |

## Historia del debug

Cronología del debug (resumida) del 2026-05 al 2026-06-01:

1. **Mayo 2026:** detectado problema "fake gamepads" en cuadro de hotkeys SC2. Resuelto con wrapper `strip-extest.sh` + udev rules + Wine registry override → documentado en `juegos/starcraft-2/fake-gamepads-hid/`.
2. **2026-05-28:** descubierto segundo síntoma: cuadro de hotkeys con 0 detección aunque resto del juego funcione. Causa: XKB desync. Documentado en `sistema/xwayland-keymap-desync/`.
3. **2026-06-01:** tras actualizar a Proton 10, el problema vuelve con sintomatología similar pero el fix XKB ya no lo resuelve. Identificada **Xalia** como capa 3 (nueva en Proton 10). Tras matar Xalia → SC2 detecta teclas en sesión activa.
4. **Mismo día:** tras reiniciar SC2, vuelve a fallar pese a `PROTON_USE_XALIA=0` en wrapper. Identificada **IBus** como capa 4 (ibus-x11 hace XGrabKey).
5. **Mismo día:** tras desactivar IBus, el cuadro **detecta** pero reporta siempre "Bloq Num". Identificada capa 5: NumLock atascado físicamente en el HyperX TKL (sin LEDs visibles para detectarlo a simple vista).
6. **Apagados NumLock + CapsLock con `xdotool` + tecla física:** cuadro de hotkeys finalmente captura teclas correctamente.

Duración total del debug del 2026-06-01: ~3 horas. El cambio de naturaleza del síntoma fue la pista clave en cada transición de capa.

## Aplicación combinada de las 5 capas

### Capa 1 — Steam Input

Wrapper `~/.local/bin/strip-extest.sh` ya estaba en uso desde mayo 2026 (ver `juegos/starcraft-2/fake-gamepads-hid/casos/001-*`).

### Capa 2 — XKB sync

Una sola input source en GNOME: `us+altgr-intl`. Antes había `latam` adicional que se quitó. Sin desync activo.

### Capa 3 — Xalia

Añadido al wrapper `~/.local/bin/strip-extest.sh`:

```bash
export PROTON_USE_XALIA=0
```

### Capa 4 — IBus

Creados los 4 archivos del fix:

```
~/.config/autostart/ibus-mozc-launch-xwayland.desktop  (Hidden=true)
~/.config/environment.d/99-no-ibus.conf                (vars vacías)
~/.local/bin/ibus-toggle.sh                            (toggle on/off)
~/.local/share/applications/ibus-toggle.desktop        (lanzador doble click)
```

Sesión actual limpiada con `pkill -x ibus-daemon` y procesos hijos.

### Capa 5 — Toggle keys

Apagados con `xdotool key Num_Lock` y `xdotool key Caps_Lock`. El HyperX TKL no tiene LEDs visibles, verificado vía `/sys/class/leds/input*::numlock/brightness`.

### Wrapper final

```bash
#!/bin/bash
# ~/.local/bin/strip-extest.sh — capas 1, 2 y 3 en un solo wrapper

clean_preload() {
  echo "$1" | tr ':' '\n' | grep -v 'libextest' | paste -sd ':' -
}

export LD_PRELOAD="$(clean_preload "$LD_PRELOAD")"
export WINE_LD_PRELOAD="$(clean_preload "$WINE_LD_PRELOAD")"

if [ -n "$DISPLAY" ] && command -v setxkbmap >/dev/null 2>&1; then
  setxkbmap us -variant altgr-intl 2>/dev/null || true
fi

export PROTON_USE_XALIA=0

exec "$@"
```

Launch options de Steam:

```
PROTON_NO_XINPUT=1 PROTON_NO_UDEV_JOYSTICK=1 SDL_JOYSTICK_DISABLED=1 SDL_JOYSTICK_HIDAPI=0 SDL_GAMECONTROLLER_IGNORE_DEVICES=0x046D/0x0AAA,0x046D/0xC539,0x0951/0x16E6 /home/<user>/.local/bin/strip-extest.sh %command%
```

## Salida de `verify-fix.sh` end-to-end

```
=== Verificación end-to-end SC2 hotkey capture (5 capas) ===

--- Capa 1: Steam Input (libextest) ---
[OK] libextest no inyectado en SC2_x64.exe (PID 144377)

--- Capa 2: XWayland keymap sync ---
XWayland: layout=us variant=altgr-intl
GNOME:    [('xkb', 'us+altgr-intl')]
[OK] XWayland sincronizado con GNOME

--- Capa 3: Proton Xalia ---
[OK] xalia.exe NO está corriendo
[OK] PROTON_USE_XALIA=0 en environ de SC2

--- Capa 4: IBus ---
[OK] Sin procesos IBus activos

--- Capa 5: Toggle keys (NumLock/CapsLock/ScrollLock) ---
[OK] Todos los locks en 0

=== Resumen ===
[OK] Las 5 capas limpias — el cuadro de hotkeys debe capturar teclas correctamente
```

## Notas adicionales

- El **cambio de naturaleza del síntoma** ("no detecta" → "detecta Bloq Num siempre") es la pista clave que reveló la capa 5. Documentado como feedback meta en la memoria del proyecto.
- Las 5 capas son **independientes** entre sí — cada una puede romperse en updates futuras sin tocar las otras. El wrapper local (capas 1-3) es la pieza más resistente; las capas 4 (IBus) y 5 (locks) requieren mantenimiento manual.
- Recomendado correr `verify-fix.sh` end-to-end después de cualquier update de Proton o del sistema base, antes de notar el problema en partida.
