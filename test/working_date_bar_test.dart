// Layout smoke tests for the guard home working-date bar. These guard against
// RenderFlex overflow and invalid (infinite) constraints at narrow widths and
// in both today / not-today states.
//
// IMPORTANT: these use the real AppTheme, because some layout bugs only surface
// under the app's button/input themes (e.g. an infinite min-width button).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gate_entry/screens/guard/guard_home.dart';
import 'package:gate_entry/theme.dart';

Widget _host(double width, {required bool isToday, required ThemeData theme}) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: width,
          child: WorkingDateBar(
            date: DateTime(2026, 9, 1),
            isToday: isToday,
            onPick: () {},
            onToday: () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('WorkingDateBar lays out cleanly across widths and themes',
      (tester) async {
    for (final theme in <ThemeData>[AppTheme.light(), AppTheme.dark()]) {
      for (final width in <double>[300, 320, 360, 400, 600, 800]) {
        for (final isToday in <bool>[true, false]) {
          await tester.pumpWidget(_host(width, isToday: isToday, theme: theme));
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: 'failed at width=$width isToday=$isToday',
          );
        }
      }
    }
  });

  testWidgets('WorkingDateBar shows the not-today hint and Today button',
      (tester) async {
    await tester.pumpWidget(
      _host(390, isToday: false, theme: AppTheme.light()),
    );
    await tester.pump();
    expect(find.text('Today'), findsOneWidget);
    expect(find.textContaining('Not today'), findsOneWidget);
  });
}
