#!/bin/bash
# Verifica que Xalia (proxy AT-SPI de Proton 10+) no esté interfiriendo con
# el polling de teclado del juego en curso.
#
# Uso:
#   ./verify-fix.sh                  → busca cualquier proceso *_x64.exe
#   ./verify-fix.sh <nombre.exe>     → busca un binario específico

set -u

GAME_BIN="${1:-}"
EXIT_CODE=0

echo "=== Verificación: Proton Xalia desactivada ==="
echo

# Capa 1: proceso xalia.exe
if pgrep -af 'xalia\.exe' >/dev/null 2>&1; then
  echo "[X] xalia.exe está corriendo:"
  pgrep -af 'xalia\.exe' | grep -v 'pgrep\|bash -c'
  EXIT_CODE=1
else
  echo "[OK] xalia.exe NO está corriendo"
fi
echo

# Capa 2: variable PROTON_USE_XALIA en proceso del juego
if [ -n "$GAME_BIN" ]; then
  GAME_PID=$(pgrep -f "$GAME_BIN" | head -1)
else
  GAME_PID=$(pgrep -f "_x64\.exe" | head -1)
fi

if [ -z "$GAME_PID" ]; then
  echo "[!] Ningún proceso de juego corriendo — lanza el juego y ejecuta de nuevo."
  exit $EXIT_CODE
fi

GAME_NAME=$(cat /proc/"$GAME_PID"/comm 2>/dev/null)
echo "Proceso del juego detectado: PID=$GAME_PID name=$GAME_NAME"

XALIA_VAR=$(cat /proc/"$GAME_PID"/environ 2>/dev/null | tr '\0' '\n' | grep "^PROTON_USE_XALIA=")
case "$XALIA_VAR" in
  "PROTON_USE_XALIA=0")
    echo "[OK] PROTON_USE_XALIA=0 está presente en el entorno del juego"
    ;;
  "PROTON_USE_XALIA=1")
    echo "[X] PROTON_USE_XALIA=1 — el wrapper o las launch options no se aplicaron"
    echo "    Revisar Steam → Propiedades → Opciones de lanzamiento o el wrapper local"
    EXIT_CODE=1
    ;;
  "")
    echo "[!] PROTON_USE_XALIA no definida — Proton usará default (1 en 10.x)"
    echo "    Recomendado: exportar PROTON_USE_XALIA=0 en el wrapper o launch options"
    EXIT_CODE=1
    ;;
esac

exit $EXIT_CODE
