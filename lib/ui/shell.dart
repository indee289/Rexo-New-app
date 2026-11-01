import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/icons.dart';
import '../data/repository.dart';
import 'dashboard_screen.dart';
import 'item_form_screen.dart';
import 'low_stock_screen.dart';
import 'reports_screen.dart';
import 'stock_list_screen.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepo>();
    final s = repo.s;
    final lowBadge = repo.totals.lowCount + repo.totals.outCount;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          DashboardScreen(),
          StockListScreen(),
          LowStockScreen(),
          ReportsScreen(),
        ],
      ),
      floatingActionButton: _index <= 1
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ItemFormScreen()),
              ),
              icon: const Icon(AppIcons.add),
              label: Text(s.addItem),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(AppIcons.home),
            label: s.navHome,
          ),
          NavigationDestination(
            icon: const Icon(AppIcons.stock),
            label: s.navStock,
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: lowBadge > 0,
              label: Text('$lowBadge'),
              child: const Icon(AppIcons.lowStock),
            ),
            label: s.navLow,
          ),
          NavigationDestination(
            icon: const Icon(AppIcons.reports),
            label: s.navReports,
          ),
        ],
      ),
    );
  }
}
