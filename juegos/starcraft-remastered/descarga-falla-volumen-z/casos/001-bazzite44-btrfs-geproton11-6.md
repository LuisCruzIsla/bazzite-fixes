# Caso 001 — Bazzite 44 + disco btrfs secundario + GE-Proton11-6

**Confirmado por:** [@LuisCruzIsla](https://github.com/LuisCruzIsla)
**Fecha:** 2026-09-24
**Estado:** Fix funciona — el aviso "No se pudo descargar" desaparece y el descargador recibe datos del CDN por primera vez desde la instalación.

## Entorno

| Componente | Versión |
|------------|---------|
| Distro | Bazzite 44 (Fedora Atomic), imagen `bazzite-gnome-nvidia-open:stable` 44.20260921 |
| Raíz `/` | `overlay` composefs, solo lectura |
| Escritorio | GNOME Shell 50.5, Wayland |
| Kernel | 7.2.4-ogc3.1.fc44 |
| GPU | NVIDIA GeForce RTX 5070 Ti |
| Driver NVIDIA | 615.71.09 |
| CPU | AMD Ryzen 9 5900X |
| RAM | 32 GB |
| Juego | StarCraft: Remastered 1.23.10.13515, 64 bits, `esMX` |
| Battle.net | 2.53.0.17840 |
| Lanzador | Steam — acceso directo no-Steam al `Battle.net Launcher.exe` |
| Runtime | `GE-Proton11-6-wc3fix` (también fallaba con Proton 11.0) |

## Configuración relevante

| Dato | Valor |
|------|-------|
| AppID del shortcut no-Steam | `3990503939` (distinto en cada equipo) |
| Disco del juego | NVMe secundario, btrfs, montado en `/var/mnt/Poderoza` vía `x-systemd.automount` |
| Ruta original | `Z:/mnt/Poderoza/Biblioteca/BattleNetLibrary/StarCraft` |
| Ruta tras el fix | `D:/Biblioteca/BattleNetLibrary/StarCraft` |
| Letra creada | `dosdevices/d:` → `/var/mnt/Poderoza` |

El mismo prefix contiene StarCraft II, Warcraft III y Heroes of the Storm bajo `Z:`. El Agent registra también para ellos `Failed to get volume information`, pero no se observaron síntomas en esos juegos y se dejaron sin mover.

## Aplicación de la solución en este caso

Pasos 1 y 2 del README, sin desviaciones:

1. Battle.net cerrado. Creado el enlace `dosdevices/d:` → `/var/mnt/Poderoza`.
2. En Battle.net, "Localizar el juego" → `D:\Biblioteca\BattleNetLibrary\StarCraft`.
3. El Agent marcó el build como no jugable un instante (`Invalid .build.info at D:/...`), reescribió `.build.info` y los índices de `Data/data` y lo dejó listo. La interfaz siguió mostrando la ruta con `Z:`, pero el Agent y el proceso ya usaban `D:`.
4. Primer arranque: el descargador recibió datos de `us.cdn.blizzard.com` y `level3.blizzard.com`. Siguiente arranque: sin aviso.

## Diagnóstico que llevó a la causa

| Prueba | Resultado |
|--------|-----------|
| CDN desde el host (`curl` al build config del juego) | 200, responde en ~0.2 s |
| Firewall | Puertos 1025-65535 TCP/UDP abiertos |
| `SCR-NGDP-DiagnosticLog.txt`, sesiones de los dos últimos meses | `totalbytes=0` en todos los servidores; el único dato real es de la instalación en julio |
| Conexiones de `StarCraft.exe` durante una sesión completa (`ss` cada 0,2 s) | Sólo servicios de Blizzard, AWS y Google (login, perfil, noticias). **Ninguna** al CDN y ninguna fallida |
| Log del Agent | `Failed to get volume information` para todas las rutas `Z:`, incluso `Z:/home/...`. Ninguna para `D:` |

## Salida de verificación

```
prefix: /home/<usuario>/.local/share/Steam/steamapps/compatdata/3990503939/pfx

=== Capa 1: letra de unidad propia en el prefix ===
  [OK] d: -> /var/mnt/Poderoza

=== Capa 2: ruta del juego guardada por el Agent ===
  [OK] D:/Biblioteca/BattleNetLibrary/StarCraft

=== Capa 3: fallos de volumen en el ultimo log del Agent ===
  [OK] sin fallos de volumen para la ruta de StarCraft (Agent-20260925T015538.log)

=== Capa 4: el descargador del juego recibe datos ===
  [OK] 9 registros con bytes recibidos del CDN en el historial
       ultima sesion: 2026-09-24T21:00:36
       (el resumen de bytes de una sesion se escribe al cerrar el juego)

=== Capa 5: proceso en ejecucion (informativo) ===
  [OK] D:\Biblioteca\BattleNetLibrary\StarCraft\x86_64\StarCraft.exe -launch -uid s1

=== Resultado ===
  [OK] StarCraft: Remastered fuera de Z: y descargando del CDN.
```

## Notas adicionales

- **El diálogo "Quedan N kb" desvió el diagnóstico hacia la red.** Se parece al de la transferencia de mapas de una sala, pero aparecía en el menú principal. La pista decisiva fue que el juego no abría ninguna conexión al CDN.
- **Cambiar de Proton no tuvo efecto.** Proton 11.0 y GE-Proton11-6 dieron el mismo resultado; la causa está en el mapeo de unidades del prefix.
- **Idioma inestable (observación sin confirmar).** Antes del fix, el juego arrancaba a veces en `enUS` aunque Battle.net le pasaba `LOCALE=esMX` en todos los lanzamientos. No se ha podido relacionar con esta causa; si alguien lo reproduce, vale la pena anotarlo en un caso.
