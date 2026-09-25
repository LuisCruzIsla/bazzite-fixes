#!/bin/bash
# Verifica que StarCraft: Remastered se ejecuta desde una letra de unidad
# propia (no Z:) y que su descargador recibe datos del CDN.
# Uso: ./verify-fix.sh <APPID>   (o la ruta completa del prefix)

set -u

ok=0
arg=${1:-}
if [ -z "$arg" ]; then
  for d in "$HOME"/.local/share/Steam/steamapps/compatdata/*/; do
    [ -d "$d/pfx/drive_c/ProgramData/Battle.net" ] && { arg=$(basename "$d"); break; }
  done
fi
if [ -d "$arg/dosdevices" ]; then
  PFX=$arg
else
  PFX="$HOME/.local/share/Steam/steamapps/compatdata/$arg/pfx"
fi
if [ ! -d "$PFX/dosdevices" ]; then
  echo "[X] no se encontro el prefix. Uso: $0 <APPID|ruta-del-prefix>"
  exit 1
fi
echo "prefix: $PFX"

echo
echo "=== Capa 1: letra de unidad propia en el prefix ==="
DRIVES=()
for l in "$PFX"/dosdevices/[a-y]:; do
  [ -L "$l" ] || continue
  name=$(basename "$l")
  [ "$name" = "c:" ] && continue
  tgt=$(readlink "$l")
  if [ "$tgt" = "/" ]; then
    continue
  elif [ -d "$tgt" ]; then
    echo "  [OK] $name -> $tgt"
    DRIVES+=("${name%:}")
  else
    echo "  [X]  $name -> $tgt (el destino no existe)"
    ok=1
  fi
done
if [ ${#DRIVES[@]} -eq 0 ]; then
  echo "  [X]  no hay ninguna letra aparte de c: y z: (ver README, Paso 1)"
  ok=1
fi

echo
echo "=== Capa 2: ruta del juego guardada por el Agent ==="
AG="$PFX/drive_c/ProgramData/Battle.net/Agent"
SC_PATH=$(strings "$AG/product.db" 2>/dev/null | grep -oE '[A-Za-z]:/[^"]*StarCraft$' | head -1)
if [ -z "$SC_PATH" ]; then
  echo "  [X]  no se encontro la ruta de StarCraft en $AG/product.db"
  ok=1
elif [[ "$SC_PATH" =~ ^[Zz]: ]]; then
  echo "  [X]  $SC_PATH -- sigue en Z:, relocalizar el juego (ver README, Paso 2)"
  ok=1
else
  echo "  [OK] $SC_PATH"
fi

echo
echo "=== Capa 3: fallos de volumen en el ultimo log del Agent ==="
LOG=$(ls -t "$AG"/Agent.*/Logs/Agent-*.log 2>/dev/null | head -1)
if [ -n "$LOG" ]; then
  n=$(grep 'volume information' "$LOG" | grep -cE '/StarCraft(/Data)?$')
  if [ "$n" -eq 0 ]; then
    echo "  [OK] sin fallos de volumen para la ruta de StarCraft ($(basename "$LOG"))"
  else
    echo "  [X]  $n fallos de volumen para la ruta de StarCraft ($(basename "$LOG"))"
    ok=1
  fi
else
  echo "  [--] no hay logs del Agent todavia"
fi

echo
echo "=== Capa 4: el descargador del juego recibe datos ==="
NG="$PFX/drive_c/users/steamuser/AppData/Roaming/Blizzard/StarCraft/SCR-NGDP-DiagnosticLog.txt"
if [ -f "$NG" ]; then
  last=$(grep -n 'NGDP initialization' "$NG" | tail -1 | cut -d: -f1)
  got=$(grep -c 'totalbytes=[1-9]' "$NG")
  if [ "$got" -gt 0 ]; then
    echo "  [OK] $got registros con bytes recibidos del CDN en el historial"
  else
    echo "  [X]  ninguna sesion ha recibido bytes del CDN"
    ok=1
  fi
  echo "       ultima sesion: $(sed -n "${last}p" "$NG" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}')"
  echo "       (el resumen de bytes de una sesion se escribe al cerrar el juego)"
else
  echo "  [--] el juego aun no se ha ejecutado en este prefix"
fi

echo
echo "=== Capa 5: proceso en ejecucion (informativo) ==="
cmd=$(pgrep -xa StarCraft.exe 2>/dev/null | head -1 | cut -d' ' -f2-)
if [ -n "$cmd" ]; then
  if [[ "$cmd" =~ ^[Zz]: ]]; then
    echo "  [X]  el juego se lanzo desde $cmd"
    ok=1
  else
    echo "  [OK] $cmd"
  fi
else
  echo "  [--] el juego no esta corriendo; comprobacion omitida"
fi

echo
echo "=== Resultado ==="
if [ "$ok" -eq 0 ]; then
  echo "  [OK] StarCraft: Remastered fuera de Z: y descargando del CDN."
else
  echo "  [X]  Revisar los pasos marcados. Ver README (Solucion completa)."
fi
exit "$ok"
