#!/usr/bin/env bash
# Activa MangoHud en todos los juegos Vulkan sin tocar las opciones de lanzamiento.
#
# Copia los manifiestos de la capa implicita al directorio del usuario quitandoles
# el bloque "enable_environment", que es lo que obliga a declarar MANGOHUD=1 por juego.
# Conserva "disable_environment" para poder excluir juegos con DISABLE_MANGOHUD=1.
#
# No requiere sudo y no modifica /usr (inmutable en Fedora Atomic).

set -euo pipefail

SYS_DIR="/usr/share/vulkan/implicit_layer.d"
USR_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/vulkan/implicit_layer.d"

echo "=== Activando MangoHud globalmente ==="
echo

if ! command -v python3 >/dev/null 2>&1; then
    echo "[X] python3 no disponible — necesario para reescribir los manifiestos"
    exit 1
fi

mkdir -p "$USR_DIR"

found=0
for arch in x86_64 x86; do
    src="$SYS_DIR/MangoHud.$arch.json"

    if [ ! -r "$src" ]; then
        echo "[!] No existe $src — se omite la capa $arch"
        continue
    fi

    dst="$USR_DIR/MangoHud.$arch.json"

    python3 - "$src" "$dst" <<'PY'
import json, sys

src, dst = sys.argv[1], sys.argv[2]
with open(src) as f:
    data = json.load(f)

removed = data["layer"].pop("enable_environment", None)

with open(dst, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

print("    enable_environment eliminado" if removed else "    ya no tenia enable_environment")
PY

    echo "[OK] $dst"
    found=$((found + 1))
done

echo

if [ "$found" -eq 0 ]; then
    echo "[X] No se encontro ningun manifiesto de MangoHud en $SYS_DIR"
    echo "    Instalar MangoHud primero (viene preinstalado en Bazzite)"
    exit 1
fi

echo "Listo: $found capa(s) activada(s)."
echo "Verificar con ./verify-fix.sh — no hace falta reiniciar la sesion."
echo
echo "Para revertir:"
echo "  rm $USR_DIR/MangoHud.*.json"
