#!/bin/bash
# Crea una copia de una build de Proton con crypt32.dll sustituido por la
# version corregida en Wine 11.6, necesaria para que Warcraft III: Reforged 3.0
# complete el login de Battle.net. No modifica la build original.
#
#   ./install-wc3fix.sh <carpeta-con-las-dll> [nombre-proton-base]
#
# La carpeta puede tener cualquier estructura: el script localiza los
# crypt32.dll que contenga y los clasifica por arquitectura leyendo la
# cabecera PE, no por el nombre de la carpeta.

set -euo pipefail

SRC=${1:-}
BASE=${2:-}
TOOLS=${STEAM_COMPAT_TOOLS_DIR:-$HOME/.steam/root/compatibilitytools.d}

if [ -z "$SRC" ] || [ ! -d "$SRC" ]; then
  echo "uso: $0 <carpeta-con-las-dll> [nombre-proton-base]" >&2
  exit 2
fi

if [ ! -d "$TOOLS" ]; then
  echo "[X]  no existe $TOOLS -- ¿Steam instalado en otra ruta? usar STEAM_COMPAT_TOOLS_DIR" >&2
  exit 2
fi

if pgrep -x steam >/dev/null 2>&1; then
  echo "[--] Steam esta corriendo. Cierralo por completo (Steam -> Salir) antes de continuar."
  echo "     Steam solo relee compatibilitytools.d al arrancar."
  exit 2
fi

# Elegir la build base: la indicada, o la GE-Proton mas reciente disponible.
if [ -z "$BASE" ]; then
  BASE=$(ls -1d "$TOOLS"/GE-Proton* 2>/dev/null | grep -v -- '-wc3fix' | sort -V | tail -1 | xargs -r basename)
fi
if [ -z "$BASE" ] || [ ! -d "$TOOLS/$BASE" ]; then
  echo "[X]  no se encontro la build base en $TOOLS (indicala como segundo argumento)" >&2
  exit 2
fi

DEST_NAME="${BASE%-x86_64}-wc3fix"
DEST="$TOOLS/$DEST_NAME"

# Clasificar los crypt32.dll de origen por arquitectura (campo Machine del PE).
arch_of() {
  python3 - "$1" <<'PY'
import struct,sys
d=open(sys.argv[1],'rb').read()
off=struct.unpack_from('<I',d,0x3c)[0]
m=struct.unpack_from('<H',d,off+4)[0]
print({0x8664:'x86_64',0x14c:'i386'}.get(m,'?'))
PY
}

DLL64=""; DLL32=""
while IFS= read -r f; do
  case "$(arch_of "$f")" in
    x86_64) DLL64=$f ;;
    i386)   DLL32=$f ;;
  esac
done < <(find "$SRC" -iname 'crypt32.dll' -type f)

if [ -z "$DLL64" ] || [ -z "$DLL32" ]; then
  echo "[X]  faltan DLL en $SRC: x86_64='${DLL64:-no encontrada}' i386='${DLL32:-no encontrada}'" >&2
  echo "     se necesitan las dos arquitecturas; Battle.net es de 32 bits y el juego de 64." >&2
  exit 2
fi

echo "=== Origen ==="
echo "  base   : $TOOLS/$BASE"
echo "  x86_64 : $DLL64"
echo "  i386   : $DLL32"
echo "  destino: $DEST"

for f in "$DLL64" "$DLL32"; do
  if ! strings -a "$f" | grep -qx CertCreateCertificateChainEngine; then
    echo "[X]  $f no exporta CertCreateCertificateChainEngine -- no parece un crypt32 valido" >&2
    exit 1
  fi
done
echo "  [OK] las dos DLL exportan CertCreateCertificateChainEngine"

if [ -e "$DEST" ]; then
  echo "[--] $DEST ya existe. Borralo antes de reinstalar:"
  echo "     rm -rf \"$DEST\""
  exit 2
fi

echo
echo "=== Copiando build base (puede tardar, son varios GB) ==="
cp -a "$TOOLS/$BASE" "$DEST"

echo "=== Sustituyendo crypt32.dll en las cuatro rutas ==="
install -m644 "$DLL64" "$DEST/files/lib/wine/x86_64-windows/crypt32.dll"
install -m644 "$DLL32" "$DEST/files/lib/wine/i386-windows/crypt32.dll"
install -m644 "$DLL64" "$DEST/files/share/default_pfx/drive_c/windows/system32/crypt32.dll"
install -m644 "$DLL32" "$DEST/files/share/default_pfx/drive_c/windows/syswow64/crypt32.dll"
echo "  [OK] lib/wine/{x86_64,i386}-windows y default_pfx/{system32,syswow64}"

echo "=== Renombrando la herramienta ==="
sed -i "s/\"$BASE\"/\"$DEST_NAME\"/g" "$DEST/compatibilitytool.vdf"
if [ -f "$DEST/version" ]; then
  sed -i "s/$BASE/$DEST_NAME/" "$DEST/version"
fi
grep -q "$DEST_NAME" "$DEST/compatibilitytool.vdf" \
  && echo "  [OK] compatibilitytool.vdf declara $DEST_NAME" \
  || { echo "[X]  no se pudo renombrar compatibilitytool.vdf; revisalo a mano" >&2; exit 1; }

echo
echo "=== Listo ==="
echo "  1. Arranca Steam."
echo "  2. Propiedades del acceso directo de Battle.net -> Compatibilidad."
echo "  3. Forzar herramienta de compatibilidad -> $DEST_NAME"
echo "  4. Lanza el juego una vez para que Proton actualice el prefix."
echo "  5. Comprueba con ./verify-fix.sh"
