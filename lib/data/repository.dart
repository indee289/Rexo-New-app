import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../core/formatters.dart';
import '../core/strings.dart';
import 'db.dart';
import 'models.dart';
import 'photo_store.dart';

class NotEnoughStock implements Exception {
  NotEnoughStock(this.available);
  final int available;
}

class DuplicateItem implements Exception {
  DuplicateItem(this.existing);
  final Item existing;
}

/// Single source of truth for the UI.
///
/// Items and categories are held in memory because the catalogue is small
/// (a few thousand rows at most), which keeps search and filtering instant and
/// keeps the SQL simple. Movements stay in the database and are queried on
/// demand, since they grow without bound.
class AppRepo extends ChangeNotifier {
  AppRepo._(this._db);

  final Database _db;

  List<Category> _categories = const [];
  List<Item> _items = const [];
  Map<String, String> _settings = const {};
  SyncState _sync = SyncState.disabled;
  Totals _totals = Totals.empty;

  /// Set by SheetsSync so a write can schedule a push without the data layer
  /// knowing anything about Google.
  void Function()? onDataChanged;

  List<Category> get categories => _categories;
  List<Item> get items => _items;
  SyncState get sync => _sync;
  Totals get totals => _totals;

  S get s => S.forCode(_settings['language'] ?? 'hi');
  String get languageCode => _settings['language'] ?? 'hi';
  String get shopName => _settings['shop_name'] ?? '';
  int get defaultMinStock => int.tryParse(_settings['default_min_stock'] ?? '5') ?? 5;
  bool get reminderEnabled => (_settings['reminder_enabled'] ?? '0') == '1';
  int get reminderHour => int.tryParse(_settings['reminder_hour'] ?? '20') ?? 20;
  int get reminderMinute => int.tryParse(_settings['reminder_minute'] ?? '0') ?? 0;
  String get deviceId => _settings['device_id'] ?? '';

  static Future<AppRepo> create() async {
    final db = await AppDb.open();
    final repo = AppRepo._(db);
    await repo.reload();
    return repo;
  }

  Future<void> reload() async {
    final catRows = await _db.query(
      'categories',
      where: 'deleted_at IS NULL',
      orderBy: 'sort_order ASC, name_en ASC',
    );
    final itemRows = await _db.query(
      'items',
      where: 'deleted_at IS NULL',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    final settingRows = await _db.query('settings');
    final syncRows = await _db.query('sync_state', where: 'id = 1');

    _categories = catRows.map(Category.fromRow).toList();
    _items = itemRows.map(Item.fromRow).toList();
    _settings = {
      for (final r in settingRows)
        (r['key'] as String): (r['value'] as String?) ?? '',
    };
    _sync = syncRows.isEmpty ? SyncState.disabled : SyncState.fromRow(syncRows.first);
    _totals = await _computeTotals();
    notifyListeners();
  }

  Future<Totals> _computeTotals() async {
    final todayStart = Fmt.startOfToday();
    final rows = await _db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN delta > 0 THEN delta ELSE 0 END), 0) AS t_in,
        COALESCE(SUM(CASE WHEN delta < 0 THEN -delta ELSE 0 END), 0) AS t_out
      FROM stock_movements
      WHERE occurred_at >= ?
      ''',
      [todayStart],
    );
    final tIn = (rows.first['t_in'] as int?) ?? 0;
    final tOut = (rows.first['t_out'] as int?) ?? 0;

    var qty = 0;
    var low = 0;
    var out = 0;
    for (final i in _items) {
      qty += i.quantity;
      switch (i.status) {
        case StockStatus.low:
          low++;
          break;
        case StockStatus.out:
          out++;
          break;
        case StockStatus.available:
          break;
      }
    }
    return Totals(
      itemCount: _items.length,
      totalQuantity: qty,
      lowCount: low,
      outCount: out,
      todayIn: tIn,
      todayOut: tOut,
    );
  }

  // ---------------------------------------------------------------- settings

  Future<void> setSetting(String key, String value) async {
    await _db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _settings = {..._settings, key: value};
    notifyListeners();
  }

  Future<void> setLanguage(String code) => setSetting('language', code);

  // -------------------------------------------------------------- categories

  Category? categoryById(String id) {
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  String categoryName(String id) {
    final c = categoryById(id);
    return c?.name(s) ?? '';
  }

  Category get fallbackCategory => _categories.firstWhere(
        (c) => c.id == 'other',
        orElse: () => _categories.first,
      );

  /// Adds a custom category. The owner types one name, used for both languages.
  Future<Category> addCategory(String name) async {
    final trimmed = name.trim();
    final existing = _categories.firstWhere(
      (c) =>
          c.nameEn.toLowerCase() == trimmed.toLowerCase() ||
          c.nameHi == trimmed,
      orElse: () => const Category(
        id: '',
        nameEn: '',
        nameHi: '',
        iconKey: 'other',
        isBuiltin: false,
        sortOrder: 0,
      ),
    );
    if (existing.id.isNotEmpty) return existing;

    final now = DateTime.now().millisecondsSinceEpoch;
    final cat = Category(
      id: AppDb.newId(),
      nameEn: trimmed,
      nameHi: trimmed,
      iconKey: 'other',
      isBuiltin: false,
      sortOrder: 500,
    );
    await _db.insert('categories', {
      ...cat.toRow(),
      'created_at': now,
      'updated_at': now,
    });
    _categories = [..._categories, cat]
      ..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.nameEn.compareTo(b.nameEn);
      });
    notifyListeners();
    return cat;
  }

  // ------------------------------------------------------------------- items

  Item? itemById(String id) {
    for (final i in _items) {
      if (i.id == id) return i;
    }
    return null;
  }

  List<String> get brands {
    final set = <String>{};
    for (final i in _items) {
      final b = (i.brand ?? '').trim();
      if (b.isNotEmpty) set.add(b);
    }
    final list = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<String> get models {
    final set = <String>{};
    for (final i in _items) {
      final m = (i.model ?? '').trim();
      if (m.isNotEmpty) set.add(m);
    }
    final list = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<Item> get lowStockItems {
    final list = _items
        .where((i) => i.status == StockStatus.low || i.status == StockStatus.out)
        .toList();
    list.sort((a, b) {
      // Out of stock first, then whichever is furthest below its minimum.
      final byStatus = a.status.index.compareTo(b.status.index);
      if (a.status != b.status) return -byStatus;
      return b.shortfall.compareTo(a.shortfall);
    });
    return list;
  }

  List<Item> filtered(StockFilter f) {
    final q = f.query.trim().toLowerCase();
    final terms = q.isEmpty ? const <String>[] : q.split(RegExp(r'\s+'));

    final result = _items.where((i) {
      if (f.categoryIds.isNotEmpty && !f.categoryIds.contains(i.categoryId)) {
        return false;
      }
      if (f.brand != null && (i.brand ?? '').trim() != f.brand) return false;
      if (f.model != null && (i.model ?? '').trim() != f.model) return false;
      if (f.status != null && i.status != f.status) return false;
      if (terms.isNotEmpty) {
        final blob = i.searchBlob;
        for (final t in terms) {
          if (!blob.contains(t)) return false;
        }
      }
      return true;
    }).toList();

    switch (f.sort) {
      case StockSort.name:
        result.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case StockSort.quantity:
        result.sort((a, b) {
          final byQty = a.quantity.compareTo(b.quantity);
          return byQty != 0
              ? byQty
              : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
      case StockSort.recent:
        result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
    }
    return result;
  }

  /// Case- and space-insensitive match on name + brand + model.
  Item? findDuplicate({
    required String name,
    String? brand,
    String? model,
    String? excludeId,
  }) {
    String norm(String? v) => (v ?? '').trim().toLowerCase();
    final n = norm(name);
    final b = norm(brand);
    final m = norm(model);
    if (n.isEmpty) return null;
    for (final i in _items) {
      if (i.id == excludeId) continue;
      if (norm(i.name) == n && norm(i.brand) == b && norm(i.model) == m) {
        return i;
      }
    }
    return null;
  }

  Future<Item> addItem({
    required String name,
    required String categoryId,
    String? brand,
    String? model,
    int openingQuantity = 0,
    int? minStock,
    String? photoPath,
    String? location,
    String? note,
  }) async {
    final dup = findDuplicate(name: name, brand: brand, model: model);
    if (dup != null) throw DuplicateItem(dup);

    final now = DateTime.now().millisecondsSinceEpoch;
    final item = Item(
      id: AppDb.newId(),
      name: name.trim(),
      categoryId: categoryId,
      brand: _orNull(brand),
      model: _orNull(model),
      quantity: 0,
      minStock: minStock ?? defaultMinStock,
      photoPath: photoPath,
      location: _orNull(location),
      note: _orNull(note),
      createdAt: now,
      updatedAt: now,
      deviceId: deviceId,
    );

    await _db.insert('items', item.toRow());
    _items = [..._items, item];

    if (openingQuantity > 0) {
      // Recorded as a movement so the ledger always explains the quantity.
      await _writeMovement(
        item: item,
        delta: openingQuantity,
        reason: MovementReason.opening,
        note: null,
      );
    } else {
      await _afterWrite();
    }
    return itemById(item.id) ?? item;
  }

  Future<void> updateItem(
    Item item, {
    required String name,
    required String categoryId,
    String? brand,
    String? model,
    required int minStock,
    String? photoPath,
    bool clearPhoto = false,
    String? location,
    String? note,
  }) async {
    final dup = findDuplicate(
      name: name,
      brand: brand,
      model: model,
      excludeId: item.id,
    );
    if (dup != null) throw DuplicateItem(dup);

    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = Item(
      id: item.id,
      name: name.trim(),
      categoryId: categoryId,
      brand: _orNull(brand),
      model: _orNull(model),
      quantity: item.quantity,
      minStock: minStock,
      photoPath: clearPhoto ? null : (photoPath ?? item.photoPath),
      location: _orNull(location),
      note: _orNull(note),
      createdAt: item.createdAt,
      updatedAt: now,
      deviceId: item.deviceId,
    );

    await _db.update(
      'items',
      updated.toRow(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
    if (clearPhoto && item.photoPath != null) {
      await PhotoStore.delete(item.photoPath);
    }
    _replaceInCache(updated);
    await _afterWrite();
  }

  /// Soft delete: the item leaves every list and export, its history stays.
  Future<void> deleteItem(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'items',
      {'deleted_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
    _items = _items.where((i) => i.id != id).toList();
    await _afterWrite();
  }

  // --------------------------------------------------------------- movements

  /// Applies a stock change. [delta] must be non-zero.
  ///
  /// Throws [NotEnoughStock] rather than ever storing a negative quantity.
  Future<Item> applyMovement({
    required String itemId,
    required int delta,
    required MovementReason reason,
    String? note,
    String? reversesMovementId,
  }) async {
    final item = itemById(itemId);
    if (item == null || delta == 0) {
      throw StateError('No such item, or zero delta');
    }
    if (item.quantity + delta < 0) {
      throw NotEnoughStock(item.quantity);
    }
    await _writeMovement(
      item: item,
      delta: delta,
      reason: reason,
      note: note,
      reversesMovementId: reversesMovementId,
    );
    return itemById(itemId)!;
  }

  /// The movement row and the cached quantity are written in one transaction,
  /// so the app being killed mid-write cannot leave the two disagreeing.
  Future<void> _writeMovement({
    required Item item,
    required int delta,
    required MovementReason reason,
    String? note,
    String? reversesMovementId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final newQty = item.quantity + delta;

    await _db.transaction((txn) async {
      final rows = await txn.query(
        'items',
        columns: ['quantity'],
        where: 'id = ?',
        whereArgs: [item.id],
      );
      final current = rows.isEmpty ? item.quantity : rows.first['quantity'] as int;
      final resulting = current + delta;
      if (resulting < 0) throw NotEnoughStock(current);

      await txn.insert('stock_movements', {
        'id': AppDb.newId(),
        'item_id': item.id,
        'delta': delta,
        'reason': reason.code,
        'note': _orNull(note),
        'resulting_quantity': resulting,
        'reverses_movement_id': reversesMovementId,
        'occurred_at': now,
        'created_at': now,
        'device_id': deviceId,
      });
      await txn.update(
        'items',
        {'quantity': resulting, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [item.id],
      );
      await txn.rawUpdate(
        'UPDATE sync_state SET dirty = 1, '
        'pending_change_count = pending_change_count + 1 WHERE id = 1',
      );
    });

    _replaceInCache(item.copyWith(quantity: newQty, updatedAt: now));
    await _refreshSyncState();
    _totals = await _computeTotals();
    notifyListeners();
    onDataChanged?.call();
  }

  /// Undo appends a reversing movement. Nothing is ever deleted from the
  /// ledger, so history stays auditable.
  Future<void> undoMovement(Movement m) async {
    await applyMovement(
      itemId: m.itemId,
      delta: -m.delta,
      reason: MovementReason.correction,
      note: null,
      reversesMovementId: m.id,
    );
  }

  Future<List<Movement>> movementsForItem(String itemId) async {
    final rows = await _db.query(
      'stock_movements',
      where: 'item_id = ?',
      whereArgs: [itemId],
      orderBy: 'occurred_at DESC, seq DESC',
    );
    return rows.map(Movement.fromRow).toList();
  }

  /// Movement ids that already have a reversing entry, so the UI can hide Undo
  /// on something already undone.
  Future<Set<String>> reversedMovementIds(String itemId) async {
    final rows = await _db.query(
      'stock_movements',
      columns: ['reverses_movement_id'],
      where: 'item_id = ? AND reverses_movement_id IS NOT NULL',
      whereArgs: [itemId],
    );
    return rows
        .map((r) => r['reverses_movement_id'] as String)
        .toSet();
  }

  Future<List<MovementEntry>> history({
    int? fromMs,
    int? toMs,
    String? itemId,
    String? categoryId,
    MovementReason? reason,
    int limit = 500,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (fromMs != null) {
      where.add('m.occurred_at >= ?');
      args.add(fromMs);
    }
    if (toMs != null) {
      where.add('m.occurred_at <= ?');
      args.add(toMs);
    }
    if (itemId != null) {
      where.add('m.item_id = ?');
      args.add(itemId);
    }
    if (categoryId != null) {
      where.add('i.category_id = ?');
      args.add(categoryId);
    }
    if (reason != null) {
      where.add('m.reason = ?');
      args.add(reason.code);
    }
    final clause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    final rows = await _db.rawQuery(
      '''
      SELECT m.*, i.name AS item_name, i.brand AS item_brand,
             i.model AS item_model, i.deleted_at AS item_deleted_at
      FROM stock_movements m
      JOIN items i ON i.id = m.item_id
      $clause
      ORDER BY m.occurred_at DESC, m.seq DESC
      LIMIT $limit
      ''',
      args,
    );
    return rows.map(MovementEntry.fromRow).toList();
  }

  /// Rows the Sheet has not seen yet, oldest first.
  Future<List<MovementEntry>> movementsAfterSeq(int seq, {int limit = 500}) async {
    final rows = await _db.rawQuery(
      '''
      SELECT m.*, i.name AS item_name, i.brand AS item_brand,
             i.model AS item_model, i.deleted_at AS item_deleted_at
      FROM stock_movements m
      JOIN items i ON i.id = m.item_id
      WHERE m.seq > ?
      ORDER BY m.seq ASC
      LIMIT $limit
      ''',
      [seq],
    );
    return rows.map(MovementEntry.fromRow).toList();
  }

  /// Recomputes every cached quantity from the ledger. The ledger is the
  /// truth; this exists so a cache that ever drifts can be repaired.
  Future<int> recomputeQuantities() async {
    final rows = await _db.rawQuery(
      'SELECT item_id, COALESCE(SUM(delta), 0) AS total '
      'FROM stock_movements GROUP BY item_id',
    );
    final sums = {
      for (final r in rows) (r['item_id'] as String): (r['total'] as int?) ?? 0,
    };
    var fixed = 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final item in _items) {
      final expected = sums[item.id] ?? 0;
      if (expected != item.quantity && expected >= 0) {
        await _db.update(
          'items',
          {'quantity': expected, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [item.id],
        );
        fixed++;
      }
    }
    if (fixed > 0) await reload();
    return fixed;
  }

  // -------------------------------------------------------------------- sync

  Future<void> _refreshSyncState() async {
    final rows = await _db.query('sync_state', where: 'id = 1');
    if (rows.isNotEmpty) _sync = SyncState.fromRow(rows.first);
  }

  Future<void> _patchSync(Map<String, Object?> values) async {
    await _db.update('sync_state', values, where: 'id = ?', whereArgs: [1]);
    await _refreshSyncState();
    notifyListeners();
  }

  Future<void> setSyncConnection({
    required String spreadsheetId,
    required String spreadsheetUrl,
    required String accountEmail,
  }) {
    return _patchSync({
      'enabled': 1,
      'spreadsheet_id': spreadsheetId,
      'spreadsheet_url': spreadsheetUrl,
      'account_email': accountEmail,
      'dirty': 1,
      'last_history_seq': 0,
      'consecutive_failures': 0,
      'last_error_code': null,
    });
  }

  Future<void> clearSyncConnection() {
    return _patchSync({
      'enabled': 0,
      'spreadsheet_id': null,
      'spreadsheet_url': null,
      'account_email': null,
      'dirty': 0,
      'pending_change_count': 0,
      'last_history_seq': 0,
      'consecutive_failures': 0,
      'last_error_code': null,
      'last_success_at': null,
      'last_attempt_at': null,
    });
  }

  Future<void> markSyncAttempt() => _patchSync({
        'last_attempt_at': DateTime.now().millisecondsSinceEpoch,
      });

  Future<void> markSyncSuccess(int lastHistorySeq) => _patchSync({
        'dirty': 0,
        'pending_change_count': 0,
        'last_history_seq': lastHistorySeq,
        'consecutive_failures': 0,
        'last_error_code': null,
        'last_success_at': DateTime.now().millisecondsSinceEpoch,
      });

  Future<void> markHistorySeq(int seq) => _patchSync({'last_history_seq': seq});

  Future<void> markSyncFailure(String code) => _patchSync({
        'last_error_code': code,
        'consecutive_failures': _sync.consecutiveFailures + 1,
      });

  Future<bool> get isDirty async {
    final rows = await _db.query(
      'sync_state',
      columns: ['dirty'],
      where: 'id = 1',
    );
    return rows.isNotEmpty && (rows.first['dirty'] as int? ?? 0) == 1;
  }

  // ------------------------------------------------------------------ backup

  Database get database => _db;

  Future<void> _afterWrite() async {
    await _db.rawUpdate(
      'UPDATE sync_state SET dirty = 1, '
      'pending_change_count = pending_change_count + 1 WHERE id = 1',
    );
    await _refreshSyncState();
    _totals = await _computeTotals();
    notifyListeners();
    onDataChanged?.call();
  }

  void _replaceInCache(Item updated) {
    _items = [
      for (final i in _items) if (i.id == updated.id) updated else i,
    ];
  }

  static String? _orNull(String? v) {
    final t = v?.trim() ?? '';
    return t.isEmpty ? null : t;
  }
}
