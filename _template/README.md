# [Título del problema en una línea, sin "issue" ni "bug"]

> **Estado:** [investigación | workaround | solución confirmada]

## Síntoma

Descripción de lo que el usuario observa. Captura o salida literal del error si aplica:

```
mensaje de error textual
```

## Quién está afectado

- **Distro:** Bazzite / Fedora Atomic / cualquier distro con X / etc.
- **Versión del software:** N.N.N
- **Hardware:** rasgo común relevante (si aplica)

Ver [`casos/`](./casos/) para configuraciones específicas confirmadas.

## Causa raíz

Explicación técnica del por qué. Si hay múltiples capas que contribuyen, enumerarlas explícitamente:

1. **Capa A:** ...
2. **Capa B:** ...
3. **Capa C:** ...

## Soluciones que NO funcionan (anti-patrones)

Importante para que otros no pierdan tiempo. Listar las soluciones de foros que parecen lógicas pero fallan.

## Solución

Pasos numerados, reproducibles, con comandos exactos:

### Paso 1 — [acción concreta]

```bash
comando exacto
```

### Paso 2 — [acción concreta]

...

## Verificación

```bash
./verify-fix.sh
```

Resultado esperado:
- ...

## Diagnóstico si vuelve a fallar

Comandos para detectar qué capa se rompió:

```bash
comando de diagnóstico
```

## Casos confirmados

| # | Distro | Hardware/versión |
|---|--------|------------------|
| 001 | ... | ... |

## Referencias

- Enlaces a docs oficiales, ProtonDB, foros relevantes

## Contribuir

Ver [`CONTRIBUTING.md`](../../../CONTRIBUTING.md) en la raíz.
