/// Radio de llegada en Modo A: nunca mayor que la cobertura del edificio.
///
/// Implementa el invariante 2 de `AGENTS.md`: llegada (Modo A) =
/// `min(15, radio_cobertura)`, para que un edificio de cobertura pequeña no
/// se considere alcanzado desde fuera de su propia geocerca. El llamador
/// garantiza `coverageRadiusM > 0`.
double arrivalRadiusM(double coverageRadiusM, {double arrivalDefaultM = 15}) =>
    coverageRadiusM < arrivalDefaultM ? coverageRadiusM : arrivalDefaultM;

/// Geocerca con histéresis (Nota 6 y documento de arquitectura):
/// se entra con distancia <= radio y se sale con distancia > radio + 5.
bool geofenceInside({
  required double distanceM,
  required double radiusM,
  required bool wasInside,
}) {
  return distanceM <= (wasInside ? radiusM + 5 : radiusM);
}
