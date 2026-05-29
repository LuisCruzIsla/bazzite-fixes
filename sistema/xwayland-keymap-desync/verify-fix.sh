#!/bin/bash
# Verificación del workaround de XWayland keymap desync.
# Compara el layout activo de GNOME con el que reporta XWayland.

set -u

echo "=== Layout activo en GNOME (Wayland) ==="
gnome_sources=$(gsettings get org.gnome.desktop.input-sources sources 2>/dev/null)
gnome_current_idx=$(gsettings get org.gnome.desktop.input-sources current 2>/dev/null | sed 's/uint32 //')

if [ -z "$gnome_sources" ]; then
  echo "  [!] gsettings no disponible o no es sesión GNOME"
else
  echo "  sources : $gnome_sources"
  echo "  current : $gnome_current_idx"
fi

echo
echo "=== Layout que ve XWayland ==="
if ! command -v setxkbmap >/dev/null 2>&1; then
  echo "  [!] setxkbmap no instalado — brew install setxkbmap (o pkg manager equivalente)"
  exit 1
fi

xkb_layout=$(setxkbmap -query | awk -F: '/^layout/  {gsub(/ /,""); print $2}')
xkb_variant=$(setxkbmap -query | awk -F: '/^variant/ {gsub(/ /,""); print $2}')

echo "  layout  : ${xkb_layout:-<none>}"
echo "  variant : ${xkb_variant:-<none>}"

echo
echo "=== Resultado ==="

if [ -z "$gnome_sources" ]; then
  echo "  [?] No puedo comparar sin gsettings. Verifica manualmente."
  exit 0
fi

gnome_idx=${gnome_current_idx:-0}
gnome_active=$(echo "$gnome_sources" | grep -oE "'xkb', *'[^']*'" | sed -n "$((gnome_idx + 1))p" | sed "s/.*'\([^']*\)'$/\1/")
gnome_layout=$(echo "$gnome_active" | cut -d+ -f1)
gnome_variant=$(echo "$gnome_active" | cut -s -d+ -f2)

echo "  GNOME activo : layout='$gnome_layout' variant='${gnome_variant:-<none>}' (index $gnome_idx)"
echo "  XWayland tiene : layout='$xkb_layout' variant='${xkb_variant:-<none>}'"

if [ "$xkb_layout" = "$gnome_layout" ] && [ "$xkb_variant" = "$gnome_variant" ]; then
  echo "  [OK] Sincronizados — el polling XKB en apps XWayland funcionará correctamente."
  exit 0
else
  echo "  [X] DESYNC detectado. Aplica el workaround:"
  if [ -n "$gnome_variant" ]; then
    echo "      setxkbmap $gnome_layout -variant $gnome_variant"
  else
    echo "      setxkbmap $gnome_layout"
  fi
  exit 1
fi
