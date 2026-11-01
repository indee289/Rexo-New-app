import '../core/strings.dart';

/// Why a quantity changed. Recorded on every movement so history stays
/// meaningful in an app that deliberately tracks no money.
enum MovementReason {
  opening('opening', 1),
  purchase('purchase', 1),
  sale('sale', -1),
  returnIn('return_in', 1),
  damage('damage', -1),
  correction('correction', 0);

  const MovementReason(this.code, this.defaultSign);

  final String code;

  /// 1 = always adds, -1 = always removes, 0 = either direction.
  final int defaultSign;

  static MovementReason fromCode(String code) => MovementReason.values
      .firstWhere((r) => r.code == code, orElse: () => MovementReason.correction);

  String label(S s) {
    switch (this) {
      case MovementReason.opening:
        return s.rOpening;
      case MovementReason.purchase:
        return s.rPurchase;
      case MovementReason.sale:
        return s.rSale;
      case MovementReason.returnIn:
        return s.rReturn;
      case MovementReason.damage:
        return s.rDamage;
      case MovementReason.correction:
        return s.rCorrection;
    }
  }

  static List<MovementReason> forDirection(bool isIn) => isIn
      ? const [
          MovementReason.purchase,
          MovementReason.returnIn,
          MovementReason.correction,
        ]
      : const [
          MovementReason.sale,
          MovementReason.damage,
          MovementReason.correction,
        ];
}

enum StockStatus { available, low, out }

/// Shared by the list rows, the PDF, the Excel sheet, and the synced Sheet, so
/// a single item never shows two different statuses.
String statusLabel(StockStatus st, S s) {
  switch (st) {
    case StockStatus.available:
      return s.stAvailable;
    case StockStatus.low:
      return s.stLow;
    case StockStatus.out:
      return s.stOut;
  }
}

class ItemCategory {
  const ItemCategory({
    required this.id,
    required this.nameEn,
    required this.nameHi,
    required this.iconKey,
    required this.isBuiltin,
    required this.sortOrder,
  });

  final String id;
  final String nameEn;
  final String nameHi;
  final String iconKey;
  final bool isBuiltin;
  final int sortOrder;

  String name(S s) => s.lang == 'hi' ? nameHi : nameEn;

  Map<String, Object?> toRow() => {
        'id': id,
        'name_en': nameEn,
        'name_hi': nameHi,
        'icon_key': iconKey,
        'is_builtin': isBuiltin ? 1 : 0,
        'sort_order': sortOrder,
      };

  static ItemCategory fromRow(Map<String, Object?> r) => ItemCategory(
        id: r['id'] as String,
        nameEn: r['name_en'] as String,
        nameHi: r['name_hi'] as String,
        iconKey: (r['icon_key'] as String?) ?? 'other',
        isBuiltin: (r['is_builtin'] as int? ?? 0) == 1,
        sortOrder: r['sort_order'] as int? ?? 100,
      );
}

class Item {
  const Item({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.quantity,
    required this.minStock,
    required this.createdAt,
    required this.updatedAt,
    required this.deviceId,
    this.brand,
    this.model,
    this.photoPath,
    this.location,
    this.note,
  });

  final String id;
  final String name;
  final String categoryId;
  final String? brand;
  final String? model;
  final int quantity;
  final int minStock;
  final String? photoPath;
  final String? location;
  final String? note;
  final int createdAt;
  final int updatedAt;
  final String deviceId;

  StockStatus get status {
    if (quantity <= 0) return StockStatus.out;
    if (quantity <= minStock) return StockStatus.low;
    return StockStatus.available;
  }

  /// How far below the minimum this item sits. Used to sort the urgent ones up.
  int get shortfall => minStock - quantity;

  /// "Samsung A55 · Rack 2" style secondary line, empty parts dropped.
  String subtitle() {
    final parts = <String>[
      if ((brand ?? '').trim().isNotEmpty) brand!.trim(),
      if ((model ?? '').trim().isNotEmpty) model!.trim(),
      if ((location ?? '').trim().isNotEmpty) location!.trim(),
    ];
    return parts.join(' · ');
  }

  String get searchBlob =>
      '$name ${brand ?? ''} ${model ?? ''} ${location ?? ''}'.toLowerCase();

  Item copyWith({
    String? name,
    String? categoryId,
    String? brand,
    String? model,
    int? quantity,
    int? minStock,
    String? photoPath,
    String? location,
    String? note,
    int? updatedAt,
    bool clearPhoto = false,
  }) {
    return Item(
      id: id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      quantity: quantity ?? this.quantity,
      minStock: minStock ?? this.minStock,
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
      location: location ?? this.location,
      note: note ?? this.note,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId,
    );
  }

  Map<String, Object?> toRow() => {
        'id': id,
        'name': name,
        'category_id': categoryId,
        'brand': brand,
        'model': model,
        'quantity': quantity,
        'min_stock': minStock,
        'photo_path': photoPath,
        'location': location,
        'note': note,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'deleted_at': null,
        'device_id': deviceId,
      };

  static Item fromRow(Map<String, Object?> r) => Item(
        id: r['id'] as String,
        name: r['name'] as String,
        categoryId: r['category_id'] as String,
        brand: r['brand'] as String?,
        model: r['model'] as String?,
        quantity: r['quantity'] as int,
        minStock: r['min_stock'] as int,
        photoPath: r['photo_path'] as String?,
        location: r['location'] as String?,
        note: r['note'] as String?,
        createdAt: r['created_at'] as int,
        updatedAt: r['updated_at'] as int,
        deviceId: (r['device_id'] as String?) ?? '',
      );
}

class Movement {
  const Movement({
    required this.seq,
    required this.id,
    required this.itemId,
    required this.delta,
    required this.reason,
    required this.resultingQuantity,
    required this.occurredAt,
    required this.createdAt,
    required this.deviceId,
    this.note,
    this.reversesMovementId,
  });

  final int seq;
  final String id;
  final String itemId;
  final int delta;
  final MovementReason reason;
  final String? note;
  final int resultingQuantity;
  final String? reversesMovementId;
  final int occurredAt;
  final int createdAt;
  final String deviceId;

  bool get isIn => delta > 0;

  static Movement fromRow(Map<String, Object?> r) => Movement(
        seq: r['seq'] as int,
        id: r['id'] as String,
        itemId: r['item_id'] as String,
        delta: r['delta'] as int,
        reason: MovementReason.fromCode(r['reason'] as String),
        note: r['note'] as String?,
        resultingQuantity: r['resulting_quantity'] as int,
        reversesMovementId: r['reverses_movement_id'] as String?,
        occurredAt: r['occurred_at'] as int,
        createdAt: r['created_at'] as int,
        deviceId: (r['device_id'] as String?) ?? '',
      );
}

/// A movement joined with enough item detail to render a history row without
/// a second lookup.
class MovementEntry {
  const MovementEntry({
    required this.movement,
    required this.itemName,
    required this.itemBrand,
    required this.itemModel,
    required this.itemDeleted,
  });

  final Movement movement;
  final String itemName;
  final String? itemBrand;
  final String? itemModel;
  final bool itemDeleted;

  static MovementEntry fromRow(Map<String, Object?> r) => MovementEntry(
        movement: Movement.fromRow(r),
        itemName: (r['item_name'] as String?) ?? '',
        itemBrand: r['item_brand'] as String?,
        itemModel: r['item_model'] as String?,
        itemDeleted: (r['item_deleted_at'] as int?) != null,
      );
}

/// Current state of the one-way push to Google Sheets.
class SyncState {
  const SyncState({
    required this.enabled,
    required this.pendingCount,
    required this.lastHistorySeq,
    required this.consecutiveFailures,
    this.spreadsheetId,
    this.spreadsheetUrl,
    this.accountEmail,
    this.lastSuccessAt,
    this.lastAttemptAt,
    this.lastErrorCode,
  });

  final bool enabled;
  final int pendingCount;
  final int lastHistorySeq;
  final int consecutiveFailures;
  final String? spreadsheetId;
  final String? spreadsheetUrl;
  final String? accountEmail;
  final int? lastSuccessAt;
  final int? lastAttemptAt;
  final String? lastErrorCode;

  bool get connected => enabled && (spreadsheetId ?? '').isNotEmpty;

  static const SyncState disabled = SyncState(
    enabled: false,
    pendingCount: 0,
    lastHistorySeq: 0,
    consecutiveFailures: 0,
  );

  static SyncState fromRow(Map<String, Object?> r) => SyncState(
        enabled: (r['enabled'] as int? ?? 0) == 1,
        pendingCount: r['pending_change_count'] as int? ?? 0,
        lastHistorySeq: r['last_history_seq'] as int? ?? 0,
        consecutiveFailures: r['consecutive_failures'] as int? ?? 0,
        spreadsheetId: r['spreadsheet_id'] as String?,
        spreadsheetUrl: r['spreadsheet_url'] as String?,
        accountEmail: r['account_email'] as String?,
        lastSuccessAt: r['last_success_at'] as int?,
        lastAttemptAt: r['last_attempt_at'] as int?,
        lastErrorCode: r['last_error_code'] as String?,
      );
}

/// Totals shown on the dashboard.
class Totals {
  const Totals({
    required this.itemCount,
    required this.totalQuantity,
    required this.lowCount,
    required this.outCount,
    required this.todayIn,
    required this.todayOut,
  });

  final int itemCount;
  final int totalQuantity;
  final int lowCount;
  final int outCount;
  final int todayIn;
  final int todayOut;

  static const Totals empty = Totals(
    itemCount: 0,
    totalQuantity: 0,
    lowCount: 0,
    outCount: 0,
    todayIn: 0,
    todayOut: 0,
  );
}

enum StockSort { name, quantity, recent }

/// Filters applied to the stock list.
class StockFilter {
  const StockFilter({
    this.query = '',
    this.categoryIds = const <String>{},
    this.brand,
    this.model,
    this.status,
    this.sort = StockSort.name,
  });

  final String query;
  final Set<String> categoryIds;
  final String? brand;
  final String? model;
  final StockStatus? status;
  final StockSort sort;

  bool get isActive =>
      query.trim().isNotEmpty ||
      categoryIds.isNotEmpty ||
      brand != null ||
      model != null ||
      status != null;

  StockFilter copyWith({
    String? query,
    Set<String>? categoryIds,
    String? brand,
    String? model,
    StockStatus? status,
    StockSort? sort,
    bool clearBrand = false,
    bool clearModel = false,
    bool clearStatus = false,
  }) {
    return StockFilter(
      query: query ?? this.query,
      categoryIds: categoryIds ?? this.categoryIds,
      brand: clearBrand ? null : (brand ?? this.brand),
      model: clearModel ? null : (model ?? this.model),
      status: clearStatus ? null : (status ?? this.status),
      sort: sort ?? this.sort,
    );
  }
}
