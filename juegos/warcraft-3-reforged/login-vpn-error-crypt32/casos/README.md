# Casos confirmados

Cada archivo `NNN-distro-hardware.md` documenta una combinación específica donde se validó la solución.

| # | Distro | Runtime | Lanzador | Resultado |
|---|--------|---------|----------|-----------|
| [001](./001-bazzite44-geproton11-6.md) | Bazzite 44 | GE-Proton11-6 + crypt32 de Wine 11.6 | Steam (shortcut no-Steam de Battle.net) | Login correcto |

¿Lo confirmaste en otra configuración? Añade un caso siguiendo la numeración (ver [`CONTRIBUTING.md`](../../../../CONTRIBUTING.md)).

Son especialmente valiosos:

- Casos con **Lutris, Heroic o Bottles usando un runner wine-11.6+** (Opción A), que confirmarían que basta con la versión de Wine sin parchear nada.
- Casos sobre **otra build de Proton** distinta de GE-Proton11-6, para confirmar que el procedimiento es independiente de la build base.
- Casos en **Steam Deck / SteamOS**, donde `compatibilitytools.d` vive en la partición de usuario y sobrevive a las actualizaciones del sistema.
- Cualquier confirmación de que **una build de Proton ya rebasó a wine-11.6** — en ese momento este arreglo deja de hacer falta.
