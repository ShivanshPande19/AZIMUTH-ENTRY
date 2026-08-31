// Basic smoke test for the misconfigured (no-Supabase) startup path.
// The full app requires live Supabase credentials, so it is not exercised here.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gate_entry/screens/misconfigured_screen.dart';

void main() {
  testWidgets('Misconfigured screen renders guidance', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: MisconfiguredScreen()),
    );
    expect(find.text('Supabase not configured'), findsOneWidget);
  });
}
