# OpenRGB (Flatpak) en Bazzite: el RGB no se controla ni persiste tras reiniciar

> **Estado:** solución confirmada. Instalar las reglas udev, cargar `i2c-dev` y mantener OpenRGB vivo por un servicio de usuario deja el RGB fijo y persistente. Limitación conocida en teclados Direct-only con chip onboard (ver Causa raíz, capa 5).

## Síntoma

En una instalación de OpenRGB por **Flatpak** sobre Bazzite (Fedora Atomic), al intentar controlar el RGB:

```
Connection attempt failed
Warning: The OpenRGB udev rules are not installed.
Most devices will not be available unless running OpenRGB as root.
```

Y aunque se aplique un color, uno o varios de estos comportamientos:

- Los dispositivos no responden salvo corriendo OpenRGB como `root`.
- El color aplicado por CLI **no se ve reflejado** al abrir la GUI (modos/tamaños vuelven a los de fábrica).
- El color **se pierde al cerrar OpenRGB** o al reiniciar la sesión.
- Un teclado queda **mayormente del color elegido pero con teclas sueltas** de otro color.
- Un servicio systemd que lanza OpenRGB **entra en bucle de fallo** tras el primer reinicio.

## Quién está afectado

| Factor | Valor |
|--------|-------|
| Distro | Bazzite / Fedora Atomic (inmutable, sin `dnf` directo) |
| Instalación OpenRGB | **Flatpak** `org.openrgb.OpenRGB` (también AppImage / compilado) |
| Dispositivos | Placa ASUS Aura, DRAM/GPU por SMBus (i2c), teclados/mouse por HID |
| Sesión | Usuario systemd (GNOME/KDE) |

**No afecta** a instalaciones nativas por paquete (`rpm`/`deb`) donde las reglas udev se instalan solas — pero en un sistema inmutable el paquete nativo no es opción.

Ver [`casos/`](./casos/) para configuraciones específicas confirmadas.

## Causa raíz

El problema es multi-capa; el síntoma se manifiesta en una capa distinta de la que lo origina.

1. **Reglas udev no instaladas (Flatpak sandbox).** OpenRGB necesita reglas udev que den permiso de usuario a los nodos `/dev/i2c-*` y `/dev/hidraw*`. El Flatpak **no puede escribir en `/etc`**, así que no las instala. Sin ellas, los nodos quedan `root`-only y OpenRGB sólo ve los dispositivos como `root`.

2. **Warning de udev = falso positivo bajo Flatpak.** El aviso "udev rules are not installed" se dispara aunque las reglas ya estén puestas, porque el sandbox **no puede leer `/etc/udev/rules.d/`**. No sirve como señal: hay que verificar por los **permisos reales del nodo**, no por el mensaje.

3. **`i2c-dev` requerido para SMBus.** Los controladores de RAM y GPU se hablan por SMBus; sin el módulo `i2c-dev` cargado no existen los `/dev/i2c-*` y esos dispositivos no aparecen.

4. **Flatpak + systemd deja huérfanos.** `flatpak run` lanza la app en **su propio scope**, fuera del cgroup del servicio. `systemctl --user stop` mata el wrapper pero **no el proceso `openrgb` real**, que queda huérfano ocupando el puerto SDK **6742**. El siguiente arranque del servicio no puede enlazar el puerto → `status=1/FAILURE` en bucle.

5. **Teclados Direct-only con chip onboard.** Modelos como el HyperX Alloy Origins Core guardan su iluminación en **memoria interna** (configurada por software de Windows). El driver de OpenRGB para ellos **sólo expone modo `Direct`** (sin `Static` ni "guardar a flash") y su **keymap es incompleto**: algunas teclas no se cubren y muestran el color grabado por debajo. Además, en `Direct` el color **sólo dura mientras OpenRGB corre**. Placa (Aura) y DRAM sí retienen el último color sin proceso; el teclado no.

6. **Sin re-detección en hotplug.** OpenRGB enumera los dispositivos **sólo al arrancar**. Al desconectar y reconectar un teclado o mouse por USB, el servidor conserva un handle muerto y **no controla la nueva instancia** hasta re-escanear (que sólo ocurre al reiniciar el servidor). El dispositivo reconectado se queda con su color de fábrica.

## Soluciones que NO funcionan (anti-patrones)

- **Fiarse del warning "udev rules not installed".** Es un falso positivo del sandbox; puede seguir apareciendo con todo funcionando. Verificar por permisos del nodo (`ls -l /dev/hidraw*`), no por el mensaje.
- **Correr OpenRGB con `sudo` para saltarse las reglas.** Funciona una vez pero no integra con la sesión de usuario ni persiste; ensucia permisos. Instalar las reglas es la vía correcta.
- **`--mode static` global.** Falla en cuanto un dispositivo no soporta Static (p.ej. un teclado Direct-only): `Error: Mode 'static' not available`. Usar `--mode direct`.
- **Confiar en que `--profile` al arrancar deje verde un teclado Direct-only.** El perfil carga ("Profile loading: Succeeded") pero el teclado **no queda cubierto al 100%**. Hay que reforzar con un push explícito de color tras levantar el servidor.
- **`Type=simple` + `flatpak run` sin limpiar huérfanos.** El proceso escapa al cgroup; el `stop` no lo mata y el puerto 6742 queda ocupado. Sin `flatpak kill` en `ExecStartPre`/`ExecStop`, el servicio no reinicia bien.
- **Editar en la GUI mientras el servicio corre.** GUI y servidor pelean por los dispositivos. Parar el servicio antes de editar.
- **`RUN+="systemctl --user ..."` en la regla udev.** El worker de udev (`udev_t`) no alcanza el bus del usuario; el restart falla con exit 1 aunque `udevadm test` muestre el `RUN` correcto. Además `--machine` requiere `systemd-machined`, que el worker de udev no activa. La solución es delegar en PID1 vía `SYSTEMD_WANTS` (ver Paso 5).
- **Dejar el `openrgb-hotplug.service` sin `ConditionPathExists`.** El coldplug del boot dispara el servicio antes de que exista la sesión de usuario → queda en `failed` en cada arranque (aunque el hotplug real, ya con sesión, funcione). Condicionarlo a que exista `/run/user/UID/bus` lo omite limpiamente cuando no aplica (ver Paso 5).

## Solución

### Paso 1 — Instalar las reglas udev (requiere sudo)

El Flatpak trae el archivo de reglas dentro de su árbol. Copiarlo a `/etc` y recargar:

```bash
RULES=$(find ~/.local/share/flatpak /var/lib/flatpak -name '60-openrgb.rules' 2>/dev/null | head -1)
sudo cp "$RULES" /etc/udev/rules.d/60-openrgb.rules
sudo udevadm control --reload-rules && sudo udevadm trigger
```

Verificar por **permiso real** (no por el warning): los nodos deben quedar accesibles (ACL `+`):

```bash
ls -l /dev/hidraw*    # crw-rw-rw-+  tras recargar
```

### Paso 2 — Asegurar `i2c-dev` en cada arranque

```bash
lsmod | grep -q i2c_dev || sudo modprobe i2c-dev
echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf
```

### Paso 3 — Crear el perfil de color

Aplicar el color deseado a todos los dispositivos y guardar el perfil. `direct` (no `static`) por compatibilidad universal. Sustituir `RRGGBB` por el hex sin `#` y `mi-perfil` por el nombre elegido:

```bash
flatpak run org.openrgb.OpenRGB --mode direct --color RRGGBB --save-profile mi-perfil
```

Para **headers direccionables** (ARGB de placa, p.ej. coolers), OpenRGB **no autodetecta cuántos LEDs hay**: fijar el tamaño de la zona a mano hasta que enciendan todos, y regrabar. `--device N` y `--zone Z` se obtienen de `--list-devices`:

```bash
flatpak run org.openrgb.OpenRGB --device N --zone Z --size 60 --color RRGGBB \
  --mode direct --color RRGGBB --save-profile mi-perfil
```

### Paso 4 — Servicio de usuario que mantiene OpenRGB vivo

Necesario para dispositivos Direct-only (mantienen color sólo con el proceso vivo). Copiar [`openrgb-verde.service`](./openrgb-verde.service) a `~/.config/systemd/user/` (ajustar el nombre del perfil y el color), y habilitar:

```bash
cp openrgb-verde.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now openrgb-verde.service
```

Claves del unit (ver archivo):
- `ExecStartPre=-flatpak kill` — mata cualquier huérfano antes de arrancar (libera el puerto 6742).
- `ExecStart=... --server --profile mi-perfil` — carga el perfil y sirve el SDK.
- `ExecStartPost` — tras un `sleep`, **refuerza** el color con varios pases `--client localhost --mode direct --color` (rellena teclas que el primer paso no cubre). Prefijo `-` = no aborta si un pase falla.
- `ExecStop=flatpak kill` — mata el proceso real (systemd solo no puede, por el scope de Flatpak).

**Costo del servidor vivo (y por qué NO hay input lag).** El proceso mantiene el color en dispositivos Direct-only, pero su costo es marginal: ~25 MB de RAM, un porcentaje bajo de **un solo núcleo** en reposo (color estático, sin recálculo de efectos por software) y **cero GPU**.

Lo importante para gaming: el servidor **no añade latencia** a teclado ni mouse. OpenRGB abre sólo descriptores **`hidraw*` (canal de control RGB) e `i2c-*`** — nunca `event*` (evdev). La entrada viaja por otra ruta del kernel (HID → evdev → libinput → compositor), físicamente separada del canal por el que OpenRGB escribe el color. Verificable:

```bash
ls -l /proc/$(pgrep -x openrgb)/fd | grep -oE 'hidraw[0-9]+|event[0-9]+|i2c-[0-9]+' | sort -u
# debe listar hidraw* e i2c-*, NUNCA event*
```

Si aun asi se quiere cero proceso durante el juego, existe la via *oneshot* (aplicar el perfil y cerrar), a costa de perder los dispositivos Direct-only y la reaplicacion en hotplug.

### Paso 5 — Re-detección en hotplug (teclado/mouse)

Reiniciar el servicio en la reconexión fuerza a OpenRGB a re-enumerar y reaplicar el color. **No basta con que udev ejecute `systemctl`**: el worker de udev corre en el dominio SELinux `udev_t`, muy confinado, y no alcanza el bus del usuario — el restart falla en silencio (exit 1). La vía que funciona tiene **dos piezas**:

1. Un **servicio de sistema** [`openrgb-hotplug.service`](./openrgb-hotplug.service) que reinicia el servicio `--user` desde el contexto de PID1 (sano), cruzando con `--machine=USUARIO@.host`.
2. Una **regla udev** [`61-openrgb-hotplug.rules`](./61-openrgb-hotplug.rules) que sólo **etiqueta** el device (`TAG+="systemd"`, `ENV{SYSTEMD_WANTS}+="openrgb-hotplug.service"`) para que PID1 arranque ese servicio.

```bash
sudo cp openrgb-hotplug.service /etc/systemd/system/     # ajustar USUARIO
sudo cp 61-openrgb-hotplug.rules /etc/udev/rules.d/       # ajustar VID:PID
sudo systemctl daemon-reload
sudo udevadm control --reload-rules
```

El servicio no necesita `enable`: la regla udev lo tira bajo demanda en cada `add`. `--machine` usa `systemd-machined` (de ahí el `Wants=` en el unit); se activa solo al invocarlo desde PID1.

> **Importante — evitar el `failed` del arranque.** En el boot, udev emite `ACTION=add` (coldplug) para los USB **ya presentes**, antes de que exista tu sesión. En ese instante no hay bus de usuario y el `systemctl --machine --user` falla → el servicio queda en `failed` de forma permanente en cada arranque (visible en `systemctl --failed`). El unit lo evita con `ConditionPathExists=/run/user/UID/bus` (sin sesión = **skipped**, no failed) y con `ExecStart=-` (un fallo puntual tampoco ensucia el estado). Ajustar `UID` por `id -u`. El re-aplicado real en hotplug —cuando ya hay sesión— sigue funcionando igual.

> Un mouse inalámbrico se reconecta vía su **receptor** — usar el VID:PID del receptor (p.ej. Logitech Lightspeed `046d:c539`), no el del mouse.

Probar sin desconectar físicamente (simula un replug):

```bash
sudo udevadm trigger --action=remove /sys/bus/usb/devices/<X-Y>
sudo udevadm trigger --action=add    /sys/bus/usb/devices/<X-Y>
# el servicio --user debe reiniciarse ~13 s despues
```

### Paso 6 — Teclados Direct-only con chip onboard (si aplica)

Las teclas sueltas **no se resuelven desde Linux** (keymap incompleto del driver, sólo modo Direct). Fix definitivo: arrancar Windows una vez, poner iluminación **sólida** del color deseado con el software del fabricante (p.ej. HyperX NGENUITY) y **guardar al perfil onboard**. Así las teclas que OpenRGB no cubre muestran el mismo color de fondo. El resto de dispositivos no necesita esto.

## Verificación

```bash
./verify-fix.sh
```

Resultado esperado:
- Reglas udev presentes en `/etc/udev/rules.d/`.
- `i2c-dev` cargado.
- Servicio `enabled` + `active`.
- Servidor SDK escuchando en `6742`.

Validación real definitiva: **reiniciar la sesión y confirmar que el color vuelve solo.**

## Por qué sobrevive a actualizaciones

| Capa | Garantía |
|------|----------|
| `/etc/udev/rules.d/60-openrgb.rules` | Archivo del sistema; `flatpak update` no lo toca. Repetir Paso 1 sólo si OpenRGB añade IDs de dispositivos nuevos. |
| `/etc/modules-load.d/i2c-dev.conf` | Carga el módulo en cada boot, sobrevive a `rpm-ostree`. |
| Perfil `.orp` + servicio `--user` | En `~`; independientes de actualizaciones del Flatpak. |
| `flatpak kill` en Pre/Stop | No depende de versión; evita huérfanos pase lo que pase. |
| `61-openrgb-hotplug.rules` + `openrgb-hotplug.service` | Regla + servicio de sistema; reaplican el color en cada reconexión USB. |
| Chip onboard del teclado (Paso 6) | Grabado en el hardware; sobrevive a todo, incluso sin OpenRGB. |

## Diagnóstico si vuelve a fallar

1. **¿Reglas y permisos?**
   ```bash
   ls -l /etc/udev/rules.d/60-openrgb.rules
   ls -l /dev/hidraw*    # deben tener ACL '+'
   ```
2. **¿Huérfano ocupando el puerto?** (síntoma: servicio en bucle de fallo)
   ```bash
   ss -tlnp | grep 6742
   flatpak kill org.openrgb.OpenRGB   # limpiar
   systemctl --user reset-failed openrgb-verde.service
   systemctl --user restart openrgb-verde.service
   ```
3. **¿Servidor vivo?**
   ```bash
   systemctl --user status openrgb-verde.service
   ss -tlnp | grep 6742
   ```
4. **Dispositivos que ve el servidor:**
   ```bash
   flatpak run org.openrgb.OpenRGB --client localhost --list-devices
   ```
5. **Reforzar color a mano** (p.ej. teclas sueltas tras suspend):
   ```bash
   flatpak run org.openrgb.OpenRGB --client localhost --mode direct --color RRGGBB
   ```

## Casos confirmados

| # | Distro | Hardware | Notas |
|---|--------|----------|-------|
| 001 | Bazzite 44 | ASUS ROG STRIX B550-F + coolers Antec C8 ARGB + HyperX Predator RAM + HyperX Alloy Origins Core | Todo verde persistente salvo teclas sueltas del teclado (chip onboard) |

## Referencias técnicas

- [OpenRGB — Instalación de reglas udev](https://openrgb.org/udev)
- [OpenRGB — Wiki (SDK server, CLI)](https://gitlab.com/CalcProgrammer1/OpenRGB/-/wikis/home)
- [Flatpak — sandbox y acceso a `/dev`](https://docs.flatpak.org/en/latest/sandbox-permissions.html)
- `systemd.service(5)` — `ExecStartPre` / `ExecStartPost` / `ExecStop`, prefijo `-`

## Contribuir

Ver [`CONTRIBUTING.md`](../../CONTRIBUTING.md) en la raíz del repositorio.
