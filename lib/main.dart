import 'package:flutter/material.dart';

import 'app.dart';
import 'data/catalog_repository.dart';
import 'data/media_cache.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final demo =
      const bool.fromEnvironment('UTHMAP_DEMO') ||
      Uri.base.queryParameters['demo'] == '1';
  runApp(
    UthMapApp(
      repository: CatalogRepository(),
      demoMode: demo,
      mediaCache: MediaCache(),
    ),
  );
}
