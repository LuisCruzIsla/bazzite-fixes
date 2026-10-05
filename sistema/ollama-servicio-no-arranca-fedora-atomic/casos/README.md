# Casos confirmados — ollama.service en Fedora Atomic

Cada archivo `NNN-<distro>-<hardware>.md` documenta una configuración concreta donde el fix se validó.

Si lo confirmas en otro entorno, abre un PR con un nuevo caso siguiendo el formato del archivo más reciente. Interesan especialmente:

- Distros Fedora Atomic distintas de Bazzite (Bluefin, Aurora, Silverblue, Kinoite)
- Modelos en un disco ext4, xfs o NTFS en vez de btrfs
- Versiones de Ollama cuyo instalador ya no use `/usr/share/ollama`
- GPUs AMD o Intel
