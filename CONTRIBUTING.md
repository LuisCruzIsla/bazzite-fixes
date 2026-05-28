# Contribuir

Este repositorio documenta problemas reales en Bazzite (y distros Fedora Atomic en general) con sus soluciones validadas. Cualquier persona puede contribuir.

## Tipos de contribución

### 1. Confirmar un fix existente en tu hardware

Si aplicaste una de las soluciones documentadas y funcionó en una combinación distinta de distro/hardware/runtime:

- Abre un **Pull Request** añadiendo un archivo en `<categoria>/<problema>/casos/NNN-distro-hardware.md`, siguiendo la plantilla en [`_template/casos/_ejemplo.md`](./_template/casos/_ejemplo.md).
- O abre un **Issue** con la etiqueta `confirmed` con la misma información si no quieres hacer un PR.

### 2. Reportar que un fix falla en tu configuración

- Abre un **Issue** con la etiqueta `fix-falla`.
- Adjunta:
  - Salida del script `verify-fix.sh` correspondiente
  - `lsusb`, `uname -a`, distro y versión, runtime usado
  - Qué capa específica del fix falla

### 3. Aportar una solución para otro problema

- Abre un **Pull Request** creando una nueva carpeta dentro de la categoría correspondiente (`juegos/`, `sistema/`, `perifericos/`, etc.).
- Sigue la estructura de [`_template/`](./_template/):
  - `README.md` con síntoma, causa raíz, anti-patrones, solución por capas, verificación, diagnóstico, referencias.
  - Archivos de configuración listos para usar.
  - `verify-fix.sh` cuando aplique.
  - Subcarpeta `casos/` con al menos un caso confirmado.

### 4. Mejoras de documentación

Correcciones, aclaraciones, traducciones (ES ↔ EN), enlaces a referencias mejores — todo vía PR.

### 5. Comentar o agradecer sin abrir issue

Usa la pestaña **Discussions** del repositorio en GitHub. No hace falta un issue formal para preguntar dudas o dejar feedback.

## Estructura del repositorio

```
problemas-bazzite/
├── README.md                          ← índice general
├── CONTRIBUTING.md                    ← este archivo
├── _template/                         ← plantillas para nuevos problemas y casos
│   ├── README.md
│   ├── verify-fix.sh
│   └── casos/_ejemplo.md
├── juegos/                            ← problemas específicos de juegos
│   └── <juego>/<problema>/
│       ├── README.md
│       ├── <archivos de config>
│       ├── verify-fix.sh
│       └── casos/
│           └── NNN-distro-hardware.md
├── sistema/                           ← problemas del SO base
└── perifericos/                       ← problemas de hardware/drivers
```

## Convenciones

- **Idiomas aceptados:** español e inglés en archivos y commits. No hace falta traducir todo.
- **Sin emojis** en archivos (preferencia del repo). Usar marcadores ASCII (`[OK]`, `[X]`, `→`) si hace falta.
- **Sin gatekeeping.** Si tu aporte ayuda a alguien con el mismo problema, encaja.
- **Slugs:** carpetas y archivos en `kebab-case` minúsculas, sin tildes ni espacios.
- **Casos numerados** secuencialmente con 3 dígitos: `001-`, `002-`, ...
- **Atribución:** cada contribuyente queda acreditado en el caso o sección correspondiente con su handle de GitHub si lo desea.

## Licencia

Todo el contenido se publica bajo **CC0** (dominio público). Al contribuir, aceptas liberar tu aporte bajo la misma licencia.
