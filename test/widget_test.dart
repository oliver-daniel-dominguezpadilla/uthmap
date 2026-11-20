import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uthmap/data/models.dart';
import 'package:uthmap/state/navigation_controller.dart';
import 'package:uthmap/ui/navigation_screen.dart';
import 'package:uthmap/ui/theme.dart';
import 'package:uthmap/ui/widgets/primitives.dart';

Future<Catalog> _loadCatalog() async {
  final raw = await rootBundle.loadString(
    'assets/data/edificios.json',
    cache: false,
  );
  return Catalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<NavigationController> _pumpScreen(
  WidgetTester tester, {
  Size size = const Size(375, 760),
  Catalog? catalog,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final resolved = catalog ?? await _loadCatalog();
  final controller = NavigationController(catalog: resolved);
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: NavigationScreen(controller: controller),
    ),
  );
  await _settle(tester);
  return controller;
}

void main() {
  testWidgets('el estado inicial reproduce el wireframe', (tester) async {
    await _pumpScreen(tester);

    expect(find.text('Edificio K'), findsOneWidget);
    expect(find.text('145 m'), findsOneWidget);
    expect(find.text('A tus espaldas, gira a la izquierda'), findsOneWidget);
    expect(find.text(kVideoCta), findsOneWidget);
    expect(find.textContaining('Fuera del área'), findsOneWidget);
    expect(find.byType(NavigationScreen), findsOneWidget);
  });

  testWidgets('el menú del avatar permite explorar sin destino', (
    tester,
  ) async {
    await _pumpScreen(tester);

    await tester.tap(find.text('CR'));
    await _settle(tester);
    expect(find.text('Explorar sin destino'), findsOneWidget);

    await tester.tap(find.text('Explorar sin destino'));
    await _settle(tester);

    expect(find.text('Explorando el campus'), findsOneWidget);
    expect(find.text('ELEGIR DESTINO'), findsOneWidget);
  });

  testWidgets('la búsqueda selecciona un destino y actualiza el panel', (
    tester,
  ) async {
    await _pumpScreen(tester);

    await tester.enterText(find.byType(TextField), 'biblioteca');
    await tester.pump();

    expect(find.text('Edificio L — Área de Estudio'), findsOneWidget);

    await tester.tap(find.text('Edificio L — Área de Estudio'));
    await _settle(tester);

    expect(find.text('Edificio L'), findsOneWidget);
    expect(find.text('Edificio K'), findsNothing);
    expect(find.text('VER FICHA COMPLETA'), findsOneWidget);
  });

  testWidgets('la ficha abre desde el panel y "Cómo llegar" vuelve al mapa', (
    tester,
  ) async {
    final controller = await _pumpScreen(tester);
    controller.selectTarget(controller.buildings[1]);
    await _settle(tester);

    await tester.tap(find.text('VER FICHA COMPLETA'));
    await _settle(tester);

    expect(find.text('Edificio L'), findsOneWidget);
    expect(find.text('Biblioteca central'), findsOneWidget);
    expect(find.text('CÓMO LLEGAR'), findsOneWidget);

    await tester.tap(find.text('CÓMO LLEGAR'));
    await _settle(tester);

    expect(find.byType(NavigationScreen), findsOneWidget);
    expect(find.text('Edificio L'), findsOneWidget);
  });

  testWidgets('en escritorio se muestra el stage y el panel de sensores', (
    tester,
  ) async {
    await _pumpScreen(tester, size: const Size(1280, 900));

    expect(find.text('SENSORES SIMULADOS'), findsOneWidget);
    expect(find.text('Orientación'), findsOneWidget);
    expect(find.text('278°'), findsOneWidget);
    expect(find.text('145 m'), findsOneWidget);
    expect(find.text('Ajustes de sensores'), findsOneWidget);
  });
}
