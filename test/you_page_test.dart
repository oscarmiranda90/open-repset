import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repset/data/demo_exercise_repository.dart';
import 'package:repset/data/memory_body_weight_repository.dart';
import 'package:repset/data/memory_muscle_coverage_repository.dart';
import 'package:repset/data/memory_training_analytics_repository.dart';
import 'package:repset/data/memory_workout_repository.dart';
import 'package:repset/domain/body_weight.dart';
import 'package:repset/domain/relative_strength_service.dart';
import 'package:repset/features/progress/body_weight_bloc.dart';
import 'package:repset/features/progress/progress_bloc.dart';
import 'package:repset/features/you/muscle_coverage_bloc.dart';
import 'package:repset/features/you/you_page.dart';

Future<MemoryBodyWeightRepository> _pumpYou(
  WidgetTester tester, {
  List<BodyWeightEntry> entries = const [],
}) async {
  final weights = MemoryBodyWeightRepository();
  for (final entry in entries) {
    await weights.save(entry);
  }
  final workouts = MemoryWorkoutRepository();
  final analytics = MemoryTrainingAnalyticsRepository(workouts);
  final muscles = MemoryMuscleCoverageRepository(
    workouts,
    DemoExerciseRepository(),
  );

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              BodyWeightBloc(weights)..add(const BodyWeightRequested()),
        ),
        BlocProvider(
          create: (_) => ProgressBloc(
            analytics,
            RelativeStrengthService(analytics, weights),
          )..add(const ProgressLoaded()),
        ),
        BlocProvider(
          create: (_) =>
              MuscleCoverageBloc(muscles)..add(const MuscleCoverageRequested()),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xffd7ff4f),
            brightness: Brightness.dark,
          ),
        ),
        home: const Scaffold(body: YouPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return weights;
}

BodyWeightEntry _entry(int daysAgo, double weightKg) => BodyWeightEntry(
  measuredOn: DateTime.now().subtract(Duration(days: daysAgo)),
  weightKg: weightKg,
);

void main() {
  testWidgets('invites a first weigh-in when nothing is logged', (
    tester,
  ) async {
    await _pumpYou(tester);

    expect(find.byKey(const Key('you-page')), findsOneWidget);
    expect(find.text('Add your\nweight.'), findsOneWidget);
    // The entry point is present before any history exists.
    expect(find.byKey(const Key('log-body-weight-button')), findsOneWidget);
    expect(find.text('HISTORY'), findsNothing);
  });

  testWidgets('leads with the current weight once one exists', (tester) async {
    await _pumpYou(tester, entries: [_entry(0, 78.4)]);

    expect(find.text('78.4'), findsOneWidget);
    expect(find.text('kg'), findsOneWidget);
    // A single reading is not a direction, so no trend is claimed.
    expect(
      find.textContaining('Log another to see the trend'),
      findsOneWidget,
    );
  });

  testWidgets('states the direction across the window', (tester) async {
    await _pumpYou(tester, entries: [_entry(30, 82), _entry(0, 78)]);

    expect(find.text('78'), findsOneWidget);
    expect(find.textContaining('Down 4 kg over 30 days'), findsOneWidget);
  });

  testWidgets('lists past weigh-ins with their change', (tester) async {
    await _pumpYou(
      tester,
      entries: [_entry(14, 80), _entry(7, 79.2), _entry(0, 78.5)],
    );

    expect(find.text('HISTORY'), findsOneWidget);
    expect(find.text('Today'), findsWidgets);
    expect(find.text('78.5 kg'), findsOneWidget);
    expect(find.text('79.2 kg'), findsOneWidget);
    // Each row states its delta against the entry before it.
    expect(find.text('−0.7'), findsOneWidget);
    expect(find.text('−0.8'), findsOneWidget);
  });

  testWidgets('records a new weigh-in through the sheet', (tester) async {
    final weights = await _pumpYou(tester);

    await tester.tap(find.byKey(const Key('log-body-weight-button')));
    await tester.pumpAndSettle();

    expect(find.text('New weigh-in'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('body-weight-field')), '81.5');
    await tester.tap(find.byKey(const Key('save-body-weight-button')));
    await tester.pumpAndSettle();

    expect((await weights.getLatest())!.weightKg, 81.5);
    expect(find.text('81.5'), findsOneWidget);
  });

  testWidgets('rejects an implausible entry without closing the sheet', (
    tester,
  ) async {
    final weights = await _pumpYou(tester);

    await tester.tap(find.byKey(const Key('log-body-weight-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('body-weight-field')), '900');
    await tester.tap(find.byKey(const Key('save-body-weight-button')));
    await tester.pumpAndSettle();

    // The error names the range that would fix it, and nothing is saved.
    expect(find.text('Enter a weight between 1 and 499 kg.'), findsOneWidget);
    expect(await weights.getLatest(), isNull);
  });

  testWidgets('edits an existing weigh-in from its row', (tester) async {
    final weights = await _pumpYou(tester, entries: [_entry(0, 80)]);

    await tester.tap(find.text('80 kg'));
    await tester.pumpAndSettle();

    expect(find.text('Edit weigh-in'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('body-weight-field')), '79');
    await tester.tap(find.byKey(const Key('save-body-weight-button')));
    await tester.pumpAndSettle();

    expect((await weights.getLatest())!.weightKg, 79);
    final entries = await weights.getEntries();
    // Editing replaces the day rather than adding a second reading.
    expect(entries, hasLength(1));
  });

  testWidgets('deletes a weigh-in from the edit sheet', (tester) async {
    final weights = await _pumpYou(
      tester,
      entries: [_entry(7, 80), _entry(0, 79)],
    );

    await tester.tap(find.text('79 kg'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-body-weight-button')));
    await tester.pumpAndSettle();

    final entries = await weights.getEntries();
    expect(entries, hasLength(1));
    expect(entries.single.weightKg, 80);
  });

  testWidgets('offers a date so a missed day can be back-filled', (
    tester,
  ) async {
    await _pumpYou(tester);

    await tester.tap(find.byKey(const Key('log-body-weight-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('weigh-in-date-button')), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
  });
}
