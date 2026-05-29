#!/bin/bash
# Sincroniza el servidor XWayland con un layout XKB concreto antes de exec.
# Workaround para el desync de Mutter cuando GNOME tiene 2+ input sources
# (rompe GetAsyncKeyState/XQueryKeymap polling en apps XWayland — típicamente
# menús de bind de hotkeys en juegos Proton/Wine).
#
# Edita LAYOUT y VARIANT abajo con los tuyos. Para descubrirlos:
#   gsettings get org.gnome.desktop.input-sources sources
#   → ('xkb', 'us+altgr-intl') significa LAYOUT=us VARIANT=altgr-intl
#
# Instalación:
#   cp sync-xkb-layout.sh ~/.local/bin/sync-xkb-layout.sh
#   chmod +x ~/.local/bin/sync-xkb-layout.sh
#
# Uso en launch options de Steam (sustituye <user>):
#   ... %command% → ... /home/<user>/.local/bin/sync-xkb-layout.sh %command%

LAYOUT="us"
VARIANT="altgr-intl"

if [ -n "$DISPLAY" ] && command -v setxkbmap >/dev/null 2>&1; then
  if [ -n "$VARIANT" ]; then
    setxkbmap "$LAYOUT" -variant "$VARIANT" 2>/dev/null || true
  else
    setxkbmap "$LAYOUT" 2>/dev/null || true
  fi
fi

exec "$@"
