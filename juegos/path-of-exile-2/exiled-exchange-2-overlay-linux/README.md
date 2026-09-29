# Exiled Exchange 2: el overlay no aparece, deja de responder o Ctrl+D no hace nada en GNOME

> **Estado:** solución confirmada. Son cuatro capas independientes: Electron arranca en Wayland nativo, la versión oficial perdió el manejo de foco en Linux, GNOME 50 exige permiso de "interacción remota" para las teclas simuladas y el idioma del overlay tiene que coincidir con el del juego. Se resuelve con variables de entorno, un build parcheado de 0.16.3, un permiso de GNOME y un ajuste de idioma.

## Síntoma

[Exiled Exchange 2](https://github.com/Kvan7/Exiled-Exchange-2) (EE2) es el overlay de precios para Path of Exile 2, derivado de Awakened PoE Trade. En Bazzite con GNOME aparece uno o varios de estos síntomas:

- El overlay arranca, sale en la lista de procesos, pero **nunca se ve** y `Shift+Space` no abre nada.
- El overlay funciona **una vez**. Al abrirlo de nuevo, los clics lo atraviesan y llegan al juego.
- `Ctrl+D` sobre un ítem **no hace nada**. `Shift+Space` sí abre el menú.
- Con `Ctrl+D` sale el panel pero dice que no reconoce el ítem.

Pista clave del tercer caso: después de pulsar `Ctrl+D`, el portapapeles contiene una marca de EE2 en vez del texto del ítem:

```bash
wl-paste
```
```
__EE2_FORCE_EMPTY_1790722001485
```

## Quién está afectado

| Factor | Valor |
|--------|-------|
| Distro | Bazzite 44 y cualquier Fedora Atomic con GNOME. Las capas 1 y 4 aplican a cualquier distro |
| Escritorio | GNOME 47+ en sesión Wayland (capa 3 confirmada en GNOME 50) |
| XWayland | 24.1+ arrancado con `-enable-ei-portal` (capa 3) |
| EE2 | Confirmado en 0.15.1 y 0.16.3 AppImage. La capa 2 afecta a toda versión posterior a 0.13.7 |
| Juego | Path of Exile 2 por Steam + Proton, en ventana X11 (XWayland) |
| GPU / driver | Irrelevante |

Ver [`casos/`](./casos/) para configuraciones específicas confirmadas.

## Causa raíz

Multi-capa. Cada capa produce un síntoma distinto y arreglar una deja visible la siguiente.

1. **Electron — backend Wayland.** Electron 40 detecta la sesión Wayland y usa Ozone Wayland. La librería `electron-overlay-window`, que engancha el overlay a la ventana del juego, solo habla X11, y `uiohook-napi`, que captura los atajos globales, escucha en el servidor X. El overlay queda creado pero sin ventana X11: invisible.

2. **EE2 — manejo de foco en Linux.** Las versiones posteriores a 0.13.7 quitaron el `setFocusable(true/false)` que alternaba el foco entre overlay y juego (commits `de30c0b` y `0bb1e916`). En 0.16.3 ya no queda ningún tratamiento específico de Linux en `OverlayWindow.ts`. Resultado: tras el primer uso, la ventana del overlay no vuelve a aceptar clics. El PR [#789](https://github.com/Kvan7/Exiled-Exchange-2/pull/789), que lo restauraba, se cerró sin mergear.

3. **GNOME / XWayland — teclas simuladas vía portal.** Para copiar el ítem, EE2 simula `Ctrl+Alt+C` con XTest. Desde XWayland 24.1, Mutter arranca XWayland con `-enable-ei-portal`: los eventos XTest ya no se inyectan directo, pasan por libei y el portal **RemoteDesktop**. Sin permiso, GNOME los descarta en silencio. El diálogo que pide el permiso ("¿Permitir interacción remota?") se abre **detrás del juego a pantalla completa**, así que no se ve. EE2 detecta el `Ctrl+D`, vacía el portapapeles con su marca `__EE2_FORCE_EMPTY_*` y espera un texto que nunca llega.

4. **EE2 — idioma.** El idioma de EE2 no es solo el de la interfaz: el parser usa la misma tabla para leer el texto copiado. Si el juego está en español y EE2 en inglés, o al revés, el panel sale pero no reconoce el ítem.

## Soluciones que NO funcionan (anti-patrones)

- **Cambiar de versión de Proton.** Si `Ctrl+C` a mano sobre un ítem sí copia el texto (`wl-paste` lo muestra), el portapapeles de Proton está bien y el problema es la capa 3. Existe un bug real de portapapeles en Proton 11 temprano ([awakened-poe-trade#1846](https://github.com/SnosMe/awakened-poe-trade/issues/1846)), pero se descarta con esa prueba.
- **Aplicar el PR #789 tal cual.** Además del foco, pone `windowOpts.type = "notification"`. En GNOME 47+ Mutter trata esa ventana como notificación del shell y la oculta: `xwininfo` la ve, `wmctrl` no.
- **Usar el AppImage oficial 0.16.3 sin parche.** Vuelve el problema de la capa 2.
- **Dejar el auto-update activo.** El updater descarga la versión oficial y reemplaza el build parcheado.
- **`PROTON_ENABLE_WAYLAND=1` en el juego** (por ejemplo, para HDR). El juego deja de ser una ventana X11 y EE2 no puede engancharse ni mandarle teclas. Reportado en [EE2#916](https://github.com/Kvan7/Exiled-Exchange-2/issues/916).
- **Poner EE2 en español con el juego en inglés.** El panel no reconoce los ítems (capa 4).

## Solución completa

### Paso 1 — Compilar EE2 0.16.3 con el parche de foco

Hace falta `git` y Node.js 22 (en Bazzite, `brew install node` o dentro de un distrobox).

```bash
git clone --branch v0.16.3 --depth 1 https://github.com/Kvan7/Exiled-Exchange-2 /tmp/Exiled-Exchange-2
cd /tmp/Exiled-Exchange-2
git apply /ruta/a/linux-focus-fix.patch
bash testUpdate.sh
```

El parche ([`linux-focus-fix.patch`](./linux-focus-fix.patch)) restaura solo el alternado de foco del PR #789, sin `type = "notification"`:

```diff
       this.onOverlayActive();

+      if (process.platform === "linux" && this.window) {
+        this.window.setFocusable(true);
+        this.window.focus();
+      }
       OverlayController.activateOverlay();
...
       this.isInteractable = false;
+      if (process.platform === "linux" && this.window) {
+        this.window.setFocusable(false);
+        this.window.blur();
+      }
       OverlayController.focusTarget();
```

El build tarda entre 5 y 20 minutos. Instalar el resultado:

```bash
mkdir -p ~/Aplicaciones
install -m755 "/tmp/Exiled-Exchange-2/main/dist/Exiled Exchange 2-0.16.3.AppImage" ~/Aplicaciones/Exiled-Exchange-2-0.16.3-linuxfocusfix.AppImage
```

### Paso 2 — Lanzador con X11 forzado y sin auto-update

```bash
cat > ~/.local/share/applications/exiled-exchange-2-fixed.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Exiled Exchange 2 (Linux Focus Fix)
Comment=Overlay para Path of Exile 2 - v0.16.3 con parche de foco
Exec=env ELECTRON_OZONE_PLATFORM_HINT=x11 GDK_BACKEND=x11 $HOME/Aplicaciones/Exiled-Exchange-2-0.16.3-linuxfocusfix.AppImage --ozone-platform=x11 --no-updates %U
Terminal=false
Categories=Game;Utility;
StartupWMClass=exiled-exchange-2
Keywords=poe;poe2;exile;price;trade;overlay;
EOF
update-desktop-database ~/.local/share/applications
```

`--no-updates` es un flag propio de EE2: desactiva la descarga de actualizaciones. En el log seguirá apareciendo `Checking for update`, es normal.

### Paso 3 — Idioma de EE2 igual al del juego

Con EE2 cerrado. El idioma del juego está en el `poe2_production_Config.ini` del prefix (clave `language` de la sección `[LANGUAGE]`):

```bash
find ~/.local/share/Steam/steamapps/compatdata/2694490 /ruta/a/SteamLibrary/steamapps/compatdata/2694490 \
  -name poe2_production_Config.ini 2>/dev/null -exec grep -A1 '\[LANGUAGE\]' {} \;
```

Poner el mismo código en EE2 (`en`, `es`, `pt`, `fr`, `de`, `ru`, `ja`, `ko`, `cmn-Hant`):

```bash
f=~/.config/exiled-exchange-2/apt-data/config.json
cp "$f" "$f.bak"
sed -i 's/"language":"[^"]*"/"language":"es"/' "$f"
```

O desde el overlay: *Settings → General → Idioma*.

### Paso 4 — Conceder el permiso de interacción remota de GNOME

1. Abrir el juego y EE2.
2. Pulsar `Ctrl+D` sobre un ítem. No pasará nada visible.
3. Salir del juego con `Super` o `Alt+Tab`. Debe haber un diálogo **"¿Permitir interacción remota?"**.
4. Pulsar **Permitir**.

Desde ese momento `Ctrl+D` funciona. Si el diálogo no aparece, repetir `Ctrl+D` y volver a salir con `Super`.

### Paso 5 — Launch options del juego

No usar `PROTON_ENABLE_WAYLAND=1`. Si se añaden variables, deben ir **antes** de `%command%`:

```
PROTON_ENABLE_NVAPI=1 %command%
```

Una variable escrita sin `%command%` (por ejemplo solo `GDK_BACKEND=x11`) Steam la pasa al juego como argumento suelto y no tiene efecto.

## Uso

| Atajo | Comportamiento |
|-------|----------------|
| `Ctrl+D` | Vistazo rápido: el panel se muestra mientras se mantiene `Ctrl`. Para dejarlo fijo, mover el ratón encima del panel sin soltar `Ctrl` |
| `Ctrl+Alt+D` | Panel fijo e interactivo. Se cierra con `Esc` |
| `Shift+Space` | Abrir/cerrar el menú del overlay |

La liga por defecto es **Standard**. Para precios de la liga actual, cambiarla en la cabecera del panel.

## Verificación

```bash
./verify-fix.sh ~/Aplicaciones/Exiled-Exchange-2-0.16.3-linuxfocusfix.AppImage
```

Comprueba:

- Que el AppImage contiene el parche de foco y no contiene `type = "notification"`.
- Que EE2 está corriendo en X11 y con `--no-updates`.
- Que el idioma de EE2 coincide con el del juego.
- Que el juego no se lanzó con `PROTON_ENABLE_WAYLAND`.
- Si XWayland usa el portal de input (capa 3) y si el portapapeles quedó con la marca `__EE2_FORCE_EMPTY_*`.

## Por qué sobrevive a actualizaciones

| Capa | Garantía |
|------|----------|
| X11 forzado | Vive en el `.desktop` del usuario. Las actualizaciones de Bazzite no lo tocan. |
| Parche de foco | Vive en el AppImage propio. `--no-updates` impide que EE2 lo reemplace. |
| Idioma | Vive en `~/.config/exiled-exchange-2/apt-data/config.json`. |
| Permiso de interacción remota | Lo guarda GNOME para la sesión de XWayland. **Puede volver a pedirse** tras reiniciar sesión o actualizar GNOME: repetir el Paso 4. |

Lo que **sí** puede romperlo: una nueva versión de EE2 (hay que recompilar con el parche), un cambio de idioma del juego, o `PROTON_ENABLE_WAYLAND=1`.

## Diagnóstico si vuelve a fallar

1. **¿El overlay está enganchado al juego?** Debe haber una ventana `Exiled Exchange 2` del mismo tamaño que la del juego:
   ```bash
   DISPLAY=:0 xwininfo -root -tree | grep -E '"Exiled Exchange 2"|"Path of Exile 2"'
   ```

2. **¿EE2 detecta `Ctrl+D` pero no llega el ítem?** Tras pulsarlo:
   ```bash
   wl-paste | head -3
   ```
   `__EE2_FORCE_EMPTY_*` → capa 3: falta el permiso de interacción remota (Paso 4).

3. **¿El juego copia al portapapeles?** Pulsar `Ctrl+C` a mano sobre un ítem y ejecutar `wl-paste`. Si sale el texto del ítem, Proton está bien.

4. **¿XWayland usa el portal de input?**
   ```bash
   ps -o args= -C Xwayland | grep -o -- '-enable-ei-portal'
   ```

5. **El ratón deja de responder en todo el escritorio** (el scroll mueve el juego, los clics no hacen nada, pero `Alt+Tab` sí funciona). Se observó una vez justo después de conceder el permiso de interacción remota: un botón del ratón virtual quedó pulsado y GNOME mandaba todo el puntero al juego. EE2 no simula clics, así que el origen probable es la sesión de libei, sin confirmar. Se libera con:
   ```bash
   DISPLAY=:0 xdotool mouseup 1 mouseup 2 mouseup 3 keyup ctrl alt shift super
   ```

## Casos confirmados

| # | Distro | Escritorio | EE2 | Proton | Resultado |
|---|--------|------------|-----|--------|-----------|
| [001](./casos/001-bazzite44-gnome50-nvidia.md) | Bazzite 44 | GNOME 50.5 | 0.16.3 + parche | Proton 11.0-2c | Precio en español con `Ctrl+D` |

## Referencias técnicas

- [Exiled Exchange 2 — repositorio](https://github.com/Kvan7/Exiled-Exchange-2)
- [EE2 PR #789 — Restore Linux overlay focus handling](https://github.com/Kvan7/Exiled-Exchange-2/pull/789) (autor: @DBosley)
- [EE2 #788 — Linux overlay stops responding to clicks after first use](https://github.com/Kvan7/Exiled-Exchange-2/issues/788)
- [EE2 #1031 — Overlay never appears on a Wayland session](https://github.com/Kvan7/Exiled-Exchange-2/issues/1031)
- [awakened-poe-trade #1846 — portapapeles con Proton 10+](https://github.com/SnosMe/awakened-poe-trade/issues/1846)
- [libei — emulated input](https://gitlab.freedesktop.org/libinput/libei)
- [XDG Desktop Portal — RemoteDesktop](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.RemoteDesktop.html)
- [Electron — `BrowserWindow.setFocusable`](https://www.electronjs.org/docs/latest/api/browser-window#winsetfocusablefocusable-windows-macos)

## Contribuir

Ver [`CONTRIBUTING.md`](../../../CONTRIBUTING.md) en la raíz del repositorio.
