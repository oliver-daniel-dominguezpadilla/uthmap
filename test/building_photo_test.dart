import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uthmap/data/media_cache.dart';
import 'package:uthmap/data/models.dart';
import 'package:uthmap/ui/widgets/building_photo.dart';

Building _building({String? photoAsset, String? photoUrl}) => Building(
  id: 'edificio_k',
  code: 'K',
  name: 'Edificio K',
  description: 'Aulas y laboratorios',
  category: BuildingCategory.academico,
  areaLabel: '',
  hours: '',
  coverageRadiusM: 20,
  dependencies: const [],
  tags: const [],
  photoAsset: photoAsset,
  videoAsset: null,
  videoUrl: null,
  footprint: null,
  photoUrl: photoUrl,
  coordinates: const [
    BuildingCoordinate(
      type: CoordinateType.entradaPrincipal,
      lat: 29.0,
      lng: -110.9,
    ),
  ],
);

Widget _wrap(Building building) => MaterialApp(
  home: Scaffold(
    body: BuildingPhoto(building: building, mediaCache: MediaCache()),
  ),
);

void main() {
  testWidgets('sin foto remota ni asset deja el relleno del wireframe', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_building()));

    expect(find.byType(ColoredBox), findsWidgets);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('sin foto remota y con asset usa AssetImage', (tester) async {
    await tester.pumpWidget(
      _wrap(_building(photoAsset: 'assets/img/edificio_k.jpg')),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<AssetImage>());
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('con foto remota monta CachedNetworkImage', (tester) async {
    await tester.pumpWidget(_wrap(_building(photoUrl: 'https://x.test/a.jpg')));
    await tester.pump();

    expect(find.byType(CachedNetworkImage), findsWidgets);
  });
}
