import 'package:intl/intl.dart';

/// Date/time utility helpers used throughout the app.
class DateHelpers {
  DateHelpers._();

  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

  static DateTime startOfMonth(DateTime date) =>
      DateTime(date.year, date.month, 1);

  static DateTime endOfMonth(DateTime date) =>
      DateTime(date.year, date.month + 1, 0, 23, 59, 59, 999);

  static DateTime startOfWeek(DateTime date) =>
      date.subtract(Duration(days: date.weekday - 1));

  static DateTime endOfWeek(DateTime date) =>
      date.add(Duration(days: 7 - date.weekday));

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool isSameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  static bool isToday(DateTime date) => isSameDay(date, DateTime.now());

  static bool isFutureMonth(DateTime date) {
    final now = DateTime.now();
    return date.year > now.year ||
        (date.year == now.year && date.month > now.month);
  }

  static bool isCurrentMonth(DateTime date) =>
      isSameMonth(date, DateTime.now());

  static int daysInMonth(DateTime date) =>
      DateTime(date.year, date.month + 1, 0).day;

  /// Number of days from start of month to [date] (inclusive).
  static int dayOfMonth(DateTime date) => date.day;

  /// Previous month from the given date.
  static DateTime previousMonth(DateTime date) =>
      DateTime(date.year, date.month - 1, 1);

  /// Next month from the given date.
  static DateTime nextMonth(DateTime date) =>
      DateTime(date.year, date.month + 1, 1);

  // ── Formatters ──

  static final _monthYear = DateFormat('MMMM yyyy');
  static final _shortMonth = DateFormat('MMM yyyy');
  static final _dayMonth = DateFormat('d MMM');
  static final _fullDate = DateFormat('d MMM yyyy');
  static final _dayName = DateFormat('EEE');
  static final _time = DateFormat('h:mm a');
  static final _iso = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS");

  static String formatMonthYear(DateTime date) => _monthYear.format(date);
  static String formatShortMonth(DateTime date) => _shortMonth.format(date);
  static String formatDayMonth(DateTime date) => _dayMonth.format(date);
  static String formatFullDate(DateTime date) => _fullDate.format(date);
  static String formatDayName(DateTime date) => _dayName.format(date);
  static String formatTime(DateTime date) => _time.format(date);
  static String toIso(DateTime date) => _iso.format(date);

  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return formatFullDate(date);
  }

  /// Format currency amount in INR.
  static String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: amount == amount.roundToDouble() ? 0 : 2,
    );
    return formatter.format(amount);
  }
}
