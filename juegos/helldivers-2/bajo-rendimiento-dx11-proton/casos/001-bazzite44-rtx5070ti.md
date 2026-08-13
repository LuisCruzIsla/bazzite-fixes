# Caso 001 — Bazzite 44 + NVIDIA RTX 5070 Ti + Helldivers 2

**Confirmado por:** [@LuisCruzIsla](https://github.com/LuisCruzIsla)
**Fecha:** 2026-08-13
**Estado:** Fix funciona — de ~70 a ~101 fps (+44%) y con una imagen notablemente mejor.

## Entorno

| Componente | Versión |
|------------|---------|
| Distro | Bazzite 44 (Fedora Atomic) |
| Escritorio | GNOME 50.3, Wayland |
| Kernel | 6.19 |
| GPU | NVIDIA GeForce RTX 5070 Ti (Blackwell), 16 GB |
| Driver NVIDIA | 610.43.03 |
| CPU | AMD Ryzen 9 5900X (12c/24t) |
| RAM | 32 GB |
| Monitor | DP-1, 1920×1080 @ 165 Hz |
| Almacenamiento | WD_BLACK SN850X NVMe (btrfs) |
| Proton | Experimental (11.0-100) |
| Juego | Helldivers 2, build `release/01.007.000/18846` |

## Configuración relevante

Estado inicial, con el problema presente:

| Ajuste | Valor |
|--------|-------|
| `render_backend` | `0` (DirectX 11 / DXVK) |
| `render_resolution` | `[1114, 626]` sobre un monitor de 1920×1080 |
| Escala de renderizado | Equilibrado (~58%) |
| Sombreado de tasa variable | Rendimiento |
| Campo de visión vertical | 90 (máximo) |
| Opciones de lanzamiento | vacías |
| Modo de visualización | Sin bordes |

El punto de comparación era un equipo con **RTX 3070 en Windows**, que rendía mejor pese a ser una GPU bastante inferior.

Comprobaciones descartadas antes de tocar nada:

- ReBAR activo (`BAR1 Memory Usage: Total 16384 MiB`) — correcto.
- Juego en NVMe, no en disco mecánico — correcto.
- Governor de CPU ya en `performance` — **`gamemode` no se llegó a instalar**, habría sido un layering de `rpm-ostree` y un reinicio para nada.

## Aplicación de la solución en este caso

Los dos cambios de fondo:

```
render_backend = 0    →    render_backend = 1
```

Opciones de lanzamiento en Steam (con Steam cerrado al editar `localconfig.vdf`, o desde la propia interfaz):

```
PROTON_ENABLE_NVAPI=1 PROTON_ENABLE_WAYLAND=1 PROTON_LOCAL_SHADER_CACHE=1 LOW_LATENCY_LAYER=1 %command%
```

Ajustes en el menú del juego:

| Ajuste | Antes | Después |
|--------|-------|---------|
| Escala de renderizado | Equilibrado | **Nativo** |
| Anti-Aliasing | DLSS | DLSS (= DLAA a escala nativa) |
| Sombreado de tasa variable | Rendimiento | **Desactivado** |
| Campo de visión vertical | 90 | **75** |
| Modo de visualización | Sin bordes | Pantalla completa |
| Definición (sharpening) | 0,75 | 0,5 |
| Calidad de iluminación | Intermedia | Alta |
| Calidad de reflejos | Intermedia | Alta |
| Niebla y nubes volumétricas | Intermedia | Alta |

VRR activado en Configuración → Pantallas (en GNOME 50 ya no es una `experimental-feature`).

## Salida de verificación

```
=== Capa 1: backend de render activo (DX12 vs DX11) ===
  [OK] el proceso carga d3d12core.dll -> DirectX 12 via vkd3d-proton (pid 26337)
  [--] tambien carga d3d11.dll; es normal, se usa para tareas auxiliares

=== Capa 2: variables de Proton en el entorno del proceso ===
  [OK] PROTON_ENABLE_NVAPI=1
  [OK] LOW_LATENCY_LAYER=1
  [OK] PROTON_ENABLE_WAYLAND=1

=== Capa 3: render_backend en la configuracion del juego ===
  [OK] render_backend = 1 (DirectX 12)

=== Capa 4: reparto CPU / GPU (informativo) ===
  uso de GPU ahora mismo: 43%
  -> por debajo del 60%: si los fps son bajos, el limite es la CPU.
```

Medición con el monitor de rendimiento del propio juego:

| Momento | FPS | CPU | GPU |
|---------|-----|-----|-----|
| Antes (DX11, render a 626p) | ~70 | — | — |
| Después, en la nave (DX12, 1080p nativo + DLAA) | **101** (mín. 85) | 52% / pico 78% | **43%** |
| Después, en misión con calidad alta | **~60 estables** | — | — |

## Notas adicionales

- **El síntoma diagnóstico decisivo fue que bajar la resolución no subía los fps.** Con la escala al 58% y la GPU al 41%, estaba claro que el cuello no era gráfico. Perseguir ajustes de calidad durante semanas es el error natural aquí.
- La GPU sigue por debajo del 50% tras el fix: **el juego continúa limitado por CPU**, sólo que con un techo mucho más alto. Parte de esa diferencia contra Windows es irreducible (traducción de API más el anticheat GameGuard).
- El margen de GPU liberado se reinvirtió en calidad de imagen, no en fps. Los ~60 fps en misión con todo alto se prefirieron sobre los 70 fps originales con la imagen a 626p y VRS degradando el sombreado.
- **Reflex estaba activado en el menú desde el principio pero no hacía nada** sin `PROTON_ENABLE_NVAPI=1` y `LOW_LATENCY_LAYER=1`. No aparece en el contador de fps: se nota en la respuesta al apuntar. Mismo patrón ya visto en No Man's Sky con la capa de baja latencia.
- El campo de visión en 90 se percibía como "imagen descuadrada": son unos 121° horizontales en 16:9, con distorsión de perspectiva clara en los bordes. Bajarlo a 75 arregló el encuadre y de paso liberó CPU.
- El juego reescribe `enable_resource_lock_debug` a `true` y el límite de fotogramas a `144` en cada arranque. Ninguno de los dos importa; no merece la pena pelearlos.
