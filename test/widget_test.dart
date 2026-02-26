// Smoke test — verifies the app shell boots and shows the splash screen.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wellness_on_wellington/main.dart';

void main() {
  testWidgets('App boots and shows splash screen without errors',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: WellnessOnWellingtonApp()),
    );
    // The splash screen subtitle is visible on first render.
    expect(find.text('Attendance Tracker'), findsOneWidget);
  });
}
