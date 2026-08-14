#!/usr/bin/env bash
# Verifica que la capa Vulkan de MangoHud este activa globalmente, sin depender
# de MANGOHUD=1 en las opciones de lanzamiento.
#
# Uso:
#   ./verify-fix.sh                  -> solo chequeos de sistema
#   ./verify-fix.sh <nombre.exe>     -> ademas inspecciona el proceso del juego

set -u

GAME_BIN="${1:-}"
SYS_DIR="/usr/share/vulkan/implicit_layer.d"
USR_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/vulkan/implicit_layer.d"
EXIT_CODE=0

echo "=== Verificacion: MangoHud global ==="
echo

# Capa 1: manifiestos presentes en el directorio del usuario
echo "--- Capa 1: manifiestos de usuario ---"
for arch in x86_64 x86; do
    f="$USR_DIR/MangoHud.$arch.json"
    if [ -r "$f" ]; then
        echo "[OK] presente: MangoHud.$arch.json"
    else
        echo "[X]  falta: $f"
        echo "     Ejecutar ./enable-mangohud-global.sh"
        EXIT_CODE=1
    fi
done
echo

# Capa 2: enable_environment eliminado
# La comilla inicial del patron ya distingue "enable_environment" de
# "disable_environment": en este ultimo, antes de 'enable' va 'dis', no una comilla.
echo "--- Capa 2: enable_environment eliminado ---"
for arch in x86_64 x86; do
    f="$USR_DIR/MangoHud.$arch.json"
    [ -r "$f" ] || continue
    if grep -q '"enable_environment"' "$f"; then
        echo "[X]  MangoHud.$arch.json conserva enable_environment"
        echo "     La capa seguira exigiendo MANGOHUD=1 por juego"
        EXIT_CODE=1
    else
        echo "[OK] MangoHud.$arch.json sin enable_environment"
    fi
done
echo

# Capa 3: disable_environment conservado (escape hatch por juego)
echo "--- Capa 3: escape hatch DISABLE_MANGOHUD ---"
for arch in x86_64 x86; do
    f="$USR_DIR/MangoHud.$arch.json"
    [ -r "$f" ] || continue
    if grep -q 'DISABLE_MANGOHUD' "$f"; then
        echo "[OK] MangoHud.$arch.json conserva DISABLE_MANGOHUD"
    else
        echo "[!]  MangoHud.$arch.json sin DISABLE_MANGOHUD"
        echo "     No se podra excluir juegos individuales por variable"
    fi
done
echo

# Capa 4: library_path de usuario coincide con la del sistema (copia no obsoleta)
echo "--- Capa 4: copia de usuario al dia ---"
for arch in x86_64 x86; do
    u="$USR_DIR/MangoHud.$arch.json"
    s="$SYS_DIR/MangoHud.$arch.json"
    [ -r "$u" ] && [ -r "$s" ] || continue
    up=$(grep -oE '"library_path"[^,}]*' "$u" | head -1)
    sp=$(grep -oE '"library_path"[^,}]*' "$s" | head -1)
    if [ "$up" = "$sp" ]; then
        echo "[OK] library_path $arch coincide con el sistema"
    else
        echo "[X]  library_path $arch difiere del sistema"
        echo "     usuario: $up"
        echo "     sistema: $sp"
        echo "     MangoHud se actualizo — reejecutar ./enable-mangohud-global.sh"
        EXIT_CODE=1
    fi
done
echo

# Capa 5: el cargador enumera la capa SIN la variable en el entorno
echo "--- Capa 5: el cargador de Vulkan la enumera ---"
if command -v vulkaninfo >/dev/null 2>&1; then
    if env -u MANGOHUD vulkaninfo --summary 2>/dev/null | grep -qi 'VK_LAYER_MANGOHUD'; then
        echo "[OK] capa enumerada sin MANGOHUD en el entorno"
        env -u MANGOHUD vulkaninfo --summary 2>/dev/null \
            | grep -i 'VK_LAYER_MANGOHUD' | sed 's/^/     /'
    else
        echo "[X]  el cargador no enumera VK_LAYER_MANGOHUD"
        EXIT_CODE=1
    fi
else
    echo "[!]  vulkaninfo no disponible — se omite este chequeo"
    echo "     Instalar con: rpm-ostree install vulkan-tools"
fi
echo

# Capa 6: proceso del juego (opcional)
echo "--- Capa 6: proceso del juego ---"
if [ -z "$GAME_BIN" ]; then
    echo "[!]  Sin argumento — se omite."
    echo "     Con el juego corriendo: ./verify-fix.sh <nombre.exe>"
    exit $EXIT_CODE
fi

GAME_PID=""
for pid in $(pgrep -f "$GAME_BIN" 2>/dev/null); do
    [ "$pid" = "$$" ] && continue
    [ -r "/proc/$pid/maps" ] || continue
    case "$(cat "/proc/$pid/comm" 2>/dev/null)" in
        bash|sh|zsh|pgrep|grep|verify-fix.sh) continue ;;
    esac
    GAME_PID="$pid"
    break
done

if [ -z "$GAME_PID" ]; then
    echo "[!]  Ningun proceso coincide con '$GAME_BIN' — lanzar el juego y repetir."
    exit $EXIT_CODE
fi

echo "Proceso detectado: PID=$GAME_PID"

if grep -qi 'mangohud' "/proc/$GAME_PID/maps" 2>/dev/null; then
    echo "[OK] libMangoHud.so mapeado en el proceso:"
    grep -oiE '[^ ]*mangohud[^ ]*' "/proc/$GAME_PID/maps" | sort -u | sed 's/^/     /'
else
    echo "[X]  libMangoHud.so NO esta mapeado"
    echo "     En juegos de Steam puede ser que pressure-vessel no monto la ruta:"
    echo "     usar 'mangohud %command%' en ese juego concreto"
    EXIT_CODE=1
fi

ENV_VAR=$(tr '\0' '\n' < "/proc/$GAME_PID/environ" 2>/dev/null | grep -E '^(DISABLE_)?MANGOHUD=')
if [ -z "$ENV_VAR" ]; then
    echo "[OK] sin variables MANGOHUD en el entorno — la carga viene de la capa"
else
    case "$ENV_VAR" in
        DISABLE_MANGOHUD=1)
            echo "[!]  DISABLE_MANGOHUD=1 presente — exclusion explicita de este juego"
            ;;
        *)
            echo "[!]  $ENV_VAR presente — la carga puede venir de las opciones de lanzamiento,"
            echo "     no de la capa global. Quitarla para probar la capa de verdad."
            ;;
    esac
fi

echo
echo "Nota: esto confirma que la capa entro en el proceso, no que el overlay"
echo "se este dibujando. Eso se comprueba a ojo (Shift_R+F10 lo alterna)."

exit $EXIT_CODE
