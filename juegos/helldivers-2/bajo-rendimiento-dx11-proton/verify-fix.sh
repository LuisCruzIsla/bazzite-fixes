#!/bin/bash
# Verifica que Helldivers 2 corre en DirectX 12 (vkd3d-proton) y no en
# DirectX 11 (DXVK), que es lo que limita el rendimiento por CPU.
# Ejecutar con Helldivers 2 ABIERTO.

set -u

ok=0

pid=$(pgrep -f "helldivers2.exe" 2>/dev/null | head -1)
if [ -z "$pid" ]; then
  echo "  [--] Helldivers 2 no esta corriendo. Lanzalo y vuelve a ejecutar este script."
  exit 2
fi

echo "=== Capa 1: backend de render activo (DX12 vs DX11) ==="
maps=$(cat "/proc/$pid/maps" 2>/dev/null)
has12=$(echo "$maps" | grep -c "d3d12core\.dll")
has11=$(echo "$maps" | grep -c "d3d11\.dll")
if [ "$has12" -gt 0 ]; then
  echo "  [OK] el proceso carga d3d12core.dll -> DirectX 12 via vkd3d-proton (pid $pid)"
  [ "$has11" -gt 0 ] && echo "  [--] tambien carga d3d11.dll; es normal, se usa para tareas auxiliares"
else
  echo "  [X]  no carga d3d12core.dll -> sigue en DirectX 11 (DXVK)"
  echo "       corregir render_backend = 1 en user_settings.config (ver README, Paso 1)"
  ok=1
fi

echo
echo "=== Capa 2: variables de Proton en el entorno del proceso ==="
env_proc=$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null)
for var in PROTON_ENABLE_NVAPI LOW_LATENCY_LAYER; do
  val=$(echo "$env_proc" | sed -n "s/^${var}=//p")
  if [ -n "$val" ]; then
    echo "  [OK] $var=$val"
  else
    echo "  [X]  $var ausente -> NVIDIA Reflex no operara (ver README, Paso 2)"
    ok=1
  fi
done
wl=$(echo "$env_proc" | sed -n 's/^PROTON_ENABLE_WAYLAND=//p')
if [ -n "$wl" ]; then
  echo "  [OK] PROTON_ENABLE_WAYLAND=$wl"
else
  echo "  [--] PROTON_ENABLE_WAYLAND ausente -> corre bajo XWayland (no critico)"
fi

echo
echo "=== Capa 3: render_backend en la configuracion del juego ==="

# La ruta del config es determinista dentro de cada biblioteca de Steam.
# Se recorren las bibliotecas declaradas en libraryfolders.vdf en vez de
# rastrear el disco: el archivo esta a 16 niveles y un find generico falla.
sub="steamapps/compatdata/553850/pfx/drive_c/users/steamuser/AppData/Roaming/Arrowhead/Helldivers2/user_settings.config"
cfg=""
for lf in "$HOME/.steam/steam/steamapps/libraryfolders.vdf" \
          "$HOME/.local/share/Steam/steamapps/libraryfolders.vdf" \
          "$HOME/.var/app/com.valvesoftware.Steam/data/Steam/steamapps/libraryfolders.vdf"; do
  [ -r "$lf" ] || continue
  while IFS= read -r lib; do
    [ -n "$lib" ] || continue
    if [ -r "$lib/$sub" ]; then cfg="$lib/$sub"; break 2; fi
  done < <(sed -n 's/^[[:space:]]*"path"[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$lf")
done

if [ -n "$cfg" ]; then
  echo "  config: $cfg"
  backend=$(sed -n 's/^render_backend = //p' "$cfg" | head -1)
  case "$backend" in
    1) echo "  [OK] render_backend = 1 (DirectX 12)" ;;
    0) echo "  [X]  render_backend = 0 (DirectX 11) -> cambiar a 1 con el juego cerrado"; ok=1 ;;
    *) echo "  [--] render_backend = '${backend:-<no encontrado>}' (valor inesperado)" ;;
  esac
  vrs=$(sed -n 's/^[[:space:]]*vrs_enabled = //p' "$cfg" | head -1)
  [ "$vrs" = "true" ] && echo "  [--] vrs_enabled = true -> con la GPU infrautilizada, VRS solo degrada la imagen"
else
  echo "  [--] user_settings.config no encontrado; comprobar render_backend a mano"
fi

echo
echo "=== Capa 4: reparto CPU / GPU (informativo) ==="
if command -v nvidia-smi >/dev/null 2>&1; then
  util=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)
  if [ -n "$util" ]; then
    echo "  uso de GPU ahora mismo: ${util}%"
    if [ "$util" -lt 60 ] 2>/dev/null; then
      echo "  -> por debajo del 60%: si los fps son bajos, el limite es la CPU."
      echo "     bajar ajustes graficos NO devolvera fps. Ver README (Paso 5)."
    else
      echo "  -> la GPU esta trabajando de verdad; el reparto es sano."
    fi
  fi
else
  echo "  [--] nvidia-smi no disponible; usar el Monitor de rendimiento del juego"
fi
echo "  NOTA: medir siempre EN MISION. El hangar de la nave es una escena mucho mas ligera."

echo
echo "=== Resultado ==="
if [ "$ok" -eq 0 ]; then
  echo "  [OK] Helldivers 2 corre en DX12 con NVAPI expuesto."
  echo "       Confirma el resultado comparando fps en una mision de dificultad alta."
else
  echo "  [X]  Revisar los pasos marcados. Ver README (Solucion completa)."
fi
exit "$ok"
