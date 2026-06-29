# Caso 001 — Bazzite 44 + NVIDIA RTX 5070 Ti + Space Marine 2

**Confirmado por:** [@LuisCruzIsla](https://github.com/LuisCruzIsla)
**Fecha:** 2026-06-29
**Estado:** Fix funciona — Pyroveil aplicado, shaders sin crash y juego estable.

## Entorno

| Componente | Versión |
|------------|---------|
| Distro | Bazzite 44 (Fedora Atomic) |
| Escritorio | GNOME Wayland |
| Kernel | 6.19 |
| GPU | NVIDIA GeForce RTX 5070 Ti (Blackwell), 16 GB |
| Driver NVIDIA | 610.43.02 |
| CPU | AMD Ryzen 9 5900X |
| Juego | Space Marine 2 (Steam app `2183900`) |
| Proton | 11 beta |
| Pyroveil | checkout en `$HOME/pyroveil`, layer en `~/.local` |

## Configuración relevante

- Layer instalado en `~/.local/lib/libVkLayer_pyroveil_64.so` + manifiesto en `~/.local/share/vulkan/implicit_layer.d/VkLayer_pyroveil_64.json`.
- Config SM2 (`hacks/space-marine-2-nv/pyroveil.json`): roundtrip de compute shaders (`spirvExecutionModel: 5`) vía `glsl-roundtrip`, con `roundtripCache: cache` y `disabledExtensions: [VK_NV_raw_access_chains]`.
- Carpeta `cache/` poblada junto al config (SPIR-V parcheado precomputado).

## Aplicación de la solución en este caso

Launch options usadas:

```
PYROVEIL=1 PYROVEIL_CONFIG=/var/home/lcruzisl/pyroveil/hacks/space-marine-2-nv/pyroveil.json PROTON_ENABLE_NVAPI=1 PROTON_LOCAL_SHADER_CACHE=1 PROTON_ENABLE_WAYLAND=1 %command%
```

Variantes frente al README genérico:

- Se descartó `DXVK_ASYNC=1` que estaba en la config previa: inerte en DX12 (SM2 usa VKD3D, no DXVK).
- Se descartó `SteamDeck=1`: sospechoso de limitar presets gráficos en hardware de escritorio potente.
- Se añadió `PROTON_ENABLE_NVAPI=1` para DLSS/Reflex.
- `PROTON_ENABLE_WAYLAND=1` viable por usar Proton 11 beta en sesión GNOME Wayland.

## Salida de verificación

```
=== Capa 1: layer Pyroveil instalado ===
  [OK] /home/lcruzisl/.local/lib/libVkLayer_pyroveil_64.so
  [OK] /home/lcruzisl/.local/share/vulkan/implicit_layer.d/VkLayer_pyroveil_64.json

=== Capa 2: config de SM2 referenciado ===
  [OK] config encontrado: /var/home/lcruzisl/pyroveil/hacks/space-marine-2-nv/pyroveil.json
  [OK] roundtripCache presente junto al config
```

## Confirmación del Xid 109

Antes de aplicar el fix, verificar que el crash es el `CTX SWITCH TIMEOUT`:

```bash
journalctl -b --no-pager -p warning | grep -i "xid"
```

Tras aplicar Pyroveil, el Xid 109 deja de aparecer en boots con SM2 ejecutado.

## Notas adicionales

- Driver muy reciente (610, Blackwell) y aun así el bug se reproducía sin Pyroveil — no es un problema de driver viejo. Otros reportes del mismo Xid 109 en serie 5000 usan driver 595 con open kernel modules; afecta a toda la familia Blackwell.
- `gamemoderun` NO disponible en esta imagen (se perdió del layering en un rebase); no incluirlo en launch options o el juego no arranca.
- Proton 11 al ser beta: si un update reintroduce stutter o "precreating shaders" largo, borrar `cache/` de Pyroveil + shader cache de Steam para regenerar.
