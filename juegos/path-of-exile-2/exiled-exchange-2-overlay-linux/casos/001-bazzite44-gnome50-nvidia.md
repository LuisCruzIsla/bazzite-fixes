# Caso 001 — Bazzite 44 + GNOME 50 + NVIDIA + EE2 0.16.3

**Confirmado por:** [@LuisCruzIsla](https://github.com/LuisCruzIsla)
**Fecha:** 2026-09-29
**Estado:** Fix funciona — `Ctrl+D` muestra el precio en español sobre el juego.

## Entorno

| Componente | Versión |
|------------|---------|
| Distro | Bazzite 44 (Fedora Atomic), imagen `bazzite-gnome-nvidia-open:stable` 44.20260928.1 |
| Escritorio | GNOME Shell 50.5, sesión Wayland |
| XWayland | 24.1.11, arrancado con `-enable-ei-portal` |
| Kernel | 7.2.7-ogc1.1.fc44 |
| GPU | NVIDIA GeForce RTX 5070 Ti |
| Driver NVIDIA | 615.71.09 |
| Runtime | Proton 11.0-2c |
| EE2 | 0.16.3 compilado con `linux-focus-fix.patch` (Electron 40.10.2) |
| Juego | Path of Exile 2 (Steam, AppID 2694490), ventana completa |

## Configuración relevante

| Dato | Valor |
|------|-------|
| Idioma del juego | `es` (`poe2_production_Config.ini`) |
| Idioma de EE2 | `es` (antes `en`) |
| Atajos | `Ctrl+D` (rápido), `Ctrl+Alt+D` (fijo) |
| Launch options del juego | `PROTON_ENABLE_NVAPI=1`, sin `PROTON_ENABLE_WAYLAND` |
| Biblioteca Steam | Disco secundario (`/var/mnt/...`), el prefix no está en `~/.local/share/Steam` |

## Aplicación de la solución en este caso

1. Ya se usaba 0.15.1 con el parche de foco y X11 forzado. Se recompiló sobre 0.16.3: el parche se aplicó limpio; en 0.16.3 ya no existían ni los bloques `focus()`/`blur()` de Linux.
2. Idioma de EE2 cambiado de `en` a `es` para coincidir con el juego.
3. `Ctrl+D` no hacía nada. El portapapeles quedaba con `__EE2_FORCE_EMPTY_*` y `Ctrl+C` manual sí copiaba el ítem.
4. Prueba con `xdotool key ctrl+alt+c` sobre un ítem: tampoco llegaba al juego, y en el mismo segundo `xdg-desktop-portal-gnome` abrió una ventana (`Failed to associate portal window with parent window`).
5. Se concedió "interacción remota" desde fuera del juego. `Ctrl+D` empezó a funcionar.

## Salida de verificación

```
=== Capa 2: parche de foco en el AppImage ===
  [OK] setFocusable(true/false) presente
  [OK] sin type="notification"

=== Capa 1: EE2 en X11 y sin auto-update ===
  [OK] Electron forzado a X11
  [OK] --no-updates activo

=== Capa 4: idioma de EE2 vs juego ===
  [OK] EE2 y juego en 'es'

=== Juego: ventana X11 ===
  [OK] juego sin PROTON_ENABLE_WAYLAND

=== Capa 3: teclas simuladas via portal ===
  [--] XWayland usa -enable-ei-portal: hace falta el permiso 'interaccion remota' (Paso 4)
  [OK] el portapapeles no tiene la marca de EE2

=== Resultado ===
  [OK] todas las capas verificables estan bien.
```

## Notas adicionales

- **Ratón bloqueado una vez.** Justo después de conceder el permiso, el ratón dejó de responder en todo el escritorio (scroll iba al juego, clics muertos, `Alt+Tab` sí funcionaba). Se liberó con `xdotool mouseup 1 mouseup 2 mouseup 3 keyup ctrl alt shift super`. No se repitió en la sesión de juego posterior.
- **Launch options mal formadas encontradas:** `GDK_BACKEND=x11` sin `%command%`, que Steam pasaba al juego como argumento. Sin efecto en el problema.
- No se ha comprobado si el permiso de interacción remota persiste tras cerrar sesión.
