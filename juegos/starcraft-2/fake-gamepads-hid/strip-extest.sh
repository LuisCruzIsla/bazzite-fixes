#!/bin/bash
# Wrapper que elimina libextest.so del LD_PRELOAD heredado de Steam.
# libextest es Steam Input — inyecta gamepads virtuales a partir de HID raw
# y se reactiva automáticamente tras suspend/resume o actualizaciones de Steam,
# incluso si "Steam Input" está desactivado en propiedades del juego.
#
# Este wrapper lo retira sin tocar gameoverlayrenderer.so (overlay de Steam).
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

exec "$@"
