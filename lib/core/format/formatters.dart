import 'package:intl/intl.dart';

/// id-ID formatting helpers. Times are always shown in WIB (Asia/Jakarta,
/// UTC+7, no DST) regardless of the device time zone.
class Fmt {
  Fmt._();

  static const _days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
  static final _int = NumberFormat('#,##0', 'id_ID');
  static const wibOffset = Duration(hours: 7);

  /// "18.420"
  static String number(num? value) => value == null ? '—' : _int.format(value.round());

  /// "+2.520" / "-360" / "0"
  static String signedNumber(num value) {
    final r = value.round();
    if (r > 0) return '+${_int.format(r)}';
    if (r < 0) return '−${_int.format(-r)}';
    return '0';
  }

  /// "15,8%" with [digits] decimals.
  static String percent(num? value, {int digits = 1}) =>
      value == null ? '—' : '${decimal(value, digits: digits)}%';

  /// "+15,8%" / "−3,0%"
  static String signedPercent(num value, {int digits = 1}) {
    final rounded = double.parse(value.toStringAsFixed(digits));
    if (rounded > 0) return '+${percent(rounded, digits: digits)}';
    if (rounded < 0) return '−${percent(-rounded, digits: digits)}';
    return percent(0, digits: digits);
  }

  /// "0,70" / "6,8"
  static String decimal(num value, {int digits = 1}) =>
      NumberFormat('#,##0${digits > 0 ? '.${'0' * digits}' : ''}', 'id_ID').format(value);

  /// Converts any instant to WIB wall-clock fields (as a UTC DateTime).
  static DateTime toWib(DateTime instant) => instant.toUtc().add(wibOffset);

  /// Today's calendar date in WIB.
  static DateTime todayWib([DateTime? now]) {
    final w = toWib(now ?? DateTime.now());
    return DateTime.utc(w.year, w.month, w.day);
  }

  static String dayName(DateTime date) => _days[date.weekday - 1];
  static String monthName(DateTime date) => _months[date.month - 1];

  /// "Kam, 8 Okt 2026" for a calendar date (no time zone conversion).
  static String date(DateTime date) => '${dayName(date)}, ${date.day} ${monthName(date)} ${date.year}';

  /// "Kam, 8 Okt"
  static String dateNoYear(DateTime date) => '${dayName(date)}, ${date.day} ${monthName(date)}';

  /// "8 Okt"
  static String dayMonth(DateTime date) => '${date.day} ${monthName(date)}';

  /// "8 Okt 2026"
  static String dayMonthYear(DateTime date) => '${date.day} ${monthName(date)} ${date.year}';

  /// "23:02 WIB" for an instant.
  static String time(DateTime instant) {
    final w = toWib(instant);
    return '${_two(w.hour)}:${_two(w.minute)} WIB';
  }

  /// "Kam, 8 Okt 2026 23:02" for an instant (WIB).
  static String dateTime(DateTime instant) {
    final w = toWib(instant);
    return '${date(w)} ${_two(w.hour)}:${_two(w.minute)}';
  }

  /// "Kam, 8 Okt 2026 23:02 WIB"
  static String dateTimeWib(DateTime instant) => '${dateTime(instant)} WIB';

  /// "9 Okt 2026 06:40" (decision log style)
  static String logTime(DateTime instant) {
    final w = toWib(instant);
    return '${dayMonthYear(w)} ${_two(w.hour)}:${_two(w.minute)}';
  }

  /// "2 mnt 14 dtk"
  static String duration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '$s dtk';
    return '$m mnt $s dtk';
  }

  /// "3 Okt – 9 Okt 2026"
  static String range(DateTime start, DateTime end) => start.year == end.year
      ? '${dayMonth(start)} – ${dayMonthYear(end)}'
      : '${dayMonthYear(start)} – ${dayMonthYear(end)}';

  /// "20260108" document-id date key.
  static String dateKey(DateTime date) => '${date.year}${_two(date.month)}${_two(date.day)}';

  /// "2026-01-08" stored `target_date` string.
  static String isoDate(DateTime date) => '${date.year}-${_two(date.month)}-${_two(date.day)}';

  /// Parses "2026-01-08" into a UTC calendar date; returns null on bad input.
  static DateTime? parseIsoDate(String? value) {
    if (value == null) return null;
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (m == null) return null;
    return DateTime.utc(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }

  /// Parses id-ID formatted integers ("17.560") into an int.
  static int? parseInt(String text) {
    final cleaned = text.replaceAll('.', '').replaceAll(' ', '').trim();
    if (cleaned.isEmpty) return null;
    return int.tryParse(cleaned);
  }

  /// Parses id-ID decimals ("0,70" or "0.70") into a double.
  static double? parseDecimal(String text) {
    final cleaned = text.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}
