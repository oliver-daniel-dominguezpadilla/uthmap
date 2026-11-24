# 08 — Verificación de campo (G5σ, G5b, T07)

Protocolo de la sesión de campo que cierra las puertas G5 y el pendiente T07. Nada de esto se puede
cerrar en escritorio: exige Android físico (G5σ exige giroscopio, ver D-36) y salida al campus.

**Estado 2026-11-24:** T17 corregida (arranque de brújula y háptico de llegada, pendiente de
confirmar en dispositivo). Sigue **bloqueado** por T15 (`Ver mapa OSM` → `Bad state: No element`).
T16 (imprecisión de GPS) es observación de campo: se anota el `precisión N m` de cada bloque.

## 1. Preflight (5 min, en escritorio)
1. `flutter analyze` sin warnings y `flutter test` verde. Si no, no se sale.
2. `flutter run` en el terminal de campo con la base real:
   `flutter run --dart-define=ORIONIS_BASE_URL=https://orionis.osoware.com/api/v1`
3. Terminal con giroscopio para G5σ (el SM-A065M no sirve: sin *rotation vector*, D-36). El resto
   de bloques sí se puede hacer en el SM-A065M.
4. GPS del teléfono encendido, ubicación en "alta precisión", app con permiso "Mientras se usa".
5. `adb logcat -c` justo antes de empezar, para que el volcado no arrastre ruido.
6. Panel de sensores → toggle **Real**. Confirmar que dice `GPS activo · precisión N m` y que
   `Ver log` muestra `sensores on` y `permiso whileInUse`.

## 2. Captura de evidencia (obligatoria, una por bloque)
- `adb logcat -d > docs/campo-<bloque>-<fecha>.txt` (no se commitea; se cita en el resumen).
- Copiar literal `Ver log` (últimas 40 líneas) de cada bloque.
- Capturas: solo si hay desviación visual (se comparan con `docs/screenshots/`).

## 3. G5σ — brújula en reposo (solo terminal con giroscopio)
Criterio de aceptación **σ < 5°**, medido así (es lo que la app permite hoy; ver §7):
1. Teléfono plano sobre superficie nivelada, lejos de metal y de imanes. Sensores en **Real**.
2. Anotar `Brújula ±X°` cada 5 s durante **60 s** (12 lecturas).
3. **Pasa** si las 12 lecturas son ≤ 5° y el estado nunca pasa a `uncalibrated` (el umbral del código
   es `> 15°`, `navigation_controller.dart`).
4. **Pasa además** si la aguja, en esos 60 s, no se aparta más de ±5° de su posición media en la
   pantalla (3 capturas espaciadas 20 s superpuestas).
5. **Falla** si aparece `Brújula sin calibrar` de forma continua (caso SM-A065M, D-36) o si X > 5°
   sostenido: se reporta y no se toca el código de sensores sin GD.

## 4. G5b — campus (Modo A y Modo B)
Modo A (destino seleccionado), caminando hacia una entrada real:
1. La aguja apunta a la puerta: de frente, error ≤ 20°; la etiqueta de cuadrante coincide con la
   realidad en 8 de 10 comprobaciones.
2. Los metros **decrecen** al avanzar y nunca saltan más de ~1.5 × la precisión GPS mostrada.
3. Al cruzar `min(15, radio_cobertura)` m: **doble vibración ligera, sin sonido** (D-37) + ficha
   completa, **una sola vez**.
4. Modo A nunca orienta a `PERIMETRO` (invariante 3).
5. Declinación: fijar el valor medido en campo (esperado **este, ~7–8°** para UTH Hermosillo, D-32;
   el 0° por defecto sesga la aguja). Se anota el valor final en el reporte y en `STATE.md`.

Modo B (sin destino), caminando:
6. Una alerta por edificio al entrar en `radio_cobertura`, sin repetición; rearme solo al salir y
   superar `radio + 5 m`.
7. Tras la sincronización inicial, modo avión: directorio y fichas abren, fotos cacheadas visibles,
   ningún 429 bloquea la UI (invariante 4).

## 5. T07 — extras (video, OSM, filtro α)
1. **OSM**: `Ver mapa OSM` abre sin excepción, descarga teselas, marcador de usuario y de edificios,
   polyline al destino; al caminar, la cámara sigue al usuario. *Hoy falla por T15.*
2. **Video**: con el payload actual `url_video` es `null` en los 5 edificios (`docs/01`), así que lo
   verificable es el camino de degradación: la ficha no rompe y la hoja muestra su estado de error /
   "abrir enlace". La reproducción remota **no se puede validar** hasta que el backend publique media.
3. **Filtro α**: α es fijo 0.15, sin control en UI. Se valida que la aguja no vibre, que el paso
   359°→0° no dé un giro completo y que **el primer giro responda de inmediato** (T17, D-38: la
   primera lectura real fija el rumbo; antes el seed 278° de la demo la frenaba).

## 6. Plantilla de reporte de campo
| Bloque | Criterio | Resultado | Evidencia |
|---|---|---|---|
| G5σ | `±X°` ≤ 5° y aguja estable | | `campo-g5sigma-<fecha>.txt` |
| G5b-A | aguja, metros, llegada única | | |
| G5b-B | geocerca única + offline | | |
| T07 | OSM, video (degradación), α | | |

## 7. Limitaciones que no se pueden medir hoy
- **σ numérica de la aguja**: ni la hoja del panel ni `NavSheet` muestran rumbo numérico; el log
  registra eventos (`fix ok`, `fix rechazado`, `brújula ±X°`), no muestras de heading. Medir σ real
  exige instrumentación nueva → tarea aparte y **G2** (toca el panel ya aprobado). No se improvisa.
- **Video remoto real**: bloqueado por backend (`url_video: null`).
- **Mapa que sigue al usuario**: bloqueado por T16.

## 8. Pendiente de git (D-29)
El `.gitignore` sigue ignorando `docs` y `\docs`; lo edita el humano. Orden:
1. Quitar de `.gitignore` las líneas `docs` y `\docs`; dejar `.opencode` y `opencode.json` (D-29). `AGENTS.md` se versiona desde 2026-11-24 (D-40), así que **no** debe ignorarse.
2. `git status --short` y revisar que solo aparezcan T08–T14, este doc y `docs/` (nada de `build/`
   ni `.dart_tool/`).
3. `flutter analyze` + `flutter test` (122/122) antes de stagear.
4. `git add -A` → commit propuesto: `feat(f1): fixes de campo T08-T14, nav sheet desplazable y mainEntrance nullable`
   (se cierra en puerta GC, nunca desde el Operador).
5. Añadir `docs/08-verificacion-campo.md` a la tabla de `AGENTS.md` (lo edita el humano: el agente
   tiene `deny edit` ahí).
