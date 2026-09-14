#!/bin/bash
# Verifica que la herramienta de compatibilidad parcheada para
# Warcraft III: Reforged esta instalada, asignada y activa en el prefix.
# No hace falta tener el juego abierto.

set -u

ok=0
TOOLS=${STEAM_COMPAT_TOOLS_DIR:-$HOME/.steam/root/compatibilitytools.d}

echo "=== Capa 1: herramienta parcheada instalada ==="
TOOL=$(ls -1d "$TOOLS"/*wc3fix* 2>/dev/null | head -1)
if [ -z "$TOOL" ]; then
  echo "  [X]  no hay ninguna herramienta *wc3fix* en $TOOLS"
  echo "       ejecutar install-wc3fix.sh (ver README, Opcion B)"
  exit 1
fi
TOOL_NAME=$(basename "$TOOL")
echo "  [OK] $TOOL_NAME"
if grep -q "$TOOL_NAME" "$TOOL/compatibilitytool.vdf" 2>/dev/null; then
  echo "  [OK] compatibilitytool.vdf la declara con nombre propio"
else
  echo "  [X]  compatibilitytool.vdf no declara '$TOOL_NAME' -> Steam la listara con el nombre de la build original"
  ok=1
fi

echo
echo "=== Capa 2: las cuatro copias de crypt32.dll estan sustituidas ==="
# La build original de la que se copio: mismo nombre sin el sufijo.
BASE_GUESS=${TOOL_NAME%-wc3fix}
BASE=""
for cand in "$TOOLS/$BASE_GUESS" "$TOOLS/${BASE_GUESS}-x86_64"; do
  [ -d "$cand" ] && { BASE=$cand; break; }
done

paths=(
  "files/lib/wine/x86_64-windows/crypt32.dll"
  "files/lib/wine/i386-windows/crypt32.dll"
  "files/share/default_pfx/drive_c/windows/system32/crypt32.dll"
  "files/share/default_pfx/drive_c/windows/syswow64/crypt32.dll"
)
for p in "${paths[@]}"; do
  f="$TOOL/$p"
  if [ ! -f "$f" ]; then
    echo "  [X]  falta $p"
    ok=1
    continue
  fi
  if ! strings -a "$f" | grep -qx CertCreateCertificateChainEngine; then
    echo "  [X]  $p no exporta CertCreateCertificateChainEngine"
    ok=1
    continue
  fi
  if [ -n "$BASE" ] && [ -f "$BASE/$p" ]; then
    if cmp -s "$f" "$BASE/$p"; then
      echo "  [X]  $p es identica a la de $(basename "$BASE") -> NO esta parcheada"
      ok=1
    else
      echo "  [OK] $p difiere de la build original"
    fi
  else
    echo "  [--] $p presente; sin build original con la que comparar"
  fi
done
[ -z "$BASE" ] && echo "  NOTA: no se encontro la build base ($BASE_GUESS); la comparacion se omitio."

echo
echo "=== Capa 3: asignacion al juego en Steam ==="
CFG=""
for c in "$HOME/.local/share/Steam/config/config.vdf" "$HOME/.steam/steam/config/config.vdf"; do
  [ -r "$c" ] && { CFG=$c; break; }
done
APPID=""
if [ -n "$CFG" ]; then
  APPID=$(awk -v tool="$TOOL_NAME" '
    /^[[:space:]]*"[0-9]+"[[:space:]]*$/ { gsub(/[" \t]/,""); id=$0 }
    /"name"/ && index($0, "\"" tool "\"") { print id; exit }
  ' "$CFG")
fi
if [ -n "$APPID" ]; then
  echo "  [OK] AppID $APPID asignado a $TOOL_NAME"
else
  echo "  [X]  ningun juego tiene asignada $TOOL_NAME en config.vdf"
  echo "       Propiedades -> Compatibilidad -> forzar $TOOL_NAME (ver README, B.3)"
  ok=1
fi

echo
echo "=== Capa 4: DLL efectiva dentro del prefix ==="
if [ -n "$APPID" ]; then
  PFX=""
  sub="steamapps/compatdata/$APPID/pfx"
  for lf in "$HOME/.steam/steam/steamapps/libraryfolders.vdf" \
            "$HOME/.local/share/Steam/steamapps/libraryfolders.vdf"; do
    [ -r "$lf" ] || continue
    while IFS= read -r lib; do
      [ -n "$lib" ] || continue
      [ -d "$lib/$sub" ] && { PFX="$lib/$sub"; break 2; }
    done < <(sed -n 's/^[[:space:]]*"path"[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$lf")
  done
  [ -z "$PFX" ] && [ -d "$HOME/.local/share/Steam/$sub" ] && PFX="$HOME/.local/share/Steam/$sub"

  if [ -n "$PFX" ]; then
    echo "  prefix: $PFX"
    for pair in "system32:files/lib/wine/x86_64-windows/crypt32.dll" \
                "syswow64:files/lib/wine/i386-windows/crypt32.dll"; do
      dir=${pair%%:*}; ref=${pair#*:}
      if cmp -s "$PFX/drive_c/windows/$dir/crypt32.dll" "$TOOL/$ref"; then
        echo "  [OK] drive_c/windows/$dir/crypt32.dll = la version parcheada"
      else
        echo "  [X]  drive_c/windows/$dir/crypt32.dll NO coincide con la de la herramienta"
        echo "       el prefix quedo con la DLL vieja -> copiarla a mano (ver README, B.4)"
        ok=1
      fi
    done
  else
    echo "  [--] no se encontro el prefix del AppID $APPID; se creara al lanzar el juego"
  fi
else
  echo "  [--] sin AppID no se puede comprobar el prefix"
fi

echo
echo "=== Capa 5: proceso en ejecucion (informativo) ==="
pid=$(pgrep -f "Battle.net.exe" 2>/dev/null | head -1)
[ -z "$pid" ] && pid=$(pgrep -f "Warcraft III.exe" 2>/dev/null | head -1)
if [ -n "$pid" ]; then
  if tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | grep -q "$TOOL_NAME"; then
    echo "  [OK] el proceso (pid $pid) corre con $TOOL_NAME"
  else
    echo "  [X]  el proceso (pid $pid) NO usa $TOOL_NAME -- cerrarlo y revisar la asignacion"
    ok=1
  fi
else
  echo "  [--] el juego no esta corriendo; comprobacion omitida"
fi

echo
echo "=== Resultado ==="
if [ "$ok" -eq 0 ]; then
  echo "  [OK] crypt32 corregido en su sitio."
  echo "       Validacion definitiva: iniciar sesion en Battle.net desde el juego."
else
  echo "  [X]  Revisar los pasos marcados. Ver README (Solucion completa)."
fi
exit "$ok"
