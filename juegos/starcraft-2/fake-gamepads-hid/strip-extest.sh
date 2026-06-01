#!/bin/bash
# Wrapper para juegos Proton lanzados desde Steam (Battle.net/SC2 en particular).
#
# Capa 1 (Steam Input):
#   Elimina libextest.so del LD_PRELOAD heredado de Steam. libextest es
#   Steam Input — inyecta gamepads virtuales a partir de HID raw. Se reactiva
#   automáticamente tras suspend/resume o actualizaciones de Steam, incluso
#   si "Steam Input" está desactivado en propiedades del juego. Lo retiramos
#   sin tocar gameoverlayrenderer.so (overlay de Steam).
#
# Capa 2 (XWayland keymap):
#   Sincroniza el layout de XWayland con el layout activo de GNOME
#   (us+altgr-intl). Tras boot, Mutter a veces deja XWayland con 'us' plain
#   aunque GNOME tenga 'us+altgr-intl' activo, y el cuadro de captura de
#   hotkeys de SC2 (polling GetAsyncKeyState/XQueryKeymap) falla con 0
#   detección. Ver sistema/xwayland-keymap-desync/ en el repo.
#
# Capa 3 (Xalia, Proton 10+):
#   Xalia es el proxy AT-SPI nuevo de Proton 10 que intercepta input de Wine
#   para exponer controles via accesibilidad. Rompe el polling de
#   XQueryKeymap del cuadro de captura de hotkeys. Se desactiva con
#   PROTON_USE_XALIA=0 antes del exec del proton runtime. Ver
#   sistema/proton-xalia-input-grab/ en el repo.
#
# Instalación:
#   cp strip-extest.sh ~/.local/bin/strip-extest.sh
#   chmod +x ~/.local/bin/strip-extest.sh
#
# Uso en launch options de Steam (sustituye <user>):
#   ... %command% → ... /home/<user>/.local/bin/strip-extest.sh %command%

clean_preload() {
  echo "$1" | tr ':' '\n' | grep -v 'libextest' | paste -sd ':' -
}

export LD_PRELOAD="$(clean_preload "$LD_PRELOAD")"
export WINE_LD_PRELOAD="$(clean_preload "$WINE_LD_PRELOAD")"

if [ -n "$DISPLAY" ] && command -v setxkbmap >/dev/null 2>&1; then
  setxkbmap us -variant altgr-intl 2>/dev/null || true
fi

export PROTON_USE_XALIA=0

exec "$@"
