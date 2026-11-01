import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/icons.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/repository.dart';
import 'actions.dart';
import 'item_detail_screen.dart';
import 'item_form_screen.dart';
import 'low_stock_screen.dart';
import 'settings_screen.dart';
import 'stock_list_screen.dart';
import 'widgets/common.dart';
import 'widgets/item_tile.dart';
import 'widgets/sync_chip.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void _openList(BuildContext context, StockFilter filter, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StockListScreen(initialFilter: filter, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepo>();
    final s = repo.s;
    final t = repo.totals;
    final shop = repo.shopName.trim();
    final low = repo.lowStockItems;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.appName),
            if (shop.isNotEmpty)
              Text(
                shop,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.muted,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: s.settings,
            icon: const Icon(AppIcons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: repo.items.isEmpty
          ? EmptyState(
              icon: AppIcons.addItem,
              message: s.noItems,
              action: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(220, AppTheme.buttonHeight),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ItemFormScreen()),
                ),
                icon: const Icon(AppIcons.add),
                label: Text(s.addItem),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 110),
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: SyncChip(),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        icon: AppIcons.stock,
                        value: t.itemCount,
                        label: s.items,
                        color: AppTheme.primary,
                        onTap: () => _openList(
                          context,
                          const StockFilter(),
                          s.navStock,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatTile(
                        icon: AppIcons.quantity,
                        value: t.totalQuantity,
                        label: s.totalQty,
                        color: AppTheme.text,
                        onTap: () => _openList(
                          context,
                          const StockFilter(sort: StockSort.quantity),
                          s.totalQty,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        icon: AppIcons.statusLow,
                        value: t.lowCount,
                        label: s.low,
                        color: AppTheme.low,
                        onTap: () => _openList(
                          context,
                          const StockFilter(status: StockStatus.low),
                          s.low,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatTile(
                        icon: AppIcons.statusOut,
                        value: t.outCount,
                        label: s.out,
                        color: AppTheme.out,
                        onTap: () => _openList(
                          context,
                          const StockFilter(status: StockStatus.out),
                          s.out,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          AppIcons.calendar,
                          size: 20,
                          color: AppTheme.muted,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          s.today,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        _todayChip(
                          AppIcons.trendUp,
                          s.inLabel,
                          t.todayIn,
                          AppTheme.ok,
                          AppTheme.okBg,
                        ),
                        const SizedBox(width: 8),
                        _todayChip(
                          AppIcons.trendDown,
                          s.outLabel,
                          t.todayOut,
                          AppTheme.low,
                          AppTheme.lowBg,
                        ),
                      ],
                    ),
                  ),
                ),
                if (low.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  SectionTitle(
                    icon: AppIcons.lowStock,
                    text: '${s.low} / ${s.out}',
                    trailing: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LowStockScreen(),
                        ),
                      ),
                      child: Text(s.seeAll),
                    ),
                  ),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (var i = 0; i < low.length && i < 5; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          ItemTile(
                            item: low[i],
                            s: s,
                            categoryIconKey: repo
                                    .categoryById(low[i].categoryId)
                                    ?.iconKey ??
                                'other',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ItemDetailScreen(itemId: low[i].id),
                              ),
                            ),
                            onPlus: () =>
                                changeStock(context, repo, low[i], isIn: true),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _todayChip(
    IconData icon,
    String label,
    int value,
    Color fg,
    Color bg,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
