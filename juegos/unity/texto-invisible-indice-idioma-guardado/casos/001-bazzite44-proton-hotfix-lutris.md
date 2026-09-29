# Caso 001 — Bazzite 44 + Proton Hotfix (umu) + Lutris

**Confirmado por:** [@LuisCruzIsla](https://github.com/LuisCruzIsla)
**Fecha:** 2026-09-29
**Estado:** Fix funciona — los textos de la interfaz aparecen tras corregir el índice de idioma de la partida.

## Entorno

| Componente | Versión |
|------------|---------|
| Distro | Bazzite 44 (Fedora Atomic), imagen `bazzite-gnome-nvidia-open:stable` 44.20260928.1 |
| Escritorio | GNOME Shell 50.5 |
| Kernel | 7.2.7-ogc1.1.fc44 |
| GPU | NVIDIA GeForce RTX 5070 Ti |
| Driver NVIDIA | 615.71.09 |
| Lanzador | Lutris 0.5.22 |
| Runtime | Proton Hotfix (`hotfix-20260828`) vía umu |
| Juego | 爆弾解体 (Kimochi, DLsite RJ01664642), 64 bits, solo japonés |
| Motor | Unity 6000.3.10f1, Mono, TextMeshPro, Live2D Cubism |

## Configuración relevante

| Dato | Valor |
|------|-------|
| Partida | `drive_c/users/steamuser/AppData/LocalLow/FoxInc/HBomb/HBomb` (JSON UTF-8 con BOM) |
| Campo | `"_languageIndex"` |
| Valor encontrado | `1` |
| Valor corregido | `0` |
| Tablas de idioma del juego | Una sola hoja, `jp`, en el objeto `Lang` de `resources.assets` |
| Fuentes TMP | `Corporate-Logo-Medium-ver3 SDF` (atlas 4096x4096 pre-generado), `DSEG7Classic-Regular SDF`, `LiberationSans SDF` |
| Locale del sistema | `es_ES.UTF-8` |

## Aplicación de la solución en este caso

1. **Paso 1:** añadido `LANG` y `LC_ALL` = `ja_JP.UTF-8` al `env` del yml de Lutris. Desaparecieron los avisos `キーが見つかりません` y `NotFoundScenario:`, pero los textos seguían vacíos.
2. **Pasos 2 y 3:** con el juego cerrado, `"_languageIndex": 1` → `0` en `HBomb` (respaldo previo).
3. **Paso 4:** textos visibles. Tras cerrar el juego el valor sigue en `0`.

No se ha comprobado si el Paso 1 sigue siendo necesario una vez corregido el índice.

## Diagnóstico que llevó a la causa

| Prueba | Resultado |
|--------|-----------|
| Textos visibles antes del fix | Solo "Parameter", "bpm" (LiberationSans, fijos en la escena) y el contador de bpm (DSEG7) |
| Fuentes de Windows en el prefix | Irrelevante: la fuente japonesa va embebida con su TTF |
| Atlas SDF de `Corporate-Logo` extraído con UnityPy | Pre-generado y lleno (~78 % de píxeles con alfa) |
| Material de `Corporate-Logo` vs `DSEG7` | Mismo shader `TextMeshPro/Distance Field`, parámetros normales |
| `-force-d3d11` | Sin cambio (ya era el backend por defecto) |
| `-force-vulkan` | No arranca: `Forced GfxDevice 'Vulkan' was not built from editor` |
| `-force-d3d12` (vkd3d-proton) | Arranca, texto igual de invisible |
| Tabla `Lang` del juego | Una sola hoja (`jp`); índice válido solo `0` |
| Partida guardada | `"_languageIndex": 1` |

## Salida de verificación

```
=== Capa 1: indice de idioma en los archivos de guardado ===
  [OK] HBomb: "_languageIndex": 0

=== Capa 2: PlayerPrefs en el registro del prefix ===
  [OK] sin PlayerPrefs de idioma

=== Resultado ===
  [OK] ningun indice de idioma fuera de lo esperado.
```

## Notas adicionales

- **El origen del `1` es una inferencia.** No se capturó el primer arranque. Lo más probable es que, con el sistema en `es_ES`, el juego eligiera un índice de idioma no japonés y lo guardara.
- **El prefix era compartido** con otros juegos; la corrección solo toca la partida de este juego.
- **Error aparte, sin relación con el texto:** `NullReferenceException` en `Live2D.Cubism.Core.CubismDrawable.get_VertexPositions` (`LiveTrack_WorldObj.SetupAsync`) en cada arranque. No impidió jugar.
