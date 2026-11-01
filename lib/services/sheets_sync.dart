import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../core/formatters.dart';
import '../data/models.dart';
import '../data/repository.dart';

/// Error codes stored in sync_state.last_error_code and mapped to plain
/// language in the Settings screen.
class SyncErrorCode {
  SyncErrorCode._();
  static const offline = 'offline';
  static const auth = 'auth';
  static const notFound = 'not_found';
  static const busy = 'busy';
  static const http = 'http';
  static const unknown = 'unknown';
}

class _SyncFailure implements Exception {
  _SyncFailure(this.code);
  final String code;
}

/// One-way push of local stock into a Google Sheet.
///
/// Two deliberate properties:
///  * The Stock and Summary tabs are rewritten as a full snapshot, so a failed
///    or partial push is corrected by the next successful one with no row
///    reconciliation.
///  * The History tab is append-only, driven by a cursor that advances only
///    after Google confirms the write, so a retry cannot duplicate rows.
///
/// Nothing is ever read back out of the Sheet.
class SheetsSync {
  SheetsSync(this._repo);

  final AppRepo _repo;

  /// Per-file scope. Google classifies this as non-sensitive, so a public
  /// release does not need to pass sensitive-scope verification. The cost is
  /// that the app can only touch spreadsheets it created itself.
  static const String driveFileScope =
      'https://www.googleapis.com/auth/drive.file';

  static const String _sheetsBase = 'https://sheets.googleapis.com/v4/spreadsheets';
  static const int _stockColumns = 9;
  static const Duration _debounceDelay = Duration(seconds: 15);

  static const List<String> stockHeaders = [
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

  static const List<String> historyHeaders = [
    'Date',
    'Time',
    'Item Name',
    'Brand',
    'Model',
    'Change',
    'Reason',
    'Resulting Quantity',
    'Note',
  ];

  static const String banner =
      'Ye sheet app se auto-update hoti hai, yahan edit na karein | '
      'This sheet is auto-updated by the app, do not edit here';

  final GoogleSignIn _signIn = GoogleSignIn(scopes: const [driveFileScope]);
  final http.Client _http = http.Client();

  Timer? _debounce;
  Timer? _retry;
  bool _running = false;
  bool _rerunRequested = false;

  /// Called after every push attempt so the UI can refresh its chip.
  void Function()? onStatusChanged;

  void attach() {
    _repo.onDataChanged = scheduleSoon;
  }

  void dispose() {
    _debounce?.cancel();
    _retry?.cancel();
    _http.close();
  }

  // ------------------------------------------------------------ connection

  /// Silently restores a previous session so pending changes can go out
  /// without the owner signing in again.
  Future<void> restoreSession() async {
    if (!_repo.sync.connected) return;
    try {
      await _signIn.signInSilently();
    } catch (_) {
      // Leave the chip as it is; the next push reports the real problem.
    }
    pushNow();
  }

  /// Signs in and creates a fresh spreadsheet. Returns null on success, or an
  /// error code for the caller to show.
  Future<String?> connect() async {
    GoogleSignInAccount? account;
    try {
      account = await _signIn.signIn();
    } catch (_) {
      return SyncErrorCode.auth;
    }
    if (account == null) return null; // owner cancelled, not an error

    try {
      final headers = await _authHeaders();
      final title = _spreadsheetTitle();
      final created = await _createSpreadsheet(headers, title);
      await _repo.setSyncConnection(
        spreadsheetId: created.id,
        spreadsheetUrl: created.url,
        accountEmail: account.email,
      );
      await _writeScaffold(headers, created);
      await pushNow(manual: true);
      return null;
    } on _SyncFailure catch (e) {
      return e.code;
    } catch (_) {
      return SyncErrorCode.unknown;
    }
  }

  Future<void> disconnect() async {
    _debounce?.cancel();
    _retry?.cancel();
    try {
      await _signIn.disconnect();
    } catch (_) {
      try {
        await _signIn.signOut();
      } catch (_) {
        // Local state is cleared regardless.
      }
    }
    await _repo.clearSyncConnection();
  }

  String _spreadsheetTitle() {
    final shop = _repo.shopName.trim();
    return shop.isEmpty ? 'StockSaathi' : 'StockSaathi - $shop';
  }

  // ------------------------------------------------------------- scheduling

  /// Debounced so a burst of quantity taps results in one push.
  void scheduleSoon() {
    if (!_repo.sync.connected) return;
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () => pushNow());
  }

  /// Fired when the app comes back to the foreground.
  void onResume() {
    if (!_repo.sync.connected) return;
    pushNow();
  }

  Duration _backoffFor(int failures) {
    const schedule = [
      Duration(seconds: 30),
      Duration(minutes: 2),
      Duration(minutes: 10),
      Duration(minutes: 30),
      Duration(hours: 2),
    ];
    final i = failures <= 0 ? 0 : (failures - 1);
    return schedule[i >= schedule.length ? schedule.length - 1 : i];
  }

  void _scheduleRetry() {
    _retry?.cancel();
    _retry = Timer(_backoffFor(_repo.sync.consecutiveFailures), () => pushNow());
  }

  // ------------------------------------------------------------------- push

  Future<void> pushNow({bool manual = false}) async {
    final state = _repo.sync;
    if (!state.connected) return;
    if (_running) {
      _rerunRequested = true;
      return;
    }
    if (!manual && !(await _repo.isDirty) && state.lastSuccessAt != null) {
      final pendingHistory = await _repo.movementsAfterSeq(state.lastHistorySeq, limit: 1);
      if (pendingHistory.isEmpty) return;
    }

    _running = true;
    _debounce?.cancel();
    await _repo.markSyncAttempt();

    try {
      final headers = await _authHeaders();
      final id = state.spreadsheetId!;
      await _pushStock(headers, id);
      await _pushSummary(headers, id);
      final newSeq = await _pushHistory(headers, id, state.lastHistorySeq);
      await _repo.markSyncSuccess(newSeq);
      _retry?.cancel();
    } on _SyncFailure catch (e) {
      await _repo.markSyncFailure(e.code);
      if (e.code != SyncErrorCode.auth && e.code != SyncErrorCode.notFound) {
        _scheduleRetry();
      }
    } catch (_) {
      await _repo.markSyncFailure(SyncErrorCode.unknown);
      _scheduleRetry();
    } finally {
      _running = false;
      onStatusChanged?.call();
      if (_rerunRequested) {
        _rerunRequested = false;
        scheduleSoon();
      }
    }
  }

  Future<void> _pushStock(Map<String, String> headers, String id) async {
    final s = _repo.s;
    final items = _repo.filtered(const StockFilter());
    final values = <List<Object?>>[];
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      values.add([
        i + 1,
        it.name,
        _repo.categoryName(it.categoryId),
        it.brand ?? '',
        it.model ?? '',
        it.quantity,
        it.minStock,
        statusLabel(it.status, s),
        Fmt.dateTime(it.updatedAt),
      ]);
    }

    final lastDataRow = 2 + values.length;
    if (values.isNotEmpty) {
      await _valuesUpdate(headers, id, 'Stock!A3:I$lastDataRow', values);
    }
    // The snapshot is authoritative, so anything below it is stale.
    await _valuesClear(headers, id, 'Stock!A${lastDataRow + 1}:I${lastDataRow + 2001}');
  }

  Future<void> _pushSummary(Map<String, String> headers, String id) async {
    final t = _repo.totals;
    final shop = _repo.shopName.trim();
    final values = <List<Object?>>[
      ['Shop', shop.isEmpty ? 'StockSaathi' : shop],
      ['Last Synced', Fmt.dateTime(DateTime.now().millisecondsSinceEpoch)],
      ['Total Items', t.itemCount],
      ['Total Quantity', t.totalQuantity],
      ['Low Stock Items', t.lowCount],
      ['Out of Stock Items', t.outCount],
    ];
    await _valuesUpdate(headers, id, 'Summary!A3:B${2 + values.length}', values);
  }

  /// Appends movements newer than [fromSeq] and returns the new cursor. The
  /// cursor only moves after Google confirms the append.
  Future<int> _pushHistory(
    Map<String, String> headers,
    String id,
    int fromSeq,
  ) async {
    var cursor = fromSeq;
    final s = _repo.s;
    while (true) {
      final batch = await _repo.movementsAfterSeq(cursor, limit: 400);
      if (batch.isEmpty) return cursor;
      final values = batch.map((e) {
        final m = e.movement;
        return <Object?>[
          Fmt.date(m.occurredAt),
          Fmt.time(m.occurredAt),
          e.itemName,
          e.itemBrand ?? '',
          e.itemModel ?? '',
          m.delta,
          m.reason.label(s),
          m.resultingQuantity,
          m.note ?? '',
        ];
      }).toList();

      await _valuesAppend(headers, id, 'History!A3', values);
      cursor = batch.last.movement.seq;
      await _repo.markHistorySeq(cursor);
      if (batch.length < 400) return cursor;
    }
  }

  // ----------------------------------------------------------- HTTP helpers

  Future<Map<String, String>> _authHeaders() async {
    GoogleSignInAccount? account = _signIn.currentUser;
    if (account == null) {
      try {
        account = await _signIn.signInSilently();
      } catch (_) {
        throw _SyncFailure(SyncErrorCode.auth);
      }
    }
    if (account == null) throw _SyncFailure(SyncErrorCode.auth);
    try {
      final auth = await account.authHeaders;
      return {...auth, 'Content-Type': 'application/json; charset=utf-8'};
    } catch (_) {
      throw _SyncFailure(SyncErrorCode.auth);
    }
  }

  Future<_CreatedSheet> _createSpreadsheet(
    Map<String, String> headers,
    String title,
  ) async {
    final body = jsonEncode({
      'properties': {'title': title, 'locale': 'en_IN'},
      'sheets': [
        {
          'properties': {
            'title': 'Stock',
            'gridProperties': {'frozenRowCount': 2, 'columnCount': _stockColumns},
          },
        },
        {
          'properties': {
            'title': 'History',
            'gridProperties': {'frozenRowCount': 2, 'columnCount': _stockColumns},
          },
        },
        {
          'properties': {'title': 'Summary'},
        },
      ],
    });

    final res = await _send(
      () => _http.post(Uri.parse(_sheetsBase), headers: headers, body: body),
    );
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final id = json['spreadsheetId'] as String?;
    if (id == null) throw _SyncFailure(SyncErrorCode.unknown);

    final sheetIds = <String, int>{};
    final sheets = json['sheets'];
    if (sheets is List) {
      for (final raw in sheets) {
        final props = (raw as Map<String, dynamic>)['properties'];
        if (props is Map<String, dynamic>) {
          final t = props['title'];
          final sid = props['sheetId'];
          if (t is String && sid is int) sheetIds[t] = sid;
        }
      }
    }

    return _CreatedSheet(
      id: id,
      url: (json['spreadsheetUrl'] as String?) ??
          'https://docs.google.com/spreadsheets/d/$id',
      sheetIds: sheetIds,
    );
  }

  /// Writes the banner, the header rows, and bold formatting. Formatting
  /// failures are swallowed: a readable sheet without bold headers is fine.
  Future<void> _writeScaffold(
    Map<String, String> headers,
    _CreatedSheet sheet,
  ) async {
    await _valuesUpdate(headers, sheet.id, 'Stock!A1:I2', [
      [banner],
      stockHeaders,
    ]);
    await _valuesUpdate(headers, sheet.id, 'History!A1:I2', [
      [banner],
      historyHeaders,
    ]);
    await _valuesUpdate(headers, sheet.id, 'Summary!A1:B2', [
      [banner],
      ['Field', 'Value'],
    ]);

    try {
      final requests = <Map<String, dynamic>>[];
      for (final title in ['Stock', 'History', 'Summary']) {
        final sid = sheet.sheetIds[title];
        if (sid == null) continue;
        requests.add({
          'repeatCell': {
            'range': {
              'sheetId': sid,
              'startRowIndex': 0,
              'endRowIndex': 2,
            },
            'cell': {
              'userEnteredFormat': {
                'textFormat': {'bold': true},
                'backgroundColor': {'red': 0.93, 'green': 0.95, 'blue': 0.99},
              },
            },
            'fields': 'userEnteredFormat(textFormat,backgroundColor)',
          },
        });
      }
      if (requests.isEmpty) return;
      await _send(
        () => _http.post(
          Uri.parse('$_sheetsBase/${sheet.id}:batchUpdate'),
          headers: headers,
          body: jsonEncode({'requests': requests}),
        ),
      );
    } catch (_) {
      // Cosmetic only.
    }
  }

  Future<void> _valuesUpdate(
    Map<String, String> headers,
    String id,
    String range,
    List<List<Object?>> values,
  ) async {
    final uri = Uri.parse(
      '$_sheetsBase/$id/values/${Uri.encodeComponent(range)}'
      '?valueInputOption=RAW',
    );
    await _send(
      () => _http.put(
        uri,
        headers: headers,
        body: jsonEncode({'range': range, 'majorDimension': 'ROWS', 'values': values}),
      ),
    );
  }

  Future<void> _valuesAppend(
    Map<String, String> headers,
    String id,
    String range,
    List<List<Object?>> values,
  ) async {
    final uri = Uri.parse(
      '$_sheetsBase/$id/values/${Uri.encodeComponent(range)}:append'
      '?valueInputOption=RAW&insertDataOption=INSERT_ROWS',
    );
    await _send(
      () => _http.post(
        uri,
        headers: headers,
        body: jsonEncode({'majorDimension': 'ROWS', 'values': values}),
      ),
    );
  }

  Future<void> _valuesClear(
    Map<String, String> headers,
    String id,
    String range,
  ) async {
    final uri = Uri.parse(
      '$_sheetsBase/$id/values/${Uri.encodeComponent(range)}:clear',
    );
    await _send(() => _http.post(uri, headers: headers, body: '{}'));
  }

  Future<http.Response> _send(Future<http.Response> Function() call) async {
    http.Response res;
    try {
      res = await call().timeout(const Duration(seconds: 30));
    } on SocketException {
      throw _SyncFailure(SyncErrorCode.offline);
    } on http.ClientException {
      throw _SyncFailure(SyncErrorCode.offline);
    } on TimeoutException {
      throw _SyncFailure(SyncErrorCode.offline);
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return res;
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw _SyncFailure(SyncErrorCode.auth);
    }
    if (res.statusCode == 404) throw _SyncFailure(SyncErrorCode.notFound);
    if (res.statusCode == 429 || res.statusCode >= 500) {
      throw _SyncFailure(SyncErrorCode.busy);
    }
    throw _SyncFailure(SyncErrorCode.http);
  }
}

class _CreatedSheet {
  _CreatedSheet({required this.id, required this.url, required this.sheetIds});
  final String id;
  final String url;
  final Map<String, int> sheetIds;
}
