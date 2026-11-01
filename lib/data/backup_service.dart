import 'dart:convert';
import 'dart:io';

import '../core/formatters.dart';
import '../services/exports.dart';
import 'db.dart';
import 'repository.dart';

class BackupResult {
  const BackupResult(this.ok, {this.itemCount = 0, this.reason});
  final bool ok;
  final int itemCount;
  final String? reason;
}

/// Full local backup as a single JSON file the owner can keep anywhere.
///
/// Photos are not included: they would turn a small shareable file into tens of
/// megabytes. A restored backup keeps every item, movement, category, and
/// setting, and item photos simply come back empty.
class BackupService {
  BackupService._();

  static const String _magic = 'stocksaathi-backup';

  static Future<File> create(AppRepo repo) async {
    final db = repo.database;
    final payload = <String, Object?>{
      'format': _magic,
      'schema': AppDb.schemaVersion,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'categories': await db.query('categories'),
      'items': await db.query('items'),
      'movements': await db.query('stock_movements'),
      'settings': await db.query('settings'),
    };
    final bytes = utf8.encode(jsonEncode(payload));
    return ExportFiles.write(
      'StockSaathi_Backup_${Fmt.fileStamp()}.json',
      bytes,
    );
  }

  /// Replaces all local data. The Sheet connection is dropped on purpose: the
  /// restored ledger would otherwise re-append every movement and duplicate
  /// the History tab.
  static Future<BackupResult> restore(AppRepo repo, File file) async {
    Map<String, Object?> payload;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) {
        return const BackupResult(false, reason: 'format');
      }
      payload = decoded;
    } catch (_) {
      return const BackupResult(false, reason: 'format');
    }

    if (payload['format'] != _magic) {
      return const BackupResult(false, reason: 'format');
    }
    final schema = payload['schema'];
    if (schema is! int || schema > AppDb.schemaVersion) {
      return const BackupResult(false, reason: 'version');
    }

    final categories = _rows(payload['categories']);
    final items = _rows(payload['items']);
    final movements = _rows(payload['movements']);
    final settings = _rows(payload['settings']);
    if (categories.isEmpty) {
      return const BackupResult(false, reason: 'format');
    }

    final db = repo.database;
    try {
      await db.transaction((txn) async {
        await txn.delete('stock_movements');
        await txn.delete('items');
        await txn.delete('categories');
        await txn.delete('settings');
        for (final r in categories) {
          await txn.insert('categories', r);
        }
        for (final r in items) {
          // Photos are not in the backup, so drop stale paths.
          await txn.insert('items', {...r, 'photo_path': null});
        }
        for (final r in movements) {
          await txn.insert('stock_movements', r);
        }
        for (final r in settings) {
          await txn.insert('settings', r);
        }
      });
    } catch (_) {
      return const BackupResult(false, reason: 'write');
    }

    await repo.clearSyncConnection();
    await repo.reload();
    return BackupResult(true, itemCount: items.length);
  }

  static List<Map<String, Object?>> _rows(Object? raw) {
    if (raw is! List) return const [];
    final out = <Map<String, Object?>>[];
    for (final e in raw) {
      if (e is Map) {
        out.add(e.map((k, v) => MapEntry(k.toString(), v)));
      }
    }
    return out;
  }
}
