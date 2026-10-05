# GNOME Quick Settings: alternar entre modo juego e IA local (Ollama) sin terminal

> **Estado:** workaround — los scripts `modo-ia` y `modo-juego` están confirmados; la extensión carga sin errores, pero el interruptor Visita y la sección de shaders siguen en validación

## Síntoma

En un equipo con una sola GPU, Ollama y los juegos compiten por la misma VRAM. Con un modelo cargado, el juego arranca con menos memoria de vídeo de la que necesita:

```
$ nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader
10440 MiB, 16303 MiB
```

Liberarla exige acordarse de abrir una terminal, descargar los modelos y parar el servicio antes de cada sesión de juego, y lo contrario antes de usar la IA local. No hay ningún indicador en el escritorio de en qué estado está el equipo.

## Quién está afectado

| Componente | Valor |
|------------|-------|
| Distro | Bazzite / Fedora Atomic con GNOME (los scripts sirven en cualquier distro con systemd) |
| GNOME Shell | 50 (la extensión declara solo esa versión) |
| Ollama | Instalación nativa con `ollama.service` (verificado en 0.21.2) |
| GPU | Una sola GPU compartida entre juegos e inferencia. `nvidia-smi` para la lectura de VRAM |
| Opcional | EasyEffects (Flatpak) y una salida HDMI, para el modo Visita. Steam nativo, para el avance de shaders |

Ver [`casos/`](./casos/) para configuraciones específicas confirmadas.

## Causa raíz

1. **Ollama retiene la VRAM.** Un modelo cargado sigue en memoria hasta que vence `OLLAMA_KEEP_ALIVE`, y el servicio en sí queda residente aunque no haya modelos.
2. **No hay conmutador nativo.** GNOME no ofrece nada para arrancar o parar un servicio de sistema desde el panel, ni muestra el uso de VRAM.
3. **Los scripts caseros fallan en silencio.** Los dos errores que motivaron las correcciones de esta entrada:
   - `ollama stop --all` y `ollama ps --format` no existen en Ollama 0.21.2. Con `set -euo pipefail`, el script abortaba antes de llegar a `systemctl stop` y el servicio nunca se apagaba.
   - `systemctl is-active --quiet` no distingue "apagado" de "reiniciándose en bucle". Si el servicio no logra arrancar, queda relanzándose cada 3 s y ningún script lo para. Ver [`sistema/ollama-servicio-no-arranca-fedora-atomic/`](../ollama-servicio-no-arranca-fedora-atomic/).

## Soluciones que NO funcionan (anti-patrones)

- **`ollama stop --all`** — la opción no existe (0.21.2). `ollama stop` exige el nombre del modelo.
- **`ollama ps --format '{{.Name}}'`** — tampoco existe. Hay que leer la salida tabular y saltarse la cabecera.
- **Bajar `OLLAMA_KEEP_ALIVE` y confiar en que la VRAM se libere sola** — depende de esperar, y el servicio sigue residente.
- **Parar el servicio solo si `is-active --quiet` da activo** — deja vivo un servicio en bucle de reinicios.
- **Dar por bueno un `systemctl start` que devuelve 0** — con `Restart=always` devuelve 0 aunque el proceso muera al instante. Hay que comprobar que el puerto responde.
- **Lanzar `sudo` desde una extensión sin regla NOPASSWD** — no hay terminal donde pedir la contraseña y el script falla.
- **`easyeffects -l <preset>` sin instancia en marcha** — el comando se convierte en la instancia primaria y no retorna nunca; el botón queda en "Cambiando...". `modo-visita` arranca antes el servicio y usa `timeout`.
- **Refrescar un `PopupSwitchMenuItem` con `setToggleState()` sin filtro** — en GNOME 50 emite `toggled`, así que sincronizar el interruptor lanza la acción. La extensión lo filtra con una bandera.

## Solución completa

### Paso 1 — Scripts de modo

```bash
mkdir -p ~/.local/bin
cp bin/modo-ia bin/modo-juego bin/modo-visita bin/steam-shaders ~/.local/bin/
chmod +x ~/.local/bin/modo-ia ~/.local/bin/modo-juego ~/.local/bin/modo-visita ~/.local/bin/steam-shaders
```

| Script | Qué hace |
|--------|----------|
| `modo-ia` | Arranca `ollama.service` y espera hasta 10 s a que el puerto responda. Si no responde, lo para y sale con error |
| `modo-juego` | Descarga cada modelo cargado, para el servicio en cualquier estado distinto de `inactive` e informa de la VRAM en uso |
| `modo-visita` / `modo-visita off` | Pasa el audio a la salida HDMI al 100 % con un preset de EasyEffects sin EQ / vuelve al headset y al preset `gaming`. `modo-visita status` sale con 0 si la salida por defecto es HDMI |
| `steam-shaders` | Imprime el avance de la precompilación de shaders de Steam leyendo `shader_log.txt`. Sale con 1 si no hay nada compilando |

Los cuatro funcionan por terminal sin la extensión.

`modo-visita` busca el headset por el patrón `Logitech_PRO_X` y los presets `gaming` y `visita`. Cambiar el patrón por el de tu dispositivo (`pactl list short sinks`). El preset `visita` es una cadena de salida vacía: copiar [`presets/visita-output.json`](./presets/visita-output.json) a `~/.var/app/com.github.wwmm.easyeffects/data/easyeffects/output/visita.json`. El preset `gaming` está en [`perifericos/logitech-g-pro-x/`](../../perifericos/logitech-g-pro-x/).

### Paso 2 — sudo sin contraseña solo para arrancar y parar Ollama

Editar [`sudoers-ollama`](./sudoers-ollama) con tu usuario y copiarlo:

```bash
sudo install -m 440 sudoers-ollama /etc/sudoers.d/ollama-modos
sudo visudo -cf /etc/sudoers.d/ollama-modos
```

La regla cubre exactamente dos comandos. Es imprescindible para la extensión y opcional si solo se usan los scripts por terminal.

### Paso 3 — Servicio apagado por defecto

```bash
sudo systemctl disable --now ollama
```

Así el equipo arranca siempre en modo juego y Ollama solo existe mientras se pide.

### Paso 4 — Extensión de Quick Settings

```bash
cp -r extension/modos@bazzite-fixes ~/.local/share/gnome-shell/extensions/
```

Cerrar sesión y volver a entrar (Wayland no recarga extensiones en caliente), y activarla:

```bash
gnome-extensions enable modos@bazzite-fixes
```

| Elemento | Comportamiento |
|----------|----------------|
| Clic en el botón | Alterna Juego / IA local |
| Menú: Juego, IA local | Elige el modo; el activo lleva la marca |
| Menú: Visita | Interruptor de `modo-visita` |
| Menú: VRAM | Usada / total |
| Menú: Shaders de Steam | Barra global; al pulsarla despliega una fila por juego (compilando, en cola, listo) |
| Subtítulo del botón | VRAM usada, o `Shaders N %` mientras Steam compila |

El estado se lee del sistema cada 30 s y al abrir el menú, así que refleja los cambios hechos por terminal. Los shaders se refrescan cada 10 s. No hay proceso residente: la extensión vive en `gnome-shell` y lanza los scripts bajo demanda.

Al terminar cada cambio, la extensión muestra una notificación con la última línea del script. Si el script sale con error, el título es `Modos: <script> fallo`.

## Verificación

```bash
./verify-fix.sh
```

Resultado esperado:

- `[OK]` los cuatro scripts en `~/.local/bin`
- `[OK]` reglas NOPASSWD para `systemctl start ollama` y `systemctl stop ollama`
- `[OK]` `ollama ps` y `ollama stop` disponibles
- `[OK]` `modo-juego` sale con 0 cuando Ollama ya está apagado
- `[OK]` extensión en estado ACTIVE y `metadata.json` con la versión mayor de GNOME en uso

El script no enciende Ollama. Para probar el ciclo completo, con al menos un modelo descargado:

```bash
modo-ia && ollama run <modelo> "hola" && ollama ps && modo-juego
```

Al final no debe quedar ningún proceso `ollama` y la VRAM debe volver a su valor de reposo.

## Por qué sobrevive a actualizaciones

| Capa | Persistencia |
|------|--------------|
| `~/.local/bin/` y `~/.local/share/gnome-shell/extensions/` | Pertenecen al usuario; `rpm-ostree upgrade` y los rebases no los tocan |
| `/etc/sudoers.d/ollama-modos` | `/etc` conserva los cambios locales entre despliegues |
| Estado leído del sistema, no guardado | Tras suspend/resume o un cambio por terminal, el botón se corrige solo en el siguiente refresco |
| `shell-version` en `metadata.json` | **No sobrevive a un salto de versión mayor de GNOME**: hay que añadir la nueva versión o el Shell desactiva la extensión |

Las opciones de la CLI de Ollama pueden cambiar entre versiones; `verify-fix.sh` comprueba las que usan los scripts.

## Diagnóstico si vuelve a fallar

```bash
# 1. ¿Qué script falla y con qué salida?
modo-juego; echo "rc=$?"
bash -x ~/.local/bin/modo-juego

# 2. ¿El servicio está en bucle?
systemctl is-active ollama
journalctl -u ollama -b --no-pager | grep -i error | tail -n 3

# 3. ¿sudo puede correr sin contraseña?
sudo -n systemctl stop ollama; echo "rc=$?"

# 4. ¿La extensión cargó?
gnome-extensions info modos@bazzite-fixes
journalctl --user -b -g 'modos@'
```

Lecturas:

- **(1) el script muere tras una orden de `ollama`** → cambió la CLI; revisar `ollama ps --help` y `ollama stop --help`.
- **(2) `activating`** → el servicio no logra arrancar; ver la entrada de [`ollama-servicio-no-arranca-fedora-atomic`](../ollama-servicio-no-arranca-fedora-atomic/).
- **(3) `a password is required`** → falta la regla del paso 2.
- **(4) estado `OUT OF DATE`** → GNOME subió de versión mayor; añadirla a `shell-version`.
- **El botón se queda en "Cambiando..."** → un script no retorna; ejecutarlo por terminal para ver dónde se detiene.

## Casos confirmados

| # | Distro | Hardware / versión |
|---|--------|--------------------|
| [001](./casos/001-bazzite44-rtx5070ti.md) | Bazzite 44 | RTX 5070 Ti 16 GB — GNOME 50.5, Ollama 0.21.2 |

## Referencias técnicas

- [GJS Guide — extensiones de GNOME Shell y Quick Settings](https://gjs.guide/extensions/topics/quick-settings.html)
- [Ollama — referencia de la CLI](https://docs.ollama.com/cli)
- `man 5 sudoers`, `man 1 pactl`
- [EasyEffects — carga de presets por línea de comandos](https://github.com/wwmm/easyeffects)

## Contribuir

Ver [`CONTRIBUTING.md`](../../CONTRIBUTING.md) en la raíz.
