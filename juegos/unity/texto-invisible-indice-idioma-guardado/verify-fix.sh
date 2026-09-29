#!/bin/bash
# Verifica que un juego Unity bajo Wine/Proton no tiene guardado un indice de
# idioma fuera de rango en su partida ni en sus PlayerPrefs.
# Uso: ./verify-fix.sh <ruta-del-prefix> <Compania/Producto> [indice-esperado]
#   ej: ./verify-fix.sh ~/Games/umu/mi-prefix FoxInc/HBomb 0

set -u

PFX=${1:-}
APP=${2:-}
EXPECTED=${3:-0}
if [ ! -d "$PFX/drive_c" ] || [ -z "$APP" ]; then
  echo "[X] Uso: $0 <ruta-del-prefix> <Compania/Producto> [indice-esperado]"
  exit 1
fi
ok=0
SAVE="$PFX/drive_c/users/steamuser/AppData/LocalLow/$APP"
KEY='"?_?[A-Za-z]*[Ll]ang(uage)?(Index|Idx|No|ID|Id)"?[[:space:]]*[:=][[:space:]]*-?[0-9]+'

echo "=== Capa 1: indice de idioma en los archivos de guardado ==="
if [ -d "$SAVE" ]; then
  found=0
  while IFS= read -r f; do
    while IFS= read -r m; do
      found=1
      v=$(grep -oE -- '-?[0-9]+$' <<<"$m")
      if [ "$v" = "$EXPECTED" ]; then
        echo "  [OK] $(basename "$f"): $m"
      else
        echo "  [X]  $(basename "$f"): $m (se esperaba $EXPECTED)"
        ok=1
      fi
    done < <(grep -aoE "$KEY" "$f")
  done < <(find "$SAVE" -maxdepth 2 -type f ! -name '*.log' ! -name '*.bak*')
  [ "$found" -eq 0 ] && echo "  [--] ningun campo de indice de idioma en $SAVE"
else
  echo "  [--] no existe $SAVE (el juego aun no se ha ejecutado o el nombre no coincide)"
fi

echo
echo "=== Capa 2: PlayerPrefs en el registro del prefix ==="
REGKEY="Software\\\\\\\\${APP%%/*}\\\\\\\\${APP#*/}"
prefs=$(awk -v k="[$REGKEY]" 'index($0,k)==1{p=1;next} /^\[/{p=0} p' "$PFX/user.reg" 2>/dev/null | grep -iE '^"[^"]*lang')
if [ -n "$prefs" ]; then
  echo "$prefs" | sed 's/^/  [--] /'
  echo "       revisar a mano: un dword distinto de $EXPECTED puede ser la causa"
else
  echo "  [OK] sin PlayerPrefs de idioma"
fi

echo
echo "=== Resultado ==="
if [ "$ok" -eq 0 ]; then
  echo "  [OK] ningun indice de idioma fuera de lo esperado."
else
  echo "  [X]  Corregir el indice marcado (ver README, Solucion completa)."
fi
exit "$ok"
