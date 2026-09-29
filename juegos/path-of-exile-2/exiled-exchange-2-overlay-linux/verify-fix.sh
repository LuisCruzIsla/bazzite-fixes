#!/bin/bash
# Verifica las capas del fix de Exiled Exchange 2 en GNOME/Wayland.
# Uso: ./verify-fix.sh <ruta-al-AppImage>
#   ej: ./verify-fix.sh ~/Aplicaciones/Exiled-Exchange-2-0.16.3-linuxfocusfix.AppImage

set -u

APPIMAGE=${1:-}
if [ ! -x "$APPIMAGE" ]; then
  echo "[X] Uso: $0 <ruta-al-AppImage>"
  exit 1
fi
ok=0
fail() { echo "  [X]  $1"; ok=1; }

echo "=== Capa 2: parche de foco en el AppImage ==="
tmp=$(mktemp -d)
(cd "$tmp" && "$APPIMAGE" --appimage-extract resources/app.asar >/dev/null 2>&1)
ASAR="$tmp/squashfs-root/resources/app.asar"
if [ -f "$ASAR" ]; then
  if grep -aq 'setFocusable(!0)' "$ASAR" && grep -aq 'setFocusable(!1)' "$ASAR"; then
    echo "  [OK] setFocusable(true/false) presente"
  else
    fail "sin setFocusable: es un build oficial sin parche"
  fi
  if grep -aq 'type="notification"' "$ASAR"; then
    fail "contiene type=\"notification\": GNOME 47+ oculta la ventana"
  else
    echo "  [OK] sin type=\"notification\""
  fi
else
  fail "no se pudo extraer resources/app.asar del AppImage"
fi
rm -rf "$tmp"

echo
echo "=== Capa 1: EE2 en X11 y sin auto-update ==="
pid=$(pgrep -f '^/tmp/\.mount_Exiled.*/exiled-exchange-2 ' | head -1)
if [ -z "$pid" ]; then
  echo "  [--] EE2 no esta corriendo; abrirlo y repetir para verificar esta capa"
else
  env=$(tr '\0' '\n' < "/proc/$pid/environ")
  args=$(tr '\0' ' ' < "/proc/$pid/cmdline")
  if grep -q -- '--ozone-platform=x11' <<<"$args" || grep -q '^ELECTRON_OZONE_PLATFORM_HINT=x11$' <<<"$env"; then
    echo "  [OK] Electron forzado a X11"
  else
    fail "EE2 corre en Wayland nativo: el overlay no se vera"
  fi
  if grep -q -- '--no-updates' <<<"$args"; then
    echo "  [OK] --no-updates activo"
  else
    fail "sin --no-updates: el updater puede reemplazar el build parcheado"
  fi
fi

echo
echo "=== Capa 4: idioma de EE2 vs juego ==="
cfg=~/.config/exiled-exchange-2/apt-data/config.json
ee2_lang=$(grep -o '"language":"[^"]*"' "$cfg" 2>/dev/null | cut -d'"' -f4)
game_ini=$(find ~/.local/share/Steam/steamapps/compatdata/2694490 /var/mnt /mnt /run/media \
  -path '*compatdata/2694490/*' -name poe2_production_Config.ini 2>/dev/null | head -1)
game_lang=$(grep -A1 '^\[LANGUAGE\]' "$game_ini" 2>/dev/null | grep -o 'language=.*' | cut -d= -f2 | tr -d '\r')
if [ -z "$ee2_lang" ] || [ -z "$game_lang" ]; then
  echo "  [--] no se pudo leer el idioma (EE2: '${ee2_lang:-?}', juego: '${game_lang:-?}')"
elif [ "$ee2_lang" = "$game_lang" ]; then
  echo "  [OK] EE2 y juego en '$ee2_lang'"
else
  fail "EE2 en '$ee2_lang' y juego en '$game_lang': el parser no reconocera los items"
fi

echo
echo "=== Juego: ventana X11 ==="
gpid=$(pgrep -f 'PathOfExile.*\.exe' | tail -1)
if [ -z "$gpid" ]; then
  echo "  [--] el juego no esta corriendo"
elif tr '\0' '\n' < "/proc/$gpid/environ" | grep -q '^PROTON_ENABLE_WAYLAND=1$'; then
  fail "juego con PROTON_ENABLE_WAYLAND=1: EE2 no puede engancharse"
else
  echo "  [OK] juego sin PROTON_ENABLE_WAYLAND"
fi

echo
echo "=== Capa 3: teclas simuladas via portal ==="
if ps -o args= -C Xwayland | grep -q -- '-enable-ei-portal'; then
  echo "  [--] XWayland usa -enable-ei-portal: hace falta el permiso 'interaccion remota' (Paso 4)"
else
  echo "  [OK] XWayland sin portal de input: XTest llega directo"
fi
clip=$(timeout 2 wl-paste 2>/dev/null | head -1)
if [[ "$clip" == __EE2_FORCE_EMPTY_* ]]; then
  fail "portapapeles con marca de EE2: el ultimo Ctrl+D no llego al juego (conceder permiso, Paso 4)"
else
  echo "  [OK] el portapapeles no tiene la marca de EE2"
fi

echo
echo "=== Resultado ==="
if [ "$ok" -eq 0 ]; then
  echo "  [OK] todas las capas verificables estan bien."
else
  echo "  [X]  Corregir las capas marcadas (ver README, Solucion completa)."
fi
exit "$ok"
