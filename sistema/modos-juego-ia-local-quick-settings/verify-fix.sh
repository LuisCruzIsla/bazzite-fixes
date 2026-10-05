#!/usr/bin/env bash
# Verifica la instalacion de los scripts de modo y de la extension de Quick Settings.
#
# Uso:
#   ./verify-fix.sh                 -> usa el UUID modos@bazzite-fixes
#   ./verify-fix.sh <uuid>          -> si instalaste la extension con otro UUID

set -u

UUID="${1:-modos@bazzite-fixes}"
BIN="$HOME/.local/bin"
EXIT_CODE=0

echo "=== Verificacion: modos juego / IA local ==="
echo

echo "--- Capa 1: scripts en ~/.local/bin ---"
for s in modo-ia modo-juego modo-visita steam-shaders; do
    if [ -x "$BIN/$s" ]; then
        echo "[OK] $s"
    else
        echo "[X]  falta o no es ejecutable: $BIN/$s"
        EXIT_CODE=1
    fi
done
echo

echo "--- Capa 2: sudo sin contrasena para ollama ---"
# La extension lanza los scripts sin terminal: sudo no puede pedir contrasena.
reglas=$(sudo -n -l 2>/dev/null | grep -i 'NOPASSWD' | grep -i 'ollama')
for accion in start stop; do
    if grep -qE "systemctl $accion ollama" <<<"$reglas"; then
        echo "[OK] systemctl $accion ollama"
    else
        echo "[X]  sin regla NOPASSWD para: systemctl $accion ollama"
        EXIT_CODE=1
    fi
done
echo

echo "--- Capa 3: opciones de ollama que usan los scripts ---"
if command -v ollama >/dev/null 2>&1; then
    if ollama ps --help >/dev/null 2>&1 && ollama stop --help >/dev/null 2>&1; then
        echo "[OK] 'ollama ps' y 'ollama stop' disponibles"
    else
        echo "[X]  esta version de ollama no tiene 'ps' o 'stop'"
        EXIT_CODE=1
    fi
else
    echo "[X]  ollama no esta en el PATH"
    EXIT_CODE=1
fi
echo

echo "--- Capa 4: modo-juego es idempotente ---"
if [ "$(systemctl is-active ollama)" = "inactive" ]; then
    if "$BIN/modo-juego" >/dev/null 2>&1; then
        echo "[OK] sale con 0 cuando Ollama ya esta apagado"
    else
        echo "[X]  falla con Ollama apagado: la extension mostrara 'modo-juego fallo'"
        EXIT_CODE=1
    fi
else
    echo "[!]  Ollama no esta inactivo — se omite para no apagarlo"
fi
echo

echo "--- Capa 5: extension ---"
if ! command -v gnome-extensions >/dev/null 2>&1; then
    echo "[!]  gnome-extensions no disponible — se omite"
    exit $EXIT_CODE
fi
info=$(gnome-extensions info "$UUID" 2>/dev/null)
if [ -z "$info" ]; then
    echo "[X]  extension $UUID no instalada (o falta cerrar sesion tras copiarla)"
    exit 1
fi
if grep -qE 'ACTIVE' <<<"$info" && ! grep -qE 'INACTIVE|ERROR|OUT OF DATE' <<<"$info"; then
    echo "[OK] $UUID en estado ACTIVE"
else
    echo "[X]  $UUID no esta activa:"
    grep -iE 'estado|state' <<<"$info" | sed 's/^/     /'
    echo "     journalctl --user -b -g '$UUID'"
    EXIT_CODE=1
fi
mayor=$(gnome-shell --version | grep -oE '[0-9]+' | head -n 1)
meta="$HOME/.local/share/gnome-shell/extensions/$UUID/metadata.json"
if grep -q "\"$mayor\"" "$meta" 2>/dev/null; then
    echo "[OK] metadata.json declara GNOME $mayor"
else
    echo "[X]  metadata.json no declara GNOME $mayor: el Shell la desactivara"
    EXIT_CODE=1
fi

exit $EXIT_CODE
