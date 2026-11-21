# F0 — CFG-02: endurecimiento de la config aplicado

- **Fecha:** 2026-11-21
- **Alcance:** `AGENTS.md`, `.opencode/agents/operador.md`, `.opencode/agents/arquitecto.md`
- **Estado:** hecha (2 pasadas: CFG-02 parcial + CFG-02-bis)

## Objetivo
Que los topes y las prohibiciones vivan en la config, no en la disciplina de quien escribe la tarea.

## Qué cambió
- `AGENTS.md`: sección "Resúmenes de bloque (obligatorio)" con el alcance de D-06 y puntero a `docs/06`.
- `operador.md`: `git commit`, `rm`, `Remove-Item` y `del` pasan de `ask` a `deny`; `ask` queda solo en `flutter run`, `flutter build` y `adb`; `deny edit` en `AGENTS.md` y `.opencode/*`; `steps: 16`.
- `arquitecto.md`: `steps: 24`.

## Decisiones
- D-12 · `steps` en frontmatter (campo V2 válido; `maxSteps` deprecado).
- D-19 · El tope de pasos se aplica con edición humana: los agentes no pueden escribir su propio tope sin relajar su `deny`.

## Verificación real
- `flutter analyze` → *No issues found!* (317 s). `flutter test` → 20/20 en verde (54 s). Ningún archivo Dart tocado.
- Diff de CFG-02-bis: exactamente 3 líneas (2 `steps` + 1 `deny` restaurado). `git status` limpio de ruido.

## Fricción encontrada (para no repetirla)
1. El Operador escribió el `deny` de `.opencode/*` antes que `steps` y se autobloqueó: la config se recarga en caliente. De ahí la regla de orden.
2. El commit base se hizo sin esa regla; el diff posterior es de una línea, revisable.
3. En YAML, `steps` debe ser la **última** línea del frontmatter y el `deny` el último ítem de `permissions`; no "las dos al final".

## Pendientes
- Verificación en caliente: abrir sesión nueva y comprobar que OpenCode carga ambos agentes sin error de esquema y respeta los topes.

## Documentos para retomar
| # | Archivo | Para qué |
|---|---|---|
| 1 | `docs/STATE.md` | Tablero, decisiones D-01…D-19, siguiente tarea |
| 2 | `docs/06-orquestacion.md` | Preflight de fase (§"Preflight") antes de la primera delegación |
| 3 | `docs/07-baseline-prototipo.md` | Estado real del código tras A0 |
