import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/icons.dart';
import '../data/models.dart';
import '../data/repository.dart';
import 'actions.dart';
import 'item_detail_screen.dart';
import 'widgets/common.dart';
import 'widgets/item_tile.dart';

/// Out of stock first, then low stock, most urgent at the top.
class LowStockScreen extends StatelessWidget {
  const LowStockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepo>();
    final s = repo.s;
    final all = repo.lowStockItems;
    final outItems = all.where((i) => i.status == StockStatus.out).toList();
    final lowItems = all.where((i) => i.status == StockStatus.low).toList();

    return Scaffold(
      appBar: AppBar(title: Text('${s.low} / ${s.out}')),
      body: all.isEmpty
          ? EmptyState(icon: AppIcons.statusOk, message: s.allGood)
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 110),
              children: [
                if (outItems.isNotEmpty) ...[
                  SectionTitle(
                    icon: AppIcons.statusOut,
                    text: '${s.out}  ·  ${outItems.length}',
                  ),
                  _group(context, repo, outItems),
                  const SizedBox(height: 20),
                ],
                if (lowItems.isNotEmpty) ...[
                  SectionTitle(
                    icon: AppIcons.statusLow,
                    text: '${s.low}  ·  ${lowItems.length}',
                  ),
                  _group(context, repo, lowItems),
                ],
              ],
            ),
    );
  }

  Widget _group(BuildContext context, AppRepo repo, List<Item> items) {
    final s = repo.s;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ItemTile(
              item: items[i],
              s: s,
              categoryIconKey:
                  repo.categoryById(items[i].categoryId)?.iconKey ?? 'other',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ItemDetailScreen(itemId: items[i].id),
                ),
              ),
              onPlus: () => changeStock(context, repo, items[i], isIn: true),
            ),
          ],
        ],
      ),
    );
  }
}
