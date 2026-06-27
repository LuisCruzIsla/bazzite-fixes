# Caso 001 — Bazzite 44 + NVIDIA RTX 5070 Ti + Vesktop

**Confirmado por:** [@LuisCruzIsla](https://github.com/LuisCruzIsla)
**Fecha:** 2026-06-26
**Estado:** Fix funciona — el negro al compartir el monitor desaparece con `--disable-gpu`.

## Entorno

| Componente | Versión |
|------------|---------|
| Distro | Bazzite 44 (Fedora Atomic) |
| Escritorio | GNOME Wayland |
| Kernel | 6.19 |
| GPU | NVIDIA GeForce RTX 5070 Ti (Blackwell) |
| Driver NVIDIA | 610.43.02 |
| CPU | AMD Ryzen 9 5900X |
| Cliente | Vesktop 1.6.5 (Flatpak `dev.vencord.Vesktop`) |
| Portal | `xdg-desktop-portal-gnome` |

## Configuración relevante

- Sesión Wayland (`XDG_SESSION_TYPE=wayland`).
- `WebRTCPipeWireCapturer` activo en el cliente (config de captura correcta de fábrica).
- Sin ningún error en `journalctl --user` de `xdg-desktop-portal`, `pipewire`, `wireplumber` ni Mutter durante el screencast — confirma que el negro es a nivel de frame DMA-BUF, no un fallo de negociación.

## Aplicación de la solución en este caso

Se intentó primero **forzar XWayland** (`ELECTRON_OZONE_PLATFORM_HINT=x11` + `DISPLAY=:0` + `--socket=wayland`) — **no funcionó**, el negro persistió, porque en sesión Wayland Chromium captura por el portal PipeWire aunque la app esté en XWayland.

La solución efectiva fue `--disable-gpu` en los dos lanzadores:

`~/.config/autostart/dev.vencord.Vesktop.desktop`:
```ini
Exec=flatpak run --command=/app/bin/vesktop/vesktop.bin dev.vencord.Vesktop --enable-speech-dispatcher --start-minimized --disable-gpu
```

`~/.local/share/applications/dev.vencord.Vesktop.desktop` (override del lanzador del menú):
```ini
Exec=/usr/bin/flatpak run --branch=stable --arch=x86_64 --command=startvesktop --file-forwarding dev.vencord.Vesktop --disable-gpu @@u %U @@
```

Seguido de `update-desktop-database ~/.local/share/applications` y reinicio del cliente.

## Salida de verificación

```
=== Capa 1: flag --disable-gpu en los lanzadores ===
  [OK] /home/lcruzisl/.config/autostart/dev.vencord.Vesktop.desktop
  [OK] /home/lcruzisl/.local/share/applications/dev.vencord.Vesktop.desktop

=== Capa 2: proceso GPU en modo software (sin libs NVIDIA) ===
  [OK] sin gpu-process activo (HW accel off)

=== Resultado ===
  [OK] Aceleracion por hardware desactivada. Comparte el monitor para confirmar que no sale negro.
```

En la prueba real compartiendo el monitor entero: el contenido ya no se pone negro.

## Notas adicionales

- Driver muy reciente (610, Blackwell) y aun así reproducía el negro — no es un problema de driver viejo, es el path DMA-BUF de Chromium en NVIDIA.
- Trade-off aceptado: el cliente pierde aceleración GPU (UI/vídeo por CPU). Irrelevante para uso de chat.
- Alternativa más ligera no probada en este equipo: mantener GPU pero forzar backend ANGLE/Vulkan con `--use-gl=angle --use-angle=vulkan`.
