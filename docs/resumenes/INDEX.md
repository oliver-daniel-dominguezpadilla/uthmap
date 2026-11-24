# Índice de resúmenes

Regla de creación y formato: `docs/06-orquestacion.md`, sección "Resúmenes de bloque".
Una línea por resumen, en orden cronológico.

| Fecha | Archivo | Alcance | Resultado |
|---|---|---|---|
| 2026-11-20 | `F0-CFG-endurecimiento.md` | Config de agentes, riesgos R1–R9, regla de resúmenes, economía de contexto | Documentado; config pendiente de CFG-02 |
| 2026-11-21 | `F0-CFG-02-endurecimiento-aplicado.md` | `AGENTS.md` + agentes: `deny` de commit/borrados/autoedición, `steps` 24/16 | Aplicado y verificado (analyze limpio, 20/20) |
| 2026-11-21 | `F1-T01-core-llegada.md` | `core/` auditado contra `docs/02`; `arrivalRadiusM` = `min(15, radio_cobertura)` | Hecha; analyze limpio, 30/30 |
| 2026-11-21 | `F1-T02-parser-v2.md` | Fixture real de Orionis + `catalogFromSincronizarV2`; D-20…D-23 | Hecha; analyze limpio, 40/40 |
| 2026-11-21 | `F1-fase.md` | Cierre de F0/F1: A0, CFG-02, T01, T02, T03a (sin revisar) | G0 y G1 aprobadas; 51/51 verde |
| 2026-11-21 | `F1-T03-api-sync.md` | `CampusApi` + `X-Device-Id` + 429/timeout; `syncRemote` con timestamp, reemplazo atómico y offline | Hecha; review OK, analyze limpio, 58/58 |
| 2026-11-21 | `F1-T04-medios-sync.md` | `MediaCache`, `BuildingPhoto`, foto/video remotos en ficha/directorio/panel y sync real en el arranque | Hecha; G2 aprobada, analyze limpio, 68/68 |
| 2026-11-21 | `F1-resumen-sesion.md` | Resumen consolidado de la sesión: F0, T01–T04, puertas, decisiones D-15…D-24, riesgos y T05 | 68/68, analyze limpio; T05 pendiente |
| 2026-11-22 | `F1-T05-sensores-reales.md` | T05 partida en T05a–T05d: `FixGate`/declinación/log, cableado del motor, panel de sensores (G2) y origen del catálogo (D-26) | T05a–T05c hechas (92/92, analyze limpio); T05d sin tests ni validación |
| 2026-11-23 | `F1-T05d-origen-catalogo.md` | Origen del catálogo en `projectToCampus`/`IsoSiteMap`/`resetDemo`; `test/catalog_origin_test.dart` | Hecha; analyze limpio, 96/96 |
| 2026-11-23 | `F4-T09-reintento-429.md` | Reintento único en 429 con `Retry-After` ≤ 2 s (`CampusApi.sleep` inyectable) | Hecha; analyze limpio, 102/102 |
| 2026-11-23 | `F4-T10-medios-prefetch.md` | Prefetch de videos paralelo con timeout y cableado en `_start`; 2 tests corregidos | Hecha; analyze limpio, 113/113 |
| 2026-11-23 | `F3-sesion-2026-11-23.md` | Sesión completa: T05d, T08–T14, hallazgos en SM-A065M, decisiones D-29…D-36 | 122/122, analyze limpio; **todo lo de campo pendiente** |
| 2026-11-24 | `F3-T17-brujula-arranque-haptico.md` | Arranque limpio de la brújula real (`_filter.reset` en la primera lectura) y aviso háptico silencioso al llegar (D-37, D-38) | Hecha; analyze limpio, 128/128; validación en dispositivo pendiente |
