import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Clave local del UUID que identifica al dispositivo ante Orionis
/// (`docs/01-api-contract.md` §"Claves locales sugeridas").
const String deviceIdKey = 'uthmap.deviceId.v1';

/// Devuelve el `X-Device-Id` persistido o genera un UUID v4 y lo guarda.
///
/// [prefs] permite inyectar una instancia (tests); en producción se obtiene
/// con `SharedPreferences.getInstance()`.
Future<String> ensureDeviceId([SharedPreferences? prefs]) async {
  final store = prefs ?? await SharedPreferences.getInstance();
  final existing = store.getString(deviceIdKey);
  if (existing != null && existing.trim().isNotEmpty) {
    return existing;
  }

  final generated = const Uuid().v4();
  await store.setString(deviceIdKey, generated);
  return generated;
}
