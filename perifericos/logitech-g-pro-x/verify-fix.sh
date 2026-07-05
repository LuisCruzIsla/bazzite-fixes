#!/usr/bin/env bash
# Verifica la config de audio del Logitech G PRO X via EasyEffects (Flatpak 8.x).
# Comprueba: servicio vivo, nodos virtuales EE, preset cargado, cadenas y autostart.
set -u
ok(){ printf '[OK] %s\n' "$1"; }
bad(){ printf '[X]  %s\n' "$1"; FAIL=1; }
FAIL=0
EE="flatpak run com.github.wwmm.easyeffects"

echo "== Servicio EasyEffects =="
pgrep -x easyeffects >/dev/null && ok "servicio corriendo" || bad "EasyEffects no esta corriendo"

echo "== Nodos virtuales EE =="
pw-cli ls Node 2>/dev/null | grep -q '"Easy Effects Sink"'   && ok "Easy Effects Sink presente"   || bad "falta Easy Effects Sink"
pw-cli ls Node 2>/dev/null | grep -q '"Easy Effects Source"' && ok "Easy Effects Source presente" || bad "falta Easy Effects Source"

echo "== Preset cargado =="
[ "$($EE -a output 2>/dev/null)" = "gaming" ] && ok "preset salida = gaming (EQ)"       || bad "preset salida no es gaming"
[ "$($EE -a input  2>/dev/null)" = "gaming" ] && ok "preset entrada = gaming (rnnoise)" || bad "preset entrada no es gaming"

echo "== Cadenas configuradas =="
# EE instancia los filtros solo con stream activo; se valida la config estatica.
DB=~/.var/app/com.github.wwmm.easyeffects/config/easyeffects/db/easyeffectsrc
grep -A6 '\[StreamInputs\]'  "$DB" 2>/dev/null | grep -q 'plugins=.*rnnoise'   && ok "cadena mic incluye rnnoise"     || bad "cadena mic sin rnnoise"
grep -A6 '\[StreamOutputs\]' "$DB" 2>/dev/null | grep -q 'plugins=.*equalizer' && ok "cadena salida incluye equalizer" || bad "cadena salida sin equalizer"

echo "== Autostart =="
[ -f ~/.config/autostart/easyeffects-service.desktop ] && ok "autostart al login presente" || bad "falta autostart easyeffects-service.desktop"

echo
[ "$FAIL" = 0 ] && echo "RESULTADO: todo OK" || echo "RESULTADO: hay fallos, revisar arriba"
exit "$FAIL"
