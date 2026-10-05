#!/usr/bin/env bash
# Verifica que ollama.service tenga lo necesario para arrancar en Fedora Atomic:
# un HOME escribible fuera de /usr y una ruta de modelos que el usuario del
# servicio pueda atravesar.
#
# Uso:
#   ./verify-fix.sh            -> chequeos estaticos + estado actual
#   ./verify-fix.sh --arrancar -> ademas arranca el servicio, comprueba que
#                                 responde y lo deja como estaba

set -u

UNIT="ollama.service"
ARRANCAR="${1:-}"
EXIT_CODE=0

valor_env() {
    systemctl show "$UNIT" -p Environment --value | tr ' ' '\n' | sed -n "s/^$1=//p" | tail -n 1
}

# Devuelve 0 si el usuario $1 puede atravesar (x) el directorio $2.
puede_atravesar() {
    local usuario="$1" dir="$2" modo dueno grupo
    modo=$(stat -c '%a' "$dir") dueno=$(stat -c '%U' "$dir") grupo=$(stat -c '%G' "$dir")
    if command -v getfacl >/dev/null 2>&1 \
        && getfacl -p "$dir" 2>/dev/null | grep -qE "^user:$usuario:..x"; then
        return 0
    fi
    if [ "$dueno" = "$usuario" ]; then
        [ $(( (8#$modo >> 6) & 1 )) -eq 1 ]; return
    fi
    if id -nG "$usuario" 2>/dev/null | tr ' ' '\n' | grep -qx "$grupo"; then
        [ $(( (8#$modo >> 3) & 1 )) -eq 1 ]; return
    fi
    [ $(( 8#$modo & 1 )) -eq 1 ]
}

echo "=== Verificacion: ollama.service en Fedora Atomic ==="
echo

if ! systemctl cat "$UNIT" >/dev/null 2>&1; then
    echo "[X]  $UNIT no existe"
    exit 1
fi

USUARIO=$(systemctl show "$UNIT" -p User --value)
USUARIO="${USUARIO:-root}"
echo "Usuario del servicio: $USUARIO"
echo

# Capa 1: HOME del servicio
echo "--- Capa 1: HOME escribible fuera de /usr ---"
HOME_SVC=$(valor_env HOME)
[ -n "$HOME_SVC" ] || HOME_SVC=$(getent passwd "$USUARIO" | cut -d: -f6)
echo "HOME efectivo: $HOME_SVC"
case "$HOME_SVC" in
    /usr/*)
        echo "[X]  HOME bajo /usr: es de solo lectura en Fedora Atomic"
        EXIT_CODE=1 ;;
    *)
        if [ ! -d "$HOME_SVC" ]; then
            echo "[X]  $HOME_SVC no existe"
            EXIT_CODE=1
        elif [ "$(stat -c '%U' "$HOME_SVC")" != "$USUARIO" ]; then
            echo "[X]  $HOME_SVC no pertenece a $USUARIO (dueno: $(stat -c '%U' "$HOME_SVC"))"
            EXIT_CODE=1
        else
            echo "[OK] $HOME_SVC existe y pertenece a $USUARIO"
        fi ;;
esac
echo

# Capa 2: ruta de modelos
echo "--- Capa 2: ruta de modelos atravesable ---"
MODELOS=$(valor_env OLLAMA_MODELS)
if [ -z "$MODELOS" ]; then
    MODELOS="$HOME_SVC/.ollama/models"
    echo "OLLAMA_MODELS sin definir; se usa el valor por defecto: $MODELOS"
else
    echo "OLLAMA_MODELS: $MODELOS"
fi
ruta=""
bloqueo=0
IFS='/' read -ra partes <<<"${MODELOS#/}"
for parte in "${partes[@]}"; do
    ruta="$ruta/$parte"
    if [ ! -d "$ruta" ]; then
        echo "[!]  $ruta no existe todavia (Ollama lo crea si puede llegar hasta el)"
        break
    fi
    if ! puede_atravesar "$USUARIO" "$ruta"; then
        echo "[X]  $USUARIO no puede atravesar $ruta ($(stat -c '%A %U:%G' "$ruta"))"
        echo "     setfacl -m u:$USUARIO:--x '$ruta'"
        bloqueo=1
        EXIT_CODE=1
    fi
done
[ "$bloqueo" -eq 0 ] && echo "[OK] todos los directorios de la ruta son atravesables por $USUARIO"
echo

# Capa 3: estado del servicio
echo "--- Capa 3: estado del servicio ---"
ESTADO=$(systemctl is-active "$UNIT")
REINICIOS=$(systemctl show "$UNIT" -p NRestarts --value)
echo "Estado: $ESTADO (reinicios automaticos: $REINICIOS)"
case "$ESTADO" in
    activating)
        echo "[X]  en bucle de reinicios: arranca, falla y systemd lo relanza"
        EXIT_CODE=1 ;;
    failed)
        echo "[X]  el ultimo arranque fallo"
        EXIT_CODE=1 ;;
    active)
        if curl -sf -m 3 http://127.0.0.1:11434/api/version >/dev/null; then
            echo "[OK] responde en 127.0.0.1:11434"
        else
            echo "[X]  activo pero no responde en 127.0.0.1:11434"
            EXIT_CODE=1
        fi ;;
    *)
        echo "[OK] detenido, sin bucle" ;;
esac
echo

# Capa 4: arranque real (opcional)
echo "--- Capa 4: arranque real ---"
if [ "$ARRANCAR" != "--arrancar" ]; then
    echo "[!]  Omitido. Para probarlo: ./verify-fix.sh --arrancar"
    exit $EXIT_CODE
fi

if [ "$ESTADO" = "active" ]; then
    echo "[OK] ya estaba activo y respondiendo; no se toca"
    exit $EXIT_CODE
fi

sudo systemctl start "$UNIT"
listo=0
for _ in $(seq 1 20); do
    if curl -sf -m 2 http://127.0.0.1:11434/api/version >/dev/null; then
        listo=1
        break
    fi
    sleep 0.5
done
if [ "$listo" -eq 1 ]; then
    echo "[OK] arranco y responde: $(curl -s -m 2 http://127.0.0.1:11434/api/version)"
else
    echo "[X]  no respondio en 10 s. Ultimo error:"
    journalctl -u "$UNIT" -b --no-pager 2>/dev/null | grep -i 'error' | tail -n 1 | sed 's/^/     /'
    EXIT_CODE=1
fi
sudo systemctl stop "$UNIT"
echo "     Servicio detenido de nuevo."

exit $EXIT_CODE
