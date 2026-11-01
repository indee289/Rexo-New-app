import 'dart:io';

import 'package:excel/excel.dart';

import '../core/formatters.dart';
import '../data/models.dart';
import '../data/repository.dart';
import 'exports.dart';

/// On-device .xlsx stock export. Nine columns, none of them money.
class ExcelExport {
  ExcelExport._();

  static const List<String> _headersEn = [
    'S.No',
    'Item Name',
    'Category',
    'Brand',
    'Model',
    'Quantity',
    'Minimum Stock',
    'Status',
    'Last Updated',
  ];

  static Future<File> build(AppRepo repo) async {
    final s = repo.s;
    final excel = Excel.createExcel();
    const sheetName = 'Stock';
    excel.rename(excel.getDefaultSheet() ?? 'Sheet1', sheetName);
    final sheet = excel[sheetName];

    sheet.appendRow([for (final h in _headersEn) TextCellValue(h)]);

    final items = repo.filtered(const StockFilter());
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      sheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue(it.name),
        TextCellValue(repo.categoryName(it.categoryId)),
        TextCellValue(it.brand ?? ''),
        TextCellValue(it.model ?? ''),
        IntCellValue(it.quantity),
        IntCellValue(it.minStock),
        TextCellValue(statusLabel(it.status, s)),
        TextCellValue(Fmt.dateTime(it.updatedAt)),
      ]);
    }

    final headerStyle = CellStyle(bold: true);
    for (var c = 0; c < _headersEn.length; c++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .cellStyle = headerStyle;
    }

    const widths = <double>[6, 34, 16, 14, 16, 10, 14, 12, 20];
    for (var c = 0; c < widths.length; c++) {
      sheet.setColumnWidth(c, widths[c]);
    }

    final bytes = excel.encode() ?? <int>[];
    return ExportFiles.write(
      'StockSaathi_Stock_${Fmt.fileStamp()}.xlsx',
      bytes,
    );
  }
}
