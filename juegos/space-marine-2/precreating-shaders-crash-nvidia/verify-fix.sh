#!/bin/bash
# Verifica que la capa Pyroveil esta instalada y (si hubo PROTON_LOG) activa para Space Marine 2.
# Pyroveil (c) 2025 Hans-Kristian Arntzen / Valve, MIT. Este script solo comprueba su aplicacion.

set -u

APPID="2183900"
SO="$HOME/.local/lib/libVkLayer_pyroveil_64.so"
MANIFEST="$HOME/.local/share/vulkan/implicit_layer.d/VkLayer_pyroveil_64.json"
PROTON_LOG="$HOME/steam-$APPID.txt"

ok=0

echo "=== Capa 1: layer Pyroveil instalado ==="
for f in "$SO" "$MANIFEST"; do
  if [ -f "$f" ]; then
    echo "  [OK] $f"
  else
    echo "  [X]  $f  (falta; construir Pyroveil con 'ninja -C build install')"
    ok=1
  fi
done

echo
echo "=== Capa 2: config de SM2 referenciado ==="
cfg=""
for f in $(find "$HOME" -maxdepth 5 -path "*space-marine-2-nv/pyroveil.json" 2>/dev/null); do
  cfg="$f"; break
done
if [ -n "$cfg" ]; then
  echo "  [OK] config encontrado: $cfg"
  if [ -d "$(dirname "$cfg")/cache" ]; then
    echo "  [OK] roundtripCache presente junto al config"
  else
    echo "  [X]  falta carpeta cache/ junto al pyroveil.json"
    ok=1
  fi
else
  echo "  [--] no se encontro space-marine-2-nv/pyroveil.json en \$HOME (ajustar PYROVEIL_CONFIG)"
fi

echo
echo "=== Capa 3: Pyroveil activo en la ultima ejecucion (requiere PROTON_LOG=1) ==="
if [ -f "$PROTON_LOG" ]; then
  n=$(grep -c "pyroveil:" "$PROTON_LOG" 2>/dev/null || echo 0)
  if [ "$n" -gt 0 ]; then
    echo "  [OK] $n lineas 'pyroveil:' en $PROTON_LOG"
    grep "pyroveil:" "$PROTON_LOG" | grep -iE "Found config|roundtrip|Found match" | head -3 | sed 's/^/      /'
  else
    echo "  [X]  $PROTON_LOG existe pero sin lineas 'pyroveil:' (no se activo)"
    ok=1
  fi
else
  echo "  [--] sin $PROTON_LOG. Lanza el juego una vez con 'PROTON_LOG=1' en las launch options para validar."
fi

echo
echo "=== Capa 4: Xid 109 (CTX SWITCH TIMEOUT) en este boot ==="
xid=$(journalctl -b --no-pager -p warning 2>/dev/null | grep -i "xid" | grep -c "109")
if [ "$xid" -eq 0 ]; then
  echo "  [OK] sin Xid 109 en el log de este boot"
else
  echo "  [X]  $xid evento(s) Xid 109 detectados -> el crash de GPU sigue ocurriendo"
  ok=1
fi

echo
echo "=== Resultado ==="
if [ "$ok" -eq 0 ]; then
  echo "  [OK] Pyroveil instalado/configurado. Si la Capa 3 quedo en [--], valida con PROTON_LOG=1."
else
  echo "  [X]  Revisa los puntos marcados arriba."
fi
exit "$ok"
