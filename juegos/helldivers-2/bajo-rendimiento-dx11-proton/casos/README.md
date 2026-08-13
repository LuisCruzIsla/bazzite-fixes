# Casos confirmados

Cada archivo `NNN-distro-hardware.md` documenta una combinación específica de distro + hardware donde se validó la solución.

| # | Distro | GPU / Driver | CPU | Resultado |
|---|--------|--------------|-----|-----------|
| [001](./001-bazzite44-rtx5070ti.md) | Bazzite 44 | NVIDIA RTX 5070 Ti / 610.43.03 | Ryzen 9 5900X | ~70 → ~101 fps (+44%) |

¿Confirmaste el fix en otro hardware? Añade un caso siguiendo la numeración (ver [`CONTRIBUTING.md`](../../../../CONTRIBUTING.md)).

Son especialmente valiosos los casos con **GPU AMD** (para confirmar que el cuello es la traducción de la API y no el driver NVIDIA) y los de **CPU con menos núcleos**, donde la ganancia de DX12 debería ser aún mayor.
