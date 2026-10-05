# Casos confirmados — modos juego / IA local

Cada archivo `NNN-<distro>-<hardware>.md` documenta una configuración concreta donde se validó.

Si lo confirmas en otro entorno, abre un PR con un nuevo caso siguiendo el formato del archivo más reciente. Interesan especialmente:

- El interruptor Visita y la sección de shaders usados desde el menú, que aún no tienen confirmación
- Versiones de GNOME Shell distintas de la 50
- Versiones de Ollama posteriores a 0.21.2
- GPUs AMD o Intel, donde la lectura de VRAM con `nvidia-smi` no aplica
