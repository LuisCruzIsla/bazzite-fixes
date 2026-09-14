# Warcraft III: Reforged: el login falla con "Please check your VPN" bajo Proton

> **Estado:** solución confirmada. No es un problema de red ni de VPN: el cliente 3.0 (parche de septiembre de 2026) llama a `CertCreateCertificateChainEngine()` con una estructura más grande de la que acepta el `crypt32` de Wine 11.0, y todos los Proton actuales siguen en esa base. Se resuelve sustituyendo `crypt32.dll` por la versión con el arreglo de Wine 11.6 dentro de una copia de la herramienta de compatibilidad.

## Síntoma

Tras el parche **3.0** de Warcraft III: Reforged, el inicio de sesión de Battle.net dentro del juego no completa nunca:

```
Se produjo un error al procesar la solicitud.
Please check your VPN
```

Características del síntoma:

- El mensaje aparece **sin usar ninguna VPN**, y también aparece si se usa una.
- El navegador del sistema entra a `battle.net` sin problema: la conexión de red está sana.
- El launcher de Battle.net sí arranca y sí se actualiza; lo que falla es la autenticación.
- Antes del parche 3.0 el mismo prefix y la misma versión de Proton funcionaban.
- Reinstalar, reparar, cambiar de DNS o desactivar IPv6 no cambian nada.

## Quién está afectado

| Factor | Valor |
|--------|-------|
| Juego | **Warcraft III: Reforged 3.0** o posterior (parche de septiembre de 2026) |
| Runtime | **Cualquier Wine o Proton con base wine-11.0 o anterior** |
| Proton | Proton 10.x, Proton Experimental, GE-Proton 11-1 … 11-6, UMU-Proton |
| Lanzador | Steam (shortcut no-Steam de Battle.net), Lutris, Heroic, Bottles — indistinto |
| GPU / driver | Irrelevante. No es un problema gráfico |
| Distro | Irrelevante. Afecta igual a Bazzite, Arch, Ubuntu o SteamOS |

**No afecta** a instalaciones con Wine **11.6 o posterior** (ni a `wine-staging` equivalente), donde el arreglo ya está incorporado.

Ver [`casos/`](./casos/) para configuraciones específicas confirmadas.

## Causa raíz

Multi-capa. El síntoma habla de red, pero ninguna de las capas implicadas es de red.

1. **Aplicación.** El `ClientSdk.dll` que Blizzard incluye en el parche 3.0 crea su propio motor de cadena de certificados llamando a `CertCreateCertificateChainEngine()` y le pasa un `CERT_CHAIN_ENGINE_CONFIG` de **88 bytes** — el tamaño que tiene la estructura desde que Windows añadió el campo `dwExclusiveFlags`.

2. **Wine / crypt32.** El `crypt32` de **wine-11.0** valida `cbSize` contra los tamaños históricos (**64 y 80 bytes**) y rechaza cualquier otro con `E_INVALIDARG`. El motor no se crea, la validación de la cadena TLS de los servidores de Blizzard no se puede completar, y el cliente interpreta la respuesta fallida como "la red está manipulada o filtrada" → muestra el aviso de VPN. **El mensaje es un diagnóstico equivocado del propio juego.**

3. **Upstream.** Wine corrigió esto en **abril de 2026** y la corrección salió en **Wine 11.6** (commits `02bb0a34`, `eef8e97d`, `c7cc9be8`).

4. **Proton.** Ninguna build de Proton ha rebasado esa base todavía: GE-Proton11-6 (28 de agosto de 2026), la más reciente en el momento de escribir esto, sigue construida sobre **wine-11.0**. Por eso no existe "una versión de Proton que funcione": todas comparten el mismo `crypt32`.

5. **Prefix.** Proton copia sus DLL al prefix sólo cuando detecta un cambio de versión de la herramienta. Un prefix ya creado puede seguir arrancando con el `crypt32` viejo aunque la herramienta nueva esté asignada, si no se fuerza la actualización.

## Soluciones que NO funcionan (anti-patrones)

- **Desactivar la VPN, cambiar de DNS, desactivar IPv6, probar otra red.** El mensaje miente. La red no interviene: falla la construcción de la cadena de certificados dentro del proceso.
- **Probar otra versión de Proton.** Proton Experimental, Proton 10, GE-Proton 11-1/11-3/11-6 y UMU-Proton comparten base wine-11.0 o anterior. Rotar entre ellas consume horas y da siempre el mismo resultado.
- **Recrear el prefix o borrar `compatdata`.** El prefix nuevo se rellena con el `crypt32` de la misma build. El error vuelve idéntico.
- **`winetricks crypt32` / override a `native`.** Forzar la DLL nativa exige una `crypt32.dll` real de Windows y arrastra dependencias (`bcrypt`, `ncrypt`, `secur32`). Rompe más de lo que arregla y no es necesario: la builtin corregida existe.
- **Reinstalar el juego o pasar "Analizar y reparar" en Battle.net.** Los archivos del juego están sanos; el que falta es un arreglo del runtime.
- **Cambiar de lanzador (Steam → Lutris, Heroic o Bottles).** Sólo cambia quién arranca el proceso. Si el runner sigue en Wine ≤ 11.5, el fallo es el mismo.
- **Esperar a que Proton Experimental lo arregle.** Puede ocurrir en cualquier momento, pero a fecha de esta documentación no ha ocurrido. Comprobar primero (ver *Diagnóstico*) antes de aplicar el parche manual.

## Solución completa

Dos caminos. El primero es el preferible cuando está disponible.

### Opción A — Usar un Wine 11.6 o posterior (sin parchear nada)

Si el juego se lanza desde **Lutris**, **Heroic** o **Bottles**, basta con seleccionar un runner `wine-11.6` o superior (`wine-ge`, `wine-staging`, `lutris-wine` reciente). El arreglo ya está dentro. Comprobar la versión del runner:

```bash
"<ruta-del-runner>/bin/wine" --version
```

Esta opción deja de requerir mantenimiento en cuanto Proton rebase a wine-11.6: a partir de ahí, la herramienta parcheada sobra.

### Opción B — Copia de Proton con `crypt32.dll` corregido

Necesaria cuando el juego se lanza desde **Steam** (shortcut no-Steam del launcher de Battle.net), donde no se puede elegir la versión de Wine.

La idea es **no tocar la instalación original de Proton**: se hace una copia con otro nombre y se parchea la copia. Así, si algo falla, basta con volver a asignar la herramienta original.

#### B.1 — Obtener las DLL corregidas

Hay que conseguir `crypt32.dll` (x86_64 e i386) compilados desde Wine 11.6 para la misma base. Las distribuye [FerMPY/wc3-reforged-proton-fix](https://github.com/FerMPY/wc3-reforged-proton-fix).

**Son binarios de terceros que se colocan dentro del runtime.** Auditar antes de instalarlos no es paranoia, es lo mínimo:

```bash
# 1. Que exporte lo mismo que el original (recuento de exports)
objdump -p crypt32.dll | grep -c "^\s*\[" 

# 2. Que la función implicada esté presente
strings -a crypt32.dll | grep -x CertCreateCertificateChainEngine

# 3. Que no aparezcan URLs, IPs o rutas sospechosas
strings -a crypt32.dll | grep -Ei "https?://|([0-9]{1,3}\.){3}[0-9]{1,3}"
```

Lo esperado: **mismo número de exports** que el `crypt32.dll` del Proton original, la función presente, y ninguna URL o IP más allá de las que también aparecen en el binario original de Wine. Si algo no cuadra, no instalarlo.

#### B.2 — Crear la herramienta parcheada

Con Steam **cerrado**:

```bash
./install-wc3fix.sh <carpeta-con-las-dll> [GE-Proton11-6]
```

El script hace, de forma reproducible, lo que se puede hacer a mano:

```bash
TOOLS=~/.steam/root/compatibilitytools.d
cp -a "$TOOLS/GE-Proton11-6" "$TOOLS/GE-Proton11-6-wc3fix"

# las cuatro rutas donde vive crypt32.dll dentro de una build de Proton
cp x86_64/crypt32.dll "$TOOLS/GE-Proton11-6-wc3fix/files/lib/wine/x86_64-windows/crypt32.dll"
cp i386/crypt32.dll   "$TOOLS/GE-Proton11-6-wc3fix/files/lib/wine/i386-windows/crypt32.dll"
cp x86_64/crypt32.dll "$TOOLS/GE-Proton11-6-wc3fix/files/share/default_pfx/drive_c/windows/system32/crypt32.dll"
cp i386/crypt32.dll   "$TOOLS/GE-Proton11-6-wc3fix/files/share/default_pfx/drive_c/windows/syswow64/crypt32.dll"
```

**Las cuatro copias importan.** Las de `files/lib/wine/` son las que Proton instala en prefixes nuevos; las de `default_pfx` son la plantilla con la que se crea el prefix. Parchear sólo una pareja produce un fix que funciona "a veces" según cómo se creara el prefix.

Después hay que renombrar la herramienta para que Steam la liste como entrada propia, en `compatibilitytool.vdf` (el nombre interno y `display_name`) y en el archivo `version`. El script lo hace.

#### B.3 — Asignar la herramienta al juego

1. Reiniciar Steam por completo (`Salir`, no cerrar la ventana). Las herramientas de compatibilidad sólo se leen al arrancar.
2. Clic derecho en el acceso directo de **Battle.net** → **Propiedades** → **Compatibilidad**.
3. Marcar *Forzar el uso de una herramienta de compatibilidad de Steam Play* y elegir **GE-Proton11-6-wc3fix**.
4. Lanzar el juego una vez. Proton detecta el cambio de versión y actualiza el prefix.

#### B.4 — Forzar la actualización del prefix si hiciera falta

Si el prefix es anterior y no se actualiza solo, copiar las DLL directamente en él:

```bash
PFX=~/.local/share/Steam/steamapps/compatdata/<APPID>/pfx
cp x86_64/crypt32.dll "$PFX/drive_c/windows/system32/crypt32.dll"
cp i386/crypt32.dll   "$PFX/drive_c/windows/syswow64/crypt32.dll"
```

El `<APPID>` de un shortcut no-Steam es un número largo generado por Steam (10 cifras). Se localiza así:

```bash
grep -B2 -A6 'GE-Proton11-6-wc3fix' ~/.local/share/Steam/config/config.vdf
```

## Verificación

```bash
./verify-fix.sh
```

Comprueba, sin necesidad de tener el juego abierto:

- La herramienta parcheada existe y está registrada con nombre propio.
- Las **cuatro** copias de `crypt32.dll` difieren de las del Proton base (es decir, están sustituidas) y conservan los exports.
- El prefix del juego tiene efectivamente las DLL parcheadas, no las de la build original.
- Si el proceso está corriendo, que se esté ejecutando con la herramienta parcheada.

Validación real definitiva: **iniciar sesión en Battle.net desde el juego.** Si entra al menú principal, el arreglo está operando.

## Por qué sobrevive a actualizaciones

| Capa | Garantía |
|------|----------|
| Herramienta de compatibilidad (`compatibilitytools.d`) | Es una carpeta del usuario con nombre propio. Steam no la actualiza ni la borra; una actualización de Proton toca la original, no la copia. |
| Asignación al juego | Vive en `config.vdf` del usuario. Sobrevive a actualizaciones de Steam y del juego. |
| Prefix | Las DLL se recopian en cada cambio de versión de la herramienta. Mientras la herramienta siga parcheada, el prefix se repara solo. |
| Parche del juego | Un parche de Blizzard no puede deshacerlo: el arreglo está en el runtime, no en el juego. |

**Este arreglo es temporal por diseño.** En cuanto una build de Proton pase a wine-11.6 o posterior, deja de hacer falta: se reasigna la herramienta oficial y se borra la copia. Conviene revisar esto en cada actualización de Proton (ver *Diagnóstico*, punto 4).

Lo que **sí** puede romperlo: reinstalar Proton borrando `compatibilitytools.d`, o migrar la biblioteca de Steam a otro equipo sin copiar esa carpeta.

## Diagnóstico si vuelve a fallar

1. **Confirmar qué `crypt32.dll` está usando el prefix:**
   ```bash
   PFX=~/.local/share/Steam/steamapps/compatdata/<APPID>/pfx
   sha256sum "$PFX/drive_c/windows/system32/crypt32.dll" \
             ~/.steam/root/compatibilitytools.d/GE-Proton11-6-wc3fix/files/lib/wine/x86_64-windows/crypt32.dll
   ```
   Los dos hashes deben coincidir. Si no, el prefix quedó con la DLL vieja → repetir el paso B.4.

2. **Confirmar con qué herramienta arranca el juego** (con el proceso vivo):
   ```bash
   pid=$(pgrep -f "Battle.net.exe" | head -1)
   tr '\0' '\n' < /proc/$pid/environ | grep -E "STEAM_COMPAT_TOOL_PATHS|WINEPREFIX"
   ```
   Debe aparecer la ruta de `GE-Proton11-6-wc3fix`.

3. **Ver el error en crudo.** Con `WINEDEBUG=+crypt` en las opciones de lanzamiento, el rechazo aparece explícitamente en el log de Steam como llamada rechazada por tamaño de estructura.

4. **Comprobar si Proton ya rebasó a Wine 11.6** — si es así, este parche ya no hace falta:
   ```bash
   cat ~/.steam/root/compatibilitytools.d/<herramienta>/files/lib/wine/*/wine --version 2>/dev/null
   strings ~/.steam/root/compatibilitytools.d/<herramienta>/files/bin/wine64 2>/dev/null | grep -m1 "^wine-"
   ```

5. **Si el mensaje de VPN persiste con las DLL correctas**, entonces sí puede ser red: probar el login en `battle.net` desde el navegador y revisar si la cuenta tiene bloqueo por región o autenticación en dos pasos pendiente.

## Casos confirmados

| # | Distro | Runtime | Lanzador | Resultado |
|---|--------|---------|----------|-----------|
| 001 | Bazzite 44 | GE-Proton11-6 + crypt32 de Wine 11.6 | Steam (shortcut no-Steam) | Login correcto |

## Referencias técnicas

- [Wine Bugzilla — `CertCreateCertificateChainEngine` rechaza `CERT_CHAIN_ENGINE_CONFIG` de 88 bytes](https://bugs.winehq.org/)
- [`CERT_CHAIN_ENGINE_CONFIG` — documentación de Microsoft](https://learn.microsoft.com/en-us/windows/win32/api/wincrypt/ns-wincrypt-cert_chain_engine_config)
- [`CertCreateCertificateChainEngine` — documentación de Microsoft](https://learn.microsoft.com/en-us/windows/win32/api/wincrypt/nf-wincrypt-certcreatecertificatechainengine)
- [FerMPY/wc3-reforged-proton-fix — DLL corregidas](https://github.com/FerMPY/wc3-reforged-proton-fix)
- [GloriousEggroll/proton-ge-custom — releases](https://github.com/GloriousEggroll/proton-ge-custom/releases)
- [Proton — herramientas de compatibilidad de terceros](https://github.com/ValveSoftware/Proton#compatibility-tools)

## Contribuir

Ver [`CONTRIBUTING.md`](../../../CONTRIBUTING.md) en la raíz del repositorio.
