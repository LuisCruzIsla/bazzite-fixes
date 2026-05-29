# Casos confirmados

Cada archivo de esta carpeta documenta una combinación específica de distro + compositor + aplicación afectada donde el workaround se validó. Convención de nombrado:

```
NNN-distro-aplicacion.md
```

Donde:

- `NNN` — número secuencial de 3 dígitos (001, 002, ...)
- `distro` — slug corto (`bazzite43`, `fedora41`, `ubuntu2410`)
- `aplicacion` — software o juego afectado (`sc2`, `warcraft3`, `dota2`, etc.)

Ejemplos:

- `001-bazzite43-sc2.md`
- `002-fedora41-warcraft3.md`

## Cómo añadir un caso

1. Confirma que el workaround (Nivel A, B o C) elimina el desync en tu entorno.
2. Copia `001-bazzite43-sc2.md` como plantilla.
3. Reemplaza el contenido con tu entorno, layout/variant y notas.
4. Abre un Pull Request o un Issue con el archivo adjunto.
