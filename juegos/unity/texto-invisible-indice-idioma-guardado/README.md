# Juegos Unity: texto de la interfaz invisible por un índice de idioma guardado

> **Estado:** solución confirmada. El juego arranca, los gráficos se ven, pero botones, etiquetas y diálogos salen vacíos. La fuente y el renderer están bien: la partida guardada tiene un índice de idioma que apunta a una tabla de textos que no existe, y el juego pinta cadenas vacías. Se resuelve corrigiendo ese índice en el archivo de guardado.

## Síntoma

El juego se ve completo salvo el texto que viene de su sistema de idiomas:

- Botones y paneles con el fondo dibujado pero sin letras.
- Siguen viéndose los textos fijos de la escena (etiquetas en inglés, números con fuentes especiales) porque no pasan por la tabla de idiomas.
- `Player.log` no registra errores de fuente ni de shader.

Antes de llegar a este estado es habitual haber visto las **claves** en lugar del texto, o avisos del propio juego como:

```
キーが見つかりません
NotFoundScenario:
```

Eso suele corregirse al arrancar el juego con un locale del idioma original (p. ej. `LANG=ja_JP.UTF-8`), pero el texto sigue invisible.

## Quién está afectado

| Factor | Valor |
|--------|-------|
| Motor | Unity (confirmado con 6000.3, Mono) con TextMeshPro y un sistema de idiomas propio que guarda el idioma elegido |
| Juegos | Sobre todo juegos de **un solo idioma** (p. ej. solo japonés) que igualmente detectan el idioma del sistema |
| Distro | Cualquiera. No depende de Bazzite ni de Fedora Atomic |
| Runtime | Cualquier Proton/Wine. Confirmado con Proton Hotfix vía umu |
| Lanzador | Lutris, Steam (juego no-Steam), Heroic — indistinto |
| GPU / driver | Irrelevante |
| Condición | El juego se abrió **al menos una vez** con un locale distinto del idioma del juego (p. ej. `es_ES`) |

Ver [`casos/`](./casos/) para configuraciones específicas confirmadas.

## Causa raíz

Multi-capa. El síntoma parece gráfico, pero la causa está en los datos guardados.

1. **Locale del sistema.** Wine traslada `LANG`/`LC_ALL` al idioma de Windows del prefix. Unity lo expone como `Application.systemLanguage`.

2. **Aplicación — detección de idioma.** En el primer arranque el juego mapea el idioma del sistema a un índice de su tabla de textos. Si el sistema no está en el idioma del juego, elige un índice distinto de 0 (típicamente el de "inglés") aunque esa tabla no exista en el build.

3. **Aplicación — persistencia.** El índice se guarda en la partida o en PlayerPrefs. En arranques posteriores manda el valor guardado: cambiar el locale después **no lo corrige**.

4. **Aplicación — render.** Con el índice fuera de rango, cada consulta a la tabla devuelve una cadena vacía. TextMeshPro dibuja correctamente un texto vacío. De ahí que fuentes, atlas y shaders estén sanos.

## Soluciones que NO funcionan (anti-patrones)

- **Instalar fuentes japonesas/CJK de Windows en el prefix** (Meiryo, Yu Gothic, MS Gothic). TextMeshPro no las usa: la fuente del juego va embebida con su atlas SDF ya generado.
- **Forzar otro backend gráfico** (`-force-d3d11`, `-force-d3d12`, WineD3D). El texto está vacío antes de llegar a la GPU. Además `-force-d3d11` no cambia nada en Unity 6 (ya es el predeterminado) y `-force-vulkan` impide arrancar si el build no incluye Vulkan (`InitializeEngineGraphics failed`).
- **Cambiar de versión de Proton.** El índice sigue guardado en el prefix.
- **Solo cambiar `LANG` en el lanzador.** Corrige las claves que no se encontraban, pero no reescribe el índice ya guardado.
- **Reinstalar el juego.** La partida vive en el prefix (`AppData/LocalLow`), no en la carpeta del juego.

## Solución completa

### Paso 1 — Arrancar con el locale del idioma del juego

En el entorno del lanzador (Lutris: *Configuración del sistema → Variables de entorno*; Steam: opciones de lanzamiento):

```bash
LANG=ja_JP.UTF-8 LC_ALL=ja_JP.UTF-8 %command%
```

Ajustar el locale al idioma original del juego. En Lutris, como entradas `env` del yml del juego:

```yaml
system:
  env:
    LANG: ja_JP.UTF-8
    LC_ALL: ja_JP.UTF-8
```

### Paso 2 — Localizar el índice de idioma guardado

Con el juego **cerrado**. La partida está en `AppData/LocalLow/<Compañía>/<Producto>` dentro del prefix (el nombre sale en la primera línea del `Player.log` o en la carpeta):

```bash
PFX=~/Games/<prefix>
ls "$PFX/drive_c/users/steamuser/AppData/LocalLow/"
SAVE="$PFX/drive_c/users/steamuser/AppData/LocalLow/<Compañía>/<Producto>"
grep -raoE '"?_?[A-Za-z]*[Ll]ang(uage)?(Index|Idx|No|ID|Id)"?[[:space:]]*[:=][[:space:]]*-?[0-9]+' "$SAVE"
```

Si no aparece en los archivos, buscarlo en las PlayerPrefs del registro del prefix:

```bash
grep -A40 '\[Software\\\\<Compañía>\\\\<Producto>\]' "$PFX/user.reg" | grep -i lang
```

### Paso 3 — Corregir el índice

Hacer un respaldo y poner el índice de la tabla que sí existe. En un juego de un solo idioma es `0`:

```bash
cd "$SAVE"
cp -a <archivo> <archivo>.bak
sed -i 's/"_languageIndex": 1,/"_languageIndex": 0,/' <archivo>
grep -ao '"_languageIndex": [0-9]*' <archivo>
```

Adaptar el nombre del campo al que devolvió el Paso 2. Si el juego tiene selector de idioma en sus opciones, elegir ahí el idioma correcto hace lo mismo sin editar archivos.

### Paso 4 — Abrir el juego

Los textos deben aparecer. Tras cerrar el juego, el índice debe seguir en `0` (el juego no lo vuelve a detectar si ya existe en la partida).

## Verificación

```bash
./verify-fix.sh <ruta-del-prefix> <Compañía/Producto> [indice-esperado]
```

Comprueba:

- Que los archivos de guardado no contienen un índice de idioma distinto del esperado (por defecto `0`).
- Que no hay PlayerPrefs de idioma en el registro del prefix, o las muestra para revisarlas.

## Por qué sobrevive a actualizaciones

| Capa | Garantía |
|------|----------|
| Locale (`LANG`/`LC_ALL`) | Vive en la configuración del lanzador. No depende del sistema ni de la versión de Proton. |
| Índice de idioma | Vive en la partida dentro del prefix. Las actualizaciones de Proton, del lanzador o de `rpm-ostree` no la tocan. |

Lo que **sí** puede romperlo: borrar la partida o recrear el prefix y abrir el juego sin el locale del Paso 1 (vuelve a guardarse un índice incorrecto), o una actualización del juego que reinicie los datos guardados.

## Diagnóstico si vuelve a fallar

1. **Ver el índice guardado:**
   ```bash
   ./verify-fix.sh <ruta-del-prefix> <Compañía/Producto>
   ```

2. **Confirmar que la fuente no es el problema** (el atlas SDF viene pre-generado). Con [UnityPy](https://github.com/K0lb3/UnityPy) en un entorno temporal:
   ```bash
   python3 -m venv /tmp/upy && /tmp/upy/bin/pip install -q UnityPy
   /tmp/upy/bin/python - "<juego>_Data" <<'PY'
   import sys, UnityPy
   for o in UnityPy.load(sys.argv[1]).objects:
       if o.type.name == "Texture2D":
           d = o.read()
           if "SDF" in d.m_Name:
               a = d.image.getchannel("A")
               print(d.m_Name, d.m_Width, "x", d.m_Height, "relleno:", round(sum(a.histogram()[1:]) / (a.width * a.height), 2))
   PY
   ```
   Un atlas con relleno > 0 tiene las letras dibujadas; la fuente no falla.

3. **Ver cuántas tablas de idioma trae el juego.** Buscar el objeto de idiomas en los assets y contar las hojas. Si solo hay una, el único índice válido es `0`:
   ```bash
   /tmp/upy/bin/python - "<juego>_Data" <<'PY'
   import sys, UnityPy, re
   for o in UnityPy.load(sys.argv[1]).objects:
       if o.type.name == "MonoBehaviour":
           raw = o.get_raw_data()
           if len(re.findall("[぀-ヿ一-鿿]{2,}", raw.decode("utf-8", "ignore"))) > 100:
               print(o.assets_file.name, o.path_id, raw[28:80])
   PY
   ```

4. **Comprobar el locale con que arranca el proceso:**
   ```bash
   tr '\0' '\n' < /proc/$(pgrep -f '<Juego>.exe' -n)/environ | grep -E '^(LANG|LC_ALL)='
   ```

## Casos confirmados

| # | Distro | Runtime | Lanzador | Resultado |
|---|--------|---------|----------|-----------|
| [001](./casos/001-bazzite44-proton-hotfix-lutris.md) | Bazzite 44 | Proton Hotfix (umu) | Lutris 0.5.22 | Texto visible |

## Referencias técnicas

- [Unity — `Application.systemLanguage`](https://docs.unity3d.com/ScriptReference/Application-systemLanguage.html)
- [Unity — `PlayerPrefs` y su ubicación en Windows](https://docs.unity3d.com/ScriptReference/PlayerPrefs.html)
- [Unity — `Application.persistentDataPath` (`AppData/LocalLow`)](https://docs.unity3d.com/ScriptReference/Application-persistentDataPath.html)
- [Unity — argumentos de línea de comandos del player](https://docs.unity3d.com/Manual/PlayerCommandLineArguments.html)
- [TextMeshPro — Font Assets](https://docs.unity3d.com/Packages/com.unity.textmeshpro@4.0/manual/FontAssets.html)

## Contribuir

Ver [`CONTRIBUTING.md`](../../../CONTRIBUTING.md) en la raíz del repositorio.
