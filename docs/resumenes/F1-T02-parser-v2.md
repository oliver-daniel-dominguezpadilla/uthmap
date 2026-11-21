# F1 — T02: payload real y mapeo v2 → catálogo local

- **Fecha:** 2026-11-21
- **Alcance:** `lib/data/catalog_v2_mapper.dart`, `lib/data/models.dart`, `lib/ui/widgets/isometric_map.dart` (1 guard), fixture y test nuevos
- **Estado:** hecha (1 reintento: error de spread en el origen)

## Objetivo
Que el catálogo real de Orionis entre en la app sin tocar UI ni inventar campos.

## Qué cambió
- `catalog_v2_mapper.dart`: `catalogFromSincronizarV2` puro, con `defaultBuildingHeightM = 10`.
- `models.dart`: `footprint` nullable, `photoUrl`/`videoUrl`, `Catalog.originLat/originLng/skipped`.
- `isometric_map.dart`: `if (f == null) continue;` (única línea de UI).
- `test/fixtures/orionis_sincronizar_v2.json` (5 851 B, descargada con `curl.exe`) + `test/catalog_v2_mapper_test.dart` (10 tests).

## Decisiones
- D-20 a D-23 (ver `STATE.md`): excluir edificios sin coordenadas, huella nullable derivada del perímetro, origen por catálogo, enum de categorías intacto.

## Verificación real
- `flutter analyze` → *No issues found!* (73.1 s) · `flutter test` → **40/40** (30 previos + 10 nuevos).
- Tests contra datos reales: B/D/E, `skipped == 2`, id 41 primero en D, huella de E con `height == 10`, origen ≈ 29.0089/−110.9024.

## Pendientes
- Sin `foto_url`/`url_video` reales: T04/T07 no tienen muestra de media remota.
- Cablear `originLat`/`originLng` al mapa isométrico y a `_exploreRoute` (T04), hoy latente.
- Commits pendientes: CFG-02-bis, T01 y T02 están sin commitear.

## Riesgos abiertos
- `_BuildingDraft` lanza `TypeError` si un acceso viene sin `latitud`/`longitud` (el payload actual no lo hace). T03 debe envolver el parseo en manejo de error de red.
- El mapa isométrico del catálogo real solo dibujará E; el resto no tiene perímetro suficiente.

## Documentos para retomar
| # | Archivo | Para qué |
|---|---|---|
| 1 | `docs/STATE.md` | T03 pendiente y decisiones D-20…D-23 |
| 2 | `docs/01-api-contract.md` §"Observaciones del payload real" | Forma y rarezas verificadas |
| 3 | `docs/resumenes/F1-T01-core-llegada.md` | Cierre de la otra mitad de F1 |
