import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uthmap/data/media_cache.dart';
import 'package:uthmap/data/models.dart';

/// Fetcher falso: registra las URLs recibidas y escribe un archivo temporal.
class _FakeFetcher {
  _FakeFetcher(this.dir, {this.failOn = const {}});

  final Directory dir;
  final Set<String> failOn;
  final List<String> calls = [];
  final Map<String, File> files = {};

  Future<File> call(String url) async {
    calls.add(url);
    if (failOn.contains(url)) {
      throw const FileSystemException('fallo simulado');
    }
    final file = File('${dir.path}/media_${calls.length}.bin');
    await file.writeAsString(url);
    files[url] = file;
    return file;
  }
}

Building _building({required String id, String? videoUrl}) => Building(
  id: id,
  code: id.toUpperCase(),
  name: 'Edificio $id',
  description: '',
  category: BuildingCategory.academico,
  areaLabel: '',
  hours: '',
  coverageRadiusM: 20,
  dependencies: const [],
  tags: const [],
  photoAsset: null,
  videoAsset: null,
  footprint: null,
  photoUrl: null,
  videoUrl: videoUrl,
  coordinates: const [
    BuildingCoordinate(
      type: CoordinateType.entradaPrincipal,
      lat: -0.2101,
      lng: -78.4909,
    ),
  ],
);

Catalog _catalog(List<Building> buildings) =>
    Catalog(version: 'test', buildings: buildings);

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('media_cache_test');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('videoFile devuelve null sin llamar al fetcher si la URL es nula o '
      'en blanco', () async {
    final fetcher = _FakeFetcher(tempDir);
    final cache = MediaCache(fetcher: fetcher.call);

    expect(await cache.videoFile(null), isNull);
    expect(await cache.videoFile('  '), isNull);
    expect(await cache.videoFile('ftp://x.test/a.mp4'), isNull);
    expect(fetcher.calls, isEmpty);
  });

  test('videoFile entrega el archivo del fetcher para la URL exacta', () async {
    final fetcher = _FakeFetcher(tempDir);
    final cache = MediaCache(fetcher: fetcher.call);

    const url = 'https://x.test/a.mp4';
    final file = await cache.videoFile(url);

    expect(file, isNotNull);
    expect(file!.path, fetcher.files[url]!.path);
    expect(file.existsSync(), isTrue);
    expect(fetcher.calls, [url]);
  });

  test('videoFile devuelve null si el fetcher lanza y no propaga', () async {
    final fetcher = _FakeFetcher(
      tempDir,
      failOn: const {'https://x.test/a.mp4'},
    );
    final cache = MediaCache(fetcher: fetcher.call);

    File? file;
    await expectLater(
      () async => file = await cache.videoFile('https://x.test/a.mp4'),
      returnsNormally,
    );

    expect(file, isNull);
    expect(fetcher.calls, ['https://x.test/a.mp4']);
  });

  test('prefetchVideos deduplica por URL y respeta max', () async {
    final fetcher = _FakeFetcher(tempDir);
    final cache = MediaCache(fetcher: fetcher.call);
    final catalog = _catalog([
      _building(id: 'b1', videoUrl: 'https://x.test/a.mp4'),
      _building(id: 'b2', videoUrl: 'https://x.test/a.mp4'),
      _building(id: 'b3'),
      _building(id: 'b4', videoUrl: 'https://x.test/b.mp4'),
    ]);

    final downloaded = await cache.prefetchVideos(catalog, max: 3);

    expect(downloaded, 2);
    expect(fetcher.calls, ['https://x.test/a.mp4', 'https://x.test/b.mp4']);
  });

  test(
    'prefetchVideos ignora los fallos y devuelve el conteo de éxitos',
    () async {
      final fetcher = _FakeFetcher(
        tempDir,
        failOn: const {'https://x.test/b.mp4'},
      );
      final cache = MediaCache(fetcher: fetcher.call);
      final catalog = _catalog([
        _building(id: 'b1', videoUrl: 'https://x.test/a.mp4'),
        _building(id: 'b2', videoUrl: 'https://x.test/b.mp4'),
        _building(id: 'b3', videoUrl: 'https://x.test/c.mp4'),
      ]);

      final downloaded = await cache.prefetchVideos(catalog);

      expect(downloaded, 2);
      expect(fetcher.calls, [
        'https://x.test/a.mp4',
        'https://x.test/b.mp4',
        'https://x.test/c.mp4',
      ]);
    },
  );

  test('prefetchVideos con max 0 no descarga nada', () async {
    final fetcher = _FakeFetcher(tempDir);
    final cache = MediaCache(fetcher: fetcher.call);
    final catalog = _catalog([
      _building(id: 'b1', videoUrl: 'https://x.test/a.mp4'),
    ]);

    expect(await cache.prefetchVideos(catalog, max: 0), 0);
    expect(fetcher.calls, isEmpty);
  });

  test(
    'imageProvider devuelve CachedNetworkImageProvider con la misma URL',
    () {
      final cache = MediaCache();

      final provider = cache.imageProvider('https://x.test/a.jpg');

      expect(provider, isA<CachedNetworkImageProvider>());
      expect(
        (provider as CachedNetworkImageProvider).url,
        'https://x.test/a.jpg',
      );
    },
  );
}
