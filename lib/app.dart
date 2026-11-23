import 'dart:async';

import 'package:flutter/material.dart';

import 'data/catalog_repository.dart';
import 'data/media_cache.dart';
import 'data/models.dart';
import 'data/sensor_prefs.dart';
import 'state/navigation_controller.dart';
import 'ui/navigation_screen.dart';
import 'ui/theme.dart';
import 'ui/welcome_screen.dart';

class UthMapApp extends StatefulWidget {
  const UthMapApp({
    super.key,
    required this.repository,
    this.demoMode = false,
    this.mediaCache,
    this.sensorPrefs,
  });

  final CatalogRepository repository;

  /// Arranca directo en el mapa con el catálogo incluido (útil para capturas
  /// y para evaluar la navegación sin pasar por la sincronización).
  final bool demoMode;

  /// Caché de medios remotos compartida por la app. Si es nula se crea una
  /// instancia propia en el estado raíz.
  final MediaCache? mediaCache;

  /// Preferencias de sensores (declinación). Si es nula se crea una propia.
  final SensorPrefs? sensorPrefs;

  @override
  State<UthMapApp> createState() => _UthMapAppState();
}

class _UthMapAppState extends State<UthMapApp> with WidgetsBindingObserver {
  late final MediaCache _mediaCache = widget.mediaCache ?? MediaCache();
  late final SensorPrefs _sensorPrefs = widget.sensorPrefs ?? SensorPrefs();
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  Catalog? _catalog;
  NavigationController? _controller;
  bool _loading = true;
  bool _offlineNoticeShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        unawaited(controller.pauseSensors());
      case AppLifecycleState.resumed:
        unawaited(controller.resumeSensors());
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  NavigationController _createController(Catalog catalog) {
    final controller = NavigationController(
      catalog: catalog,
      sensorPrefs: _sensorPrefs,
    );
    unawaited(controller.loadSettings());
    return controller;
  }

  Future<void> _bootstrap() async {
    final local = widget.demoMode
        ? await widget.repository.loadBundled()
        : await widget.repository.loadLocal();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (local != null) {
        _catalog = local;
        _controller = _createController(local);
      }
    });
  }

  void _start(Catalog catalog, {bool offline = false}) {
    setState(() {
      _catalog = catalog;
      _controller?.dispose();
      _controller = _createController(catalog);
    });
    if (!offline || _offlineNoticeShown) return;
    _offlineNoticeShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messenger = _messengerKey.currentState;
      if (!mounted || messenger == null) return;
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.ink,
          content: Text(
            'Catálogo local · sin conexión',
            style: AppTheme.mono(size: 11, color: AppColors.page),
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return MaterialApp(
      title: 'UthMap',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: AppTheme.light,
      home: _loading
          ? const _BootstrapView()
          : (controller == null || _catalog == null)
          ? WelcomeScreen(repository: widget.repository, onReady: _start)
          : NavigationScreen(controller: controller, mediaCache: _mediaCache),
    );
  }
}

class _BootstrapView extends StatelessWidget {
  const _BootstrapView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.page,
      body: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accent,
          ),
        ),
      ),
    );
  }
}
