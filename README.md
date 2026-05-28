# Problemas de Bazzite — soluciones documentadas

Colección de problemas reales en **Bazzite** (y distros Fedora Atomic en general) con **soluciones reproducibles, validadas y abiertas a contribuciones**.

Cada solución está organizada por categoría → problema → casos confirmados. La estructura permite que distintas personas reporten variantes del mismo problema con hardware distinto sin pisarse.

## Índice

### Juegos

| Problema | Estado | Carpeta |
|----------|--------|---------|
| StarCraft II — dispositivos HID detectados como mandos virtuales | Solución confirmada | [`juegos/starcraft-2/fake-gamepads-hid/`](./juegos/starcraft-2/fake-gamepads-hid/) |

### Sistema

*Sin entradas todavía. Aporta la primera con un PR — ver [`CONTRIBUTING.md`](./CONTRIBUTING.md).*

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
