# 001 — Bazzite 44 / RTX 5070 Ti / GNOME 50.5 / Ollama 0.21.2

**Confirmado por:** [@LuisCruzIsla](https://github.com/LuisCruzIsla)
**Fecha:** 2026-10-05
**Estado:** Fix falla parcialmente — `modo-ia` y `modo-juego` confirmados por terminal con el servicio real; la extensión carga sin errores, la sección de shaders validada desde el menú con Steam compilando (2026-10-10); el interruptor Visita no se ha validado desde el menú

## Entorno

| Componente | Versión |
|------------|---------|
| Distro | Bazzite 44 (Fedora Atomic), imagen 44.20260929 |
| Escritorio | GNOME 50.5 sobre Wayland |
| Kernel | 7.2.7-ogc1.1.fc44 |
| GPU | NVIDIA RTX 5070 Ti 16 GB, driver 615.71.09 |
| CPU | Ryzen 9 5900X |
| RAM | 32 GB |
| Ollama | 0.21.2, servicio `disabled` (arranque manual) |
| Modelos | `qwen3:14b`, `qwen3:30b-a3b`, `qwen3:32b` |
| Audio | Logitech G PRO X + EasyEffects (Flatpak), tele por HDMI |

## Configuración relevante

Regla de sudo en uso:

```
(root) NOPASSWD: /usr/bin/systemctl start ollama, /usr/bin/systemctl stop ollama
```

`OLLAMA_KEEP_ALIVE=5m` en el drop-in del servicio.

## Aplicación de la solución en este caso

Sin variantes respecto al README, salvo el UUID de la extensión, que en este equipo es otro. El script de verificación se ejecutó pasándolo como argumento.

## Salida de verificación

```
=== Verificacion: modos juego / IA local ===

--- Capa 1: scripts en ~/.local/bin ---
[OK] modo-ia
[OK] modo-juego
[OK] modo-visita
[OK] steam-shaders

--- Capa 2: sudo sin contrasena para ollama ---
[OK] systemctl start ollama
[OK] systemctl stop ollama

--- Capa 3: opciones de ollama que usan los scripts ---
[OK] 'ollama ps' y 'ollama stop' disponibles

--- Capa 4: modo-juego es idempotente ---
[OK] sale con 0 cuando Ollama ya esta apagado

--- Capa 5: extension ---
[OK] modos@<uuid-local> en estado ACTIVE
[OK] metadata.json declara GNOME 50
```

Ciclo completo por terminal con el servicio real:

| Paso | Resultado |
|------|-----------|
| `modo-ia` | Ollama listo, lista los 3 modelos, código 0 |
| Cargar `qwen3:14b` | 100 % GPU, VRAM 10440 MiB |
| `modo-juego` | `ollama stop qwen3:14b`, servicio detenido, código 0 |
| Estado final | `inactive`, sin procesos, puerto 11434 cerrado, VRAM 906 MiB |

## Notas adicionales

- **Origen de las correcciones:** la extensión mostró la notificación `Modos: modo-juego fallo`. El script usaba `ollama stop --all` y `ollama ps --format`, inexistentes en 0.21.2, y abortaba antes de parar el servicio. Fallaba siempre, también con Ollama ya apagado.
- **Segundo fallo encontrado al probar:** el servicio no arrancaba por un problema aparte (ver [`ollama-servicio-no-arranca-fedora-atomic`](../../ollama-servicio-no-arranca-fedora-atomic/)). `modo-ia` salía con 0 y lo dejaba reiniciándose en bucle; `modo-juego` no lo paraba por estar en `activating`.
- **Pendiente de validar:** encender Visita desde el menú y confirmar audio por la tele.
- **Shaders de Steam (validado 2026-10-10):** las barras se rellenan según el avance tras dar alto al relleno (antes medía 0 px y solo se veía el fondo gris).
- **Coste:** `steam-shaders` tarda unos 0,04 s cada 10 s.
- **Journal de `gnome-shell`:** sin errores de la extensión en la sesión de la prueba.
