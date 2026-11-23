import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias de calibración de sensores persistidas en clave-valor.
///
/// Solo guarda la declinación magnética: el resto del estado de sensores es
/// efímero (se recalcula en cada sesión).
class SensorPrefs {
  /// Clave de la declinación en grados.
  static const String declinationKey = 'uthmap.declination.v1';

  /// Límite de recorte de la declinación, en grados.
  static const double minDeclinationDeg = -30;
  static const double maxDeclinationDeg = 30;

  /// Declinación guardada, recortada a [-30, 30]. Cero si no hay valor.
  Future<double> loadDeclinationDeg() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getDouble(declinationKey);
    if (stored == null) return 0;
    return _clamp(stored);
  }

  /// Persiste [value] recortado a [-30, 30].
  Future<void> saveDeclinationDeg(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(declinationKey, _clamp(value));
  }

  static double _clamp(double value) =>
      value.clamp(minDeclinationDeg, maxDeclinationDeg).toDouble();
}
