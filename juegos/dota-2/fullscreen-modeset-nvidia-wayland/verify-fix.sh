#!/bin/bash
# Verifica que Dota 2 corre con SDL en backend Wayland nativo (no XWayland),
# lo que evita el modeset que desajusta la resolucion del monitor en NVIDIA.
# Ejecutar con Dota 2 ABIERTO.

set -u

ok=0

pid=$(pgrep -x dota2 | head -1)
if [ -z "$pid" ]; then
  echo "  [--] Dota 2 no esta corriendo. Lanzalo y vuelve a ejecutar este script."
  exit 2
fi

echo "=== Capa 1: SDL_VIDEODRIVER=wayland en el entorno del proceso ==="
drv=$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | sed -n 's/^SDL_VIDEODRIVER=//p')
if [ "$drv" = "wayland" ]; then
  echo "  [OK] SDL_VIDEODRIVER=wayland (pid $pid)"
else
  echo "  [X]  SDL_VIDEODRIVER='${drv:-<vacio>}' -> falta forzar wayland en las opciones de lanzamiento"
  ok=1
fi

echo
echo "=== Capa 2: backend Wayland nativo cargado (libwayland-client) ==="
if grep -q libwayland-client "/proc/$pid/maps" 2>/dev/null; then
  echo "  [OK] el proceso carga libwayland-client -> backend Wayland nativo"
else
  echo "  [X]  no carga libwayland-client -> probablemente sigue en XWayland"
  ok=1
fi

echo
echo "=== Capa 3: resolucion del monitor (inspeccion manual) ==="
if command -v xrandr >/dev/null 2>&1; then
  xrandr 2>/dev/null | grep -E "\bconnected|\*" | sed 's/^/  /'
  echo "  -> debe coincidir con la resolucion nativa del escritorio (sin cambio de modo)"
else
  echo "  [--] xrandr no disponible; verifica en GNOME -> Pantallas que la resolucion sea la nativa"
fi

echo
echo "=== Resultado ==="
if [ "$ok" -eq 0 ]; then
  echo "  [OK] Dota corre en Wayland nativo. Confirma fullscreen correcto y que al salir el escritorio queda en su resolucion."
else
  echo "  [X]  Revisar opciones de lanzamiento. Ver README (Solucion / Plan B gamescope)."
fi
exit "$ok"
