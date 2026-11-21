# 05 — Workflow Arquitecto ↔ Operador

## Plantilla de tarea (la escribe el Arquitecto; el Operador no ve nada más que esto + AGENTS.md + docs citados)
```
TAREA T-xx: <título>
Objetivo: <resultado verificable en una línea>
Leer: <docs/xx.md §sección concreta, solo lo imprescindible>
Archivos que puedes crear/modificar: <lista exacta>
Archivos prohibidos: todo lo demás
Interfaz/contrato: <firmas, modelos, puertos>
Tests obligatorios: <casos concretos con valores esperados>
Criterios de aceptación: <lista verificable>
Fuera de alcance: <lo que NO se hace>
```

## Plantilla de reporte (la escribe el Operador)
```
REPORTE T-xx
Estado: completo | parcial | bloqueado
Archivos creados/modificados: <lista>
Comandos y resultado: dart format / flutter analyze / flutter test (pegar resumen real)
Criterios de aceptación: <cada uno: cumple / no cumple + evidencia>
Desviaciones: <qué cambió y por qué>
Dudas/bloqueos: <preguntas concretas>
```

## Checklist de revisión del Arquitecto
Contrato intacto · sin archivos fuera de lista · tests prueban el comportamiento (no solo existen) · invariantes de AGENTS.md respetados · sin paquetes ni APIs inventadas · UI acorde a `04-design-system.md`.

## Fases y tareas (re-planificadas sobre el prototipo)
| Fase | Tarea | Depende de | Paralelizable con |
|---|---|---|---|
| F0 | A0 Auditoría de `lib/` y `test/` (solo lectura, la hace el Arquitecto) → corrige `07-baseline-prototipo.md` y `STATE.md` | — | — |
| F1 | T01 Auditar `core/geo.dart` y `core/geofence.dart` contra los vectores de `02`; añadir los tests que falten; sin tocar UI | A0 | T02 |
| F1 | T02 Parser de `sincronizar_v2` → modelos existentes + fixtures JSON (usar el JSON de assets como semilla) | A0 | T01 |
| F2 | T03 `CampusApi` + sync (`ultima_actualizacion` → `sincronizar_v2`) + `X-Device-Id` + respaldo en assets/local + reglas 429/offline | T02 | — |
| F2 | T04 Caché de fotos/videos remotos; indicador de sync respetando el wireframe | T03 | — |
| F3 | T05 Fuentes reales de posición y heading (Android) detrás de la simulación existente; permisos; conservar modo demo | T01 | T03 |
| F3 | T06 Calibración: declinación configurable, descarte de fixes imprecisos, log de depuración | T05 | T04 |
| F4 | T07 Validación de extras en dispositivo (video, OSM, filtro α) y correcciones | T05, T04 | — |
Paralelismo: máximo 2 operadores concurrentes (allowance compartido) y siempre con archivos disjuntos.

## Hitos de validación en campo (puertas de `06-orquestacion.md`; Android físico)
- 7.0: modo avión, ficha completa con foto visible.
- 8.0: caminar hacia 3 edificios; una sola alerta por entrada; sin repetición al rondar el borde.
- 9.0: aguja estable (σ < 5° en reposo) y apuntando a la puerta correcta; llegada a ≤ 15 m.

## Primer mensaje al Arquitecto (pegar en la sesión)
```
Proyecto: Campus Compass — app Flutter de navegación por rumbo y geocercado para campus.
Objetivo: cumplir nivel 9.0 (Modo A + Modo B), sin extras por ahora.
Stack: Flutter/Dart (Android primero); consumo de API Orionis (docs/01), sin backend propio; cálculo local; OpenCode Go (DeepSeek V4 Flash).
Restricciones: sin mapas de pago; offline-first; evaluación física con sensores reales.
Estado actual: idea con documentación completa en docs/. Decisiones del usuario en docs/00-spec.md.
Lee AGENTS.md, docs/00-spec.md, docs/06-orquestacion.md y docs/STATE.md.
Presenta el plan de F0 y abre la puerta G0. Con mi aprobación, ejecuta /orquestar.
```
