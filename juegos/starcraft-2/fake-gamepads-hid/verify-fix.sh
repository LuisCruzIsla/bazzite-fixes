#!/bin/bash
# Verificación del fix de gamepads falsos en SC2 (4 capas)
# Uso: ./verify-fix.sh
#
# Adapta TARGET_VIDS si tus dispositivos problemáticos no son
# Logitech (046d) o Kingston (0951).

set -u

TARGET_VIDS="046d 0951"

echo "=== Capa 1: udev rule activa para HID problemáticos ==="
found=0
for ev in /dev/input/event*; do
  props=$(udevadm info -q property -n "$ev" 2>/dev/null)
  vid=$(echo "$props" | grep -E "^ID_VENDOR_ID=" | cut -d= -f2)
  pid=$(echo "$props" | grep -E "^ID_MODEL_ID=" | cut -d= -f2)
  js=$(echo  "$props" | grep -E "^ID_INPUT_JOYSTICK=" | cut -d= -f2)
  name=$(echo "$props" | grep -E "^NAME=" | cut -d= -f2- | tr -d '"')
  for tv in $TARGET_VIDS; do
    if [ "$vid" = "$tv" ]; then
      status="JOYSTICK=${js:-UNSET}"
      [ "$js" = "0" ] && marker="[OK]" || marker="[X]"
      printf "  %s %-10s [%s:%s] %-40s %s\n" "$marker" "$(basename "$ev")" "$vid" "$pid" "$name" "$status"
      found=1
      break
    fi
  done
done
[ "$found" = 0 ] && echo "  (sin dispositivos coincidentes — adapta TARGET_VIDS al inicio del script)"

echo
echo "=== Capa 2: wrapper strip-extest activo ==="
target_pids=$(pgrep -f "Battle.net.exe|SC2_x64" 2>/dev/null)
if [ -z "$target_pids" ]; then
  echo "  (Battle.net/SC2 no están corriendo — lanza el juego y vuelve a verificar)"
else
  bad=0
  for pid in $target_pids; do
    if grep -q "libextest" /proc/$pid/maps 2>/dev/null; then
      echo "  [X] PID $pid tiene libextest CARGADO"
      bad=1
    fi
    ld=$(tr '\0' '\n' < /proc/$pid/environ 2>/dev/null | grep "^LD_PRELOAD=" | head -1)
    if echo "$ld" | grep -q "libextest"; then
      echo "  [X] PID $pid: LD_PRELOAD aún contiene libextest"
      bad=1
    fi
  done
  [ "$bad" = 0 ] && echo "  [OK] Sin libextest cargado en ningún proceso Battle.net/SC2"
fi

echo
echo "=== Capa 3: env vars heredadas en SC2 ==="
sc2_pid=$(pgrep -f "SC2_x64.exe" | head -1)
if [ -n "$sc2_pid" ]; then
  for var in PROTON_NO_XINPUT PROTON_NO_UDEV_JOYSTICK SDL_JOYSTICK_DISABLED SDL_JOYSTICK_HIDAPI; do
    val=$(tr '\0' '\n' < /proc/$sc2_pid/environ 2>/dev/null | grep "^$var=" | cut -d= -f2-)
    if [ -n "$val" ]; then
      printf "  [OK] %-30s = %s\n" "$var" "$val"
    else
      printf "  [X]  %-30s = NO SET\n" "$var"
    fi
  done
else
  echo "  (SC2 no está corriendo — verificación parcial)"
fi

echo
echo "=== Mando real (si aplica) ==="
if ls /dev/input/js* >/dev/null 2>&1; then
  for js in /dev/input/js*; do
    name=$(udevadm info -q property -n "$js" 2>/dev/null | grep -E "^NAME=" | cut -d= -f2- | tr -d '"')
    echo "  [OK] $(basename "$js"): $name"
  done
else
  echo "  (sin /dev/input/js* — ningún mando conectado)"
fi
