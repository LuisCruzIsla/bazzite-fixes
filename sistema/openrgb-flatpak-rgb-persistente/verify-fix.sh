#!/bin/bash
# Verifica las capas del fix de OpenRGB persistente en Bazzite/Flatpak:
# reglas udev, i2c-dev, servicio de usuario vivo y servidor SDK escuchando.

set -u

SERVICE="openrgb-verde.service"
UDEV="/etc/udev/rules.d/60-openrgb.rules"
HOTPLUG="/etc/udev/rules.d/61-openrgb-hotplug.rules"
PORT=6742

ok=0

echo "=== Capa 1: reglas udev de OpenRGB ==="
if [ -f "$UDEV" ]; then
  echo "  [OK] $UDEV"
else
  echo "  [X]  falta $UDEV  (dispositivos quedaran root-only)"
  ok=1
fi

echo
echo "=== Capa 2: modulo i2c-dev (controladores SMBus: RAM/GPU) ==="
if lsmod | grep -q i2c_dev; then
  echo "  [OK] i2c-dev cargado"
else
  echo "  [X]  i2c-dev NO cargado  (RAM/GPU por SMBus no apareceran)"
  ok=1
fi

echo
echo "=== Capa 3: servicio de usuario ==="
en=$(systemctl --user is-enabled "$SERVICE" 2>/dev/null)
ac=$(systemctl --user is-active "$SERVICE" 2>/dev/null)
if [ "$en" = "enabled" ]; then echo "  [OK] enabled"; else echo "  [X]  no enabled (no arranca en login)"; ok=1; fi
if [ "$ac" = "active" ]; then echo "  [OK] active"; else echo "  [X]  no active"; ok=1; fi

echo
echo "=== Capa 4: servidor SDK escuchando en $PORT ==="
if ss -tlnp 2>/dev/null | grep -q ":$PORT "; then
  echo "  [OK] servidor OpenRGB escucha en $PORT"
else
  echo "  [X]  nadie escucha $PORT  (revisar huerfano/puerto ocupado)"
  ok=1
fi

echo
echo "=== Capa 5 (opcional): hotplug (regla udev + servicio de sistema) ==="
HOTPLUG_SVC="/etc/systemd/system/openrgb-hotplug.service"
if [ -f "$HOTPLUG" ] && [ -f "$HOTPLUG_SVC" ]; then
  echo "  [OK] $HOTPLUG"
  echo "  [OK] $HOTPLUG_SVC"
elif [ -f "$HOTPLUG" ]; then
  echo "  [X]  falta $HOTPLUG_SVC  (la regla sola no reaplica: udev no puede reiniciar el servicio)"
else
  echo "  [--] sin hotplug (el color no se reaplica al reconectar USB)"
fi

echo
echo "=== Resultado ==="
if [ "$ok" -eq 0 ]; then
  echo "  [OK] Fix en pie. Reinicia la sesion para confirmar que el color vuelve solo."
else
  echo "  [X]  Alguna capa falla. Ver README (seccion Diagnostico)."
fi
exit "$ok"
