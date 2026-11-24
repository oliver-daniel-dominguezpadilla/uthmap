import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uthmap/core/geo.dart';
import 'package:uthmap/data/models.dart';
import 'package:uthmap/state/navigation_controller.dart';
import 'package:uthmap/ui/theme.dart';
import 'package:uthmap/ui/widgets/nav_sheet.dart';
import 'package:uthmap/ui/widgets/primitives.dart';

/// Tamaño lógico del dispositivo donde se vio el desbordamiento
/// (SM-A065M: 360×800).
const Size _phone = Size(360, 800);

/// Edificio sintético: sin foto remota, sin video y sin asset, para que el
/// test no dependa de red, `Hero` ni imágenes.
const Building _building = Building(
  id: 'test-1',
  code: 'T01',
  name: 'Edificio sintético',
  description: 'Datos de prueba para el panel de navegación.',
  category: BuildingCategory.academico,
  areaLabel: 'Área de prueba',
  hours: 'L-V 8:00-18:00',
  coverageRadiusM: 20,
  dependencies: <String>[],
  tags: <String>[],
  photoAsset: null,
  videoAsset: null,
  coordinates: <BuildingCoordinate>[
    BuildingCoordinate(
      type: CoordinateType.entradaPrincipal,
      lat: campusOriginLat + 0.001,
      lng: campusOriginLng,
    ),
  ],
);

Future<void> _pumpSheet(
  WidgetTester tester, {
  required bool expanded,
  required double height,
}) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final controller = NavigationController(
    catalog: const Catalog(version: 'test', buildings: [_building]),
  );
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: const MediaQueryData(size: _phone),
        child: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: _phone.width,
              height: height,
              child: NavSheet(
                controller: controller,
                expanded: expanded,
                bottomInset: 0,
                onExpanded: (_) {},
                onPlayVideo: (_) {},
                onOpenDetail: (_) {},
                onOpenDirectory: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );

  // Pumps explícitos: nunca pumpAndSettle (animación del sheet en curso).
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Comprueba que ningún texto del panel queda fuera de sus límites (ni
/// colapsado a altura cero por clipping silencioso).
void _expectTextsInsideSheet(WidgetTester tester) {
  final sheet = tester.getRect(find.byType(NavSheet));
  final texts = find.descendant(
    of: find.byType(NavSheet),
    matching: find.byType(Text),
  );
  final count = texts.evaluate().length;
  expect(count, greaterThanOrEqualTo(3));

  for (var i = 0; i < count; i++) {
    final rect = tester.getRect(texts.at(i));
    expect(rect.height, greaterThan(0));
    expect(
      rect.top >= sheet.top - 0.01 && rect.bottom <= sheet.bottom + 0.01,
      isTrue,
      reason: 'Texto fuera del panel: $rect frente a $sheet',
    );
  }
}

void main() {
  testWidgets('contraído en 360×800 no desborda y los textos siguen visibles', (
    tester,
  ) async {
    await _pumpSheet(tester, expanded: false, height: NavSheet.collapsedHeight);

    expect(tester.takeException(), isNull);
    expect(find.text('Edificio sintético'), findsOneWidget);
    expect(find.textContaining('Fuera del área'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^\d+ m$')), findsOneWidget);
    _expectTextsInsideSheet(tester);
  });

  testWidgets('expandido en 360×800 no desborda y muestra el CTA', (
    tester,
  ) async {
    await _pumpSheet(tester, expanded: true, height: 380);

    expect(tester.takeException(), isNull);
    expect(find.byType(BlackButton), findsOneWidget);
    expect(find.text('VER FICHA COMPLETA'), findsOneWidget);
    _expectTextsInsideSheet(tester);
  });

  testWidgets('expandido con su alto natural (218) mantiene el CTA', (
    tester,
  ) async {
    await _pumpSheet(tester, expanded: true, height: NavSheet.expandedHeight);

    expect(tester.takeException(), isNull);
    expect(find.byType(BlackButton), findsOneWidget);
    _expectTextsInsideSheet(tester);
  });

  testWidgets('expandirse antes de crecer no lanza desbordamiento', (
    tester,
  ) async {
    // Reproduce el síntoma real: el CTA entra en el árbol mientras el
    // AnimatedContainer todavía mide el alto contraído.
    await _pumpSheet(tester, expanded: true, height: NavSheet.collapsedHeight);

    expect(tester.takeException(), isNull);
    expect(find.byType(BlackButton), findsOneWidget);
  });
}
