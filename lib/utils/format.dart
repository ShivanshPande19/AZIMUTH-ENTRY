import 'package:intl/intl.dart';

final DateFormat _timeFmt = DateFormat('dd MMM, hh:mm a');

String formatTime(DateTime? dt) {
  if (dt == null) return '—';
  return _timeFmt.format(dt);
}

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
