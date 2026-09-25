# StarCraft: Remastered: "No se pudo descargar" al iniciar en Fedora Atomic

> **Estado:** solución confirmada. No es un problema de red: el juego aborta la descarga antes de abrir ninguna conexión porque Wine no logra leer la información del volumen de las rutas bajo `Z:\`, que apunta a la raíz `/` inmutable (composefs) de Fedora Atomic. Se resuelve mapeando una letra de unidad propia al disco real del juego y relocalizando el juego en Battle.net a esa letra.

## Síntoma

Al abrir StarCraft: Remastered desde Battle.net, sin tocar nada, el juego empieza a bajar algo en segundo plano y nunca termina. Si se intenta salir mientras tanto:

```
Carga en proceso. ¿Realmente quieres salir?
(Quedan 4,436 kb).
```

Poco después aparece:

```
No se pudo descargar.
```

Características del síntoma:

- Ocurre **al iniciar**, en el menú principal, sin entrar en salas ni partidas.
- Las partidas multijugador, el login y la descarga de mapas de otras salas **funcionan**.
- El panel de noticias del menú principal suele quedarse con el indicador de carga girando.
- Cambiar de versión de Proton no cambia nada.
- En `SCR-NGDP-DiagnosticLog.txt` todas las sesiones terminan con `totalbytes=0` para todos los servidores del CDN.

## Quién está afectado

| Factor | Valor |
|--------|-------|
| Juego | StarCraft: Remastered (producto `s1` de Battle.net) |
| Distro | **Fedora Atomic y derivadas** (Bazzite, Silverblue, Kinoite, Bluefin, Aurora) — raíz `/` en composefs/overlay de solo lectura |
| Instalación | El juego está en una ruta que el prefix ve como `Z:\...` (cualquier disco o carpeta fuera de `drive_c`) |
| Runtime | Cualquier Proton/Wine. Confirmado con Proton 11.0 y GE-Proton11-6 |
| Lanzador | Battle.net bajo Steam (shortcut no-Steam), Lutris u otro — indistinto |
| GPU / driver | Irrelevante |

Probablemente afecta también a otros juegos de Battle.net instalados bajo `Z:\` en estas distros (el Agent registra el mismo fallo para StarCraft II, Warcraft III y Heroes of the Storm), aunque sólo está confirmado el efecto en StarCraft: Remastered.

Ver [`casos/`](./casos/) para configuraciones específicas confirmadas.

## Causa raíz

Multi-capa. El síntoma habla de descargas, pero ninguna conexión de red llega a intentarse.

1. **Wine / mapeo de unidades.** Todo prefix crea por defecto `Z:` → `/`. Un juego instalado en `/var/mnt/<disco>/...` queda como `Z:\mnt\<disco>\...` (o `Z:\var\mnt\...`).

2. **Sistema base.** En Fedora Atomic, `/` es un overlay de **composefs** de solo lectura. Cuando una aplicación pide los datos del volumen de una ruta bajo `Z:\` (`GetVolumeInformation` y derivadas), Wine no consigue resolverlos. El Agent de Battle.net lo deja registrado para **toda** ruta bajo `Z:`, incluso `Z:/home/...`:
   ```
   [W] Failed to get volume information for Z:/mnt/<disco>/BattleNetLibrary/StarCraft
   [W] Failed to get volume information for Z:/mnt/<disco>/BattleNetLibrary/StarCraft/Data
   ```
   Las mismas rutas accedidas por una letra que apunta directamente al sistema de archivos real (btrfs, ext4) no producen ningún aviso.

3. **Aplicación.** El descargador en segundo plano del juego (NGDP) comprueba el volumen de destino antes de bajar contenido. Al fallar esa consulta, aborta sin conectarse al CDN y muestra "No se pudo descargar". Una captura de las conexiones del proceso durante toda la sesión lo confirma: ninguna conexión a `us.cdn.blizzard.com` ni a `level3.blizzard.com`, y ninguna conexión fallida.

4. **Escritorio del cliente.** El diálogo de "Quedan N kb" se parece al de la transferencia de mapas entre jugadores de una sala, lo que desvía el diagnóstico hacia la red o el anfitrión de la partida.

## Soluciones que NO funcionan (anti-patrones)

- **Revisar firewall, abrir el puerto 6112, cambiar de DNS.** El juego no intenta conectarse al CDN. Desde el sistema los mismos servidores responden correctamente.
- **Cambiar de versión de Proton.** El fallo está en cómo el prefix ve el disco, no en el runtime. Proton 11.0 y GE-Proton11-6 fallan igual.
- **"Analizar y reparar" en Battle.net o reinstalar el juego.** Los archivos están sanos; la reinstalación en la misma ruta `Z:` reproduce el problema.
- **Esperar a que la descarga termine o reintentar.** Nunca empieza: la sesión registra `totalbytes=0` en todos los servidores.
- **Dar por hecho que es el anfitrión de una sala.** El mensaje aparece en el menú principal, sin sala.

## Solución completa

Dos capas: una letra de unidad que apunte al disco real, y el juego relocalizado a esa letra.

### Paso 1 — Crear una letra de unidad en el prefix

Con Battle.net **cerrado**. Sustituir `<APPID>` por el del shortcut (o la ruta del prefix de Lutris) y `/var/mnt/<disco>` por el punto de montaje real del disco donde está el juego:

```bash
PFX=~/.local/share/Steam/steamapps/compatdata/<APPID>/pfx
ls "$PFX/dosdevices/"          # elegir una letra libre, p. ej. d:
ln -s /var/mnt/<disco> "$PFX/dosdevices/d:"
```

Usar la ruta real (`/var/mnt/...`), no `/mnt/...`: en Fedora Atomic `/mnt` es un enlace a `var/mnt` que vive en la raíz composefs.

El `<APPID>` de un shortcut no-Steam se localiza así:

```bash
for d in ~/.local/share/Steam/steamapps/compatdata/*/; do
  [ -d "$d/pfx/drive_c/ProgramData/Battle.net" ] && basename "$d"
done
```

### Paso 2 — Relocalizar el juego en Battle.net

1. Abrir Battle.net y seleccionar StarCraft: Remastered.
2. Usar **"Localizar el juego"** y elegir la nueva ruta, p. ej. `D:\<carpeta>\StarCraft`.
3. Battle.net verifica los archivos (unos segundos) y deja el juego listo para jugar.

La interfaz de Battle.net puede seguir mostrando la ruta antigua con `Z:`. Lo que cuenta es la ruta guardada por el Agent, que se comprueba en la verificación.

### Paso 3 — Abrir el juego

El menú principal no debe mostrar "No se pudo descargar" y la descarga en segundo plano termina sola.

## Verificación

```bash
./verify-fix.sh <APPID>
```

Comprueba:

- Que existe una letra de unidad en el prefix que no apunta a `/` y cuyo destino es un directorio real.
- Que el Agent de Battle.net guarda la ruta de StarCraft con esa letra y no con `Z:`.
- Que el último log del Agent no registra fallos de volumen para la ruta de StarCraft.
- Que alguna sesión del log NGDP del juego registra bytes recibidos del CDN.
- Si el juego está corriendo, que el ejecutable se lanzó desde la nueva letra.

## Por qué sobrevive a actualizaciones

| Capa | Garantía |
|------|----------|
| Letra de unidad (`dosdevices/d:`) | Es un enlace dentro del prefix. Proton no lo toca al actualizar el prefix ni al cambiar de versión. |
| Ruta del juego en Battle.net | Se guarda en `ProgramData/Battle.net/Agent/product.db`. Sobrevive a actualizaciones del Agent, de Battle.net y del juego. |
| Sistema base | No se modifica nada fuera del prefix. Las actualizaciones de `rpm-ostree` no afectan. |

Lo que **sí** puede romperlo: borrar o recrear el prefix (`compatdata/<APPID>`), cambiar el punto de montaje del disco, o volver a localizar el juego con una ruta `Z:\`.

## Diagnóstico si vuelve a fallar

1. **Ver con qué ruta arranca el juego** (con el proceso vivo):
   ```bash
   pgrep -xa StarCraft.exe
   ```
   Debe empezar por la nueva letra (`D:\...`), no por `Z:\`.

2. **Ver los fallos de volumen del Agent:**
   ```bash
   A=~/.local/share/Steam/steamapps/compatdata/<APPID>/pfx/drive_c/ProgramData/Battle.net/Agent
   grep 'volume information' "$(ls -t "$A"/Agent.*/Logs/Agent-*.log | head -1)" | grep -i starcraft
   ```
   No debe aparecer ninguna ruta de StarCraft: Remastered.

3. **Ver si el descargador recibe datos:**
   ```bash
   L=~/.local/share/Steam/steamapps/compatdata/<APPID>/pfx/drive_c/users/steamuser/AppData/Roaming/Blizzard/StarCraft/SCR-NGDP-DiagnosticLog.txt
   grep -c 'totalbytes=[1-9]' "$L"
   ```

4. **Comprobar si el juego intenta conectarse al CDN** durante una sesión:
   ```bash
   watch -n0.5 "ss -tanp | grep '\"StarCraft.exe\"' | grep -v 127.0.0.1"
   ```
   Si nunca aparecen IP del CDN de Blizzard y el aviso persiste, el juego sigue viendo el volumen bajo `Z:`.

## Casos confirmados

| # | Distro | Runtime | Lanzador | Resultado |
|---|--------|---------|----------|-----------|
| 001 | Bazzite 44 | GE-Proton11-6 (copia parcheada) | Steam (shortcut no-Steam) | Descarga completa |

## Referencias técnicas

- [`GetVolumeInformationW` — documentación de Microsoft](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-getvolumeinformationw)
- [Wine — FAQ, unidades y `dosdevices`](https://gitlab.winehq.org/wine/wine/-/wikis/FAQ)
- [Fedora Atomic — composefs en la raíz](https://docs.fedoraproject.org/en-US/fedora-silverblue/technical-information/)
- [Blizzard NGDP / TACT — formato de distribución](https://wowdev.wiki/TACT)

## Contribuir

Ver [`CONTRIBUTING.md`](../../../CONTRIBUTING.md) en la raíz del repositorio.
