# Casos confirmados

Cada archivo `NNN-distro-hardware.md` documenta una combinación específica donde se validó la solución.

| # | Distro | Runtime | Lanzador | Resultado |
|---|--------|---------|----------|-----------|
| [001](./001-bazzite44-btrfs-geproton11-6.md) | Bazzite 44 (disco btrfs secundario) | GE-Proton11-6 | Steam (shortcut no-Steam de Battle.net) | Descarga completa |

¿Lo confirmaste en otra configuración? Añade un caso siguiendo la numeración (ver [`CONTRIBUTING.md`](../../../../CONTRIBUTING.md)).

Son especialmente valiosos:

- Casos en **otras Fedora Atomic** (Silverblue, Kinoite, Bluefin, Aurora) o **SteamOS**, cuya raíz también es de solo lectura.
- Casos en **distros con raíz normal** (Arch, Ubuntu, Fedora Workstation) donde el juego bajo `Z:` descargue sin problema — confirmarían que la raíz composefs es la condición necesaria.
- Casos con **Lutris, Heroic o Bottles**.
- Otros juegos de Battle.net (StarCraft II, Warcraft III, Heroes of the Storm) con fallos de descarga o actualización bajo `Z:` que se resuelvan con el mismo procedimiento.
