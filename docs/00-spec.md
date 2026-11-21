# 00 — Especificación (destilada del PDF de requisitos)

Fuente: `docs/source/` PDF "Sistema de Navegación por Rumbo, Geocercado Perimetral y Guía Universitaria Basado en Sensores Móviles".

## Alcance
App móvil (Flutter) + backend/panel web. Orientación espacial y guía descriptiva dentro del campus con GPS y magnetómetro. Backend de referencia: API Orionis (ver `01-api-contract.md`).

## Modos
- **Modo A — Destino (búsqueda activa):** el usuario elige un edificio; la aguja apunta a la entrada transitable más cercana; contador de metros en vivo; al llegar a ≤15 m se abre la ficha completa.
- **Modo B — Exploración libre (pasiva):** sin destino; GPS continuo; al entrar al radio de un edificio: sonido/vibración corta + tarjeta con nombre y acceso a la ficha.

## Umbrales
| Evento | Condición | Acción |
|---|---|---|
| Proximidad (B) | `d <= radio_cobertura` (default 20 m, rango 15–20) | Aviso háptico/sonoro + tarjeta |
| Llegada (A) | `d <= min(15, radio_cobertura)` | Alerta + ficha completa |
| Salida de geocerca | `d > radio + 5 m` (histéresis) | Rearmar notificación |

## Requisitos funcionales
### Nivel 7.0 — Fundamentos
- RF-01 Pantalla de bienvenida, directorio, detalle del inmueble.
- RF-02 Descargar catálogo y persistirlo en el dispositivo.
- RF-03 Directorio por categorías; abrir ficha sin Internet.
- (Web) RF-04 Login admin, CRUD edificios, coordenadas, exposición remota.

### Nivel 8.0 — Geocercado (Modo B)
- RF-05 Haversine implementado.
- RF-06 Lectura continua de GPS al caminar.
- RF-07 Geocerca 15–20 m: alerta sonora/háptica + tarjeta con foto.
- (Web) RF-08 Fotos de fachada, `radio_cobertura` configurable, API con rutas de imagen y radios.

### Nivel 9.0 — Navegación activa (Modo A)
- RF-09 Búsqueda con filtrado en tiempo real por nombre, dependencia o etiqueta.
- RF-10 Bearing inicial hacia la entrada.
- RF-11 Magnetómetro para heading.
- RF-12 Brújula con aguja rotatoria y contador de metros hasta el umbral de 15 m.
- (Web) RF-13 Etiquetas por edificio; coordenadas precisas del acceso.

### Extras
- **Reto Mayor (+10):** RF-14 coordenadas 1:N (`ENTRADA_PRINCIPAL`, `ENTRADA_SECUNDARIA`, `PERIMETRO`); RF-15 Modo B activa por cualquier punto, Modo A ignora `PERIMETRO`; RF-16 texto relativo por cuadrante (ver `02-algoritmos.md`).
- **Extra 1 (+3):** RF-17 filtro pasa-bajas del heading, α entre 0.10 y 0.20, con distancia angular más corta en el cruce 359°→0°.
- **Extra 2 (+3):** RF-18 mapa OpenStreetMap (sin credenciales) con marcador usuario, marcador destino y polyline en vivo.
- **Extra 3 (+3):** RF-19 `url_video` (MP4 o enlace HTTP/S): botón "Ver recorrido en video", reproductor con play/pausa/progreso/pantalla completa, estados de carga y error.
- Se recomienda implementar al menos 2 extras: los puntos compensan fallos de sensor en la evaluación física.

## Notas técnicas obligatorias
1. Cálculo de distancia y rumbo 100% local; red solo para descarga inicial.
2. Sin SDKs cartográficos de pago.
3. Haversine, R = 6 371 000 m.
4. Bearing inicial con `atan2`, resultado 0–360° respecto al norte geográfico.
5. Rotación de aguja = `(bearing - heading) mod 360`.
6. Tolerancia GPS: umbral de llegada 15–20 m.

## Decisiones tomadas (resuelven ambigüedades)
| ID | Decisión | Motivo |
|---|---|---|
| D1 | Proximidad = `radio_cobertura`; llegada = `min(15, radio)` | El PDF dice 20 m/15 m; el manual usa `radio_cobertura` para "llegada". Se separan ambos eventos |
| D2 | Histéresis +5 m y rearme al salir | Evita parpadeo de alertas por ruido GPS |
| D3 | Usar `/sincronizar_v2` + `/ultima_actualizacion` | v2 ya separa accesos/perímetro y trae `coordenada_central` |
| D4 | Stack móvil: Flutter (el PDF cita `video_player`/`chewie`). Backend: contrato Orionis; si se construye backend propio (el PDF menciona Django) debe serializar idéntico | Un solo contrato |
| D5 | Persistencia: clave-valor (JSON) + caché de imágenes en disco | KISS; el filtrado de cientos de edificios se hace en memoria |
| D6 | La app no tiene login ni usuarios; el ícono derecho del topbar muestra estado de sincronización/ajustes, no "perfil" | El API es público |

## Decisiones confirmadas por el usuario
| ID | Decisión |
|---|---|
| U1 | Backend: **se consume la API Orionis**. No se construye backend ni panel web. Los requisitos "(Web)" quedan fuera de alcance |
| U2 | **Android primero**; iOS secundario y sin prioridad (no escribir código iOS-específico; mantener el código neutral a plataforma) |
| U3 | **Los extras ya existen en el prototipo con datos simulados** (coordenadas 1:N, filtro α, OSM, video, Modo B). No se rehacen; se **validan** al conectar datos y sensores reales (ver `07-baseline-prototipo.md`) |
| U5 | **Baseline = prototipo UthMap existente** (Flutter, `C:/proyectos_flutter/uthmap`, paquete `uthmap`): 100% local, sensores simulados, catálogo en `assets/data/edificios.json`. Se **extiende**, no se reescribe |
| U6 | **El wireframe manda sobre el tema oscuro** del kit original: tema blanco, `#111317`/`#6B6F76`/`#E4E2DD`/`#0055FF`, Space Grotesk/Space Mono, lienzo 375×760 |
| U7 | Host de desarrollo **Windows**; el flujo de desarrollo NO usa web (build web 5–8 min); se usa `flutter test` y Android |
| U4 | Operación semiautomática: Arquitecto y Operador se comunican solos; el sistema se detiene en las puertas humanas de `docs/06-orquestacion.md` |

### Consecuencias del alcance actual
- El objetivo de esta etapa: **sustituir lo simulado por real** sin alterar la fidelidad visual: (1) catálogo desde Orionis con el assets JSON como semilla/respaldo offline; (2) sensores reales en Android detrás de la abstracción de simulación ya existente; (3) validar extras en dispositivo.
- El modo demo (`?demo=1` / `UTHMAP_DEMO`) se conserva.
- Cualquier cambio visual respecto al wireframe es una decisión GD.
- Pendiente de confirmar con el usuario: si el prototipo visual es el entregable final o se evoluciona a app conectada (supuesto actual: se evoluciona).
