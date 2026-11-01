import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/formatters.dart';
import '../core/strings.dart';
import '../data/models.dart';
import '../data/repository.dart';
import 'exports.dart';

/// On-device PDF stock report. No network, no server, and no money column.
class PdfExport {
  PdfExport._();

  /// Fetched by CI into assets/fonts. Missing font degrades to the built-in
  /// Helvetica, which cannot draw Devanagari, so Hindi names would show as
  /// blanks rather than crashing the export.
  static Future<pw.ThemeData?> _theme() async {
    try {
      final regular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf'),
      );
      final bold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSansDevanagari-Bold.ttf'),
      );
      return pw.ThemeData.withFont(base: regular, bold: bold);
    } catch (_) {
      return null;
    }
  }

  static Future<File> build(AppRepo repo) async {
    final s = repo.s;
    final theme = await _theme();
    final doc = pw.Document(theme: theme);

    final items = repo.filtered(const StockFilter());
    final totals = repo.totals;
    final shop = repo.shopName.trim().isEmpty ? s.appName : repo.shopName.trim();
    final generated = Fmt.dateTime(DateTime.now().millisecondsSinceEpoch);

    final rows = <List<String>>[];
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      rows.add([
        '${i + 1}',
        it.name,
        repo.categoryName(it.categoryId),
        it.brand ?? '',
        it.model ?? '',
        '${it.quantity}',
        statusLabel(it.status, s),
      ]);
    }

    final shortItems = repo.lowStockItems;
    final shortRows = <List<String>>[];
    for (var i = 0; i < shortItems.length; i++) {
      final it = shortItems[i];
      shortRows.add([
        '${i + 1}',
        it.name,
        it.model ?? '',
        '${it.quantity}',
        '${it.minStock}',
        statusLabel(it.status, s),
      ]);
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (ctx) => ctx.pageNumber == 1
            ? pw.SizedBox()
            : pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(
                  shop,
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            '${s.appName}   ${ctx.pageNumber}/${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (ctx) => [
          pw.Text(
            shop,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            '${s.navStock}  ·  $generated',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 14),
          _summary(s, totals),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: [
              '#',
              s.name,
              s.category,
              s.brand,
              s.model,
              s.qty,
              _statusHeader(s),
            ],
            data: rows,
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
            headerStyle: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellStyle: const pw.TextStyle(fontSize: 9.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(24),
              1: const pw.FlexColumnWidth(3.4),
              2: const pw.FlexColumnWidth(1.7),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.7),
              5: const pw.FixedColumnWidth(38),
              6: const pw.FixedColumnWidth(52),
            },
            cellAlignments: {
              0: pw.Alignment.center,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.center,
            },
          ),
          if (shortRows.isNotEmpty) ...[
            pw.SizedBox(height: 22),
            pw.Text(
              '${s.low} / ${s.out}',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['#', s.name, s.model, s.qty, s.minQty, _statusHeader(s)],
              data: shortRows,
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
              headerStyle: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              cellStyle: const pw.TextStyle(fontSize: 9.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(24),
                1: const pw.FlexColumnWidth(3.4),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FixedColumnWidth(38),
                4: const pw.FixedColumnWidth(44),
                5: const pw.FixedColumnWidth(52),
              },
              cellAlignments: {
                0: pw.Alignment.center,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.center,
              },
            ),
          ],
        ],
      ),
    );

    final bytes = await doc.save();
    return ExportFiles.write(
      'StockSaathi_Stock_${Fmt.fileStamp()}.pdf',
      bytes,
    );
  }

  static String _statusHeader(S s) => s.lang == 'hi' ? 'हालत' : 'Status';

  static pw.Widget _summary(S s, Totals t) {
    pw.Widget box(String label, String value) => pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.only(right: 8),
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  label,
                  style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  value,
                  style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
        );

    return pw.Row(
      children: [
        box(s.items, '${t.itemCount}'),
        box(s.totalQty, '${t.totalQuantity}'),
        box(s.low, '${t.lowCount}'),
        box(s.out, '${t.outCount}'),
      ],
    );
  }
}
