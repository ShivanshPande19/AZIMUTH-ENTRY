// Unit tests for the date/time helpers used on the visitor cards.
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_entry/utils/format.dart';

void main() {
  group('formatDuration', () {
    final start = DateTime(2026, 9, 3, 9, 0);

    test('under a minute is "just now"', () {
      expect(formatDuration(start, start.add(const Duration(seconds: 30))),
          'just now');
      expect(formatDuration(start, start), 'just now');
    });

    test('negative (clock skew / bad data) is clamped to "just now"', () {
      expect(formatDuration(start, start.subtract(const Duration(minutes: 5))),
          'just now');
    });

    test('minutes only', () {
      expect(formatDuration(start, start.add(const Duration(minutes: 45))),
          '45m');
    });

    test('hours and minutes', () {
      expect(
          formatDuration(
              start, start.add(const Duration(hours: 2, minutes: 15))),
          '2h 15m');
    });

    test('exact hour shows 0 minutes', () {
      expect(formatDuration(start, start.add(const Duration(hours: 1))),
          '1h 0m');
    });

    test('multi-day stays show days', () {
      expect(
          formatDuration(
              start, start.add(const Duration(days: 1, hours: 3))),
          '1d 3h');
      expect(formatDuration(start, start.add(const Duration(days: 2))), '2d');
    });

    test('open (still inside) uses now and stays non-negative', () {
      final result = formatDuration(DateTime.now(), null);
      expect(result, isNot(contains('-')));
    });
  });

  group('isSameDay', () {
    test('same calendar day, different times', () {
      expect(
          isSameDay(DateTime(2026, 9, 3, 1), DateTime(2026, 9, 3, 23)), isTrue);
    });
    test('different days', () {
      expect(isSameDay(DateTime(2026, 9, 3), DateTime(2026, 9, 4)), isFalse);
    });
  });

  group('relativeDayLabel', () {
    final now = DateTime(2026, 9, 3, 12);
    test('today', () {
      expect(relativeDayLabel(DateTime(2026, 9, 3, 8), now: now), 'Today');
    });
    test('yesterday', () {
      expect(relativeDayLabel(DateTime(2026, 9, 2, 8), now: now), 'Yesterday');
    });
    test('older day is not Today/Yesterday', () {
      final label = relativeDayLabel(DateTime(2026, 8, 20), now: now);
      expect(label, isNot('Today'));
      expect(label, isNot('Yesterday'));
    });
  });

  group('formatClock', () {
    test('null renders an em dash', () {
      expect(formatClock(null), '—');
    });
  });
}
