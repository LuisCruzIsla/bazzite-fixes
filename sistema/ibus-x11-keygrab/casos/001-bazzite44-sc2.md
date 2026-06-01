# 001 — Bazzite 44 + StarCraft II (cuadro de hotkeys)

- **Confirmado por:** [@LuisCruzIsla](https://github.com/LuisCruzIsla)
- **Fecha:** 2026-06-01
- **Estado:** Fix funciona

## Entorno

| Componente | Versión |
|------------|---------|
| Distro | Bazzite 44 (`bazzite-gnome-nvidia-open:stable`, build 44.20260515) |
| Locale | `es_PE.UTF-8` (Fedora arranca IBus por defecto con este locale) |
| Compositor | GNOME Wayland (Mutter) |
| IBus daemon | `ibus-daemon --panel disable` |
| Engines activos | `ibus-typing-booster`, `ibus-engine-simple` |
| Juego afectado | StarCraft II + Proton 10.0-4 |

## Síntoma exacto observado

Tras eliminar las capas anteriores del análisis multi-capa (Steam Input via `libextest`, desync XKB y Xalia de Proton 10), el cuadro de captura de hotkeys de SC2 **seguía sin detectar teclas**. El usuario no usa ningún input method (solo XKB `us+altgr-intl` con AltGr para tildes/ñ) — IBus estaba activo sin función real pero interceptando teclas.

Procesos IBus encontrados:

```
ibus-daemon --panel disable
ibus-dconf
ibus-extension-gtk3
ibus-portal
ibus-engine-simple
ibus-x11
ibus-typing-booster --ibus
```

Variables relevantes en `/proc/$SC2_PID/environ`:

```
QT_IM_MODULE=ibus
QT_IM_MODULES=wayland;ibus
XMODIFIERS=@im=ibus
```

## Aplicación del fix

Aplicada la solución completa de los 4 archivos:

1. `~/.config/autostart/ibus-mozc-launch-xwayland.desktop` con `Hidden=true`
2. `~/.config/environment.d/99-no-ibus.conf` con variables vacías
3. `~/.local/bin/ibus-toggle.sh` (toggle on/off)
4. `~/.local/share/applications/ibus-toggle.desktop` (lanzador con doble click)

Tras crear los archivos, sesión actual limpiada con:

```bash
pkill -x ibus-x11
pkill -f ibus-typing-booster
pkill -f ibus-engine
pkill -f ibus-extension
pkill -f ibus-portal
pkill -f ibus-dconf
pkill -x ibus-daemon
```

## Validación

Tras matar IBus, el cuadro de captura de SC2 continuaba mostrando "Bloq Num" en cada captura — lo que llevó a descubrir la capa 5 (NumLock atascado físicamente). Una vez apagado NumLock, el cuadro detectó teclas correctamente.

IBus no es la **única** capa que rompe el polling de SC2 (de hecho son 5 acumulativas), pero sí es necesaria su desactivación porque ninguna de las otras solas resuelve el problema.

## Salida de `verify-fix.sh`

```
=== Verificación: IBus desactivado ===

[OK] Sin procesos IBus activos

[OK] Override de autostart presente: /home/<user>/.config/autostart/ibus-mozc-launch-xwayland.desktop
[OK] Contiene flag de desactivación

Variables IM en sesión:
QT_IM_MODULES=wayland
```

## Notas adicionales

- En Fedora Atomic (Bazzite), el archivo de autostart system-wide aparece como `ibus-mozc-launch-xwayland.desktop`. En otras distros puede ser `ibus-autostart.desktop` o similar — verificar con `ls /etc/xdg/autostart/ibus*`.
- El toggle script permite reactivar IBus puntualmente si se necesita escribir Unicode hex (`Ctrl+Shift+u` + código) o usar `ibus-typing-booster`.
- Tras reactivar IBus con el toggle, **la app donde se quiera usar debe cerrarse y reabrirse** para que tome `QT_IM_MODULE=ibus` exportado por el toggle.
- Este es la **capa 4** del análisis multi-capa de SC2 documentado en `juegos/starcraft-2/hotkey-capture-debug-multicapa/`.
