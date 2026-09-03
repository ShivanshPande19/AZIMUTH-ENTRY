// Layout smoke tests for the guard home working-date bar. These guard against
// RenderFlex overflow (which corrupts the render tree) at narrow widths and in
// both today / not-today states.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gate_entry/screens/guard/guard_home.dart';

Widget _host(double width, {required bool isToday}) {
  return MaterialApp(
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
  testWidgets('WorkingDateBar lays out without overflow across widths',
      (tester) async {
    for (final width in <double>[300, 320, 360, 400, 600, 800]) {
      for (final isToday in <bool>[true, false]) {
        await tester.pumpWidget(_host(width, isToday: isToday));
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: 'overflow at width=$width isToday=$isToday',
        );
      }
    }
  });

  testWidgets('WorkingDateBar shows the not-today hint and Today button',
      (tester) async {
    await tester.pumpWidget(_host(390, isToday: false));
    await tester.pump();
    expect(find.text('Today'), findsOneWidget);
    expect(find.textContaining('Not today'), findsOneWidget);
  });
}
