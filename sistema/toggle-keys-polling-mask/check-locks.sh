#!/bin/bash
# Verifica que NumLock, CapsLock y ScrollLock NO estén en estado "lock on".
# Si alguno está activo, devuelve exit code 1 y lista cuáles.
#
# Usar como paso 0 en cualquier debug de polling de teclado en juegos
# y aplicaciones que polean `XQueryKeymap` / `GetAsyncKeyState`.

set -u

echo "=== Estado de toggle keys (NumLock, CapsLock, ScrollLock) ==="
echo

LOCKED_FOUND=0

for led in /sys/class/leds/input*::numlock /sys/class/leds/input*::capslock /sys/class/leds/input*::scrolllock; do
  test -e "$led" || continue
  name=$(basename "$led")
  value=$(cat "$led/brightness" 2>/dev/null)
  if [ "$value" = "1" ]; then
    echo "[X] $name=1  → tecla en estado lock on"
    LOCKED_FOUND=1
  else
    echo "[OK] $name=$value"
  fi
done

echo

if [ $LOCKED_FOUND -eq 0 ]; then
  echo "[OK] Ninguna toggle key activa. Polling de teclado limpio."
  exit 0
else
  echo
  echo "Acción: apaga las teclas marcadas con [X] presionándolas físicamente"
  echo "  - NumLock / Bloq Num (en TKL: Fn + N o Fn + Tab según modelo)"
  echo "  - CapsLock / Bloq Mayús (sobre Shift izquierdo)"
  echo "  - ScrollLock / Bloq Despl (fila superior junto a Pause)"
  echo
  echo "Alternativa por software (puede no funcionar si una app captura el foco):"
  echo "  xdotool key Num_Lock"
  echo "  xdotool key Caps_Lock"
  echo "  xdotool key Scroll_Lock"
  exit 1
fi
