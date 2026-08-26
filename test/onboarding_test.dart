import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repset/domain/app_preferences.dart';
import 'package:repset/features/onboarding/onboarding_gate.dart';

const _app = Key('the-app');

Widget _harness(AppPreferencesRepository preferences) => MaterialApp(
  home: OnboardingGate(
    preferences: preferences,
    child: const SizedBox(key: _app),
  ),
);

void main() {
  testWidgets('a first run is introduced', (tester) async {
    await tester.pumpWidget(_harness(MemoryAppPreferencesRepository()));
    await tester.pumpAndSettle();

    expect(find.text('This is RepSet.'), findsOneWidget);
    expect(find.byKey(_app), findsNothing);
  });

  testWidgets('a returning launch goes straight to the app', (tester) async {
    await tester.pumpWidget(
      _harness(MemoryAppPreferencesRepository.onboarded()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(_app), findsOneWidget);
    expect(find.text('This is RepSet.'), findsNothing);
  });

  testWidgets('continuing needs a path, not a name', (tester) async {
    await tester.pumpWidget(_harness(MemoryAppPreferencesRepository()));
    await tester.pumpAndSettle();

    // Tapping continue before choosing a path must not move the flow on.
    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();
    expect(find.text('This is RepSet.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-path-lifter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();

    expect(find.text('This is RepSet.'), findsNothing);
  });

  testWidgets('the lifter path reaches the app and is remembered', (
    tester,
  ) async {
    final preferences = MemoryAppPreferencesRepository();
    await tester.pumpWidget(_harness(preferences));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('onboarding-name')), 'Oscar');
    await tester.tap(find.byKey(const Key('onboarding-path-lifter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();

    expect(find.text('Great, Oscar.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-lifter-continue')));
    // The closing screen animates continuously, so settling would never
    // return; fixed pumps carry the flow the rest of the way.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const Key('onboarding-finish')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(_app), findsOneWidget);
    final saved = await preferences.readOnboarding();
    expect(saved.isComplete, isTrue);
    expect(saved.name, 'Oscar');
    expect(saved.path, TrainerPath.lifter);
  });

  testWidgets('the developer path shows the terminal', (tester) async {
    final preferences = MemoryAppPreferencesRepository();
    await tester.pumpWidget(_harness(preferences));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('onboarding-path-developer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-continue')));
    // The page transitions, then the terminal types a line at a time.
    for (var frame = 0; frame < 6; frame++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.textContaining('git clone'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-developer-continue')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const Key('onboarding-finish')));
    await tester.pump(const Duration(milliseconds: 500));

    final saved = await preferences.readOnboarding();
    expect(saved.path, TrainerPath.developer);
  });
}
