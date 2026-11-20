/// Geocerca con histéresis (Nota 6 y documento de arquitectura):
/// se entra con distancia <= radio y se sale con distancia > radio + 5.
bool geofenceInside({
  required double distanceM,
  required double radiusM,
  required bool wasInside,
}) {
  return distanceM <= (wasInside ? radiusM + 5 : radiusM);
}
