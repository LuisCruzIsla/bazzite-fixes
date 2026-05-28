# Casos confirmados

Cada archivo de esta carpeta documenta una combinación específica de distro + runtime + hardware donde el fix se validó. Convención de nombrado:

```
NNN-distro-hardware.md
```

Donde:

- `NNN` — número secuencial de 3 dígitos (001, 002, ...)
- `distro` — slug corto (`bazzite43`, `arch`, `fedora41`, `steamos`)
- `hardware` — fabricante(s) principal(es) involucrados

Ejemplos:

- `001-bazzite43-logitech-kingston.md`
- `002-arch-razer-corsair.md`
- `003-steamos-genericbox.md`

## Cómo añadir un caso

1. Confirma que aplicaste las cuatro capas y el fix funciona.
2. Copia `001-bazzite43-logitech-kingston.md` como plantilla.
3. Reemplaza el contenido con tu entorno, VID:PID y notas.
4. Abre un Pull Request o un Issue con el archivo adjunto si no tienes cuenta GitHub para PRs.
