import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uthmap/data/catalog_repository.dart';
import 'package:uthmap/data/models.dart';
import 'package:uthmap/state/navigation_controller.dart';
import 'package:uthmap/ui/theme.dart';
import 'package:uthmap/ui/widgets/sensor_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Catalog catalog;

  setUpAll(() async {
    catalog = await CatalogRepository().loadBundled();
  });

  Future<void> pumpPanel(
    WidgetTester tester,
    NavigationController controller,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => SensorPanel(controller: controller),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('el panel muestra la declinación en cero', (tester) async {
    final controller = NavigationController(catalog: catalog);

    await pumpPanel(tester, controller);

    expect(find.text('DECLINACIÓN'), findsOneWidget);
    expect(find.text('0°'), findsOneWidget);
    expect(find.text('−1°'), findsOneWidget);
    expect(find.text('+1°'), findsOneWidget);
    expect(find.text('Ver log'), findsOneWidget);
    expect(find.text('Brújula —'), findsOneWidget);
  });

  testWidgets('pulsar +1° sube el valor de la declinación', (tester) async {
    final controller = NavigationController(catalog: catalog);

    await pumpPanel(tester, controller);
    await tester.tap(find.text('+1°'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.declinationDeg, 1);
    expect(find.text('+1.0°'), findsOneWidget);
    expect(find.text('0°'), findsNothing);
  });
}
