#!/bin/bash
# Verifica que la aceleracion por hardware de Vesktop esta desactivada
# (captura de pantalla por software, sin import DMA-BUF que da negro en NVIDIA).

set -u

APP_ID="dev.vencord.Vesktop"
AUTOSTART="$HOME/.config/autostart/$APP_ID.desktop"
MENU="$HOME/.local/share/applications/$APP_ID.desktop"

ok=0

echo "=== Capa 1: flag --disable-gpu en los lanzadores ==="
for f in "$AUTOSTART" "$MENU"; do
  if [ -f "$f" ]; then
    if grep -q -- "--disable-gpu" "$f"; then
      echo "  [OK] $f"
    else
      echo "  [X]  $f  (falta --disable-gpu)"
      ok=1
    fi
  else
    echo "  [--] $f  (no existe; ruta de arranque no usada?)"
  fi
done

echo
echo "=== Capa 2: proceso GPU en modo software (sin libs NVIDIA) ==="
gpid=""
for d in /proc/[0-9]*; do
  if tr '\0' ' ' < "$d/cmdline" 2>/dev/null | grep -q "vesktop.bin.*type=gpu-process"; then
    gpid=${d#/proc/}
    break
  fi
done

if [ -z "$gpid" ]; then
  echo "  [OK] sin gpu-process activo (HW accel off)"
else
  nv=$(grep -ic nvidia "/proc/$gpid/maps" 2>/dev/null || echo 0)
  if [ "$nv" -eq 0 ]; then
    echo "  [OK] gpu-process (pid $gpid) sin librerias NVIDIA -> render software"
  else
    echo "  [X]  gpu-process (pid $gpid) carga NVIDIA -> HW accel sigue activa"
    ok=1
  fi
fi

echo
echo "=== Resultado ==="
if [ "$ok" -eq 0 ]; then
  echo "  [OK] Aceleracion por hardware desactivada. Comparte el monitor para confirmar que no sale negro."
else
  echo "  [X]  Revisar: la captura puede seguir dando negro. Ver README."
fi
exit "$ok"
