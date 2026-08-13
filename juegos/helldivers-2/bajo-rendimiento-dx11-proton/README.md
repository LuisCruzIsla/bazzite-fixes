# Helldivers 2: rendimiento muy por debajo de Windows con la GPU infrautilizada (Proton)

> **Estado:** solución confirmada. El juego corre por defecto en DirectX 11 traducido por DXVK, lo que serializa los draw calls en un solo hilo de CPU y deja la GPU a menos de la mitad de uso. Forzar DirectX 12 (vkd3d-proton) sube el rendimiento de forma sustancial. La corrección vive en `user_settings.config` y en las opciones de lanzamiento de Steam.

## Síntoma

**Helldivers 2** rinde claramente peor bajo Proton que en Windows con hardware equivalente o **incluso inferior**. El detalle que delata el problema: **bajar la resolución no aumenta los fps**.

```
GPU de gama alta, monitor 1080p
  ↳ escala de renderizado bajada hasta el 58% (render interno < 720p)
  ↳ los fps NO suben
  ↳ el monitor de rendimiento muestra la GPU al ~40% de uso
  ↳ un equipo con GPU inferior en Windows va mejor
```

El overlay del juego (Opciones → Pantalla → Monitor de rendimiento) muestra el patrón característico:

```
FPS 70   CPU 53%/pico 76%   GPU 41%   VRAM 5.4/15.9 GB
```

Una GPU al 41% con fps bajos significa que **la GPU está esperando a la CPU**. El cuello no está donde parece.

## Quién está afectado

| Factor | Valor |
|--------|-------|
| Juego | **Helldivers 2** (motor Autodesk Stingray / Bitsquid) |
| Runtime | **Proton** (cualquier versión con vkd3d-proton) |
| Backend de render | **DirectX 11** → traducido por **DXVK** (valor por defecto) |
| GPU | Cualquiera. El síntoma es más llamativo cuanto **mejor** es la GPU |
| CPU | Cualquiera; agrava con IPC bajo o pocos núcleos rápidos |

**No afecta** a partidas ya configuradas en DirectX 12, ni es exclusivo de NVIDIA — el cuello es la traducción de la API, no el driver gráfico.

Helldivers 2 genera un volumen muy alto de draw calls (hordas de decenas de enemigos, partículas, escombros). DX11 concentra el envío de esos draw calls en un único hilo, y DXVK añade su propio coste de traducción encima. Con DX12/vkd3d-proton el envío se reparte y el coste por llamada baja.

Ver [`casos/`](./casos/) para configuraciones específicas confirmadas.

## Causa raíz

Multi-capa. La capa dominante es la primera; el resto amplifica el problema.

1. **Backend DirectX 11 sobre DXVK.** `render_backend = 0` en `user_settings.config`. DX11 serializa el envío de draw calls en un hilo, y DXVK traduce cada llamada a Vulkan. En una escena con hordas, ese hilo satura antes de que la GPU llegue siquiera a la mitad de su capacidad. Es un límite de CPU, no de GPU.

2. **NVAPI no expuesto al prefix.** Sin `PROTON_ENABLE_NVAPI=1`, la opción "Latencia baja de NVIDIA Reflex" aparece activada en el menú pero es **decorativa**: el juego no tiene a quién pedir la reducción de latencia. En Windows sí opera. Esto no cambia los fps, pero sí la latencia de input — parte de la sensación de "allá va mejor" que no se ve en el contador.

3. **XWayland de por medio.** Sin `PROTON_ENABLE_WAYLAND=1` en sesión Wayland, el juego pasa por la capa de compatibilidad X11 en vez de hablar con el compositor directamente.

4. **Configuración compensatoria mal orientada.** Al no subir los fps, es habitual bajar la escala de renderizado y activar el sombreado de tasa variable (VRS). Ambas son optimizaciones **de GPU**, aplicadas sobre una GPU que está ociosa: degradan la imagen sin devolver un solo fotograma. El problema se enmascara y empeora visualmente.

## Soluciones que NO funcionan (anti-patrones)

- **Bajar la escala de renderizado.** Es el reflejo natural y es exactamente lo contrario de lo que hace falta. Si el cuello es la CPU, reducir píxeles no devuelve fps: solo empeora la imagen. **Si bajar la resolución no sube los fps, deja de bajarla — acabas de diagnosticar un límite de CPU.**
- **Activar el sombreado de tasa variable (VRS) en modo rendimiento.** Alivia la GPU. Con la GPU al 40% no hay nada que aliviar; se paga calidad de imagen a cambio de cero.
- **Bajar el preset gráfico general.** Mezcla ajustes de GPU (gratis en este escenario) con ajustes de CPU (los únicos que importan). Bajarlo todo sacrifica mucha imagen para recuperar poco.
- **Instalar `gamemode`.** En Bazzite el governor de CPU ya viene en `performance`. No aporta nada y en un sistema inmutable cuesta un layering de `rpm-ostree` más un reinicio. Verificar antes con `cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor`.
- **Cambiar de versión de Proton o recrear el prefix.** El backend por defecto seguirá siendo DX11; el síntoma vuelve idéntico.
- **`DXVK_ASYNC=1`.** Proton no incluye el parche async. La variable se ignora.

## Solución completa

### Paso 1 — Forzar DirectX 12 (la capa que resuelve el problema)

Con el juego **cerrado**, editar `user_settings.config` dentro del prefix:

```
<BIBLIOTECA_STEAM>/steamapps/compatdata/553850/pfx/drive_c/users/steamuser/AppData/Roaming/Arrowhead/Helldivers2/user_settings.config
```

Cambiar:

```
render_backend = 0    →    render_backend = 1
```

`0` es DirectX 11 (DXVK), `1` es DirectX 12 (vkd3d-proton). Hacer copia del archivo antes de tocarlo; si el juego no arrancara, se restaura o se vuelve a poner `0`.

La primera partida tras el cambio tendrá tirones mientras vkd3d compila sus shaders desde cero. Es normal y no se repite: juzgar el resultado a partir de la segunda.

### Paso 2 — Opciones de lanzamiento

Steam → clic derecho en **HELLDIVERS 2** → **Propiedades** → **General** → **Opciones de lanzamiento**:

```
PROTON_ENABLE_NVAPI=1 PROTON_ENABLE_WAYLAND=1 PROTON_LOCAL_SHADER_CACHE=1 LOW_LATENCY_LAYER=1 %command%
```

- `PROTON_ENABLE_NVAPI=1` → expone NVAPI al prefix; sin esto Reflex y DLSS no tienen interlocutor.
- `LOW_LATENCY_LAYER=1` → habilita la capa Vulkan de baja latencia que Reflex necesita para operar de verdad.
- `PROTON_ENABLE_WAYLAND=1` → Wayland nativo en vez de XWayland. **Es el primero que hay que quitar si algo falla**, sobre todo con anticheat.
- `PROTON_LOCAL_SHADER_CACHE=1` → caché de shaders local al prefix, evita invalidaciones del caché compartido de Steam.

En GPU no NVIDIA, omitir `PROTON_ENABLE_NVAPI` y `LOW_LATENCY_LAYER`.

### Paso 3 — Recuperar calidad de imagen (Opciones → Pantalla)

Al dejar de estar limitado por GPU, la resolución sale prácticamente gratis:

| Ajuste | Valor |
|--------|-------|
| Escala de renderizado | **Nativo** |
| Anti-Aliasing | **DLSS** (con escala nativa esto es DLAA: máxima calidad) |
| Sombreado de tasa variable | **Desactivado** |
| Escala de resolución dinámica | Desactivada (su oscilación ensucia el frametime) |
| Modo de visualización | Pantalla completa |
| Latencia baja de NVIDIA Reflex | Activado |

### Paso 4 — Campo de visión

El **campo de visión vertical** al máximo (90) equivale a unos 121° horizontales en 16:9 y produce distorsión de perspectiva tipo ojo de pez en los bordes. Bajarlo a **70-75** corrige el encuadre **y** libera CPU, porque entran menos objetos en el frustum. Es el único ajuste que mejora imagen y rendimiento a la vez.

### Paso 5 — Repartir la calidad según el recurso correcto

Con la GPU aún con margen, subir sólo lo que es trabajo de GPU:

| Suben gratis (GPU) | No tocar (CPU) |
|--------------------|----------------|
| Calidad de iluminación | Distancia de renderizado |
| Calidad de reflejos | Vegetación y densidad de escombros |
| Calidad de niebla volumétrica | Calidad de detalle de objeto |
| Calidad de nubes volumétricas | Calidad de partículas |
| Calidad de texturas | |

**Regla general:** lo que **añade objetos a la escena** es CPU; lo que **añade detalle a píxeles que ya existen** es GPU. La calidad de sombras es mixta — subirla de una en una y medir.

Ajuste fino: con DLAA a resolución nativa, la **Definición** (sharpening) en 0,75 genera halos. Bajarla a ~0,5.

### Paso 6 — VRR

Con la sincronización vertical desactivada y sin VRR hay tearing. En GNOME 48 y posteriores la frecuencia de actualización variable **ya no está en `experimental-features`** (intentarlo devuelve "valor fuera de rango"): es un interruptor en **Configuración → Pantallas**.

## Verificación

```bash
./verify-fix.sh
```

Ejecutar con el juego **abierto**. Resultado esperado:

- El proceso carga `d3d12core.dll` → la ruta DX12 está activa.
- `PROTON_ENABLE_NVAPI` y `LOW_LATENCY_LAYER` presentes en el entorno del proceso.
- `render_backend = 1` en la configuración.
- El uso de GPU deja de estar anclado por debajo del 50% mientras los fps siguen bajos.

Validación real definitiva: **jugar una misión de dificultad alta y comparar los fps con los de antes del cambio.** El hangar de la nave no sirve como referencia — es una escena mucho más ligera que un planeta con hordas.

## Por qué sobrevive a actualizaciones

| Capa | Garantía |
|------|----------|
| Opciones de lanzamiento (Steam) | Se guardan en `localconfig.vdf` del usuario; ni una actualización de Steam ni del juego las tocan. |
| `render_backend` | Persiste en `user_settings.config` entre sesiones y parches. El juego reescribe el archivo al arrancar pero **conserva el valor**. |
| Variables de Proton | Son estándar del runtime, no dependen de la versión del juego. |
| Ajustes gráficos | Se guardan en el mismo archivo y se pueden reponer desde el menú. |

Dos campos **sí** los reescribe el juego en cada arranque y conviene ignorarlos: `enable_resource_lock_debug` vuelve a `true`, y el límite de fotogramas se restablece a `144`. Ninguno de los dos afecta al resultado.

Si una versión futura de Helldivers 2 pusiera DX12 por defecto, el cambio quedaría redundante, no dañino.

## Diagnóstico si vuelve a fallar

1. **Confirmar qué API está usando** (con el juego abierto). La prueba directa:
   ```bash
   pid=$(pgrep -f helldivers2.exe | head -1)
   grep -oE "d3d12core\.dll|d3d11\.dll" /proc/$pid/maps | sort -u
   ```
   Si sólo aparece `d3d11.dll`, sigue en DirectX 11.

2. **Pista indirecta rápida** (sin el juego abierto): si `steamapps/shadercache/553850/DXVK_state_cache` crece, se está usando DXVK, es decir DX11.

3. **Confirmar que las variables llegan al proceso:**
   ```bash
   tr '\0' '\n' < /proc/$pid/environ | grep -E "NVAPI|LOW_LATENCY|WAYLAND"
   ```

4. **Determinar si el cuello es CPU o GPU:** activar Opciones → Pantalla → **Monitor de rendimiento** y mirar **en misión**, no en la nave.
   - GPU por debajo del 60% con fps bajos → límite de CPU. Bajar calidad gráfica no devolverá fps.
   - GPU al 90-100% → límite de GPU. Ahí sí bajar ajustes gráficos rinde.

5. **Verificar el governor** antes de culpar al sistema:
   ```bash
   cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
   ```
   Debe decir `performance`.

6. **Si el juego no arranca tras el cambio:** restaurar la copia de `user_settings.config` o volver a `render_backend = 0`, y quitar `PROTON_ENABLE_WAYLAND=1` como primer sospechoso.

## Casos confirmados

| # | Distro | GPU / Driver | CPU | Resultado |
|---|--------|--------------|-----|-----------|
| 001 | Bazzite 44 | NVIDIA RTX 5070 Ti / 610.43.03 | Ryzen 9 5900X | ~70 → ~101 fps (+44%) y mejor imagen |

## Referencias técnicas

- [vkd3d-proton — traducción de Direct3D 12 a Vulkan](https://github.com/HansKristian-Work/vkd3d-proton)
- [DXVK — traducción de Direct3D 9/10/11 a Vulkan](https://github.com/doitsujin/dxvk)
- [dxvk-nvapi — soporte de NVAPI en Proton (Reflex, DLSS)](https://github.com/jp7677/dxvk-nvapi)
- [Proton — variables de entorno documentadas](https://github.com/ValveSoftware/Proton#runtime-config-options)
- [ProtonDB — Helldivers 2 (AppID 553850)](https://www.protondb.com/app/553850)
- [NVIDIA Reflex — Vulkan low latency layer](https://developer.nvidia.com/performance-rendering-tools/reflex)

## Contribuir

Ver [`CONTRIBUTING.md`](../../../CONTRIBUTING.md) en la raíz del repositorio.
