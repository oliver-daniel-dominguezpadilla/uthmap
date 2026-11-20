import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/navigation_controller.dart';
import 'detail_screen.dart';
import 'theme.dart';
import 'widgets/primitives.dart';

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({
    super.key,
    required this.controller,
    this.initialQuery = '',
  });

  final NavigationController controller;
  final String initialQuery;

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  late final TextEditingController _search;
  final FocusNode _focus = FocusNode();
  BuildingCategory? _category;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.initialQuery);
    _search.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _search
      ..removeListener(_onTextChanged)
      ..dispose();
    _focus.dispose();
    super.dispose();
  }

  List<Building> get _results {
    final query = _search.text;
    return widget.controller.buildings
        .where(
          (building) =>
              (_category == null || building.category == _category) &&
              building.matches(query),
        )
        .toList(growable: false);
  }

  void _open(Building building) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            DetailScreen(building: building, controller: widget.controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Scaffold(
      backgroundColor: AppColors.page,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Row(
                children: [
                  RoundIconButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Volver',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Directorio',
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: AppColors.ink,
                    ),
                  ),
                  const Spacer(),
                  TinyLabel('${results.length} edificios'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: UthSearchField(
                controller: _search,
                focusNode: _focus,
                hint: 'Busca por nombre, dependencia o etiqueta...',
              ),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _FilterPill(
                    label: 'Todas',
                    selected: _category == null,
                    onTap: () => setState(() => _category = null),
                  ),
                  for (final category in BuildingCategory.values) ...[
                    const SizedBox(width: 6),
                    _FilterPill(
                      label: category.label,
                      selected: _category == category,
                      onTap: () => setState(() => _category = category),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: results.isEmpty
                  ? _EmptyState(
                      query: _search.text,
                      onClear: () => setState(() {
                        _search.clear();
                        _category = null;
                      }),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
                      children: _category == null
                          ? _grouped(results)
                          : results
                                .map((building) => _tile(building))
                                .toList(growable: false),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _grouped(List<Building> results) {
    final children = <Widget>[];
    for (final category in BuildingCategory.values) {
      final items = results
          .where((building) => building.category == category)
          .toList(growable: false);
      if (items.isEmpty) continue;
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 4),
          child: TinyLabel(category.label),
        ),
      );
      children.addAll(items.map(_tile));
    }
    return children;
  }

  Widget _tile(Building building) {
    final distance = widget.controller.nearestEntranceTo(building)?.distanceM;
    final isTarget = widget.controller.target?.id == building.id;
    return InkWell(
      onTap: () => _open(building),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.lineSoft)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 64,
                height: 64,
                child: building.photoAsset == null
                    ? const ColoredBox(color: AppColors.muted)
                    : Image.asset(
                        building.photoAsset!,
                        fit: BoxFit.cover,
                        cacheWidth: 192,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    building.code,
                    style: AppTheme.mono(
                      size: 10,
                      weight: FontWeight.w500,
                      color: AppColors.accent,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    building.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    building.areaLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.dim),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isTarget)
              Text(
                'DESTINO',
                style: AppTheme.mono(
                  size: 10,
                  weight: FontWeight.w700,
                  color: AppColors.accent,
                  letterSpacing: 1,
                ),
              )
            else
              Text(
                distance == null ? '—' : '${distance.round()} m',
                style: AppTheme.mono(size: 12, color: AppColors.dim),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.dim),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: kFast,
        curve: kEase,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.page,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? AppColors.ink : AppColors.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppColors.dim,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.query, required this.onClear});

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 28, color: AppColors.dim),
            const SizedBox(height: 12),
            Text(
              query.trim().isEmpty
                  ? 'No hay edificios en esta categoría.'
                  : 'Sin resultados para «${query.trim()}».',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.dim),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onClear,
              child: const Text(
                'Limpiar búsqueda',
                style: TextStyle(fontSize: 12, color: AppColors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
