# IBus: ibus-x11 captura teclas y rompe polling en apps Wine/Win32

> **Estado:** solución confirmada (con toggle on-demand)

## Síntoma

En aplicaciones Wine/Proton (y otras apps X11/XWayland que polean estado de teclado vía `XQueryKeymap`), las teclas no llegan al cliente — los cuadros de captura de hotkeys de juegos no detectan pulsaciones aunque el resto del teclado funcione en partida.

Después de un `Alt+Tab` el polling puede funcionar momentáneamente y volver a fallar — sintomatología confundible con un grab persistente del WM.

## Quién está afectado

- **Distro:** Fedora / Bazzite / cualquier distro con GNOME y locale no-en (por defecto activa IBus para soporte de input methods)
- **Software intermedio:** `ibus-daemon` + `ibus-x11` + `ibus-typing-booster` (engine de predicción de texto que GNOME instala por defecto en Fedora-based)
- **Casos típicos:** juegos Proton con cuadros de bind (RTS, MOBA), aplicaciones Wine antiguas, herramientas de automatización en X11

Ver [`casos/`](./casos/) para configuraciones específicas.

## Causa raíz

IBus (Intelligent Input Bus) es un framework de **input methods** para componer caracteres que no están en el teclado físico (CJK, símbolos Unicode, predicción de texto). Su componente `ibus-x11` se ejecuta como un cliente X que hace `XGrabKey` sobre combinaciones globales para interceptar teclas antes de que el cliente final las reciba.

Para apps modernas que respetan input methods (Qt/GTK con `QT_IM_MODULE=ibus` y `GTK_IM_MODULE=ibus`) esto es correcto y transparente. Para **apps Win32/Wine que polean directamente el bitmap de `XQueryKeymap`**, IBus consume eventos sin reenviarlos correctamente al polling, dejando el bitmap "vacío" desde la perspectiva del cliente.

Procesos típicos de la cadena IBus:

```
ibus-daemon --panel disable
ibus-x11
ibus-typing-booster --ibus
ibus-engine-simple
ibus-dconf, ibus-extension-gtk3, ibus-portal
```

Variables de entorno que marcan IBus activa:

```
QT_IM_MODULE=ibus
XMODIFIERS=@im=ibus
GTK_IM_MODULE=ibus
```

## Soluciones que NO funcionan (anti-patrones)

- **`gsettings set org.gnome.desktop.interface gtk-im-module ''`** — solo afecta a GTK; las variables de entorno y `ibus-x11` siguen activas para Wine y Qt.
- **`pkill ibus-daemon`** sin desactivar el autostart — IBus se relanza al próximo login.
- **Quitar locales del sistema** — el autostart de IBus depende de paquetes instalados, no del locale activo.
- **Marcar `Show Input Sources` off en GNOME** — solo oculta el indicador del panel; el daemon sigue corriendo.

## Solución

Estrategia recomendada: **desactivar IBus globalmente al boot** y proveer un **toggle on-demand** para reactivarlo si en algún momento se necesita (escribir Unicode hex con `Ctrl+Shift+u`, idiomas CJK, predicción de texto en apps GNOME).

Cuatro archivos:

### 1. Override del autostart system-wide

Crear `~/.config/autostart/ibus-mozc-launch-xwayland.desktop`:

```ini
[Desktop Entry]
Type=Application
Name=IBus Mozc XWayland (deshabilitado por usuario)
Comment=Override de /etc/xdg/autostart - IBus se inicia bajo demanda via ibus-toggle
Hidden=true
X-GNOME-Autostart-enabled=false
```

El nombre debe coincidir exactamente con el archivo en `/etc/xdg/autostart/` (en Bazzite/Fedora actual: `ibus-mozc-launch-xwayland.desktop`). El override por usuario tiene precedencia.

> Si tu distro arranca IBus con otro archivo (`ibus-autostart.desktop`, `ibus-x11.desktop`, etc.), revisa `/etc/xdg/autostart/ibus*` y crea el override con el mismo nombre.

### 2. Limpiar variables de entorno al login

Crear `~/.config/environment.d/99-no-ibus.conf`:

```
QT_IM_MODULE=
QT_IM_MODULES=wayland
XMODIFIERS=
GTK_IM_MODULE=
```

Estas variables se cargan en el entorno del usuario por systemd al inicio de sesión. Las apps lanzadas después ven IBus como "no presente".

### 3. Script de toggle

Crear `~/.local/bin/ibus-toggle.sh`:

```bash
#!/bin/bash
# Toggle IBus on/off. Lanzar con doble click desde el .desktop launcher.
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
```

Hacer ejecutable:

```bash
chmod +x ~/.local/bin/ibus-toggle.sh
```

### 4. Launcher `.desktop` para doble click

Crear `~/.local/share/applications/ibus-toggle.desktop`:

```ini
[Desktop Entry]
Type=Application
Name=IBus Toggle
Comment=Activar/desactivar IBus a demanda (off por defecto al boot)
Exec=/home/<user>/.local/bin/ibus-toggle.sh
Icon=input-keyboard
Terminal=false
Categories=Utility;Settings;
Keywords=ibus;input;method;teclado;
```

Reemplaza `<user>` con tu nombre de usuario. Tras crearlo aparece en el lanzador de GNOME (tecla Super → escribir "IBus Toggle").

### Aplicar en la sesión actual sin reiniciar

```bash
pkill -x ibus-x11
pkill -f ibus-typing-booster
pkill -f ibus-engine
pkill -f ibus-extension
pkill -f ibus-portal
pkill -f ibus-dconf
pkill -x ibus-daemon
```

Los cambios de `environment.d` solo aplican al próximo login — pero los procesos IBus ya muertos no se relanzan en esta sesión.

## Verificación

```bash
./verify-fix.sh
```

Resultado esperado:

- `[OK] Sin procesos IBus activos`
- `[OK] QT_IM_MODULE vacía en sesión` (tras el próximo login)
- `[OK] autostart override presente`

## Por qué sobrevive a actualizaciones

| Capa | Resistencia |
|------|-------------|
| `~/.config/autostart/` override | Sobrevive a updates del sistema porque `/etc/xdg/autostart/` system-wide queda intacto pero el override usuario tiene precedencia |
| `~/.config/environment.d/` | Sobrevive a updates de GNOME y systemd — pertenece al usuario |
| Script + `.desktop` en `~/.local/` | Sobrevive a updates de cualquier paquete del sistema |
| Toggle es reversible | Si una update reintroduce variables, el toggle off vuelve a apagar todo |

## Diagnóstico si vuelve a fallar

```bash
# 1) Procesos IBus (no debe haber con el toggle apagado)
pgrep -af "ibus" | grep -v "pgrep\|bash -c"

# 2) Variables en una shell nueva tras login (deben estar vacías o ausentes)
env | grep -iE "im_module|xmodifier|gtk_im|qt_im"

# 3) Autostart system-wide (puede haberse renombrado en una update)
ls /etc/xdg/autostart/ibus*

# 4) Override del usuario presente
ls ~/.config/autostart/ibus*

# 5) Variables de un proceso específico (ej. juego)
GAME_PID=$(pgrep -f <nombre> | head -1)
cat /proc/$GAME_PID/environ | tr '\0' '\n' | grep -iE "im_module|xmodifier"
```

Si tras una update aparece un nuevo archivo en `/etc/xdg/autostart/ibus*.desktop` con nombre distinto, replicar el override con el mismo nombre.

## Casos confirmados

| # | Distro | Caso |
|---|--------|------|
| [001](./casos/001-bazzite44-sc2.md) | Bazzite 44 | StarCraft II — cuadro de hotkeys |

## Referencias

- IBus project upstream
- Fedora packaging guidelines para `ibus-typing-booster`
- freedesktop.org spec de `environment.d` y autostart `.desktop`

## Contribuir

Ver [`CONTRIBUTING.md`](../../CONTRIBUTING.md) en la raíz.
