# Caso 001 — Bazzite 44 + ASUS ROG STRIX B550-F + coolers Antec C8 ARGB

**Confirmado por:** [@LuisCruzIsla](https://github.com/LuisCruzIsla)
**Fecha:** 2026-07-10
**Estado:** Fix funciona — todo el RGB queda en verde fijo y persistente. Única salvedad: teclas sueltas del teclado (chip onboard, ver Notas).

## Entorno

| Componente | Versión |
|------------|---------|
| Distro | Bazzite 44 (Fedora Atomic) |
| Escritorio | GNOME, kernel 6.19 |
| OpenRGB | 1.0rc3 (Flatpak `org.openrgb.OpenRGB`) |
| Placa | ASUS ROG STRIX B550-F GAMING (controlador AURA LED USB `0b05:1939`) |
| CPU | AMD Ryzen 9 5900X |
| GPU | Gigabyte GeForce RTX 5070 Ti (RGB Fusion, por i2c) |
| RAM | HyperX Predator RGB (SMBus i2c, addr 0x27) |
| Coolers | Antec Constellation C8 ARGB — hub ARGB propio → header ADD_GEN2 |
| Teclado | HyperX Alloy Origins Core (`0951:16e6`) — Direct-only, chip onboard |
| Mouse | Logitech G703 Lightspeed (receptor `046d:c539`) |

## Configuración relevante

- **Perfil:** `modeRGB-VERDE` — verde olivo `#6B8E23`, modo Direct en todos los dispositivos.
- **Coolers:** conectados al header **ADD_GEN2** (3-pin 5V) = zona `Aura Addressable 1` en OpenRGB. Tamaño de zona fijado a **60 LEDs** a mano (OpenRGB no autodetecta el conteo de LEDs direccionables).
- **VID:PID para hotplug:** teclado `0951:16e6`, receptor del mouse `046d:c539`.

## Aplicación de la solución en este caso

- Reglas udev del Flatpak copiadas a `/etc/udev/rules.d/60-openrgb.rules`. El warning "udev rules not installed" **siguió apareciendo** (falso positivo del sandbox); se verificó por el permiso real: `/dev/hidraw7` pasó a `crw-rw-rw-+`.
- `--mode static` global **falló** (`Mode 'static' not available for device 'HyperX Alloy Origins Core'`) → se usó `--mode direct`.
- Primer intento de servicio `Type=simple` con `flatpak run`: al segundo arranque quedó un **openrgb huérfano** ocupando el 6742 y el servicio entró en bucle `status=1/FAILURE`. Resuelto con `ExecStartPre=-flatpak kill` y `ExecStop=flatpak kill`.
- El teclado no quedaba cubierto sólo con `--profile`; se añadió el refuerzo `ExecStartPost` (3 pases `--client localhost --mode direct --color 6B8E23`).
- Regla hotplug `61-openrgb-hotplug.rules` con `--machine=lcruzisl@.host --no-block` para reaplicar al reconectar teclado/mouse.

## Salida de verificación

```
=== Capa 1: reglas udev de OpenRGB ===
  [OK] /etc/udev/rules.d/60-openrgb.rules

=== Capa 2: modulo i2c-dev (controladores SMBus: RAM/GPU) ===
  [OK] i2c-dev cargado

=== Capa 3: servicio de usuario ===
  [OK] enabled
  [OK] active

=== Capa 4: servidor SDK escuchando en 6742 ===
  [OK] servidor OpenRGB escucha en 6742

=== Capa 5 (opcional): regla hotplug ===
  [OK] /etc/udev/rules.d/61-openrgb-hotplug.rules

=== Resultado ===
  [OK] Fix en pie. Reinicia la sesion para confirmar que el color vuelve solo.
```

Coolers, RAM, LEDs de la placa, GPU y mouse quedaron verdes y persistentes.

## Notas adicionales

- **Teclas sueltas del teclado:** el HyperX Alloy Origins Core guarda su iluminación en un chip onboard (última config hecha con NGENUITY en Windows). El driver OpenRGB sólo expone `Direct` y su keymap deja algunas teclas sin cubrir, que muestran el color grabado. No resoluble desde Linux; fix pendiente = grabar el onboard en verde desde Windows (Paso 6 del README).
- El GPU RTX 5070 Ti aparece **dos veces** en `--list-devices` (dos buses i2c del GPU) — es normal, no es error.
- La placa ASUS Aura y la RAM HyperX retienen el color sin proceso vivo; el teclado (Direct-only) no, de ahí el servicio.
