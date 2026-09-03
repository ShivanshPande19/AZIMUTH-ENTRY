import 'package:intl/intl.dart';

final DateFormat _timeFmt = DateFormat('dd MMM, hh:mm a');
final DateFormat _timeOnlyFmt = DateFormat('hh:mm a');
final DateFormat _dayFmt = DateFormat('EEE, d MMM');
final DateFormat _dayWithYearFmt = DateFormat('EEE, d MMM yyyy');
final DateFormat _fullDayFmt = DateFormat('EEEE, d MMMM yyyy');

/// Time only, e.g. "09:15 AM".
String formatClock(DateTime? dt) => dt == null ? '—' : _timeOnlyFmt.format(dt);

String formatTime(DateTime? dt) {
  if (dt == null) return '—';
  return _timeFmt.format(dt);
}

/// Short day label, e.g. "Wed, 3 Sep".
String formatDay(DateTime dt) => _dayFmt.format(dt);

/// Full day label, e.g. "Wednesday, 3 September 2026".
String formatFullDay(DateTime dt) => _fullDayFmt.format(dt);

/// True if the two dates fall on the same calendar day.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// A friendly heading for a day: "Today", "Yesterday", or a dated label.
String relativeDayLabel(DateTime day, {DateTime? now}) {
  final n = now ?? DateTime.now();
  if (isSameDay(day, n)) return 'Today';
  if (isSameDay(day, n.subtract(const Duration(days: 1)))) return 'Yesterday';
  return day.year == n.year ? _dayFmt.format(day) : _dayWithYearFmt.format(day);
}

/// Human-friendly duration, e.g. "15m", "2h 15m", "1d 3h".
///
/// Robust to clock skew (a slightly-in-the-future start is clamped to zero) and
/// to long/overnight stays (shows days).
String formatDuration(DateTime start, DateTime? end) {
  final to = end ?? DateTime.now();
  var d = to.difference(start);
  if (d.isNegative) d = Duration.zero;
  if (d.inMinutes < 1) return 'just now';

  final days = d.inDays;
  final hours = d.inHours % 24;
  final minutes = d.inMinutes % 60;

  if (days > 0) return hours > 0 ? '${days}d ${hours}h' : '${days}d';
  if (d.inHours > 0) return '${d.inHours}h ${minutes}m';
  return '${minutes}m';
}
