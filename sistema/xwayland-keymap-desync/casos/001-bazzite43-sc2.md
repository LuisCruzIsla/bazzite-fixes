# Caso 001 — Bazzite 43 + GNOME Wayland + StarCraft II

**Confirmado por:** [@LuisCruzIsla](https://github.com/LuisCruzIsla)
**Fecha inicial:** 2026-05-28
**Última validación:** 2026-05-29 (Nivel B integrado en wrapper de SC2)
**Estado:** Workaround funciona y sobrevive a la sesión. Reaparece tras logout/login si no se aplica el Nivel B/C.

## Historia del caso

Durante la depuración del fix de gamepads falsos en SC2 ([juegos/starcraft-2/fake-gamepads-hid/](../../../juegos/starcraft-2/fake-gamepads-hid/)) apareció un síntoma extra que no estaba en el problema original: el **cuadro de captura de hotkeys** del menú de teclas rápidas en SC2 dejó de detectar pulsaciones. El resto del teclado funcionaba en partida (mover unidades, escribir en chat) — sólo el componente de bind quedaba inerte.

Diagnóstico inicial — comparar layouts:

```bash
setxkbmap -query
# layout:  us

gsettings get org.gnome.desktop.input-sources sources
# [('xkb', 'us+altgr-intl'), ('xkb', 'latam')]
```

`us` plano en XWayland vs `us+altgr-intl` activo en GNOME. SC2 usa `GetAsyncKeyState` → `XQueryKeymap` en el polling del cuadro de captura, y consulta keysyms sobre un mapeo distinto al que reciben los keysyms reales del teclado físico → cero coincidencias.

Workaround validado: `setxkbmap us -variant altgr-intl` sincroniza XWayland en caliente, y SC2 detecta inmediatamente las pulsaciones en el cuadro de bind sin reiniciar el juego.

## Entorno

| Componente | Versión |
|------------|---------|
| Distro | Bazzite 43 (Fedora Atomic) |
| Escritorio | GNOME Wayland |
| Mutter | 47 |
| Kernel | 6.17 |
| GPU | NVIDIA RTX 5070 Ti |
| CPU | AMD Ryzen 9 5900X |
| Runtime | Steam + Proton 10.0-4 |
| Juego | StarCraft II (Battle.net 2.51.5.17438) |

## Configuración relevante

Input sources en GNOME (Settings → Keyboard → Input Sources):

```
1. English (US, alt. intl.)   ← us+altgr-intl
2. Spanish (Latin American)   ← latam
```

`current = 0` (`us+altgr-intl` activo por defecto). El desync aparece tras boot pese a tener el layout US activo en GNOME.

## Aplicación del workaround en este caso

Se eligió el **Nivel B** (wrapper) integrándolo dentro del wrapper ya existente `strip-extest.sh` del fix de gamepads — así no hay que encadenar dos scripts en las launch options de Steam.

Líneas añadidas a `~/.local/bin/strip-extest.sh` justo antes del `exec`:

```bash
if [ -n "$DISPLAY" ] && command -v setxkbmap >/dev/null 2>&1; then
  setxkbmap us -variant altgr-intl 2>/dev/null || true
fi

exec "$@"
```

Launch options en Steam (sin cambios respecto al fix original):

```
... /home/lcruzisl/.local/bin/strip-extest.sh %command%
```

## Salida de verificación

Tras aplicar el workaround:

```
=== Layout activo en GNOME (Wayland) ===
  sources : [('xkb', 'us+altgr-intl'), ('xkb', 'latam')]
  current : 0

=== Layout que ve XWayland ===
  layout  : us
  variant : altgr-intl

=== Resultado ===
  GNOME activo : layout='us' variant='altgr-intl' (index 0)
  XWayland tiene : layout='us' variant='altgr-intl'
  [OK] Sincronizados — el polling XKB en apps XWayland funcionará correctamente.
```

En SC2 in-game: el cuadro de captura de hotkeys detecta correctamente todas las teclas del teclado físico al primer intento.

## Notas adicionales

- Antes del workaround se probó cambiar el layout en GNOME a `latam` y volver a `us+altgr-intl` desde el indicador del shell — funcionó una vez pero no era reproducible tras reboot.
- El desync **no** afecta a la jugabilidad normal: caminar, escribir en chat, atajos asignados previamente funcionan. Sólo el componente de bind con polling activo.
- Combinado con el fix de gamepads falsos, las dos capas conviven en el mismo wrapper sin interferir.
- Si en el futuro Mutter resuelve [issue#1697](https://gitlab.gnome.org/GNOME/mutter/-/issues/1697), el `setxkbmap` será no-op (idempotente) — no hay costo en mantenerlo.
