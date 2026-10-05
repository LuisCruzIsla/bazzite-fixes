# Ollama: el servicio systemd no arranca y queda reiniciándose en bucle

> **Estado:** solución confirmada

## Síntoma

`sudo systemctl start ollama` vuelve sin error, pero el servidor nunca escucha:

```
$ ollama list
Error: could not connect to ollama server, run 'ollama serve' to start it
```

`systemctl status ollama` lo muestra relanzándose cada pocos segundos:

```
Active: activating (auto-restart) (Result: exit-code)
Process: ExecStart=/usr/local/bin/ollama serve (code=exited, status=1/FAILURE)
```

En el journal aparece uno de estos dos errores, según la capa que falle:

```
Couldn't find '/usr/share/ollama/.ollama/id_ed25519'. Generating new private key.
Error: could not create directory mkdir /usr/share/ollama: read-only file system
```

```
Error: mkdir /ruta/al/disco/modelos: permission denied: ensure path elements are traversable
```

El segundo solo se ve después de corregir el primero.

## Quién está afectado

| Componente | Valor |
|------------|-------|
| Distro | Bazzite / Fedora Atomic (Silverblue, Kinoite, Bluefin, Aurora): cualquiera con `/usr` de solo lectura |
| Ollama | Instalación nativa con servicio systemd que corre como usuario `ollama` (verificado en 0.21.2) |
| Capa 1 | Unit o usuario con home en `/usr/share/ollama` |
| Capa 2 | Solo si los modelos viven fuera del home del servicio (`OLLAMA_MODELS` en otro disco o en tu home) |

No afecta a Ollama en contenedor (Podman, Distrobox) ni a quien lo lanza a mano con `ollama serve` desde su propio usuario.

Ver [`casos/`](./casos/) para configuraciones específicas confirmadas.

## Causa raíz

1. **HOME del servicio en `/usr`.** El instalador oficial crea el usuario `ollama` con home en `/usr/share/ollama`. En Fedora Atomic `/usr` es una imagen de solo lectura, así que ese directorio no existe ni puede crearse. Al arrancar, Ollama intenta generar su clave en `$HOME/.ollama/id_ed25519` y termina con `read-only file system`.
2. **Ruta de modelos no atravesable.** El servicio corre como usuario `ollama`, no como tú. Si `OLLAMA_MODELS` apunta a un disco o carpeta cuyo punto de montaje es `700` de tu usuario, `ollama` no puede pasar por ese directorio aunque la carpeta final de modelos sea `777`. Basta un solo eslabón sin permiso `x` en toda la ruta.
3. **`Restart=always` oculta el fallo.** La unit se relanza cada 3 s indefinidamente. `systemctl start` devuelve éxito porque el proceso llegó a lanzarse, y `systemctl is-active --quiet` devuelve "no activo" porque el estado es `activating`, no `failed`. Un script que use esas dos señales cree que encendió el servicio y luego cree que está apagado, mientras systemd sigue reintentando en segundo plano.

Las capas 1 y 2 son independientes y se manifiestan en orden: la 2 queda tapada hasta que la 1 se corrige.

## Soluciones que NO funcionan (anti-patrones)

- **`sudo mkdir /usr/share/ollama`** — `/usr` es de solo lectura. Forzarlo con `rpm-ostree usroverlay` dura hasta el siguiente reinicio.
- **Reinstalar Ollama** — el instalador vuelve a escribir la misma unit y el mismo usuario.
- **`chmod 755` o `chmod o+x` sobre el punto de montaje del disco** — funciona, pero abre el paso a todos los usuarios y servicios del sistema. Una ACL para un solo usuario consigue lo mismo sin ampliar el acceso.
- **`chmod -R 777` sobre la carpeta de modelos** — no sirve: el bloqueo está en un directorio superior, no en la carpeta final.
- **Sospechar de SELinux** — en el caso confirmado no hubo ninguna denegación AVC. El error es de permisos Unix clásicos.
- **Reescribir `override.conf` entero al añadir una variable** — así se pierden `HOME` u `OLLAMA_MODELS` sin darse cuenta y el servicio deja de arrancar semanas después, la próxima vez que se enciende. Usar `systemctl edit` y conservar las líneas existentes.
- **Comprobar el servicio con `systemctl is-active --quiet`** — un servicio en bucle de reinicios no está `active` ni `failed`. Comparar contra `inactive` o consultar `NRestarts`.

## Solución completa

### Paso 1 — Dar al servicio un HOME escribible

`/var/lib` es escribible y persiste entre actualizaciones.

```bash
sudo install -d -o ollama -g ollama -m 755 /var/lib/ollama
```

### Paso 2 — Declarar HOME y la ruta de modelos en un drop-in

Editar [`override.conf`](./override.conf) con la ruta real de los modelos y copiarlo:

```bash
sudo install -D -m 644 override.conf /etc/systemd/system/ollama.service.d/override.conf
sudo systemctl daemon-reload
```

Si ya existe un `override.conf` con otras variables (`OLLAMA_KEEP_ALIVE`, `OLLAMA_FLASH_ATTENTION`...), no lo sobrescribas: añade las dos líneas con `sudo systemctl edit ollama`.

Quien guarde los modelos en la ubicación por defecto puede omitir `OLLAMA_MODELS`; quedarán en `/var/lib/ollama/.ollama/models` y el paso 3 no hace falta.

Comprobar que systemd las ve:

```bash
systemctl show ollama -p Environment
```

### Paso 3 — Permitir que `ollama` atraviese la ruta de modelos

Localizar el eslabón que bloquea:

```bash
namei -l /ruta/a/tus/modelos
```

Cualquier directorio que no sea de `ollama` y no tenga `x` para "otros" corta el paso. Darle a ese directorio una ACL de solo travesía (sin listar ni leer) para el usuario del servicio:

```bash
setfacl -m u:ollama:--x /ruta/al/directorio/bloqueante
```

No requiere `sudo` si el directorio es tuyo. La carpeta de modelos en sí debe ser legible y escribible por `ollama`.

Para deshacerlo:

```bash
setfacl -x u:ollama /ruta/al/directorio/bloqueante
```

### Paso 4 — Si el servicio quedó en bucle, pararlo

```bash
sudo systemctl stop ollama
```

`stop` corta el ciclo de `Restart=always`. Después, arrancar normalmente.

## Verificación

```bash
./verify-fix.sh
./verify-fix.sh --arrancar
```

Resultado esperado:

- `[OK]` HOME del servicio fuera de `/usr`, existente y propiedad de `ollama`
- `[OK]` todos los directorios de la ruta de modelos son atravesables por `ollama`
- `[OK]` el servicio no está en bucle de reinicios
- Con `--arrancar`: `[OK]` arranca, responde en `127.0.0.1:11434` y vuelve a quedar detenido

Si falta un permiso, el script imprime el `setfacl` exacto para el directorio que bloquea.

## Por qué sobrevive a actualizaciones

| Capa | Persistencia |
|------|--------------|
| `/var/lib/ollama` | `/var` es estado de la máquina: `rpm-ostree upgrade` y los rebases no lo tocan |
| `/etc/systemd/system/ollama.service.d/override.conf` | `/etc` se fusiona en cada despliegue conservando los cambios locales. Un drop-in tampoco se pierde si el instalador de Ollama reescribe la unit base |
| ACL en el punto de montaje | Se guarda en el sistema de archivos del disco (btrfs, ext4, xfs). Sobrevive a reinicios y remontajes |
| Suspend/resume | Ninguna capa depende de estado en memoria |

Lo único que la rompe es recrear o reformatear el sistema de archivos del disco de modelos, o sobrescribir el drop-in.

## Diagnóstico si vuelve a fallar

```bash
# 1. ¿Qué error da el arranque?
journalctl -u ollama -b --no-pager | grep -i error | tail -n 3

# 2. ¿Está en bucle?
systemctl is-active ollama
systemctl show ollama -p NRestarts

# 3. ¿Qué entorno recibe realmente el servicio?
systemctl show ollama -p Environment -p User

# 4. ¿Qué eslabón de la ruta bloquea?
namei -l "$(systemctl show ollama -p Environment --value | tr ' ' '\n' | sed -n 's/^OLLAMA_MODELS=//p')"
```

Lecturas:

- **(1) `read-only file system`** → falta `HOME` en el drop-in o apunta a `/usr`.
- **(1) `permission denied: ensure path elements are traversable`** → capa 2; (4) muestra cuál.
- **(2) `activating` con `NRestarts` creciendo** → bucle; `sudo systemctl stop ollama` antes de seguir.
- **(3) sin `HOME` ni `OLLAMA_MODELS`** → el drop-in se sobrescribió o falta `daemon-reload`.

## Casos confirmados

| # | Distro | Hardware / versión |
|---|--------|--------------------|
| [001](./casos/001-bazzite44-rtx5070ti.md) | Bazzite 44 | RTX 5070 Ti — Ollama 0.21.2, modelos en un segundo disco btrfs |

## Referencias técnicas

- [Ollama — instalación en Linux y unit de systemd](https://docs.ollama.com/linux)
- [Ollama FAQ — `OLLAMA_MODELS` y variables de entorno del servicio](https://docs.ollama.com/faq)
- [Fedora Atomic — qué directorios son escribibles (`/etc`, `/var`)](https://docs.fedoraproject.org/en-US/fedora-silverblue/technical-information/)
- `man 5 systemd.service` (`Restart=`), `man 1 setfacl`, `man 1 namei`

## Contribuir

Ver [`CONTRIBUTING.md`](../../CONTRIBUTING.md) en la raíz.
