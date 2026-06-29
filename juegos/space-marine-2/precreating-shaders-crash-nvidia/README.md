# Space Marine 2: crash en NVIDIA serie 5000 — Xid 109 CTX SWITCH TIMEOUT

> **Estado:** solución confirmada (vía capa upstream [Pyroveil](https://github.com/HansKristian-Work/pyroveil))

## Síntoma

En **Warhammer 40,000: Space Marine 2** (Steam app `2183900`) con Proton sobre GPU NVIDIA serie 5000 (Blackwell):

- El menú funciona y **EasyAntiCheat carga bien**, pero el juego **crashea/congela justo después de la primera cinemática** (escena `story_intro`), al cargar el gameplay — la GPU se cuelga.
- También puede manifestarse como cuelgue en `PRECREATING SHADERS` o stutter severo al compilar shaders.

```
Game crashes/freezes immediately after the first cutscene (story_intro)
```

## Cómo confirmar que es este problema

```bash
journalctl -b --no-pager -p warning | grep -i "xid"
```

Si es este bug, aparece un **Xid 109** con `CTX SWITCH TIMEOUT`:

```
NVRM: Xid (PCI:0000:01:00): 109, pid=XXXXX, name=Warhammer 40000, channel 0x0000000a, errorString CTX SWITCH TIMEOUT, Info 0xc006
```

## Quién está afectado

| Factor | Valor |
|--------|-------|
| Juego | Space Marine 2 (app `2183900`), motor DX12 → VKD3D-Proton |
| GPU | **NVIDIA serie 5000 (Blackwell)** — confirmado en RTX 5060 Ti y RTX 5070 Ti, con driver propietario y open kernel modules |
| Runtime | Proton (Experimental, GE, proton-cachyos, 11 beta) sobre el driver NVIDIA |
| Distro | Cualquiera; reportado en CachyOS, documentado aquí en **Bazzite / Fedora Atomic** |

No afecta a GPUs AMD/Intel (Mesa RADV/ANV), donde los shaders compilan sin el bug.

## Causa raíz

Bug del **driver NVIDIA en Blackwell**: ciertos compute shaders de SM2 usan instrucciones SPIR-V que el driver de la serie 5000 no maneja, provocando un **context switch timeout** que cuelga la GPU. En `journalctl` aparece como **`Xid 109 — CTX SWITCH TIMEOUT`**. La extensión `VK_NV_raw_access_chains` agrava la incompatibilidad.

La causa no está en Proton ni en el juego, sino en cómo el driver NVIDIA digiere ese SPIR-V concreto. Por eso ninguna versión de Proton lo arregla por sí sola.

## Soluciones que NO funcionan (anti-patrones)

- **`DXVK_ASYNC=1`** — inerte: SM2 es DX12 y usa VKD3D-Proton, no DXVK. Aparece en algunos reportes de la comunidad junto a la solución, pero no aporta nada (no daña). El que arregla es Pyroveil.
- **`VKD3D_CONFIG=no_upload_hvv`** y otros tweaks de VRAM — mitigan stutter genérico, no el bug de shaders NVIDIA.
- **Borrar el shader cache de Steam** repetidamente — el cache se vuelve a generar roto porque el origen es el driver.
- **Bajar settings gráficos** — el crash de "Precreating Shaders" ocurre antes del gameplay.
- **Cambiar de versión de Proton a ciegas** — ninguna versión arregla por sí sola el bug del driver.

## Solución

La solución de raíz es **Pyroveil**, una capa (layer) Vulkan de Hans-Kristian Arntzen (Valve) que intercepta los shaders problemáticos y los reescribe (roundtrip SPIRV-Cross → glslang) a un SPIR-V que el driver NVIDIA digiere bien, además de desactivar `VK_NV_raw_access_chains`. El propio repo de Pyroveil incluye un config listo para SM2 en [`hacks/space-marine-2-nv/`](https://github.com/HansKristian-Work/pyroveil/tree/master/hacks/space-marine-2-nv).

> Este repo **no redistribuye** Pyroveil ni su config. Se obtienen del upstream (ver [Créditos y licencia](#créditos-y-licencia-upstream)). Aquí se documenta sólo cómo aplicarlo en Bazzite.

### Paso 1 — Obtener y construir Pyroveil

Bazzite es inmutable: no hay `base-devel` en el sistema. Construir dentro de un contenedor de desarrollo (`distrobox`/`toolbox`) con las herramientas de compilación, o instalando `cmake`/`ninja`/gcc vía `brew`.

```bash
git clone https://github.com/HansKristian-Work/pyroveil.git ~/pyroveil
cd ~/pyroveil
git submodule update --init
cmake . -Bbuild -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$HOME/.local
ninja -C build install
```

Esto deja el layer en rutas que Steam (incluida la versión Flatpak/runtime) ya busca:

- `$HOME/.local/lib/libVkLayer_pyroveil_64.so`
- `$HOME/.local/share/vulkan/implicit_layer.d/VkLayer_pyroveil_64.json`

### Paso 2 — Launch options en Steam

Propiedades de SM2 → Opciones de lanzamiento. Sustituir la ruta por la del checkout real:

```
PYROVEIL=1 PYROVEIL_CONFIG=/ruta/a/pyroveil/hacks/space-marine-2-nv/pyroveil.json PROTON_ENABLE_NVAPI=1 PROTON_LOCAL_SHADER_CACHE=1 PROTON_ENABLE_WAYLAND=1 %command%
```

| Variable | Para qué |
|----------|----------|
| `PYROVEIL=1` + `PYROVEIL_CONFIG=...` | Activa la capa y el config de SM2 (el fix de raíz) |
| `PROTON_ENABLE_NVAPI=1` | Habilita DLSS/Reflex (NVAPI/NVNGX) |
| `PROTON_LOCAL_SHADER_CACHE=1` | Cache de shaders en el prefix, coherente con el `roundtripCache` de Pyroveil |
| `PROTON_ENABLE_WAYLAND=1` | Backend Wayland nativo (opcional; requiere Proton 11+; quitar si hay glitches) |

El config de SM2 usa un `roundtripCache` en `cache/` junto al `pyroveil.json` — por eso se apunta a la ruta del checkout, que ya lo trae.

### Paso 3 — Proton recomendado

Proton **11 beta** (o Experimental reciente) en GPU Blackwell (RTX 50): mejor soporte NVAPI y backend Wayland nativo. Pyroveil funciona también con Proton oficial estable y GE.

## Verificación

```bash
./verify-fix.sh
```

Comprueba que el layer está instalado y, si se corrió el juego con `PROTON_LOG=1`, que Pyroveil encontró el config y aplicó los matches.

Verificación manual (método oficial upstream), tras lanzar el juego una vez con `PROTON_LOG=1`:

```bash
grep "pyroveil:" ~/steam-2183900.txt
```

Salida esperada (entre otras líneas):

```
pyroveil: Found config in /ruta/a/pyroveil/hacks/space-marine-2-nv/pyroveil.json!
pyroveil: Adding GLSL roundtrip via SPIRV-Cross for match.
pyroveil: Found match for execution model in ...
```

## Por qué sobrevive a actualizaciones

| Capa | Garantía |
|------|----------|
| Layer Pyroveil en `~/.local` | Persiste a rebases de `rpm-ostree` (vive en `$HOME`, no en la imagen) |
| Launch options de Steam | Persisten en `localconfig.vdf` del usuario |
| Config de SM2 | Versionado en el repo upstream de Pyroveil |

Riesgo: una actualización del **driver NVIDIA** podría arreglar el bug de origen (haciendo Pyroveil innecesario) o, en Proton beta, cambiar el comportamiento del cache. Si tras un update vuelve el stutter o el crash, borrar el `cache/` de Pyroveil y el shader cache de Steam para regenerarlos.

## Diagnóstico si vuelve a fallar

```bash
# Volvió el Xid 109? (señal de que Pyroveil no se está aplicando)
journalctl -b --no-pager -p warning | grep -i "xid"

# El layer sigue instalado?
ls ~/.local/lib/libVkLayer_pyroveil_64.so ~/.local/share/vulkan/implicit_layer.d/VkLayer_pyroveil_64.json

# Pyroveil se activó en la última ejecución? (requiere PROTON_LOG=1)
grep -c "pyroveil:" ~/steam-2183900.txt

# Hay update del driver NVIDIA reciente? (podría hacer el fix innecesario)
rpm-ostree status | grep -i nvidia
```

Si NVIDIA corrige el Xid 109 en un driver futuro, este workaround puede dejar de ser necesario. El mismo Xid 109 en serie 5000 afecta a otros juegos (reportado en **Resident Evil 8**); Pyroveil con un config equivalente puede ayudar también ahí.

## Casos confirmados

| # | Distro | Hardware/versión |
|---|--------|------------------|
| [001](./casos/001-bazzite44-rtx5070ti.md) | Bazzite 44 | RTX 5070 Ti (Blackwell) + Ryzen 9 5900X, Proton 11 beta |

## Referencias

- [Pyroveil — repo upstream](https://github.com/HansKristian-Work/pyroveil)
- [Config SM2 en Pyroveil](https://github.com/HansKristian-Work/pyroveil/tree/master/hacks/space-marine-2-nv)
- [Pyroveil PR de origen del fix SM2 — `73dfb82`](https://github.com/HansKristian-Work/pyroveil/commit/73dfb82)
- [ProtonDB — Space Marine 2 (app 2183900)](https://www.protondb.com/app/2183900)
- [Steam — Bug Report: DLSS Internal Resolution Failure on Linux (NVIDIA)](https://steamcommunity.com/app/2183900/discussions/0/687492429636592023/)

## Créditos y licencia upstream

La solución de raíz es obra de terceros. El mérito técnico es de:

- **Pyroveil** — Hans-Kristian Arntzen para Valve Corporation. Licencia **MIT**.
  `Copyright (c) 2025 Hans-Kristian Arntzen for Valve Corporation`
  https://github.com/HansKristian-Work/pyroveil
- **Diagnóstico del Xid 109 y guía de aplicación a SM2** — [**Nefariouz**](https://www.protondb.com/users/812079574) en ProtonDB (perfil: https://www.protondb.com/users/812079574 — entorno CachyOS + RTX 5060 Ti, Proton Experimental/GE), que identificó el `CTX SWITCH TIMEOUT` y enlazó el [PR `73dfb82`](https://github.com/HansKristian-Work/pyroveil/commit/73dfb82) de Pyroveil.

Este documento es una **guía de aplicación en Bazzite** que adapta ese reporte a Fedora Atomic; no es una redistribución del software ni una copia de la guía original. El layer y el config de SM2 deben obtenerse del repositorio oficial de Pyroveil bajo su licencia MIT. Si reutilizas o redistribuyes Pyroveil o su config, conserva el aviso de copyright y la licencia MIT según exigen sus términos.

## Contribuir

Ver [`CONTRIBUTING.md`](../../../CONTRIBUTING.md) en la raíz.
