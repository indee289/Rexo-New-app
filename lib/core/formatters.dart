import 'package:intl/intl.dart';

import 'strings.dart';

/// Date and number formatting. Timestamps are stored UTC and shown local.
class Fmt {
  Fmt._();

  static DateTime local(int epochMs) =>
      DateTime.fromMillisecondsSinceEpoch(epochMs);

  static String date(int epochMs) =>
      DateFormat('dd/MM/yyyy').format(local(epochMs));

  static String time(int epochMs) => DateFormat('hh:mm a').format(local(epochMs));

  static String dateTime(int epochMs) =>
      '${date(epochMs)}  ${time(epochMs)}';

  static String dayLabel(DateTime d) => DateFormat('dd MMM yyyy').format(d);

  static String monthLabel(DateTime d) => DateFormat('MMM yyyy').format(d);

  static String fileStamp() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  static String signed(int n) => n > 0 ? '+$n' : '$n';

  /// Short relative time for the sync chip.
  static String ago(int? epochMs, S s) {
    if (epochMs == null) return s.never;
    final diff = DateTime.now().difference(local(epochMs));
    if (diff.inMinutes < 1) return s.justNow;
    if (diff.inMinutes < 60) return '${diff.inMinutes} ${s.minAgo}';
    if (diff.inHours < 24) return '${diff.inHours} ${s.hourAgo}';
    return date(epochMs);
  }

  static int startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
  }

  static int startOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;

  static int endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999).millisecondsSinceEpoch;
}
