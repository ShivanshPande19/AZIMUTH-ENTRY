import 'package:intl/intl.dart';

final DateFormat _timeFmt = DateFormat('dd MMM, hh:mm a');
final DateFormat _dayFmt = DateFormat('EEE, d MMM');
final DateFormat _fullDayFmt = DateFormat('EEEE, d MMMM yyyy');

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

/// Human-friendly duration, e.g. "2h 15m".
String formatDuration(DateTime start, DateTime? end) {
  final to = end ?? DateTime.now();
  final d = to.difference(start);
  if (d.inMinutes < 1) return 'just now';
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h == 0) return '${m}m';
  return '${h}h ${m}m';
}
