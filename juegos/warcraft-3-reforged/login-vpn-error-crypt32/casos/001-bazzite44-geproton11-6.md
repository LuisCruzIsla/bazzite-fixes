# Caso 001 — Bazzite 44 + GE-Proton11-6 + Warcraft III: Reforged 3.0

**Confirmado por:** [@LuisCruzIsla](https://github.com/LuisCruzIsla)
**Fecha:** 2026-09-14
**Estado:** Fix funciona — el login de Battle.net completa y el juego entra al menú principal.

## Entorno

| Componente | Versión |
|------------|---------|
| Distro | Bazzite 44 (Fedora Atomic), imagen `bazzite-gnome-nvidia-open:stable` 44.20260908 |
| Escritorio | GNOME Shell 50.4, Wayland |
| Kernel | 7.2.3-ogc3.1.fc44 |
| GPU | NVIDIA GeForce RTX 5070 Ti |
| Driver NVIDIA | 610.57.04 |
| CPU | AMD Ryzen 9 5900X |
| RAM | 32 GB |
| Juego | Warcraft III: Reforged **3.0** (parche de septiembre de 2026) |
| Lanzador | Steam — acceso directo no-Steam al `Battle.net Launcher.exe` |
| Proton base | GE-Proton11-6 (28-ago-2026, base **wine-11.0**) |
| Herramienta usada | `GE-Proton11-6-wc3fix` (copia parcheada) |

## Configuración relevante

| Dato | Valor |
|------|-------|
| AppID del shortcut no-Steam | `3990503939` (generado por Steam, distinto en cada equipo) |
| Prefix efectivo | `~/.local/share/Steam/steamapps/compatdata/3990503939/pfx` |
| Ejecutable lanzado | `~/Games/battlenet/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe` |
| Herramienta previa | `proton_hotfix` (fallaba igual) |

Detalle que costó tiempo: el `.exe` vive dentro de un prefix **de Lutris**, pero al lanzarlo desde Steam el prefix que se usa es el de `compatdata/3990503939`. Editar el prefix de Lutris no tiene ningún efecto sobre el arranque desde Steam. Son entornos separados.

Versiones de las DLL implicadas:

| Archivo | Origen | Tamaño | sha256 |
|---------|--------|--------|--------|
| `crypt32.dll` x86_64 | GE-Proton11-6 (wine-11.0) | 1 203 319 | `968e3a77…a017035` |
| `crypt32.dll` i386 | GE-Proton11-6 (wine-11.0) | 1 106 314 | `82dd907f…6e192701` |
| `crypt32.dll` x86_64 | parche (wine-11.6) | 903 302 | `dca9a2c0…6903b6e3` |
| `crypt32.dll` i386 | parche (wine-11.6) | 794 231 | `c73b6266…e192ab1b` |

Las DLL corregidas son **más pequeñas** que las originales de GE-Proton: se compilan sin los mismos símbolos de depuración. La diferencia de tamaño no indica nada por sí sola.

## Auditoría previa a instalar los binarios

Al ser DLL de terceros dentro del runtime, se revisaron antes de copiarlas:

- **246 exports** en cada arquitectura, el mismo recuento que el `crypt32.dll` original de GE-Proton11-6.
- `CertCreateCertificateChainEngine` presente en la tabla de exports.
- Sin URLs ni direcciones IP más allá de la única cadena que también trae el binario original de Wine.
- Cabecera PE coherente con la arquitectura declarada.

## Aplicación de la solución en este caso

Opción B del README, sin desviaciones:

1. Instalado `GE-Proton11-6-x86_64` limpio (la copia parcheada debe partir de una build íntegra).
2. Copia completa a `GE-Proton11-6-wc3fix` y sustitución de las **cuatro** rutas de `crypt32.dll`.
3. Renombrado de `compatibilitytool.vdf` y del archivo `version` a `GE-Proton11-6-wc3fix`.
4. Reinicio completo de Steam.
5. Propiedades del acceso directo de Battle.net → Compatibilidad → forzar `GE-Proton11-6-wc3fix` (antes tenía `proton_hotfix`).
6. Primer lanzamiento: Proton detectó el cambio de versión y actualizó el prefix solo. No hizo falta el paso B.4.

## Salida de verificación

```
=== Capa 1: herramienta parcheada instalada ===
  [OK] GE-Proton11-6-wc3fix
  [OK] compatibilitytool.vdf la declara con nombre propio

=== Capa 2: las cuatro copias de crypt32.dll estan sustituidas ===
  [OK] files/lib/wine/x86_64-windows/crypt32.dll difiere de la build original
  [OK] files/lib/wine/i386-windows/crypt32.dll difiere de la build original
  [OK] files/share/default_pfx/drive_c/windows/system32/crypt32.dll difiere de la build original
  [OK] files/share/default_pfx/drive_c/windows/syswow64/crypt32.dll difiere de la build original

=== Capa 3: asignacion al juego en Steam ===
  [OK] AppID 3990503939 asignado a GE-Proton11-6-wc3fix

=== Capa 4: DLL efectiva dentro del prefix ===
  prefix: /var/home/<usuario>/.local/share/Steam/steamapps/compatdata/3990503939/pfx
  [OK] drive_c/windows/system32/crypt32.dll = la version parcheada
  [OK] drive_c/windows/syswow64/crypt32.dll = la version parcheada

=== Capa 5: proceso en ejecucion (informativo) ===
  [OK] el proceso (pid 18836) corre con GE-Proton11-6-wc3fix

=== Resultado ===
  [OK] crypt32 corregido en su sitio.
```

Validación real: login de Battle.net completado desde el juego, sin el aviso de VPN.

## Notas adicionales

- **El mensaje de error dirigió el diagnóstico en la dirección equivocada durante días.** "Please check your VPN" empuja a revisar red, DNS, IPv6 y cortafuegos; ninguna de esas capas participa. La pista real fue que el navegador entraba a `battle.net` sin problema mientras el cliente insistía.
- **Rotar versiones de Proton fue tiempo perdido.** Se probaron Proton Experimental, GE-Proton10-34, GE-Proton11-1 y GE-Proton11-3: todas comparten base wine ≤ 11.0, así que todas fallan igual. Una vez identificada la capa, quedó claro que no podía existir una build oficial que funcionara.
- **Las dos arquitecturas son obligatorias.** El launcher de Battle.net es de 32 bits y el juego de 64. Parchear sólo `x86_64` deja el login del launcher roto.
- **Ojo con el prefix ya existente.** Proton sólo recopia sus DLL cuando cambia la versión de la herramienta; el archivo `version` del prefix seguía diciendo `GE-Proton11-6`. Al asignar una herramienta con nombre distinto, la actualización se disparó sola, pero conviene comprobarlo (Capa 4 del script) antes de concluir que el parche no sirve.
- **Este arreglo caduca por diseño.** En cuanto GE-Proton o Proton Experimental pasen a wine-11.6+, se reasigna la herramienta oficial y se borra la copia. Revisarlo en cada release de Proton.
