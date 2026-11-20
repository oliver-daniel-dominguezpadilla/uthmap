import 'package:flutter/material.dart';

import 'data/catalog_repository.dart';
import 'data/models.dart';
import 'state/navigation_controller.dart';
import 'ui/navigation_screen.dart';
import 'ui/theme.dart';
import 'ui/welcome_screen.dart';

class UthMapApp extends StatefulWidget {
  const UthMapApp({super.key, required this.repository, this.demoMode = false});

  final CatalogRepository repository;

  /// Arranca directo en el mapa con el catálogo incluido (útil para capturas
  /// y para evaluar la navegación sin pasar por la sincronización).
  final bool demoMode;

  @override
  State<UthMapApp> createState() => _UthMapAppState();
}

class _UthMapAppState extends State<UthMapApp> {
  Catalog? _catalog;
  NavigationController? _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
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
        _controller = NavigationController(catalog: local);
      }
    });
  }

  void _start(Catalog catalog) {
    setState(() {
      _catalog = catalog;
      _controller?.dispose();
      _controller = NavigationController(catalog: catalog);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return MaterialApp(
      title: 'UthMap',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: _loading
          ? const _BootstrapView()
          : (controller == null || _catalog == null)
          ? WelcomeScreen(repository: widget.repository, onReady: _start)
          : NavigationScreen(controller: controller),
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
