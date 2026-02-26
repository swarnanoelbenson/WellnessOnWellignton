// Phase 2 smoke test — verifies the app shell boots without throwing.
// Full widget tests for the main screen will be added in Phase 3.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wellness_on_wellington/main.dart';

void main() {
  testWidgets('App boots and shows phase placeholder without errors',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: WellnessOnWellingtonApp()),
    );
    // The phase-1 placeholder screen should be visible.
    expect(find.text('Wellness on Wellington'), findsOneWidget);
  });
}
