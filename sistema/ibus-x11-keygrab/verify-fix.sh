#!/bin/bash
# Verifica que IBus esté desactivado y los overrides de autostart/environment
# estén en su sitio.
#
# Uso:
#   ./verify-fix.sh                  → estado general
#   ./verify-fix.sh <pid>            → además, inspecciona el environ del proceso

set -u
EXIT_CODE=0

echo "=== Verificación: IBus desactivado ==="
echo

# 1) Procesos IBus activos
IBUS_PROCS=$(pgrep -af "ibus" 2>/dev/null | grep -v "pgrep\|bash -c" | grep -E "ibus-daemon|ibus-x11|ibus-engine|ibus-typing-booster|ibus-extension|ibus-portal|ibus-dconf")
if [ -z "$IBUS_PROCS" ]; then
  echo "[OK] Sin procesos IBus activos"
else
  echo "[X] Procesos IBus corriendo (toggle off no aplicado o reactivado):"
  echo "$IBUS_PROCS"
  EXIT_CODE=1
fi
echo

# 2) Override de autostart
AUTOSTART_OVERRIDE=$(ls ~/.config/autostart/ibus*.desktop 2>/dev/null)
if [ -n "$AUTOSTART_OVERRIDE" ]; then
  echo "[OK] Override de autostart presente: $AUTOSTART_OVERRIDE"
  if grep -q "Hidden=true\|X-GNOME-Autostart-enabled=false" "$AUTOSTART_OVERRIDE"; then
    echo "[OK] Contiene flag de desactivación"
  else
    echo "[X] El override existe pero NO contiene Hidden=true ni X-GNOME-Autostart-enabled=false"
    EXIT_CODE=1
  fi
else
  echo "[X] Falta override en ~/.config/autostart/"
  echo "    System autostart actual:"
  ls /etc/xdg/autostart/ibus*.desktop 2>/dev/null || echo "    (ninguno — IBus no se autostart en el sistema)"
  EXIT_CODE=1
fi
echo

# 3) Variables de entorno en la sesión actual
echo "Variables IM en sesión:"
env | grep -iE "im_module|xmodifier|gtk_im|qt_im" || echo "(ninguna definida)"
echo

# 4) Si nos pasan un PID, inspeccionar su environ
if [ "${1:-}" != "" ]; then
  PID="$1"
  if [ -r "/proc/$PID/environ" ]; then
    echo "Variables IM en proceso $PID:"
    cat /proc/"$PID"/environ | tr '\0' '\n' | grep -iE "im_module|xmodifier|gtk_im|qt_im" || echo "(ninguna)"
  else
    echo "[!] No se puede leer /proc/$PID/environ"
  fi
fi

exit $EXIT_CODE
