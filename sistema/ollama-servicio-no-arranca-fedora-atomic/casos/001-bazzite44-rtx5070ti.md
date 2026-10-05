# 001 — Bazzite 44 / RTX 5070 Ti / Ollama 0.21.2 con modelos en un segundo disco

**Confirmado por:** [@LuisCruzIsla](https://github.com/LuisCruzIsla)
**Fecha:** 2026-10-05
**Estado:** Fix funciona — el servicio arranca, carga un modelo en GPU y se detiene limpio

## Entorno

| Componente | Versión |
|------------|---------|
| Distro | Bazzite 44 (Fedora Atomic), imagen 44.20260929 |
| Escritorio | GNOME 50.5 sobre Wayland |
| Kernel | 7.2.7-ogc1.1.fc44 |
| systemd | 259.9 |
| GPU | NVIDIA RTX 5070 Ti, driver 615.71.09 |
| CPU | Ryzen 9 5900X |
| RAM | 32 GB |
| Ollama | 0.21.2, binario en `/usr/local/bin/ollama` |
| Disco de modelos | btrfs, montado por `x-systemd.automount` en `/var/mnt/<disco>` |

## Configuración relevante

Unit base, tal como estaba:

```ini
[Service]
ExecStart=/usr/local/bin/ollama serve
User=ollama
Group=ollama
Restart=always
RestartSec=3
Environment="HOME=/usr/share/ollama"
```

Usuario del servicio:

```
ollama:x:992:995::/usr/share/ollama:/bin/false
```

Drop-in antes del fix, sin `HOME` ni `OLLAMA_MODELS`:

```ini
[Service]
Environment="OLLAMA_FLASH_ATTENTION=1"
Environment="OLLAMA_KEEP_ALIVE=5m"
```

Ruta de modelos antes del fix:

```
drwxr-xr-x root   root   var
drwxr-xr-x root   root   mnt
drwx------ <user> <user> <disco>
drwxrwxrwx <user> <user> Modelos_locales_IA
drwxrwxrwx <user> <user> models
```

El servicio es de arranque manual (`disabled`): se enciende solo para sesiones de IA local y se apaga para jugar.

## Aplicación de la solución en este caso

- **Paso 1:** omitido. `/var/lib/ollama` ya existía con la clave del servicio dentro; solo faltaba que la unit apuntara ahí.
- **Paso 2:** el drop-in existente se amplió conservando sus dos líneas. Quedó con `HOME`, `OLLAMA_MODELS`, `OLLAMA_FLASH_ATTENTION` y `OLLAMA_KEEP_ALIVE`.
- **Paso 3:** `setfacl -m u:ollama:--x` sobre el punto de montaje del disco, que es `700` del usuario.
- **Paso 4:** necesario. El servicio llevaba varios minutos en bucle tras un `systemctl start`.

## Salida de verificación

```
=== Verificacion: ollama.service en Fedora Atomic ===

Usuario del servicio: ollama

--- Capa 1: HOME escribible fuera de /usr ---
HOME efectivo: /var/lib/ollama
[OK] /var/lib/ollama existe y pertenece a ollama

--- Capa 2: ruta de modelos atravesable ---
OLLAMA_MODELS: /var/mnt/<disco>/Modelos_locales_IA/models
[OK] todos los directorios de la ruta son atravesables por ollama

--- Capa 3: estado del servicio ---
Estado: inactive (reinicios automaticos: 0)
[OK] detenido, sin bucle

--- Capa 4: arranque real ---
[OK] arranco y responde: {"version":"0.21.2"}
     Servicio detenido de nuevo.
```

Con la ACL retirada a propósito, el script señala el eslabón exacto:

```
[X]  ollama no puede atravesar /var/mnt/<disco> (drwx------ <user>:<user>)
     setfacl -m u:ollama:--x '/var/mnt/<disco>'
```

Prueba funcional con el servicio real:

| Paso | Resultado |
|------|-----------|
| `systemctl start ollama` | escucha en `127.0.0.1:11434`, lista los 3 modelos |
| Cargar `qwen3:14b` | 100 % GPU, VRAM 10440 MiB |
| `ollama stop qwen3:14b` + `systemctl stop ollama` | sin procesos, puerto cerrado, VRAM 906 MiB |

## Notas adicionales

- **El fallo estuvo meses sin verse.** El último arranque correcto en el journal es del 2026-06-07 por la mañana. Ese mismo día se reescribió `override.conf` y no volvió a arrancar; no se detectó hasta octubre porque el servicio es de encendido manual. El contenido anterior del drop-in no se pudo recuperar, pero la configuración registrada en el último arranque bueno ya incluía `OLLAMA_MODELS` apuntando al segundo disco.
- **Los dos errores aparecieron en orden.** Primero `read-only file system`; tras fijar `HOME`, `permission denied: ensure path elements are traversable`.
- **Sin denegaciones de SELinux** en modo `Enforcing`, pese a que la carpeta de modelos lleva la etiqueta `user_home_t`.
- **El bucle engañó al script de encendido.** Esperaba 10 s a que el puerto respondiera y, al no hacerlo, terminaba con código 0 dejando el servicio reintentando cada 3 s. El script de apagado comprobaba `is-active --quiet` y no lo paraba. Ver [`sistema/modos-juego-ia-local-quick-settings/`](../../modos-juego-ia-local-quick-settings/).
- **`ollama stop --all` y `ollama ps --format` no existen en 0.21.2.** Para descargar los modelos cargados hay que leer la salida tabular de `ollama ps`.
