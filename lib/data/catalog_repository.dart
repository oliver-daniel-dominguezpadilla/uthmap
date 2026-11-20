import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Catálogo del prototipo: se sirve desde assets (no hay backend) y se
/// persiste en el dispositivo para demostrar el arranque offline.
class CatalogRepository {
  static const String catalogKey = 'uthmap.catalog.v1';
  static const String syncedAtKey = 'uthmap.syncedAt.v1';
  static const String assetPath = 'assets/data/edificios.json';

  Catalog? _memoryCatalog;

  Future<Catalog?> loadLocal() async {
    final cached = _memoryCatalog;
    if (cached != null) return cached;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(catalogKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final catalog = Catalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      _memoryCatalog = catalog;
      return catalog;
    } catch (_) {
      await prefs.remove(catalogKey);
      return null;
    }
  }

  Future<Catalog> loadBundled() async {
    final raw = await rootBundle.loadString(assetPath);
    return Catalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<Catalog> sync() async {
    await Future<void>.delayed(const Duration(milliseconds: 850));
    final raw = await rootBundle.loadString(assetPath);
    final catalog = Catalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(catalogKey, raw);
    await prefs.setString(syncedAtKey, DateTime.now().toIso8601String());
    _memoryCatalog = catalog;
    return catalog;
  }

  Future<DateTime?> syncedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(syncedAtKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> clearLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(catalogKey);
    await prefs.remove(syncedAtKey);
    _memoryCatalog = null;
  }
}
