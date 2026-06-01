# Proton 10+: Xalia intercepta input de Wine y rompe polling de teclado

> **Estado:** solución confirmada

## Síntoma

En juegos lanzados con **Proton 10 o superior** que usan polling de teclado vía `GetAsyncKeyState` / `XQueryKeymap` (típicamente cuadros de captura de hotkeys en RTS/MOBA/FPS), el polling **no detecta ninguna tecla** o detecta esporádicamente solo tras `Alt+Tab`.

El juego funciona normal en partida (la cola de eventos `WM_KEYDOWN` sí entrega) — el fallo es específico de los menús que polean estado de teclado.

```
Vincular tecla rápida:
  [ ningún cambio ]
  Oprime la tecla deseada
```

## Quién está afectado

- **Distro:** cualquiera con GNOME Wayland o KDE Plasma Wayland (XWayland por debajo)
- **Versión de Proton:** 10.x — `xalia.exe` no existía en Proton 9.x ni anteriores
- **Software intermedio:** Xalia es un proxy de accesibilidad introducido en Proton 10 que se activa por defecto con `PROTON_USE_XALIA=1`
- **Juegos confirmados:** StarCraft II (Battle.net), reportes similares en otros RTS Proton

Ver [`casos/`](./casos/) para hardware específico confirmado.

## Causa raíz

Xalia (`xalia.exe`, distribuido dentro de Proton en `files/share/wine/../xalia/`) es un proceso que actúa como puente entre Wine y el bus AT-SPI (Linux Accessibility Toolkit). Su objetivo es exponer controles UI del juego a screen readers y herramientas de accesibilidad.

Para hacerlo, Xalia se sitúa entre el servidor X y el cliente Wine del juego y **intercepta eventos de teclado** para procesarlos antes de pasarlos al juego. Para apps que reciben input vía cola de eventos (`WM_KEYDOWN`) esto es transparente: Xalia reenvía el evento tras consumirlo. Para apps que polean el estado directo del teclado (`GetAsyncKeyState`, traducido a `XQueryKeymap` en XWayland), el polling se queda esperando un estado que Xalia tiene capturado.

Variables relevantes en el entorno del juego cuando Xalia está activa:

```
PROTON_USE_XALIA=1
XALIA_SUPPORTED_ONLY=1
```

Y el proceso visible:

```
\\?\Z:\...\Proton 10.0\files\share\wine/../xalia/xalia.exe
```

## Soluciones que NO funcionan (anti-patrones)

- **Marcar "deshabilitar accesibilidad" en GNOME** — Xalia no consulta `org.gnome.desktop.interface toolkit-accessibility`, se activa por la variable `PROTON_USE_XALIA` que Proton ajusta sola.
- **`pkill xalia.exe` desde un servicio externo** — Xalia se relanza al siguiente arranque del juego porque Proton la inyecta al inicializar el prefix.
- **Usar Proton 9 o GE-Proton** — funciona como workaround, pero pierdes los fixes de compatibilidad y mejoras de Proton 10.
- **Tocar `WINEDLLOVERRIDES`** — Xalia es un binario externo, no una DLL inyectada.

## Solución

Forzar `PROTON_USE_XALIA=0` en el entorno del juego **antes** del `exec` del runtime de Proton. Tres formas, de menos a más robusta:

### Opción 1 — Launch options de Steam (rápida, por juego)

En Steam → click derecho en el juego → **Propiedades** → **General** → **Opciones de lanzamiento**, antepón:

```
PROTON_USE_XALIA=0 %command%
```

Si tienes un wrapper (ej. `strip-extest.sh`), el orden debe ser:

```
PROTON_USE_XALIA=0 /home/<user>/.local/bin/strip-extest.sh %command%
```

Limitación: Steam Cloud sync puede sobrescribir launch options. Es la opción más simple pero menos resistente.

### Opción 2 — Variable en un wrapper local (robusta, por juego)

Si ya usas un wrapper para otras capas (Steam Input, XKB sync, etc.), añadir un `export`:

```bash
#!/bin/bash
# Wrapper para juegos Proton 10+
export PROTON_USE_XALIA=0
exec "$@"
```

Sobrevive a Steam Cloud sync porque vive en `~/.local/bin/` del usuario.

### Opción 3 — Variable global (más amplia, todos los juegos Proton 10+)

Crear `~/.config/environment.d/99-disable-proton-xalia.conf`:

```
PROTON_USE_XALIA=0
```

Aplica al próximo login. Cubre **todos** los juegos Proton sin tocar launch options de cada uno. Recomendada si no usas accesibilidad AT-SPI con juegos.

## Verificación

```bash
./verify-fix.sh
```

Resultado esperado:

- `[OK] xalia.exe no está corriendo` con el juego lanzado.
- Variable `PROTON_USE_XALIA=0` presente en `/proc/<PID>/environ` del proceso del juego.

## Por qué sobrevive a actualizaciones

| Capa de fix | Persistencia |
|-------------|--------------|
| Launch options Steam | Sobrevive a updates de Proton, frágil ante Steam Cloud sync |
| Wrapper local en `~/.local/bin/` | Sobrevive a updates de Steam y Proton — pertenece al usuario |
| `environment.d` | Sobrevive a updates de todo; solo se rompe si el usuario lo borra |

Las tres opciones sobreviven a `suspend/resume` porque la variable se evalúa al `exec` del proceso, no en runtime.

## Diagnóstico si vuelve a fallar

```bash
# Xalia corriendo (no debería)
pgrep -af xalia.exe

# Variable en el proceso del juego (debe ser 0 o ausente)
GAME_PID=$(pgrep -f "<nombre del .exe>" | head -1)
cat /proc/$GAME_PID/environ | tr '\0' '\n' | grep -i xalia
```

Si `PROTON_USE_XALIA=1` aparece en `/proc/<PID>/environ`, el wrapper no se está aplicando: revisar el orden en launch options o el contenido del wrapper.

## Casos confirmados

| # | Distro | Juego / Proton |
|---|--------|----------------|
| [001](./casos/001-bazzite44-sc2-proton10.md) | Bazzite 44 | StarCraft II + Proton 10.0-4 |

## Referencias

- Proton release notes 10.0 — introducción de Xalia
- Repositorio Xalia upstream (Wine Project)
- Issue tracker Proton GitHub para reportes relacionados

## Contribuir

Ver [`CONTRIBUTING.md`](../../CONTRIBUTING.md) en la raíz.
