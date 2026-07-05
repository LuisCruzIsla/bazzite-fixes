# Caso 001 — Bazzite 44 + Logitech G PRO X (dongle USB)

**Confirmado por:** [@LuisCruzIsla](https://github.com/LuisCruzIsla)
**Fecha:** 2026-07-05
**Estado:** Fix funciona. EQ de salida y supresión de ruido del mic validados con apps reales; sobrevive reboot/suspend vía autostart.

## Entorno

| Componente | Versión |
|------------|---------|
| Distro | Bazzite 44 (Fedora Atomic) |
| Escritorio | GNOME Wayland |
| Kernel | 6.19 |
| Audio | PipeWire + WirePlumber |
| EasyEffects | 8.2.7 (Flatpak, reescritura Qt/KConfig) |
| Headset | Logitech G PRO X (dongle USB) |

## Configuración relevante

Nodos del headset según `wpctl status`:

```
Sink:   alsa_output.usb-Logitech_PRO_X_000000000000-00.analog-stereo
Source: alsa_input.usb-Logitech_PRO_X_000000000000-00.mono-fallback
```

El serial reportado es `000000000000` (genérico del dongle G PRO X). El mic es **mono por hardware** (boom mic). El source por defecto inicial era la webcam, no el headset — corregido en `easyeffectsrc`.

## Aplicación de la solución en este caso

- Presets `gaming` (salida EQ 3 bandas, entrada rnnoise) copiados a `~/.var/app/com.github.wwmm.easyeffects/data/easyeffects/{output,input}/`.
- `db/easyeffectsrc` apuntando `outputDevice`/`inputDevice` a los nodos del G PRO X, `plugins=equalizer#0` en salida y `plugins=rnnoise#0` en entrada.
- Servicio con autostart `--hide-window` en `~/.config/autostart/`.
- **Default sink** fijado a Easy Effects Sink. El **default source** NO se pudo fijar con `wpctl set-default` (nodo `Audio/Source/Virtual`, lo rechaza) — irrelevante: EasyEffects reroutea la captura del mic real igual.

## Notas de validación (por qué se confió solo tras app real)

Un intento previo con drop-in de PipeWire (`module-filter-chain` EQ + `module-echo-cancel`) se descartó: `pw-play` directo al nodo del filtro daba OK pero las apps ruteadas al sink por defecto quedaban **sin sonido**. Por eso aquí la validación fue con streams reales:

```
# Salida — el stream se movio solo a Easy Effects Sink -> EQ -> headset
speaker-test (FL/FR)  ->  Easy Effects Sink  ->  alsa_output...analog-stereo

# Mic — parec desde @DEFAULT_SOURCE@ se movio solo a Easy Effects Source
mic real -> ee_sie_rnnoise -> Easy Effects Source -> parec   (573 KB grabados en 3 s)
```

## Salida de verificación

```
== Servicio EasyEffects ==
[OK] servicio corriendo
== Nodos virtuales EE ==
[OK] Easy Effects Sink presente
[OK] Easy Effects Source presente
== Preset cargado ==
[OK] preset salida = gaming (EQ)
[OK] preset entrada = gaming (rnnoise)
== Cadenas configuradas ==
[OK] cadena mic incluye rnnoise
[OK] cadena salida incluye equalizer
== Autostart ==
[OK] autostart al login presente

RESULTADO: todo OK
```

## Notas adicionales

- Los filtros de EasyEffects (`ee_sie_rnnoise`, `equalizer`) solo aparecen en el grafo (`pw-link -l`) con un stream activo; en reposo no. Por eso el `verify-fix.sh` chequea la config estática, no el grafo vivo.
- La salida analógica del headset **sigue en uso**: Easy Effects Sink es solo un nodo intermedio que aplica el EQ y reinyecta a `alsa_output...analog-stereo`.
- Surround 7.1 virtual no aplicado (competitivo). EQ suave, no destructivo.
