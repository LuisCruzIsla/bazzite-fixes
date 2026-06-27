# Casos confirmados

Cada archivo documenta una combinación específica de distro + GPU/driver + cliente donde la solución se validó. Convención de nombrado:

```
NNN-distro-gpu.md
```

Donde:

- `NNN` — número secuencial de 3 dígitos (001, 002, ...)
- `distro` — slug corto (`bazzite44`, `fedora41`, `ubuntu2410`)
- `gpu` — fabricante/serie relevante (`nvidia`, `nvidia-rtx50`, etc.)

Ejemplos:

- `001-bazzite44-nvidia.md`
- `002-fedora41-nvidia.md`

## Cómo añadir un caso

1. Confirma que `--disable-gpu` elimina el negro al compartir el monitor en tu entorno.
2. Copia `001-bazzite44-nvidia.md` como plantilla.
3. Reemplaza el contenido con tu entorno, driver y notas.
4. Abre un Pull Request o un Issue con el archivo adjunto.
