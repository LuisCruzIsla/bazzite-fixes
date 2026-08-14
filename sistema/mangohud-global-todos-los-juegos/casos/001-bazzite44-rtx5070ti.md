# 001 — Bazzite 44 / RTX 5070 Ti / Helldivers 2 (Proton Experimental)

**Confirmado por:** [@LuisCruzIsla](https://github.com/LuisCruzIsla)
**Fecha:** 2026-08-14
**Estado:** Fix funciona — capa cargada en el proceso del juego sin variables de entorno

## Entorno

| Componente | Versión |
|------------|---------|
| Distro | Bazzite 44 (Fedora Atomic) |
| Escritorio | GNOME sobre Wayland |
| GPU | NVIDIA RTX 5070 Ti |
| CPU | Ryzen 9 5900X (24 hilos) |
| RAM | 32 GB |
| MangoHud | 0.8.4 |
| Steam | nativo (no Flatpak) |
| Runtime | Steam Linux Runtime 4 (pressure-vessel) |
| Proton | Experimental |
| Juego de prueba | Helldivers 2 (DX12 → VKD3D) |

## Configuración relevante

Librerías de MangoHud presentes en el sistema:

```
/usr/lib64/mangohud/libMangoHud.so
/usr/lib64/mangohud/libMangoHud_opengl.so
/usr/lib64/mangohud/libMangoHud_shim.so
```

Manifiesto original del sistema, con el bloque que causa el problema:

```json
"enable_environment": {
  "MANGOHUD": "1"
},
"disable_environment": {
  "DISABLE_MANGOHUD": "1"
}
```

Opciones de lanzamiento del juego durante la prueba — **sin ninguna variable `MANGOHUD`**, a propósito, para comprobar que la carga viene de la capa y no del entorno:

```
PROTON_ENABLE_NVAPI=1 PROTON_ENABLE_WAYLAND=1 PROTON_LOCAL_SHADER_CACHE=1 LOW_LATENCY_LAYER=1 DXVK_HUD=0 %command%
```

## Aplicación de la solución en este caso

Sin variantes respecto al README genérico. Se ejecutó `enable-mangohud-global.sh` y se copió `MangoHud.conf` a `~/.config/MangoHud/`.

Un detalle específico de este equipo: el atajo por defecto `Shift_R+F12` se cambió a `Shift_R+F10` porque Steam estaba usando la tecla de captura de pantalla por defecto (F12), sin hotkey personalizada en `localconfig.vdf`.

## Salida de verificación

```
=== Verificacion: MangoHud global ===

--- Capa 1: manifiestos de usuario ---
[OK] presente: MangoHud.x86_64.json
[OK] presente: MangoHud.x86.json

--- Capa 2: enable_environment eliminado ---
[OK] MangoHud.x86_64.json sin enable_environment
[OK] MangoHud.x86.json sin enable_environment

--- Capa 3: escape hatch DISABLE_MANGOHUD ---
[OK] MangoHud.x86_64.json conserva DISABLE_MANGOHUD
[OK] MangoHud.x86.json conserva DISABLE_MANGOHUD

--- Capa 4: copia de usuario al dia ---
[OK] library_path x86_64 coincide con el sistema
[OK] library_path x86 coincide con el sistema

--- Capa 5: el cargador de Vulkan la enumera ---
[OK] capa enumerada sin MANGOHUD en el entorno
     VK_LAYER_MANGOHUD_overlay_x86      Vulkan Hud Overlay      1.3.0    version 1
     VK_LAYER_MANGOHUD_overlay_x86_64   Vulkan Hud Overlay      1.3.0    version 1
```

Con Helldivers 2 corriendo, contenido relevante de `/proc/<PID>/maps`:

```
/run/host/usr/lib64/mangohud/libMangoHud.so
/var/home/<user>/.local/share/Steam/ubuntu12_64/steamoverlayvulkanlayer.so
```

Y el entorno del mismo proceso, sin ninguna variable `MANGOHUD`:

```
ENABLE_VK_LAYER_VALVE_steam_fossilize_1=1
ENABLE_VK_LAYER_VALVE_steam_overlay_1=1
LOW_LATENCY_LAYER=1
PROTON_ENABLE_WAYLAND=1
```

Esa combinación es la prueba concreta de que la capa se cargó por el manifiesto y no por una opción de lanzamiento.

## Notas adicionales

- **pressure-vessel no fue obstáculo.** El contenedor del Steam Linux Runtime hizo bind-mount de la ruta del host y la capa entró igual, apareciendo reescrita como `/run/host/usr/lib64/mangohud/libMangoHud.so`. Era la duda principal antes de probar, porque el contenedor aísla el sistema de archivos.
- **Convive con otras capas Vulkan** sin conflicto. En este equipo coexisten la capa de Steam (`steamoverlayvulkanlayer.so`), Fossilize y Pyroveil, todas activas al mismo tiempo.
- **Compatible con `PROTON_ENABLE_WAYLAND=1`.** MangoHud engancha `vkQueuePresentKHR`, así que es indiferente al backend de ventanas.
- **Motivo del cambio desde el contador de Steam:** el contador integrado no reporta utilización de GPU. En este equipo Helldivers 2 estaba CPU-bound y el contador de Steam no permitía verlo; `gpu_load_change` lo hace evidente de un vistazo.
- **`InGameOverlayShowFPSDetailLevel` en 4** (el nivel más verboso de Steam) sondea frametimes de forma continua aunque el overlay esté cerrado. Se recomienda bajarlo o apagarlo tras adoptar MangoHud.
- **Sobre `que-upscaler` en este juego:** Helldivers 2 trae `nvngx_dlss.dll`, `libxess.dll` y `amd_fidelityfx_upscaler_dx12.dll`, pero **no** `nvngx_dlssg.dll` — no implementa frame generation.
