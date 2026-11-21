# 04 — Design system (SUPERSEDED el tema oscuro del kit original)

Fuente de verdad visual: **wireframe del usuario + código existente** (`lib/ui/widgets/primitives.dart` para tokens; `docs/screenshots/` como referencia). Este documento solo fija reglas; no redefine tokens.

## Tokens vigentes (del wireframe)
| Token | Valor |
|---|---|
| Lienzo | 375×760, tema blanco |
| Texto | `#111317` |
| Texto secundario | `#6B6F76` |
| Borde/línea | `#E4E2DD` |
| Acento | `#0055FF` |
| Tipografías | Space Grotesk (UI), Space Mono (datos) — assets locales TTF |
| Buscador | altura 50 px |
| Sheet inferior | 218 / 146 px (expandido/compacto) |
| CTA video | `[ REPRODUCIR RECORRIDO EN VIDEO — MP4 ]` |
| Mapa | isométrico (`CustomPainter`) con alternativa OSM |

## Reglas
- Fidelidad al wireframe: no cambiar medidas, colores, tipografías ni textos sin puerta GD.
- Estado inicial canónico (referencia de regresión visual): Edificio K, 145 m, heading 278°, aguja 205°, frase «A tus espaldas, gira a la izquierda».
- Sin emojis; un solo set de íconos; sin degradados, glow ni glassmorphism salvo que el wireframe los use.
- Movimiento corto y respetando reducción de movimiento si el wireframe no indica otra cosa.
- Contraste: verificar `#6B6F76` sobre blanco (≈5:1) en textos pequeños.
- Los skills `anti-ai-slop-uiux` y `ui-ux-pro-max` son criterio secundario: **ante conflicto gana el wireframe**.
- Cualquier tarea de UI debe conservar los 20 tests existentes y las capturas de referencia.

## Checklist de entrega UI
- [ ] Capturas comparadas con `docs/screenshots/` (nav_compact, nav_wide, welcome)
- [ ] Estados de carga, vacío, error y permiso denegado cubiertos
- [ ] `flutter analyze` limpio y `flutter test` verde
