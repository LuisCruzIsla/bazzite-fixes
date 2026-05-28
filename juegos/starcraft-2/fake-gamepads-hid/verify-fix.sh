#!/bin/bash
# Verificación del fix de gamepads falsos en SC2
# Uso: ./verify-fix.sh

set -u

echo "=== Capa 1: udev rule activa para HID problemáticos ==="
found=0
for ev in /dev/input/event*; do
  props=$(udevadm info -q property -n "$ev" 2>/dev/null)
  name=$(echo "$props" | grep -oP '(?<=^NAME=).*' | tr -d '"')
  vid=$(echo "$props" | grep -oP '(?<=^ID_VENDOR_ID=).*')
  pid=$(echo "$props" | grep -oP '(?<=^ID_MODEL_ID=).*')
  js=$(echo "$props"  | grep -oP '(?<=^ID_INPUT_JOYSTICK=).*')
  if echo "$name" | grep -qiE "logitech|kingston|hyperx"; then
    printf "  %-12s [%s:%s] %-50s JOYSTICK=%s\n" \
      "$(basename "$ev")" "${vid:-?}" "${pid:-?}" "$name" "${js:-unset}"
    found=1
  fi
done
[ "$found" = 0 ] && echo "  (sin dispositivos coincidentes — ¿son los correctos?)"

echo
echo "=== Capa 2: Steam Input (libextest) inyectado en SC2 ==="
if pgrep -af "SC2_x64" 2>/dev/null | grep -q "libextest.so"; then
  echo "  PROBLEMA: libextest.so está inyectado → desactiva Steam Input"
else
  echo "  OK — sin libextest en procesos SC2 (o SC2 cerrado)"
fi

echo
echo "=== Capa 3: launch options heredadas ==="
sc2_pid=$(pgrep -f "SC2_x64.exe" | head -1)
if [ -n "$sc2_pid" ]; then
  for var in PROTON_NO_XINPUT PROTON_NO_UDEV_JOYSTICK SDL_JOYSTICK_DISABLED SDL_JOYSTICK_HIDAPI; do
    val=$(tr '\0' '\n' < /proc/$sc2_pid/environ 2>/dev/null | grep "^$var=" | cut -d= -f2-)
    printf "  %-30s = %s\n" "$var" "${val:-NO SET}"
  done
else
  echo "  (SC2 no está corriendo — lanza el juego y vuelve a ejecutar)"
fi

echo
echo "=== Mando real (si aplica) ==="
if ls /dev/input/js* >/dev/null 2>&1; then
  for js in /dev/input/js*; do
    name=$(udevadm info -q property -n "$js" 2>/dev/null | grep -oP '(?<=^NAME=).*' | tr -d '"')
    echo "  OK — $(basename $js): $name"
  done
else
  echo "  (sin /dev/input/js* — ningún mando conectado)"
fi
