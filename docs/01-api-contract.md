# 01 — Contrato de API (destilado del Manual de Endpoints Orionis, v1.0.0)

Fuente completa: `docs/source/Manual_de_Endpoints_Orionis.html`. Base: `{BASE_URL}/api/v1`. JSON UTF-8. Backend Laravel 12.

## Reglas generales
- Todos los endpoints: `GET`, públicos, sin auth.
- Headers de request: `Accept: application/json`, `X-Device-Id: <uuid>` (UUID generado en el primer arranque y persistido).
- Cuota: 100 req/min por dispositivo (`X-Device-Id` + IP). Response headers: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `Retry-After` (en 429).
- Envoltura OK: `{ "success": true, "message": "...", "data": ... }`.
- Envoltura error: `{ "success": false, "message": "...", "errors": null }` (404, 422, 500). 429: `{ "success": false, "data": null, "message": "..." }`.

## Endpoints
| Ruta | Uso en la app |
|---|---|
| `/sincronizar_v2` | **Principal.** Catálogo compacto completo |
| `/ultima_actualizacion` | Check ligero antes de descargar. `data` = timestamp ISO 8601 con zona (`2026-11-10T19:45:00-07:00`) o `null` |
| `/sincronizar` | Alternativa v1 (etiquetas como objetos, accesos con `PERIMETRO` mezclados, timestamp sin zona) |
| `/edificios?categoria=&search=` | Listado resumido (online) |
| `/edificios/{id}` | Ficha completa (online) |
| `/edificios/{id}/accesos?solo_entradas=true` | Accesos GPS (online) |
| `/categorias` | `data: [{id, nombre}]` |
| `/etiquetas?search=` | `data: [{id, nombre}]` |

## Forma de `/sincronizar_v2` (`data[]`)
```json
{
  "id": 1, "codigo": "EDIF-A", "nombre": "Edificio A - Aulas y Docencia",
  "descripcion": "...", "dependencias": "...",
  "radio_cobertura": 20,
  "foto_url": "http://host/storage/edificios/fotos/edificio_a.jpg",
  "url_video": "http://host/storage/edificios/videos/recorrido_a.mp4",
  "categoria": { "id": 1, "nombre": "Académico", "descripcion": "..." },
  "etiquetas": ["ingenieria", "tutorias"],
  "coordenada_central": { "latitud": 20.08123456, "longitud": -98.76123456 },
  "accesos": [
    { "id": 1, "nombre": "Acceso Principal Frontal", "latitud": 20.08123456, "longitud": -98.76123456,
      "tipo_punto": "ENTRADA_PRINCIPAL", "es_principal": true }
  ],
  "perimetro": [[20.08145678, -98.76145678], [20.08148, -98.7611]]
}
```
Raíz: `{ success, ultima_actualizacion, data, message }`.

## Reglas de transformación (v2)
- `accesos`: solo `ENTRADA_PRINCIPAL` y `ENTRADA_SECUNDARIA`.
- `perimetro`: solo vértices `PERIMETRO`, lista ordenada de `[lat, lng]`; `[]` si no hay.
- `coordenada_central`: acceso con `es_principal`, si no el primero, si no el promedio; `null` si el edificio no tiene coordenadas.
- `url_video`, `foto_url`: pueden ser `null`. `url_video` puede ser MP4 propio o enlace (p.ej. YouTube) → el reproductor debe manejar ambos o degradar a "abrir enlace".
- Edificios inactivos no se devuelven; si un edificio desaparece del catálogo, la sincronización **reemplaza** el catálogo local completo (no hacer merge).

## Flujo de sincronización
1. Arranque con red: `GET /ultima_actualizacion`.
2. Si `data == ultima_sync_local` → conservar datos. Comparar por igualdad de string, no por orden.
3. Si difiere → `GET /sincronizar_v2` → reemplazo atómico del catálogo + descarga de imágenes → guardar el nuevo timestamp **solo si todo terminó bien**.
4. Sin red, 429 o error → usar catálogo local; mensaje discreto (snackbar). Respetar `Retry-After` para reintentos en segundo plano.

## Errores a manejar
| Código | Comportamiento |
|---|---|
| 200 con `success:false` o `data:null` | Tratar como fallo, conservar local |
| 404 | Edificio inexistente/inactivo |
| 429 | Offline-first, snackbar, esperar `Retry-After` |
| 500 / timeout / sin red | Conservar local, reintento con backoff |

## Claves locales sugeridas
`campus_catalogo_offline` (JSON del catálogo), `campus_ultima_sincronizacion` (string timestamp), `device_id` (UUID).

## Discrepancias detectadas en el manual
- `ultima_actualizacion` de `/sincronizar` no trae zona horaria; la de `/sincronizar_v2` y `/ultima_actualizacion` sí. Usar solo las segundas para comparar.
- El manual indica llegada con `d <= radio_cobertura`; la spec exige 15 m. Resuelto en D1 (`00-spec.md`).
- `localhost` en los ejemplos: la `BASE_URL` real debe ser configurable (variable de compilación), nunca hardcodeada.
