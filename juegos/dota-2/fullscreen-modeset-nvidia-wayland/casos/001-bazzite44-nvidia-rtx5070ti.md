# Caso 001 — Bazzite 44 + NVIDIA RTX 5070 Ti + Dota 2

**Confirmado por:** [@LuisCruzIsla](https://github.com/LuisCruzIsla)
**Fecha:** 2026-07-19
**Estado:** Fix funciona — Dota entra en pantalla completa correcta y el escritorio ya no cambia de resolución.

## Entorno

| Componente | Versión |
|------------|---------|
| Distro | Bazzite 44 (Fedora Atomic) |
| Escritorio | GNOME Wayland |
| Kernel | 6.19 |
| GPU | NVIDIA GeForce RTX 5070 Ti (Blackwell) |
| Driver NVIDIA | 610.43.03 |
| CPU | AMD Ryzen 9 5900X |
| Monitor | DP-1, 1920×1080 @ 165 Hz |
| Juego | Dota 2 (Source 2, binario nativo Linux) |

## Configuración relevante

- Sesión Wayland (`XDG_SESSION_TYPE=wayland`).
- Monitor único DP-1 a 1920×1080 @ 165 Hz.
- Sin la corrección, SDL arrancaba sobre XWayland (backend `x11`) e intentaba modeset del monitor real.

## Aplicación de la solución en este caso

Opciones de lanzamiento de Dota 2 en Steam:

```
SDL_VIDEODRIVER=wayland %command% -fullscreen -w 1920 -h 1080
```

Dentro de Dota → Vídeo: **Pantalla completa** + **1920×1080**.

No fue necesario el Plan B (gamescope); el backend Wayland nativo resolvió el problema directamente.

## Salida de verificación

```
=== Capa 1: SDL_VIDEODRIVER=wayland en el entorno del proceso ===
  [OK] SDL_VIDEODRIVER=wayland (pid <pid>)

=== Capa 2: backend Wayland nativo cargado (libwayland-client) ===
  [OK] el proceso carga libwayland-client -> backend Wayland nativo

=== Capa 3: resolucion del monitor (inspeccion manual) ===
  DP-1 connected primary 1920x1080+0+0
     1920x1080    164.83*+
  -> debe coincidir con la resolucion nativa del escritorio (sin cambio de modo)

=== Resultado ===
  [OK] Dota corre en Wayland nativo. Confirma fullscreen correcto y que al salir el escritorio queda en su resolucion.
```

En la prueba real: Dota abre en pantalla completa correcta y, al salir, el escritorio conserva su resolución de 1920×1080.

## Notas adicionales

- Driver muy reciente (610, Blackwell) y aun así reproducía el desajuste — no es un problema de driver viejo, es el path de modeset de XWayland en NVIDIA.
- El monitor es de 165 Hz; con Wayland nativo no hizo falta especificar refresh (lo hereda del compositor). Con el Plan B gamescope sí se pasaría `-r 165`.
