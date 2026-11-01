import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// SQLite schema. Hand-written on purpose: no code generation step, so what
/// ships is exactly what is in this file.
///
/// There is no money column in any table, and the CI guard in
/// .github/workflows/release.yml fails the build if one appears.
class AppDb {
  AppDb._();

  static const int schemaVersion = 1;
  static const _uuid = Uuid();

  static String newId() => _uuid.v4();

  static Future<Database> open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'stocksaathi.db');
    return openDatabase(
      path,
      version: schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _create,
      onUpgrade: _upgrade,
    );
  }

  static Future<void> _create(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE categories (
        id          TEXT PRIMARY KEY,
        name_en     TEXT NOT NULL,
        name_hi     TEXT NOT NULL,
        icon_key    TEXT NOT NULL DEFAULT 'other',
        is_builtin  INTEGER NOT NULL DEFAULT 0,
        sort_order  INTEGER NOT NULL DEFAULT 100,
        created_at  INTEGER NOT NULL,
        updated_at  INTEGER NOT NULL,
        deleted_at  INTEGER
      )
    ''');

    batch.execute('''
      CREATE TABLE items (
        id          TEXT PRIMARY KEY,
        name        TEXT NOT NULL,
        category_id TEXT NOT NULL REFERENCES categories(id),
        brand       TEXT,
        model       TEXT,
        quantity    INTEGER NOT NULL DEFAULT 0 CHECK (quantity >= 0),
        min_stock   INTEGER NOT NULL DEFAULT 5 CHECK (min_stock >= 0),
        photo_path  TEXT,
        location    TEXT,
        note        TEXT,
        created_at  INTEGER NOT NULL,
        updated_at  INTEGER NOT NULL,
        deleted_at  INTEGER,
        device_id   TEXT NOT NULL DEFAULT ''
      )
    ''');

    // seq is the rowid alias, so it is monotonic and gap-tolerant. The sync
    // cursor relies on that: History rows are pushed in seq order.
    batch.execute('''
      CREATE TABLE stock_movements (
        seq                  INTEGER PRIMARY KEY AUTOINCREMENT,
        id                   TEXT NOT NULL UNIQUE,
        item_id              TEXT NOT NULL REFERENCES items(id),
        delta                INTEGER NOT NULL CHECK (delta <> 0),
        reason               TEXT NOT NULL,
        note                 TEXT,
        resulting_quantity   INTEGER NOT NULL,
        reverses_movement_id TEXT,
        occurred_at          INTEGER NOT NULL,
        created_at           INTEGER NOT NULL,
        device_id            TEXT NOT NULL DEFAULT ''
      )
    ''');

    batch.execute('''
      CREATE TABLE sync_state (
        id                   INTEGER PRIMARY KEY CHECK (id = 1),
        enabled              INTEGER NOT NULL DEFAULT 0,
        spreadsheet_id       TEXT,
        spreadsheet_url      TEXT,
        account_email        TEXT,
        dirty                INTEGER NOT NULL DEFAULT 0,
        pending_change_count INTEGER NOT NULL DEFAULT 0,
        last_history_seq     INTEGER NOT NULL DEFAULT 0,
        last_success_at      INTEGER,
        last_attempt_at      INTEGER,
        consecutive_failures INTEGER NOT NULL DEFAULT 0,
        last_error_code      TEXT
      )
    ''');

    batch.execute('''
      CREATE TABLE settings (
        key   TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // Prevents the same name + brand + model being added twice, ignoring case
    // and surrounding spaces. Scoped to live rows so a deleted item does not
    // block re-adding it.
    batch.execute('''
      CREATE UNIQUE INDEX idx_items_identity ON items(
        lower(trim(name)),
        lower(coalesce(trim(brand), '')),
        lower(coalesce(trim(model), ''))
      ) WHERE deleted_at IS NULL
    ''');

    batch.execute('CREATE INDEX idx_items_category ON items(category_id)');
    batch.execute('CREATE INDEX idx_items_deleted ON items(deleted_at)');
    batch.execute('CREATE INDEX idx_items_stock ON items(quantity, min_stock)');
    batch.execute(
      'CREATE INDEX idx_mv_item ON stock_movements(item_id, occurred_at DESC)',
    );
    batch.execute('CREATE INDEX idx_mv_when ON stock_movements(occurred_at)');

    batch.insert('sync_state', {'id': 1});

    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < _builtinCategories.length; i++) {
      final c = _builtinCategories[i];
      batch.insert('categories', {
        'id': c.$1,
        'name_en': c.$2,
        'name_hi': c.$3,
        'icon_key': c.$1,
        'is_builtin': 1,
        'sort_order': i,
        'created_at': now,
        'updated_at': now,
      });
    }

    batch.insert('settings', {'key': 'device_id', 'value': newId()});
    batch.insert('settings', {'key': 'default_min_stock', 'value': '5'});
    batch.insert('settings', {'key': 'language', 'value': 'hi'});
    batch.insert('settings', {'key': 'shop_name', 'value': ''});
    batch.insert('settings', {'key': 'reminder_enabled', 'value': '0'});
    batch.insert('settings', {'key': 'reminder_hour', 'value': '20'});
    batch.insert('settings', {'key': 'reminder_minute', 'value': '0'});

    await batch.commit(noResult: true);
  }

  static Future<void> _upgrade(Database db, int from, int to) async {
    // Schema version 1 is the first release, so there is nothing to migrate
    // yet. Future versions add their steps here, one `if (from < n)` per bump.
  }

  /// (id / icon key, English name, Hindi name)
  static const List<(String, String, String)> _builtinCategories = [
    ('cover', 'Cover', 'कवर'),
    ('glass', 'Tempered Glass', 'टेम्पर्ड ग्लास'),
    ('charger', 'Charger', 'चार्जर'),
    ('cable', 'Cable', 'केबल'),
    ('earphone', 'Earphone', 'ईयरफोन'),
    ('powerbank', 'Power Bank', 'पावर बैंक'),
    ('memory', 'Memory Card', 'मेमोरी कार्ड'),
    ('other', 'Other', 'अन्य'),
  ];
}
