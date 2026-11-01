import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/icons.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/repository.dart';
import 'actions.dart';
import 'item_detail_screen.dart';
import 'widgets/common.dart';
import 'widgets/item_tile.dart';

class StockListScreen extends StatefulWidget {
  const StockListScreen({super.key, this.initialFilter, this.title});

  final StockFilter? initialFilter;
  final String? title;

  @override
  State<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends State<StockListScreen> {
  late StockFilter _filter = widget.initialFilter ?? const StockFilter();
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.text = _filter.query;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _set(StockFilter f) => setState(() => _filter = f);

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepo>();
    final s = repo.s;
    final items = repo.filtered(_filter);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? s.navStock),
        actions: [
          IconButton(
            tooltip: s.sortName,
            icon: const Icon(AppIcons.sort),
            onPressed: () => _pickSort(repo),
          ),
          IconButton(
            tooltip: s.category,
            icon: const Icon(AppIcons.filter),
            onPressed: () => _openFilters(repo),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onChanged: (v) => _set(_filter.copyWith(query: v)),
              decoration: InputDecoration(
                hintText: s.search,
                prefixIcon: const Icon(AppIcons.search, size: 20),
                suffixIcon: _filter.query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(AppIcons.clear, size: 20),
                        onPressed: () {
                          _search.clear();
                          _set(_filter.copyWith(query: ''));
                        },
                      ),
              ),
            ),
          ),
          if (_filter.isActive) _chips(repo),
          Expanded(
            child: items.isEmpty
                ? EmptyState(
                    icon: AppIcons.stock,
                    message: repo.items.isEmpty ? s.noItems : s.noResults,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final item = items[i];
                      return ItemTile(
                        item: item,
                        s: s,
                        categoryIconKey:
                            repo.categoryById(item.categoryId)?.iconKey ?? 'other',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ItemDetailScreen(itemId: item.id),
                          ),
                        ),
                        onPlus: () => changeStock(context, repo, item, isIn: true),
                        onMinus: () =>
                            changeStock(context, repo, item, isIn: false),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chips(AppRepo repo) {
    final s = repo.s;
    final chips = <Widget>[];

    for (final id in _filter.categoryIds) {
      chips.add(
        _removable(repo.categoryName(id), () {
          final next = {..._filter.categoryIds}..remove(id);
          _set(_filter.copyWith(categoryIds: next));
        }),
      );
    }
    if (_filter.brand != null) {
      chips.add(
        _removable(_filter.brand!, () => _set(_filter.copyWith(clearBrand: true))),
      );
    }
    if (_filter.model != null) {
      chips.add(
        _removable(_filter.model!, () => _set(_filter.copyWith(clearModel: true))),
      );
    }
    if (_filter.status != null) {
      chips.add(
        _removable(
          statusLabel(_filter.status!, s),
          () => _set(_filter.copyWith(clearStatus: true)),
        ),
      );
    }
    if (chips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          ...chips,
          TextButton(
            onPressed: () => _set(
              StockFilter(query: _filter.query, sort: _filter.sort),
            ),
            child: Text(s.clear),
          ),
        ],
      ),
    );
  }

  Widget _removable(String label, VoidCallback onRemove) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InputChip(
          label: Text(label),
          onDeleted: onRemove,
          deleteIcon: const Icon(AppIcons.clear, size: 16),
        ),
      );

  Future<void> _pickSort(AppRepo repo) async {
    final s = repo.s;
    final picked = await showModalBottomSheet<StockSort>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            for (final entry in <(StockSort, String, IconData)>[
              (StockSort.name, s.sortName, AppIcons.sort),
              (StockSort.quantity, s.sortQty, AppIcons.quantity),
              (StockSort.recent, s.sortRecent, AppIcons.history),
            ])
              ListTile(
                leading: Icon(entry.$3),
                title: Text(entry.$2),
                trailing: _filter.sort == entry.$1
                    ? const Icon(AppIcons.save, color: AppTheme.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, entry.$1),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) _set(_filter.copyWith(sort: picked));
  }

  Future<void> _openFilters(AppRepo repo) async {
    final s = repo.s;
    var draft = _filter;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 18,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                SectionTitle(icon: AppIcons.category, text: s.category),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in repo.categories)
                      FilterChip(
                        avatar: Icon(AppIcons.forCategory(c.iconKey), size: 16),
                        label: Text(c.name(s)),
                        selected: draft.categoryIds.contains(c.id),
                        onSelected: (on) => setSheet(() {
                          final next = {...draft.categoryIds};
                          if (on) {
                            next.add(c.id);
                          } else {
                            next.remove(c.id);
                          }
                          draft = draft.copyWith(categoryIds: next);
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                SectionTitle(icon: AppIcons.statusOk, text: s.navStock),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final st in StockStatus.values)
                      FilterChip(
                        avatar: Icon(statusIcon(st), size: 16, color: statusFg(st)),
                        label: Text(statusLabel(st, s)),
                        selected: draft.status == st,
                        onSelected: (on) => setSheet(() {
                          draft = on
                              ? draft.copyWith(status: st)
                              : draft.copyWith(clearStatus: true);
                        }),
                      ),
                  ],
                ),
                if (repo.brands.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  SectionTitle(icon: AppIcons.brand, text: s.brand),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final b in repo.brands)
                        FilterChip(
                          label: Text(b),
                          selected: draft.brand == b,
                          onSelected: (on) => setSheet(() {
                            draft = on
                                ? draft.copyWith(brand: b)
                                : draft.copyWith(clearBrand: true);
                          }),
                        ),
                    ],
                  ),
                ],
                if (repo.models.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  SectionTitle(icon: AppIcons.model, text: s.model),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in repo.models)
                        FilterChip(
                          label: Text(m),
                          selected: draft.model == m,
                          onSelected: (on) => setSheet(() {
                            draft = on
                                ? draft.copyWith(model: m)
                                : draft.copyWith(clearModel: true);
                          }),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: () {
                    _set(draft);
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(AppIcons.save),
                  label: Text(s.done),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {
                    _set(StockFilter(query: _filter.query, sort: _filter.sort));
                    Navigator.pop(ctx);
                  },
                  child: Text(s.clear),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
