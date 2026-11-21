# STATE — Tablero (solo lo edita el Arquitecto)

Fase activa: F0 (A0 hecha, G0 aprobada; CFG-02 en curso)
Alcance: evolucionar el prototipo UthMap a datos y sensores reales. Android primero. Wireframe manda.

## Tareas
| ID | Título | Estado | Reintentos | Notas |
|---|---|---|---|---|
| CFG-02 | Endurecer config de agentes: `steps`, `deny` de commit/borrados/autoconfig, regla de resúmenes en `AGENTS.md` | bloqueada | 1 | Hecho y verificado: D-06 en `AGENTS.md`, `deny` en commit/borrados, `deny edit` en `.opencode/*` y `AGENTS.md`; analyze limpio y 20/20 tests. **Falta solo `steps: 16` / `steps: 24`**: los dos agentes tienen `deny edit` en `.opencode/*` → edición humana de 2 líneas (ver D-19) |
| A0 | Auditoría de lib/ y test/ → corregir docs/07 | hecha | 0 | 2026-11-21, solo lectura estática; `docs/07` reescrito con inventario real, 20 tests y 6 discrepancias |
| T01 | Auditar core/geo y geofence vs vectores; `arrivalM = min(15, radio_cobertura)` con tests | pendiente | 0 | Paralelo con T02 (archivos disjuntos) |
| T02 | Capturar payload real de Orionis como fixture → parser a modelos existentes | pendiente | 0 | Sin payload real no se escribe parser (D-13) |
| T03 | CampusApi + sync + X-Device-Id + 429/offline | pendiente | 0 | Dependencia nueva → GD antes |
| T04 | Caché de fotos/videos remotos + indicador de sync | pendiente | 0 | Dependencia nueva → GD antes |
| T05 | Sensores reales + calibración + descarte de fixes + log (T05+T06 fusionadas) | pendiente | 0 | Mismo archivo: `navigation_controller.dart` |
| T07 | Validación de extras en dispositivo | pendiente | 0 | |

Estados: pendiente · en curso · en revisión · hecha · bloqueada.

## Puertas
| ID | Estado | Respuesta del usuario | Fecha |
|---|---|---|---|
| G0 | aprobada | Aprobado con plan ajustado (CFG-02 → T01 ∥ T02 → G1 → T03/T04 con GD → T05 fusionada → T07) | 2026-11-21 |

## Decisiones
- D-01 · Modelo único: `opencode-go/deepseek-v4.1-flash` en ambos roles. Origen único en `opencode.json`; el Operador lo declara explícito. El ID anterior (`deepseek-v4-flash`) no existe en el catálogo.
- D-02 · `git commit` denegado al Operador; **el commit lo ejecuta el humano en GC**. Motivo: un "Allow always" sobre `ask` desactivaría GC de forma permanente.
- D-03 · Topes duros de pasos: `arquitecto: 24`, `operador: 16`. Impide bucles de coste.
- D-04 · Borrados (`rm`, `Remove-Item`, `del`) pasan de `ask` a `deny`: un agente de implementación no necesita borrar archivos.
- D-05 · Riesgos R1–R8 y preflight de fase documentados en `docs/06-orquestacion.md`.
- D-06 · Todo bloque de trabajo cierra con un `.md` en `docs/resumenes/` + línea en su `INDEX.md`; lo escribe el Arquitecto. Confinado a esa carpeta: sin carpetas ni archivos de resumen en otro sitio. Se genera al cerrar tarea no trivial, fase, bloque de ≥3 tareas o decisión GD/GB.
- D-07 · La regla D-06 se replica en `AGENTS.md` (pendiente, dentro de CFG-02) para que aplique a cualquier agente futuro, no solo al que lea `docs/06`.
- D-08 · Economía de contexto (R9): la tarea cita archivo + sección, no docs enteros; el Operador no amplía lectura por su cuenta.
- D-09 · Llegada = `min(15, radio_cobertura)` (invariante 2). Hoy el código usa `15` fijo: se corrige en T01 (función pura + tests) y se consume en T05. No se toca UI.
- D-10 · Los videos `assets/videos/edificio_k.mp4` y `edificio_m.mp4` **no existen** ni están declarados en `pubspec.yaml`. Decisión: no fabricar assets; T04 los sustituye por `url_video` remoto con caché y fallback al error actual. G6 valida el resultado.
- D-11 · No hay cliente HTTP en el árbol (sin `http`/`dio`). T03 elige el paquete; cualquier dependencia nueva exige puerta GD antes de T03.
- D-12 · `steps` va en el frontmatter de cada agente (campo V2 válido; `maxSteps` está deprecado). El Operador no puede editar `.opencode/*` ni `AGENTS.md`: la config la cambia el humano o el Arquitecto nunca; evita que un agente en bucle reescriba sus propias reglas.
- D-13 · T02 exige una respuesta real de Orionis guardada como fixture antes de escribir el parser; sin payload no se adivinan campos.
- D-14 · T05 y T06 se fusionan: ambas tocaban `navigation_controller.dart` y partirlas duplicaba ciclos de reporte sobre el mismo bloque.
- D-15 · El parser v2 es una **capa de mapeo aparte** (`lib/data/catalog_v2_mapper.dart` o similar → `Catalog`); `Building.fromJson` se queda intacto para el JSON de assets. Sin clases DTO paralelas ni alias dentro del modelo.
- D-16 · `/sincronizar_v2` no trae `mapa` (huella isométrica). Se deriva del `perimetro` (centro = coordenada central proyectada, ancho/fondo = bbox) con un `alto` constante declarado; si no hay perímetro, el mapa isométrico no se dibuja. No se inventan huellas.
- D-17 · `Building` gana `photoUrl`/`videoUrl` nullable; `photoAsset`/`videoAsset` se conservan para el catálogo incluido. La UI elige remoto si hay URL (T04), local si no.
- D-18 · El repo **no tiene commit base** (todo el árbol sin rastrear). Antes de T01/T02 se hace un commit inicial del estado actual para tener punto de retorno y diffs revisables. Lo ejecuta el humano (GC).
- D-19 · `steps` se aplica a mano: ambos agentes tienen `deny edit` en `.opencode/*`, así que la tarea no puede escribir su propio tope. Edición humana de 2 líneas, no se relaja el `deny`.
- Wireframe manda sobre el tema oscuro del kit (U6).
- Desarrollo sin web: build web tarda 5–8 min (U7).
