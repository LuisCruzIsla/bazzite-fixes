# Problemas de Bazzite — soluciones documentadas

Colección de problemas reales en **Bazzite** (y distros Fedora Atomic en general) con **soluciones reproducibles, validadas y abiertas a contribuciones**.

Cada solución está organizada por categoría → problema → casos confirmados. La estructura permite que distintas personas reporten variantes del mismo problema con hardware distinto sin pisarse.

## Índice

### Juegos

| Problema | Estado | Carpeta |
|----------|--------|---------|
| StarCraft II — dispositivos HID detectados como mandos virtuales | Solución confirmada | [`juegos/starcraft-2/fake-gamepads-hid/`](./juegos/starcraft-2/fake-gamepads-hid/) |
| StarCraft II — cuadro de captura de hotkeys no detecta o detecta erróneamente | Solución confirmada (debug multi-capa con 5 capas) | [`juegos/starcraft-2/hotkey-capture-debug-multicapa/`](./juegos/starcraft-2/hotkey-capture-debug-multicapa/) |
| Space Marine 2 — crash en NVIDIA serie 5000 (Xid 109 CTX SWITCH TIMEOUT) | Solución confirmada (vía capa upstream Pyroveil) | [`juegos/space-marine-2/precreating-shaders-crash-nvidia/`](./juegos/space-marine-2/precreating-shaders-crash-nvidia/) |

### Sistema

| Problema | Estado | Carpeta |
|----------|--------|---------|
| XWayland — layout de teclado desincronizado del compositor Wayland | Workaround confirmado | [`sistema/xwayland-keymap-desync/`](./sistema/xwayland-keymap-desync/) |
| Proton 10+ Xalia intercepta input de Wine y rompe polling de teclado | Solución confirmada | [`sistema/proton-xalia-input-grab/`](./sistema/proton-xalia-input-grab/) |
| IBus (`ibus-x11`) captura teclas y rompe polling en apps Wine/Win32 | Solución confirmada (con toggle on-demand) | [`sistema/ibus-x11-keygrab/`](./sistema/ibus-x11-keygrab/) |
| NumLock/CapsLock atascados enmascaran el polling de teclado | Solución confirmada (chequeo trivial) | [`sistema/toggle-keys-polling-mask/`](./sistema/toggle-keys-polling-mask/) |
| Vesktop/Discord — pantalla negra al compartir pantalla en NVIDIA | Solución confirmada | [`sistema/vesktop-screenshare-negro-nvidia/`](./sistema/vesktop-screenshare-negro-nvidia/) |

### Periféricos

*Sin entradas todavía.*

## Cómo navegar

```
problemas-bazzite/
├── README.md                          ← este archivo (índice)
├── CONTRIBUTING.md                    ← cómo contribuir
├── _template/                         ← plantillas para nuevos problemas
├── juegos/
│   └── starcraft-2/
│       └── fake-gamepads-hid/
│           ├── README.md              ← descripción genérica del problema y solución
│           ├── 99-*.rules             ← archivos listos para copiar
│           ├── userdef-snippet.reg
│           ├── verify-fix.sh
│           └── casos/                 ← casuísticas confirmadas por hardware
│               ├── README.md
│               └── 001-bazzite43-logitech-kingston.md
├── sistema/                           ← (vacío, listo para futuros)
└── perifericos/                       ← (vacío, listo para futuros)
```

Cada problema tiene su propio `README.md` con:

1. Síntoma exacto
2. Quién está afectado
3. Causa raíz (frecuentemente multi-capa)
4. Soluciones que NO funcionan (anti-patrones)
5. Solución completa paso a paso
6. Script de verificación
7. Diagnóstico si vuelve a fallar
8. Tabla de casos confirmados

Y una subcarpeta `casos/` donde cada archivo `NNN-distro-hardware.md` documenta una combinación específica que se validó.

## Contribuir

Lee [`CONTRIBUTING.md`](./CONTRIBUTING.md). Resumen rápido:

- **Confirmaste un fix en otro hardware:** abre PR o issue añadiendo un caso.
- **El fix no te funcionó:** abre issue con la salida del script de verificación.
- **Tienes una solución para otro problema:** abre PR siguiendo [`_template/`](./_template/).
- **Solo quieres comentar o agradecer:** usa la pestaña *Discussions* del repo (sin abrir issue).

## Licencia

**CC0** (dominio público). Usa, copia, modifica y redistribuye libremente — incluso comercialmente, sin atribución obligatoria.

## Autor inicial

[Luis Felipe Cruz Isla — @LuisCruzIsla](https://github.com/LuisCruzIsla)
