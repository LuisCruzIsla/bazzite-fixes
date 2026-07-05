# Casos confirmados

Cada archivo documenta una combinación específica de distro + hardware donde la solución se validó. Convención de nombrado:

```
NNN-distro-hardware.md
```

Donde:

- `NNN` — número secuencial de 3 dígitos (001, 002, ...)
- `distro` — slug corto (`bazzite44`, `fedora41`, `nobara40`)
- `hardware` — periférico validado (`logitech-g-pro-x`)

## Cómo añadir un caso

1. Confirma que la solución aplica EQ + supresión de ruido y sobrevive a reboot en tu entorno.
2. Copia `001-bazzite44-logitech-g-pro-x.md` como plantilla.
3. Reemplaza con tu entorno, nombres de nodo y salida de `verify-fix.sh`.
4. Abre un Pull Request o un Issue con el archivo adjunto.
