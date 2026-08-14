# MangoHud: solo aparece si se edita las opciones de lanzamiento de cada juego

> **Estado:** solución confirmada

## Síntoma

MangoHud viene preinstalado en Bazzite, pero el overlay **no aparece en ningún juego** salvo que se anteponga la variable o el wrapper en las opciones de lanzamiento, uno por uno:

```
MANGOHUD=1 %command%
mangohud %command%
```

Con decenas de juegos en la biblioteca esto significa editar cada entrada a mano, y cada juego nuevo arranca sin overlay hasta que uno se acuerda de configurarlo.

El contador de FPS integrado de Steam sí es global, pero **no muestra utilización de GPU**, que es el dato que distingue un cuello de botella de CPU de uno de GPU. Con solo los FPS a la vista no se puede diagnosticar por qué un juego rinde por debajo de lo esperado.

## Quién está afectado

| Componente | Valor |
|------------|-------|
| Distro | Bazzite / Fedora Atomic (cualquier versión con MangoHud preinstalado) |
| MangoHud | 0.8.x (verificado en 0.8.4) |
| Escritorio | Indistinto — GNOME o KDE, X11 o Wayland |
| GPU | Indistinta — NVIDIA, AMD o Intel |
| Alcance | Todo juego Vulkan, incluidos los de Proton vía DXVK/VKD3D |

No afecta a quien solo quiera el overlay en uno o dos juegos: para ese caso las opciones de lanzamiento son suficientes.

Ver [`casos/`](./casos/) para hardware específico confirmado.

## Causa raíz

MangoHud se registra ante el cargador de Vulkan como **capa implícita**. Los archivos de registro viven en `/usr/share/vulkan/implicit_layer.d/` y contienen un bloque `enable_environment`:

```json
{
  "layer": {
    "name": "VK_LAYER_MANGOHUD_overlay_x86_64",
    "library_path": "/usr/lib64/mangohud/libMangoHud.so",
    "enable_environment": {
      "MANGOHUD": "1"
    },
    "disable_environment": {
      "DISABLE_MANGOHUD": "1"
    }
  }
}
```

`enable_environment` invierte el comportamiento normal de una capa implícita: en vez de cargarse siempre, el cargador la **omite** salvo que la variable indicada esté presente en el entorno del proceso. Ese es el motivo exacto por el que hay que declarar `MANGOHUD=1` en cada juego.

La contraparte `disable_environment` (`DISABLE_MANGOHUD=1`) es la vía normal de exclusión y **no** depende de la anterior: sigue funcionando aunque se quite `enable_environment`.

Como el cargador de Vulkan busca capas en `$XDG_DATA_HOME/vulkan/implicit_layer.d/` **antes** que en `/usr/share/`, y descarta duplicados por nombre de capa quedándose con el primero, una copia en el home del usuario tiene precedencia sobre la del sistema sin necesidad de tocar `/usr/`.

## Soluciones que NO funcionan (anti-patrones)

- **Exportar `MANGOHUD=1` en `~/.bashrc` o `~/.profile`** — Steam y los lanzadores gráficos arrancan desde el `.desktop` de la sesión, no desde un shell interactivo. La variable nunca llega al juego.
- **Editar el JSON en `/usr/share/vulkan/implicit_layer.d/`** — en Fedora Atomic `/usr` es inmutable, y aunque se fuerce con `rpm-ostree`, el siguiente update o rebase revierte el cambio.
- **`~/.config/environment.d/` con `MANGOHUD=1`** — funciona, pero inyecta la variable en **todos** los procesos de la sesión de usuario, no solo en los juegos. Cualquier aplicación Vulkan del escritorio termina con el overlay encima.
- **Confiar en el contador de FPS de Steam** — es global y liviano, pero solo reporta FPS y frametime. Sin utilización de GPU no permite distinguir CPU-bound de GPU-bound, que suele ser la pregunta real.
- **Esperar que cubra juegos OpenGL** — la capa implícita es exclusivamente Vulkan. Los títulos OpenGL nativos usan `libMangoHud_opengl.so` vía `LD_PRELOAD` y quedan fuera (ver limitaciones abajo).
- **Suponer que basta con instalar MangoHud** — el paquete se instala activado en el sentido de "registrado", pero inerte por el `enable_environment`.

## Solución

Copiar los archivos de registro de la capa al directorio del usuario, quitándoles el bloque `enable_environment`. Sin él, la capa vuelve a comportarse como implícita normal: se carga sola en todo proceso Vulkan.

### Paso 1 — Activar la capa globalmente

```bash
./enable-mangohud-global.sh
```

El script copia las capas de 64 y 32 bits desde `/usr/share/vulkan/implicit_layer.d/` a `~/.local/share/vulkan/implicit_layer.d/`, elimina `enable_environment` y conserva `disable_environment`. No requiere sudo y no toca `/usr/`.

Equivalente manual, si se prefiere no usar el script:

```bash
mkdir -p ~/.local/share/vulkan/implicit_layer.d
for a in x86_64 x86; do
  python3 -c "
import json, os, sys
a = sys.argv[1]
d = json.load(open(f'/usr/share/vulkan/implicit_layer.d/MangoHud.{a}.json'))
d['layer'].pop('enable_environment', None)
json.dump(d, open(os.path.expanduser(f'~/.local/share/vulkan/implicit_layer.d/MangoHud.{a}.json'), 'w'), indent=2)
" "$a"
done
```

Los juegos de 32 bits necesitan la capa `x86`; por eso se copian ambas.

### Paso 2 — Configurar el overlay

Copiar [`MangoHud.conf`](./MangoHud.conf) a `~/.config/MangoHud/MangoHud.conf`:

```bash
mkdir -p ~/.config/MangoHud
cp MangoHud.conf ~/.config/MangoHud/MangoHud.conf
```

La config incluida usa un layout de **una sola línea** (`horizontal` + `hud_compact` + `hud_no_margin`), pensado para ser tan poco invasivo como el contador de Steam pero con los datos que aquel no da:

```
GPU 68% 6.2GiB | CPU 91% 14.1GiB | 142 FPS 7.0ms | 1920x1080
```

La clave del diagnóstico son `gpu_load_change` y `cpu_load_change` con umbrales en 60 y 90: ambos porcentajes cambian de color al cruzarlos. **GPU en verde con CPU en rojo significa CPU-bound**, sin necesidad de leer los números.

### Paso 3 — Atajos de teclado

La config define estos atajos:

| Atajo | Acción |
|-------|--------|
| `Shift_R+F10` | Ocultar / mostrar el overlay |
| `Shift_R+F11` | Rotar el overlay entre las esquinas |
| `Shift_L+F4` | Recargar la config sin reiniciar el juego |
| `Shift_L+F2` | Grabar 60 s de log a `output_folder` |

`Shift_R+F11` resuelve el caso frecuente de un juego que dibuja su propio HUD en la misma esquina: se mueve el overlay en vez de apagarlo.

**El atajo de ocultar se puso deliberadamente en F10 y no en el `Shift_R+F12` que trae MangoHud por defecto**, porque F12 es la tecla de captura de pantalla de Steam. Con el binding por defecto, ocultar el overlay dispara además una captura en cada pulsación.

### Paso 4 (opcional) — Consultar el upscaler activo

MangoHud **no tiene** indicador de DLSS, DLAA, FSR ni frame generation; no existe como parámetro. Se puede emular con `custom_text` + `exec`, pero `exec` ejecuta el comando en cada refresco del overlay, lo que es contraproducente justo en los juegos CPU-bound donde más interesa medir.

[`que-upscaler`](./que-upscaler) lo resuelve como consulta puntual, leyendo qué DLLs tiene mapeados el proceso del juego:

```bash
cp que-upscaler ~/.local/bin/ && chmod +x ~/.local/bin/que-upscaler
que-upscaler                  # todos los .exe Wine/Proton corriendo
que-upscaler <nombre-juego>   # uno concreto
```

Distingue entre:

| DLL mapeado | Significa |
|-------------|-----------|
| `nvngx_dlss.dll` | DLSS Super Resolution **o** DLAA |
| `nvngx_dlssg.dll` | DLSS Frame Generation |
| `nvngx_dlssd.dll` | DLSS Ray Reconstruction |
| `libxess.dll` | XeSS (Intel) |
| `amd_fidelityfx_upscaler_dx12.dll` | FSR |

Dos limitaciones honestas: **DLSS y DLAA comparten el mismo DLL** y se diferencian solo por el factor de escala, así que el script confirma que está cargado pero no cuál de los dos modos está activo. Y si un juego no trae `nvngx_dlssg.dll` en su carpeta, simplemente no implementa frame generation — no hay nada que medir.

Como diagnóstico previo, listar los DLLs que el juego trae de fábrica dice qué soporta antes siquiera de lanzarlo:

```bash
ls "<ruta del juego>/bin/" | grep -iE "nvngx|dlss|xess|fidelityfx"
```

## Verificación

```bash
./verify-fix.sh
```

Resultado esperado:

- `[OK]` las dos capas presentes en `~/.local/share/vulkan/implicit_layer.d/`
- `[OK]` ninguna conserva `enable_environment`
- `[OK]` `vulkaninfo` enumera `VK_LAYER_MANGOHUD_overlay_*` **sin** `MANGOHUD` en el entorno
- `[OK]` `library_path` de la copia de usuario coincide con la del sistema
- Con un juego corriendo, `libMangoHud.so` mapeado en `/proc/<PID>/maps`

El último punto confirma que la capa entró en el proceso. **No confirma que el overlay se esté dibujando** — eso se comprueba a ojo.

## Por qué sobrevive a actualizaciones

| Capa | Persistencia |
|------|--------------|
| `~/.local/share/vulkan/implicit_layer.d/` | Sobrevive a `rpm-ostree upgrade` y a rebases: no vive en `/usr/` |
| Independiente de Steam | Sobrevive a Steam Cloud sync, que sí puede pisar las opciones de lanzamiento |
| Independiente de la aplicación | Sobrevive a suspend/resume: la capa se resuelve en el `exec`, no en runtime |
| `~/.config/MangoHud/MangoHud.conf` | Pertenece al usuario; ninguna actualización lo toca |

**Advertencia sobre la copia de usuario:** al tener precedencia sobre la del sistema, queda congelada en la versión del día que se creó. Si una actualización de MangoHud cambia `library_path` o `api_version`, la copia obsoleta gana y la capa puede dejar de cargar. `verify-fix.sh` compara ambas rutas y avisa; ante una discrepancia, basta con volver a ejecutar `enable-mangohud-global.sh`.

## Limitaciones conocidas

| Caso | ¿Cubierto? | Motivo |
|------|-----------|--------|
| Juegos Proton (DX9/10/11/12) | Sí | DXVK y VKD3D traducen todo a Vulkan |
| Juegos nativos Vulkan | Sí | Directo |
| Lutris, Heroic, binarios sueltos | Sí | No depende de Steam |
| Juegos de 32 bits | Sí | Se instalan ambas capas |
| Juegos nativos OpenGL | **No** | La capa implícita es solo Vulkan; usar `mangohud %command%` |
| Juegos en Flatpak | **No** | Runtime aislado, no ve `~/.local/share`; requiere la extensión MangoHud de Flatpak |

Para excluir un juego concreto sin desactivar nada global, anteponer en sus opciones de lanzamiento:

```
DISABLE_MANGOHUD=1 %command%
```

## Diagnóstico si vuelve a fallar

```bash
# 1. ¿Están las capas de usuario y sin enable_environment?
grep -l enable_environment ~/.local/share/vulkan/implicit_layer.d/MangoHud.*.json

# 2. ¿El cargador las enumera sin la variable?
env -u MANGOHUD vulkaninfo --summary 2>/dev/null | grep -i mangohud

# 3. ¿La capa entró en el proceso del juego?
GAME_PID=$(pgrep -f "<nombre del .exe>" | head -1)
grep -i mangohud /proc/$GAME_PID/maps

# 4. ¿Algo la está desactivando por variable?
tr '\0' '\n' < /proc/$GAME_PID/environ | grep -i mangohud
```

Lecturas:

- **(1) devuelve algún archivo** → la copia conserva `enable_environment`; volver a ejecutar el script.
- **(2) vacío** → el cargador no ve las capas de usuario; revisar permisos y `XDG_DATA_HOME`.
- **(3) vacío con (2) correcto en un juego de Steam** → el contenedor de pressure-vessel no montó la ruta; usar `mangohud %command%` en ese juego.
- **(4) muestra `DISABLE_MANGOHUD=1`** → hay una exclusión explícita en las opciones de lanzamiento.

En juegos de Steam la ruta aparece reescrita como `/run/host/usr/lib64/mangohud/libMangoHud.so`: es el bind-mount del contenedor y es el resultado correcto.

## Casos confirmados

| # | Distro | Hardware / Juego |
|---|--------|------------------|
| [001](./casos/001-bazzite44-rtx5070ti.md) | Bazzite 44 | RTX 5070 Ti — Helldivers 2 bajo Proton Experimental |

## Referencias técnicas

- [MangoHud — repositorio y documentación de parámetros](https://github.com/flightlessmango/MangoHud)
- [Vulkan Loader — Layer Discovery y orden de búsqueda](https://github.com/KhronosGroup/Vulkan-Loader/blob/main/docs/LoaderLayerInterface.md)
- Especificación de `enable_environment` / `disable_environment` en el manifiesto de capas implícitas
- [pressure-vessel — contenedor del Steam Linux Runtime](https://gitlab.steamos.cloud/steamrt/steam-runtime-tools)

## Contribuir

Ver [`CONTRIBUTING.md`](../../CONTRIBUTING.md) en la raíz.
