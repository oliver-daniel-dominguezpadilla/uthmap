# 06 — Orquestación automatizada y puertas humanas

## Cómo se comunican (mecánica de opencode 2.x)
- **Arquitecto → Operador:** el Arquitecto invoca al subagente con la herramienta de subagentes (permiso `subagent: operador → allow`; los demás subagentes están denegados). Varias invocaciones en el mismo turno corren en paralelo.
- **Operador → Arquitecto:** el subagente no escribe a un primary; su **respuesta final es el resultado de la tarea** y vuelve al Arquitecto. Por eso el Operador cierra siempre con `REPORTE T-xx` (`05-workflow.md`).
- **Memoria compartida:** `docs/STATE.md` (tablero). El Operador no puede editar `docs/` (permiso `edit docs/* → deny`).
- **Pausa hacia el humano:** solo el Arquitecto habla con el usuario, con la herramienta `question` (permiso `question: allow`; denegado al Operador). Si el Operador necesita una decisión, la devuelve en `Dudas/bloqueos`.
- **Pausa dura (permisos `shell` con `ask`):** en el Operador, `flutter run`, `flutter build` y `adb` requieren aprobación (se resuelve en primer plano, ver R4).
- **Prohibido por config (`deny`):** `git commit`, `git push`, `flutter run -d edge`, `flutter build web` y todo borrado (`rm`, `Remove-Item`, `del`). **El commit lo ejecuta el humano en la puerta GC**, nunca el Operador.
- **Reglas V2:** el orden importa y gana la última regla que coincide; todo agente parte permitiendo todo, por eso los `deny` van primero y las excepciones después.

## Bucle del Arquitecto (`/orquestar`)
1. Leer `docs/STATE.md`. Identificar tareas de la fase activa con dependencias cumplidas.
2. Si una tarea exige una decisión o aprobación pendiente → ir a **Puerta**.
3. Delegar con la herramienta de subagentes usando la plantilla de `05-workflow.md`. Máx. 2 en paralelo, archivos disjuntos y **nunca en background si la tarea puede disparar un `ask`** (R4).
4. Recibir `REPORTE`. Revisar contra criterios de aceptación y checklist.
   - Cumple → marcar hecha en `STATE.md`, escribir el resumen del bloque en `docs/resumenes/` (ver abajo) y continuar.
   - No cumple → reenviar correcciones concretas. Máx. 2 reintentos por tarea; al tercer fallo → **Puerta GB**.
5. Al completar la fase → **Puerta de campo**. Antes de abrirla: resumen de fase en `docs/resumenes/` + `STATE.md` al día. Detenerse.
6. Jamás avanzar más allá de una puerta sin respuesta explícita del usuario.

## Puertas humanas (el Arquitecto se detiene y pregunta con `question`)
| ID | Cuándo | Qué debe verificar el humano |
|---|---|---|
| G0 | Tras la auditoría A0 | Aprobar el diagnóstico del baseline, las brechas y el plan |
| G1 | Fin F1 | Ejecutar `flutter test` (todo verde) y confirmar que la UI no cambió frente a `docs/screenshots/` |
| G2 | Cualquier cambio visual propuesto | Aprobar la desviación del wireframe (por defecto: prohibido) |
| G3 | Fin F2 | Android físico, modo avión tras sincronizar: directorio y ficha con foto; luego con red: sync desde Orionis |
| G4 | Fin F3 (parte 1) | Caminar hacia 3 edificios con sensores reales: una alerta por entrada, sin repetición |
| G5 | Fin F3 (parte 2) | Brújula real: aguja estable (σ < 5° en reposo), apunta a la puerta, llegada a ≤ 15 m |
| G6 | Fin F4 | Video y OSM funcionando en el dispositivo |
| GD | Decisión importante | Cambio de contrato/spec, desviación de un invariante, dependencia nueva, cambio de arquitectura |
| GB | Bloqueo | Tarea con 3 fallos, operador bloqueado, o ambigüedad no resoluble con los docs |
| GC | Antes de `git commit` | El Arquitecto muestra el mensaje propuesto; **el humano ejecuta el commit** (el Operador tiene `git commit` denegado) |

### Formato de una puerta
El Arquitecto escribe: (1) qué se completó, (2) checklist de verificación numerado y ejecutable, (3) cómo reportar un fallo. Luego llama a `question` con opciones **Aprobado / Falló (describir) / Cambiar plan**. Si `question` no está disponible, lo pide en texto y se detiene. Registra la respuesta en `docs/STATE.md` (sección Puertas).

## Reglas de autonomía
- Sin puerta de por medio, el Arquitecto no pide confirmación: decide, justifica en una línea y sigue.
- Los tests automáticos (`flutter analyze`, `flutter test`) los corre y valida el Operador; no son puertas.
- Presupuesto: al cierre de cada fase el Arquitecto resume tareas hechas y estado, para que decidas si continuar (el allowance de Go es compartido).

## Resúmenes de bloque (`docs/resumenes/`) — obligatorio
Todo bloque de trabajo cierra con un `.md` en `docs/resumenes/`. Lo escribe **siempre el Arquitecto** (el Operador tiene `docs/` denegado), después de aceptar el `REPORTE`.

**Cuándo se genera** (si no se cumple ninguno, no hay archivo; basta `STATE.md`):
1. Cierre de **cada tarea** de la tabla que toque ≥3 archivos o introduzca una decisión.
2. Cierre de **cada fase** (F0–F4), sin excepción.
3. Cierre de un **bloque de trabajo** de la sesión: ≥3 tareas seguidas, o cualquier puerta GD/GB resuelta.
4. Cualquier **parte importante del proyecto** fuera de la tabla (contrato, arquitectura, migración, dependencia nueva).

**Nombre:** `F<fase>-<ID>-<slug>.md` para tarea (`F0-T01-geo-geofence.md`), `F<fase>-fase.md` para fase (`F2-fase.md`).
**Índice:** `docs/resumenes/INDEX.md`, una línea por resumen, en orden cronológico. Se actualiza en el mismo paso.

**Contenido mínimo:** fecha · tarea/fase · objetivo · qué cambió (archivos) · decisiones tomadas · verificación real (comandos y resultado) · pendientes · riesgos abiertos · **documentos que hay que leer para retomar** (ruta + para qué + si es obligatorio o solo si aplica).
**Límite:** ~40 líneas. Sin código pegado, sin capturas de log. El resumen no sustituye a `STATE.md` ni al `REPORTE`.

**Confinamiento (no negociable):** todo resumen vive **exclusivamente** en `docs/resumenes/`. No se crea ninguna otra carpeta ni archivo de resumen en `docs/` ni fuera de él. `docs/06` solo define la regla y `docs/STATE.md` solo guarda una línea de estado; ninguno acumula contenido de resumen. Si un bloque necesita detalle técnico largo, ese detalle va en el `REPORTE` o en el doc temático que ya exista (`01`–`07`), nunca en un resumen paralelo.

## Preflight de fase (antes de la primera delegación)
El Arquitecto verifica y anota en `STATE.md`; si algo falla, no delega.

1. **Modelo:** ambos agentes declaran `opencode-go/deepseek-v4.1-flash`. Si la sesión es antigua, el modelo guardado puede ser el obsoleto → abrir sesión nueva.
2. **Permisos:** el Operador conserva `deny` en `git commit`, `git push`, borrados y builds web; `ask` solo en `flutter run`, `flutter build` y `adb`.
3. **Aprobaciones guardadas:** revisar que ningún `ask` haya quedado como `allow` permanente.
4. **Topes:** `steps` finito en ambos agentes.
5. **`STATE.md`:** tareas y puertas al día.

## Reglas de ejecución segura
- **R1 · Un solo origen de modelo.** El ID vive en `opencode.json`; el Operador lo repite explícitamente porque hereda del padre. No se duplica en más sitios.
- **R2 · Propiedad de archivos.** La tarea declara su lista cerrada de archivos. Dos delegaciones en paralelo no comparten ni archivo ni directorio de tests. Si una tarea necesita un archivo fuera de su lista, se detiene y lo reporta.
- **R3 · Tope de pasos.** `steps` finito (`arquitecto: 24`, `operador: 16`). Al llegar al tope el agente pierde herramientas y debe resumir; no puede seguir trabajando.
- **R4 · Nada de `ask` en background.** Un subagente en segundo plano que pide aprobación queda esperando sin que el turno lo resuelva. Toda tarea con `ask` posible se lanza en primer plano.
- **R5 · Nada crítico en `ask`.** Si una operación no debe automatizarse nunca, va en `deny` (no en `ask`): un "Allow always" la volvería permanente.
- **R6 · Bucle de dudas acotado.** Dos ciclos de ida/vuelta por duda; al segundo, puerta GB.
- **R7 · Worktree no toca docs.** El aislamiento por worktree es para código; `docs/STATE.md` vive solo en la rama principal.
- **R8 · Config entre fases.** Los cambios de `opencode.json` o de agentes se aplican sin ninguna delegación en vuelo (la config se recarga en caliente).
- **R9 · Economía de contexto.** El subagente no comparte memoria: siempre relee. El ahorro no viene de "que recuerde", viene de **citar poco**.
  1. `Leer:` cita **archivo + sección**, nunca "el doc entero". Un doc de 300 líneas para usar 20 es desperdicio puro.
  2. Si el Operador necesita más contexto, lo pide en `Dudas/bloqueos`; no lo busca por su cuenta.
  3. El estado se lee de `STATE.md` y del último `REPORTE`; no se reconstruye releyendo specs.
  4. Para localizar un símbolo, `grep`/`glob` antes que lectura completa.
  5. En tarea y reporte: rutas y números de línea, nunca logs ni archivos pegados.
  6. Repetir el mismo orden de lectura (AGENTS.md primero) sube el acierto de caché; el cache read cuesta ~50× menos que el input.
