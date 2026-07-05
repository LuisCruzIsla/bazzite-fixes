# Logitech G PRO X: sin ecualización ni supresión de ruido de mic en Linux (no hay G HUB)

> **Estado:** solución confirmada. Replica el procesamiento de Logitech G HUB (Blue VO!CE + EQ) con EasyEffects, sobrevive a reboot/suspend y no depende del hardware ni de software propietario.

## Síntoma

El headset **Logitech G PRO X** (dongle USB o jack) funciona en Linux, pero **sin el procesamiento que en Windows aplica Logitech G HUB**:

- **Micrófono:** captura el ruido de fondo tal cual (ventilador, teclado, sala). En Windows esto lo limpia **Blue VO!CE**; en Linux no existe equivalente nativo del fabricante.
- **Salida:** sonido plano, sin la ecualización de claridad que G HUB ofrece para juego (presencia de pasos/disparos, control de graves embarrados).

No hay error en logs — simplemente el audio llega crudo porque **G HUB no tiene versión Linux**.

## Quién está afectado

- **Distro:** Bazzite / Fedora Atomic / cualquier distro con PipeWire y Flatpak.
- **Audio server:** PipeWire (WirePlumber). No aplica a PulseAudio puro.
- **Hardware:** Logitech G PRO X (y variantes con el mismo boom mic Blue VO!CE). El mic es **mono por hardware** — no es limitación de Linux.
- **Software ausente:** Logitech G HUB (sin build Linux) → sin Blue VO!CE ni EQ del fabricante.

Ver [`casos/`](./casos/) para configuraciones específicas confirmadas.

## Causa raíz

No es un fallo del sistema sino **ausencia del software de procesamiento del fabricante**:

1. **Blue VO!CE** (supresión de ruido, gate, EQ de voz del mic) vive dentro de G HUB, que no existe en Linux.
2. La **ecualización de salida** de G HUB tampoco está disponible.
3. RNNoise "del sistema" que traen algunos runtimes vive **solo dentro de sandboxes Flatpak/Steam**, no en el PipeWire del host → no procesa el audio global.

La solución es reemplazar ambas funciones con **EasyEffects**: EQ paramétrico en la salida y supresión de ruido **RNNoise** en el mic, aplicados a nivel de host.

## Soluciones que NO funcionan (anti-patrones)

- **Drop-in manual de PipeWire con `module-filter-chain` + `module-echo-cancel`.** Enrutar el sink por defecto a un filter-chain EQ **deja las apps sin sonido**: `pw-play` directo al nodo del filtro reporta OK, pero el audio no llega a las apps ruteadas al sink por defecto. El grafo no propaga la señal a los clientes. (Ver "Verificación": validar **siempre con app real**, no con `pw-play`.)
- **Confiar en RNNoise del runtime Flatpak/Steam** para limpiar el mic a nivel de sistema: solo afecta a la app dentro de ese sandbox, no al mic global.
- **Surround virtual 7.1** para juego competitivo: desaconsejado, distorsiona la localización real. Aquí no se aplica.
- **Depender de que EasyEffects sea el dispositivo por defecto.** No hace falta: EasyEffects **mueve automáticamente** los streams (playback y captura) del dispositivo monitorizado a través de sus filtros aunque el default siga siendo el hardware.

## Solución

Todo con **EasyEffects** (Flatpak), presets versionados y arranque como servicio al login.

### Paso 1 — Instalar EasyEffects

```bash
flatpak install -y flathub com.github.wwmm.easyeffects
```

### Paso 2 — Copiar los presets

Los presets de esta carpeta van al directorio de datos de EasyEffects (Flatpak):

```bash
DEST=~/.var/app/com.github.wwmm.easyeffects/data/easyeffects
mkdir -p "$DEST/output" "$DEST/input"
cp presets/gaming-output.json "$DEST/output/gaming.json"
cp presets/gaming-input.json  "$DEST/input/gaming.json"
```

Contenido:

- **`gaming` (salida):** EQ de 3 bandas para claridad de juego — `-2 dB Bell @250 Hz` (quita graves embarrados), `+2.5 dB Bell @4 kHz` (presencia de pasos/disparos), `+1.5 dB Hi-shelf @10 kHz` (aire). Ganancia suave, no destructiva.
- **`gaming` (entrada):** `rnnoise` (supresión de ruido, reemplazo de Blue VO!CE).

### Paso 3 — Apuntar EasyEffects al headset y cargar los presets

Averigua los nombres de nodo de tu headset:

```bash
wpctl status | grep -i 'PRO X'
# Sink (salida):   alsa_output.usb-Logitech_PRO_X_..."-00.analog-stereo
# Source (mic):    alsa_input.usb-Logitech_PRO_X_..."-00.mono-fallback
```

Escribe la config del servicio (`db/easyeffectsrc`) con esos nodos y las cadenas de plugins:

```bash
DB=~/.var/app/com.github.wwmm.easyeffects/config/easyeffects/db
mkdir -p "$DB"
cat > "$DB/easyeffectsrc" <<'EOF'
[StreamInputs]
inputDevice=alsa_input.usb-Logitech_PRO_X_000000000000-00.mono-fallback
plugins=rnnoise#0

[StreamOutputs]
outputDevice=alsa_output.usb-Logitech_PRO_X_000000000000-00.analog-stereo
plugins=equalizer#0
visiblePage=pluginsPage
visiblePlugin=equalizer#0
EOF
```

> El serial `000000000000` es el que reporta el G PRO X (dongle) en la mayoría de sistemas; ajusta el nombre exacto a lo que muestre `wpctl status` si difiere.

Arranca el servicio y carga los presets:

```bash
flatpak run com.github.wwmm.easyeffects --hide-window &   # servicio en background
flatpak run com.github.wwmm.easyeffects -l gaming          # carga preset salida y entrada
```

Comandos útiles de la CLI (EasyEffects 8.x):

| Comando | Efecto |
|---------|--------|
| `-p` | lista presets disponibles |
| `-l <nombre>` | carga un preset |
| `-a output` / `-a input` | muestra el último preset cargado |
| `-q` | sale del servicio |
| `--hide-window` | arranca en modo servicio (sin ventana) |

### Paso 4 — Arranque automático al login

Copia el `.desktop` de autostart (arranca el servicio oculto al iniciar sesión, sobrevive reboot/suspend):

```bash
mkdir -p ~/.config/autostart
cp easyeffects-service.desktop ~/.config/autostart/
```

## Verificación

```bash
./verify-fix.sh
```

Comprueba: servicio vivo, nodos virtuales `Easy Effects Sink`/`Source`, preset `gaming` cargado en salida y entrada, cadenas configuradas y autostart presente.

**Validación con app real (crítica).** Los filtros de EasyEffects solo se instancian en el grafo cuando hay un stream activo. Verifica el enrutamiento real:

```bash
# Salida: el stream debe moverse a "Easy Effects Sink"
speaker-test -t sine -f 440 -l 1 -c 2 & sleep 2
wpctl status | grep -iA2 'Easy Effects Sink'   # -> alsa_output...analog-stereo (headset)
kill %1

# Mic: la captura del default debe moverse a "Easy Effects Source" vía rnnoise
timeout 3 parec -d @DEFAULT_SOURCE@ /tmp/mic.wav
pw-link -l | grep -iB3 'parec'   # cadena: mic real -> ee_sie_rnnoise -> Easy Effects Source -> app
ls -l /tmp/mic.wav               # debe pesar >0 (audio real capturado)
```

## Por qué sobrevive a actualizaciones

| Capa | Garantía |
|------|----------|
| EasyEffects (Flatpak) | Aislado de `rpm-ostree`; las actualizaciones del sistema base no lo tocan. |
| Presets (`data/easyeffects/*/gaming.json`) | Archivos de usuario; persisten entre versiones de EasyEffects. |
| Config del servicio (`db/easyeffectsrc`) | Estado de usuario; independiente del sistema inmutable. |
| Autostart (`~/.config/autostart/`) | Estándar XDG; arranca en cada login sin depender de systemd del sistema. |
| Enrutamiento | EasyEffects mueve los streams por sí mismo; no depende de que sea el default → suspend/resume no lo rompe. |

## Diagnóstico si vuelve a fallar

```bash
# ¿Servicio corriendo?
pgrep -x easyeffects || flatpak run com.github.wwmm.easyeffects --hide-window &

# ¿Preset cargado?
flatpak run com.github.wwmm.easyeffects -a output   # debe imprimir: gaming
flatpak run com.github.wwmm.easyeffects -a input    # debe imprimir: gaming

# ¿Nodos virtuales presentes?
pw-cli ls Node | grep -i 'easy effects'

# ¿El mic sale crudo? Comprobar que la captura pasa por rnnoise (con un stream activo)
pw-link -l | grep -i ee_sie_rnnoise
```

## Casos confirmados

| # | Distro | Hardware |
|---|--------|----------|
| [001](./casos/001-bazzite44-logitech-g-pro-x.md) | Bazzite 44 (Fedora Atomic) | Logitech G PRO X (dongle USB) |

## Referencias técnicas

- [EasyEffects — repositorio y documentación](https://github.com/wwmm/easyeffects)
- [RNNoise (Xiph) — supresión de ruido](https://github.com/xiph/rnnoise)
- [PipeWire — documentación](https://docs.pipewire.org/)

## Contribuir

Ver [`CONTRIBUTING.md`](../../CONTRIBUTING.md) en la raíz.
