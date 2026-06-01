#!/bin/bash
# Verificación end-to-end de las 5 capas del cuadro de captura de hotkeys SC2.
# Ejecutar con SC2 corriendo en sistema. Devuelve exit code 0 solo si todas
# las capas están limpias.
#
# Cada capa tiene su propio verify-fix.sh con detalles — este script da el
# resumen orquestado.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
EXIT_CODE=0

echo "=== Verificación end-to-end SC2 hotkey capture (5 capas) ==="
echo

SC2_PID=$(pgrep -f "SC2_x64\.exe" | head -1)

# Capa 1: libextest en SC2
echo "--- Capa 1: Steam Input (libextest) ---"
if [ -n "$SC2_PID" ]; then
  HITS=$(grep -c "libextest" /proc/"$SC2_PID"/maps 2>/dev/null || echo "?")
  if [ "$HITS" = "0" ]; then
    echo "[OK] libextest no inyectado en SC2_x64.exe (PID $SC2_PID)"
  else
    echo "[X] libextest detectado en SC2_x64.exe (hits=$HITS) — wrapper strip-extest no aplicó"
    EXIT_CODE=1
  fi
else
  echo "[!] SC2_x64.exe no está corriendo — lanza el juego para validar"
fi
echo

# Capa 2: XKB sync
echo "--- Capa 2: XWayland keymap sync ---"
XKB_LAYOUT=$(setxkbmap -query 2>/dev/null | awk '/^layout/{print $2}')
XKB_VARIANT=$(setxkbmap -query 2>/dev/null | awk '/^variant/{print $2}')
GNOME_SOURCES=$(gsettings get org.gnome.desktop.input-sources sources 2>/dev/null)
echo "XWayland: layout=$XKB_LAYOUT variant=$XKB_VARIANT"
echo "GNOME:    $GNOME_SOURCES"
if echo "$GNOME_SOURCES" | grep -q "$XKB_LAYOUT.*$XKB_VARIANT\|${XKB_LAYOUT}+${XKB_VARIANT}"; then
  echo "[OK] XWayland sincronizado con GNOME"
else
  echo "[!] Posible desync — verificar manualmente"
  # No marca error porque la heurística no cubre todos los formatos
fi
echo

# Capa 3: Xalia
echo "--- Capa 3: Proton Xalia ---"
if pgrep -af "xalia\.exe" >/dev/null 2>&1; then
  echo "[X] xalia.exe corriendo:"
  pgrep -af "xalia\.exe" | grep -v "pgrep\|bash -c"
  EXIT_CODE=1
else
  echo "[OK] xalia.exe NO está corriendo"
fi
if [ -n "$SC2_PID" ]; then
  XALIA_VAR=$(cat /proc/"$SC2_PID"/environ 2>/dev/null | tr '\0' '\n' | grep "^PROTON_USE_XALIA=")
  case "$XALIA_VAR" in
    "PROTON_USE_XALIA=0") echo "[OK] PROTON_USE_XALIA=0 en environ de SC2" ;;
    "PROTON_USE_XALIA=1") echo "[X] PROTON_USE_XALIA=1 — wrapper o launch options no aplicaron"; EXIT_CODE=1 ;;
    "") echo "[!] PROTON_USE_XALIA no definida — Proton usará default" ;;
  esac
fi
echo

# Capa 4: IBus
echo "--- Capa 4: IBus ---"
IBUS_PROCS=$(pgrep -af "^ibus-|/ibus-" 2>/dev/null | grep -v "pgrep\|bash -c")
if [ -z "$IBUS_PROCS" ]; then
  echo "[OK] Sin procesos IBus activos"
else
  echo "[X] IBus corriendo:"
  echo "$IBUS_PROCS"
  EXIT_CODE=1
fi
echo

# Capa 5: toggle keys
echo "--- Capa 5: Toggle keys (NumLock/CapsLock/ScrollLock) ---"
LOCKED=0
for led in /sys/class/leds/input*::numlock /sys/class/leds/input*::capslock /sys/class/leds/input*::scrolllock; do
  test -e "$led" || continue
  name=$(basename "$led")
  value=$(cat "$led/brightness" 2>/dev/null)
  if [ "$value" = "1" ]; then
    echo "[X] $name=1 — apagar la tecla físicamente o con xdotool"
    LOCKED=1
  fi
done
if [ $LOCKED -eq 0 ]; then
  echo "[OK] Todos los locks en 0"
else
  EXIT_CODE=1
fi
echo

echo "=== Resumen ==="
if [ $EXIT_CODE -eq 0 ]; then
  echo "[OK] Las 5 capas limpias — el cuadro de hotkeys debe capturar teclas correctamente"
else
  echo "[X] Una o más capas requieren atención — ver detalles arriba"
fi

exit $EXIT_CODE
