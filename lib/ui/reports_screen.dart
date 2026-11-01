import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/icons.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../services/export_excel.dart';
import '../services/export_pdf.dart';
import '../services/exports.dart';
import 'widgets/common.dart';

enum _Range { today, week, month, custom }

enum _Grouping { daily, monthly }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _Range _range = _Range.month;
  _Grouping _grouping = _Grouping.daily;
  DateTimeRange? _custom;
  bool _busy = false;

  (int, int) _bounds() {
    final now = DateTime.now();
    switch (_range) {
      case _Range.today:
        return (Fmt.startOfDay(now), Fmt.endOfDay(now));
      case _Range.week:
        final from = now.subtract(const Duration(days: 6));
        return (Fmt.startOfDay(from), Fmt.endOfDay(now));
      case _Range.month:
        return (
          Fmt.startOfDay(DateTime(now.year, now.month, 1)),
          Fmt.endOfDay(now),
        );
      case _Range.custom:
        final r = _custom;
        if (r == null) return (Fmt.startOfDay(now), Fmt.endOfDay(now));
        return (Fmt.startOfDay(r.start), Fmt.endOfDay(r.end));
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepo>();
    final s = repo.s;
    final (from, to) = _bounds();

    return Scaffold(
      appBar: AppBar(title: Text(s.navReports)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 110),
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _rangeChip(_Range.today, s.today),
                _rangeChip(_Range.week, s.week),
                _rangeChip(_Range.month, s.month),
                _rangeChip(_Range.custom, _customLabel(s.custom)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FutureBuilder<List<MovementEntry>>(
            key: ValueKey('$from-$to-${repo.totals.totalQuantity}'),
            future: repo.history(fromMs: from, toMs: to, limit: 5000),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final entries = snap.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _summaryCard(repo, entries),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<_Grouping>(
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                              value: _Grouping.daily,
                              label: Text(s.dayWise),
                              icon: const Icon(AppIcons.calendar, size: 16),
                            ),
                            ButtonSegment(
                              value: _Grouping.monthly,
                              label: Text(s.monthWise),
                              icon: const Icon(AppIcons.history, size: 16),
                            ),
                          ],
                          selected: {_grouping},
                          onSelectionChanged: (v) =>
                              setState(() => _grouping = v.first),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (entries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: EmptyState(
                        icon: AppIcons.history,
                        message: s.noHistory,
                      ),
                    )
                  else
                    _buckets(repo, entries),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          SectionTitle(icon: AppIcons.pdf, text: '${s.pdf} / ${s.excel}'),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _exportPdf(repo),
                  icon: const Icon(AppIcons.pdf),
                  label: Text(s.pdf),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _exportExcel(repo),
                  icon: const Icon(AppIcons.excel),
                  label: Text(s.excel),
                ),
              ),
            ],
          ),
          if (_busy)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Center(
                child: Text(
                  s.making,
                  style: const TextStyle(color: AppTheme.muted),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _customLabel(String fallback) {
    final r = _custom;
    if (r == null) return fallback;
    return '${Fmt.dayLabel(r.start)} - ${Fmt.dayLabel(r.end)}';
  }

  Widget _rangeChip(_Range value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _range == value,
        onSelected: (_) async {
          if (value == _Range.custom) {
            final now = DateTime.now();
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(now.year - 3),
              lastDate: now,
              initialDateRange: _custom,
            );
            if (picked == null) return;
            setState(() {
              _custom = picked;
              _range = value;
            });
            return;
          }
          setState(() => _range = value);
        },
      ),
    );
  }

  Widget _summaryCard(AppRepo repo, List<MovementEntry> entries) {
    final s = repo.s;
    var totalIn = 0;
    var totalOut = 0;
    final byReason = <MovementReason, int>{};
    for (final e in entries) {
      final d = e.movement.delta;
      if (d > 0) {
        totalIn += d;
      } else {
        totalOut += -d;
      }
      byReason.update(
        e.movement.reason,
        (v) => v + d.abs(),
        ifAbsent: () => d.abs(),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _bigNumber(
                    AppIcons.trendUp,
                    s.inLabel,
                    totalIn,
                    AppTheme.ok,
                  ),
                ),
                Container(width: 1, height: 44, color: AppTheme.line),
                Expanded(
                  child: _bigNumber(
                    AppIcons.trendDown,
                    s.outLabel,
                    totalOut,
                    AppTheme.low,
                  ),
                ),
              ],
            ),
            if (byReason.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in byReason.entries)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${entry.key.label(s)}  ${entry.value}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.muted,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bigNumber(IconData icon, String label, int value, Color color) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppTheme.muted),
        ),
      ],
    );
  }

  Widget _buckets(AppRepo repo, List<MovementEntry> entries) {
    final groups = <String, List<int>>{};
    final order = <String>[];
    for (final e in entries) {
      final when = Fmt.local(e.movement.occurredAt);
      final key = _grouping == _Grouping.daily
          ? Fmt.dayLabel(when)
          : Fmt.monthLabel(when);
      if (!groups.containsKey(key)) {
        groups[key] = [0, 0];
        order.add(key);
      }
      final d = e.movement.delta;
      if (d > 0) {
        groups[key]![0] += d;
      } else {
        groups[key]![1] += -d;
      }
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < order.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 13,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      order[i],
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '+${groups[order[i]]![0]}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ok,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    '-${groups[order[i]]![1]}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.low,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _exportPdf(AppRepo repo) async {
    setState(() => _busy = true);
    try {
      final file = await PdfExport.build(repo);
      await ExportFiles.share(file, subject: repo.shopName);
    } catch (_) {
      if (mounted) showSnack(context, repo.s.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportExcel(AppRepo repo) async {
    setState(() => _busy = true);
    try {
      final file = await ExcelExport.build(repo);
      await ExportFiles.share(file, subject: repo.shopName);
    } catch (_) {
      if (mounted) showSnack(context, repo.s.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
