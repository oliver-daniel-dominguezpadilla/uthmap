# F0 — CFG: endurecimiento de la orquestación

- **Fecha:** 2026-11-20
- **Alcance:** config de agentes (modelo, topes, permisos), riesgos R1–R9, regla de resúmenes y economía de contexto
- **Estado:** documentado; configuración **no aplicada** (pendiente CFG-02)

## Objetivo
Pasar de mitigaciones disciplinarias a estructurales: que ningún riesgo dependa de que alguien se acuerde.

## Qué cambió
- `docs/06-orquestacion.md`: pausa dura reescrita, `deny` para commit/push/borrados/builds web, puerta GC pasa a commit manual, secciones "Preflight de fase", "Reglas de ejecución segura" (R1–R9), "Resúmenes de bloque".
- `docs/05-workflow.md`: el campo `Leer:` exige archivo + sección, no docs enteros.
- `docs/STATE.md`: tarea `CFG-02` como prerrequisito; decisiones D-01 a D-08.
- `docs/resumenes/`: carpeta, índice y este resumen.

## Decisiones
- D-01 modelo único `opencode-go/deepseek-v4.1-flash` (el anterior no existe en el catálogo).
- D-02 `git commit` denegado al Operador; commit manual del humano en GC.
- D-03 topes de pasos: arquitecto 24, operador 16.
- D-04 borrados pasan de `ask` a `deny`.
- D-05 riesgos R1–R8 y preflight publicados en `docs/06`.
- D-06 resúmenes confinados a `docs/resumenes/`, con índice propio.
- D-07 replicar la regla de resúmenes en `AGENTS.md` (pendiente, dentro de CFG-02).
- D-08 economía de contexto (R9): citar secciones, no docs enteros.

## Verificación
Solo revisión documental: no hubo ejecución de código ni tests. Sin cambios en `lib/`, `test/`, `pubspec.yaml` ni `android/`.

## Coste estimado
Con el plan Go ($100 de allowance mensual para este modelo) y ~$0.02–0.03 por tarea delegada, una hora diaria consume ~2–3% del allowance. El límite real no es el volumen, es no cambiar de modelo ni inflar el contexto citado.

## Pendientes
- CFG-02: aplicar los cambios en `opencode.json`, `arquitecto.md` y `operador.md`.
- Abrir sesión nueva tras aplicar (el modelo se guarda por sesión).
- Evaluar si la regla de resúmenes debe subir a `AGENTS.md` para que aplique a futuros agentes.

## Documentos para retomar
Orden de lectura; no hace falta leer todo ni en una sola pasada.

| # | Archivo | Para qué | ¿Obligatorio? |
|---|---|---|---|
| 1 | `AGENTS.md` | Contexto base, invariantes, comandos, DoD | Sí, se carga solo |
| 2 | `docs/STATE.md` | Tablero: fase activa, tareas, puertas, decisiones D-01…D-07 | Sí |
| 3 | `docs/06-orquestacion.md` | Protocolo A↔O, puertas, R1–R8, regla de resúmenes | Sí |
| 4 | `docs/05-workflow.md` | Plantilla de tarea para delegar y formato `REPORTE T-xx` | Sí, antes de la primera delegación |
| 5 | `docs/07-baseline-prototipo.md` | Qué existe ya en `lib/`, convenciones de test, brechas | Sí, antes de tocar código |
| 6 | `docs/00-spec.md` | Requisitos, niveles, "Decisiones confirmadas", trazabilidad RF | Antes de planificar F1+ |
| 7 | `docs/01-api-contract.md` | Contrato Orionis, `X-Device-Id`, 429 | Solo si la tarea toca red/sync |
| 8 | `docs/02-algoritmos.md` | Haversine, bearing, cuadrantes, filtro, vectores de test | Solo si la tarea toca `core/` |
| 9 | `docs/03-arquitectura-movil.md` | Estructura de carpetas, interfaces, modelos | Solo si la tarea crea módulos |
| 10 | `docs/04-design-system.md` | Tokens, pantallas, reglas anti-slop | Solo si la tarea toca UI |
| 11 | `docs/source/` | PDF de requisitos y manual de endpoints | Solo ante discrepancia |

**No leer al arrancar:** los docs 01–04 y `docs/source/` si la tarea no los cita. Leer de más gasta contexto y no mejora la decisión.

## Riesgos abiertos
- Desajuste temporal entre `docs/06` (estado objetivo) y la config real hasta CFG-02.
- Dos tareas que compartan `test/` no pueden ir en paralelo.
