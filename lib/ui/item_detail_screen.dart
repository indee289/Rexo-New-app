import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/icons.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/photo_store.dart';
import '../data/repository.dart';
import 'actions.dart';
import 'item_form_screen.dart';
import 'widgets/common.dart';

class ItemDetailScreen extends StatelessWidget {
  const ItemDetailScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepo>();
    final s = repo.s;
    final item = repo.itemById(itemId);

    if (item == null) {
      // Deleted while open.
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(icon: AppIcons.stock, message: s.noItems),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: s.edit,
            icon: const Icon(AppIcons.edit),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ItemFormScreen(item: item)),
            ),
          ),
          IconButton(
            tooltip: s.delete,
            icon: const Icon(AppIcons.delete),
            onPressed: () async {
              final yes = await confirm(
                context,
                title: s.deleteConfirm,
                detail: item.name,
                yes: s.delete,
                cancel: s.cancel,
              );
              if (!yes) return;
              await repo.deleteItem(item.id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
        children: [
          _header(repo, item, s),
          const SizedBox(height: 14),
          _quantityCard(context, repo, item, s),
          const SizedBox(height: 18),
          SectionTitle(icon: AppIcons.history, text: s.history),
          _HistoryList(itemId: item.id),
        ],
      ),
    );
  }

  Widget _header(AppRepo repo, Item item, S s) {
    final cat = repo.categoryById(item.categoryId);
    final chips = <(IconData, String)>[
      (AppIcons.category, cat?.name(s) ?? ''),
      if ((item.brand ?? '').isNotEmpty) (AppIcons.brand, item.brand!),
      if ((item.model ?? '').isNotEmpty) (AppIcons.model, item.model!),
      if ((item.location ?? '').isNotEmpty) (AppIcons.shelf, item.location!),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Thumb(
              icon: AppIcons.forCategory(cat?.iconKey),
              file: PhotoStore.file(item.photoPath),
              size: 72,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in chips)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(c.$1, size: 13, color: AppTheme.muted),
                              const SizedBox(width: 4),
                              Text(
                                c.$2,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if ((item.note ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      item.note!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quantityCard(
    BuildContext context,
    AppRepo repo,
    Item item,
    S s,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.quantity}',
                  style: TextStyle(
                    fontSize: 46,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: statusFg(item.status),
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: StatusPill(
                    status: item.status,
                    label: statusLabel(item.status, s),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(
                        AppIcons.lowStock,
                        size: 15,
                        color: AppTheme.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${item.minStock}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.ok,
                      minimumSize: const Size.fromHeight(
                        AppTheme.qtyButtonHeight,
                      ),
                    ),
                    onPressed: () =>
                        changeStock(context, repo, item, isIn: true),
                    icon: const Icon(AppIcons.stockIn),
                    label: Text(s.stockIn),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.low,
                      minimumSize: const Size.fromHeight(
                        AppTheme.qtyButtonHeight,
                      ),
                    ),
                    onPressed: item.quantity > 0
                        ? () => changeStock(context, repo, item, isIn: false)
                        : null,
                    icon: const Icon(AppIcons.stockOut),
                    label: Text(s.stockOut),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.itemId});

  final String itemId;

  Future<(List<Movement>, Set<String>)> _load(AppRepo repo) async {
    final movements = await repo.movementsForItem(itemId);
    final reversed = await repo.reversedMovementIds(itemId);
    return (movements, reversed);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepo>();
    final s = repo.s;
    final item = repo.itemById(itemId);

    return FutureBuilder<(List<Movement>, Set<String>)>(
      // Refetch whenever this item changes.
      key: ValueKey('${item?.updatedAt}-${item?.quantity}'),
      future: _load(repo),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final movements = snap.data!.$1;
        final reversed = snap.data!.$2;
        if (movements.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: Center(
                child: Text(
                  s.noHistory,
                  style: const TextStyle(color: AppTheme.muted, fontSize: 15),
                ),
              ),
            ),
          );
        }

        return Card(
          child: Column(
            children: [
              for (var i = 0; i < movements.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _row(context, repo, s, movements[i], reversed),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _row(
    BuildContext context,
    AppRepo repo,
    S s,
    Movement m,
    Set<String> reversed,
  ) {
    final isIn = m.isIn;
    final color = isIn ? AppTheme.ok : AppTheme.low;
    final alreadyUndone = reversed.contains(m.id);
    final isUndo = m.reversesMovementId != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isIn ? AppTheme.okBg : AppTheme.lowBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isIn ? AppIcons.trendUp : AppIcons.trendDown,
              size: 17,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.reason.label(s),
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  Fmt.dateTime(m.occurredAt),
                  style: const TextStyle(fontSize: 13, color: AppTheme.muted),
                ),
                if ((m.note ?? '').isNotEmpty)
                  Text(
                    m.note!,
                    style: const TextStyle(fontSize: 13, color: AppTheme.muted),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Fmt.signed(m.delta),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                '= ${m.resultingQuantity}',
                style: const TextStyle(fontSize: 12.5, color: AppTheme.muted),
              ),
            ],
          ),
          if (!alreadyUndone && !isUndo)
            IconButton(
              tooltip: s.undo,
              icon: const Icon(AppIcons.undo, size: 19),
              onPressed: () async {
                final yes = await confirm(
                  context,
                  title: s.undoConfirm,
                  detail: '${m.reason.label(s)}  ${Fmt.signed(m.delta)}',
                  yes: s.undo,
                  cancel: s.cancel,
                  destructive: false,
                );
                if (!yes) return;
                try {
                  await repo.undoMovement(m);
                  if (context.mounted) showSnack(context, s.done);
                } on NotEnoughStock catch (e) {
                  if (context.mounted) {
                    showSnack(context, '${s.notEnough} (${e.available})');
                  }
                }
              },
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}
