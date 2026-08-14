# Casos confirmados — MangoHud global

Cada archivo `NNN-<distro>-<hardware>.md` documenta una configuración concreta donde el fix se validó.

Si confirmas el fix en otra distro, GPU o versión de MangoHud, abre un PR con un nuevo caso siguiendo el formato del archivo más reciente. Interesan especialmente:

- Distros Fedora Atomic distintas de Bazzite (Bluefin, Aurora, Silverblue)
- GPUs AMD e Intel — el fix es agnóstico de driver, pero no está confirmado fuera de NVIDIA
- Juegos lanzados desde Lutris o Heroic en vez de Steam
- Versiones de MangoHud anteriores a 0.8.x, donde el formato del manifiesto puede diferir
