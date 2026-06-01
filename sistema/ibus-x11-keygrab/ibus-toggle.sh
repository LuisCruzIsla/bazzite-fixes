#!/bin/bash
# Toggle IBus on/off. Lanzar con doble click desde el .desktop launcher
# adjunto en este mismo directorio (ibus-toggle.desktop).
#
# Estado por defecto: APAGADO al boot (override en ~/.config/autostart/).
# Al activar, IBus solo afecta apps lanzadas DESPUES del toggle. Si necesitas
# IBus en una app que ya está abierta, ciérrala y reábrela tras activar.

notify() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -i input-keyboard "IBus" "$1"
  fi
  echo "$1"
}

if pgrep -x ibus-daemon >/dev/null 2>&1; then
  pkill -x ibus-x11 2>/dev/null
  pkill -f "ibus-typing-booster" 2>/dev/null
  pkill -f "ibus-engine" 2>/dev/null
  pkill -f "ibus-extension" 2>/dev/null
  pkill -f "ibus-portal" 2>/dev/null
  pkill -f "ibus-dconf" 2>/dev/null
  pkill -x ibus-daemon 2>/dev/null
  sleep 0.3
  notify "Desactivado. Las apps abiertas dejan de tener interferencia."
else
  export QT_IM_MODULE=ibus
  export GTK_IM_MODULE=ibus
  export XMODIFIERS=@im=ibus
  ibus-daemon -drx --panel disable >/dev/null 2>&1 &
  disown
  sleep 0.5
  notify "Activado. Reabre la app donde lo necesites."
fi
