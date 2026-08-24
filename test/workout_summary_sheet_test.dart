import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repset/domain/workout_session.dart';
import 'package:repset/domain/workout_summary.dart';
import 'package:repset/features/workout/summary/workout_summary_sheet.dart';

WorkoutSummary _summary({
  List<WorkoutRecord> records = const [],
  double previousVolumeKg = 0,
  int completedSessionCount = 0,
}) => WorkoutSummary(
  session: WorkoutSession(
    id: 'session',
    title: 'Push day',
    startedAt: DateTime(2026, 8, 24, 9),
    completedAt: DateTime(2026, 8, 24, 10, 5),
    exercises: const [
      WorkoutExercise(
        id: 'entry-1',
        exerciseId: 'bench',
        name: 'Bench press',
        position: 0,
        sets: [
          WorkoutSet(
            id: 'set-1',
            exerciseId: 'bench',
            position: 0,
            repetitions: 8,
            loadKg: 80,
            rpe: 8,
            isCompleted: true,
          ),
        ],
      ),
    ],
  ),
  records: records,
  previousSessionVolumeKg: previousVolumeKg,
  completedSessionCount: completedSessionCount,
);

/// Scrolls the modal's list until [finder] is built and on screen. The list is
/// lazy, so sections below the fold do not exist until scrolled to.
Future<void> _revealInSummary(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.descendant(
      of: find.byKey(const Key('workout-summary-sheet')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openSheet(WidgetTester tester, WorkoutSummary summary) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xffd7ff4f),
          brightness: Brightness.dark,
        ),
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () =>
                  showWorkoutSummarySheet(context, load: () async => summary),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows session metrics and a receipt', (tester) async {
    await _openSheet(tester, _summary());

    expect(find.byKey(const Key('workout-summary-sheet')), findsOneWidget);
    expect(find.text('Push day'), findsOneWidget);
    // The brand mark identifies the modal as RepSet's own moment.
    expect(
      find.image(const AssetImage('assets/icon/brand_mark.png')),
      findsOneWidget,
    );
    expect(find.text('REPSET / SESSION RECEIPT'), findsOneWidget);
    expect(find.text('SESSION SAVED'), findsOneWidget);
    expect(find.text('BENCH PRESS'), findsOneWidget);
    // The metric grid sits below the receipt, so it needs scrolling into view.
    await _revealInSummary(tester, find.text('total volume (kg)'));
    expect(find.text('total volume (kg)'), findsOneWidget);
    expect(find.text('sets completed'), findsOneWidget);
    expect(find.text('average RPE'), findsOneWidget);
    // The dismiss action is pinned, so it is reachable without scrolling.
    expect(find.byKey(const Key('summary-done-button')), findsOneWidget);
  });

  testWidgets('labels the very first session instead of comparing', (
    tester,
  ) async {
    await _openSheet(tester, _summary());

    expect(find.text('FIRST SESSION LOGGED'), findsOneWidget);
    // The headline is drawn at random from a pool, so the assertion targets the
    // subline, which is derived from the session itself.
    expect(
      find.text(
        'Your first session is saved. Every future one compares to this.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('reports the volume change against the previous session', (
    tester,
  ) async {
    await _openSheet(
      tester,
      // 640 kg this session against 500 kg before is a 28% gain.
      _summary(previousVolumeKg: 500, completedSessionCount: 3),
    );

    expect(find.text('WORKOUT COMPLETE'), findsOneWidget);
    expect(
      find.text('28% more volume than your last session.'),
      findsOneWidget,
    );
  });

  testWidgets('renders each personal record with its improvement', (
    tester,
  ) async {
    await _openSheet(
      tester,
      _summary(
        completedSessionCount: 4,
        previousVolumeKg: 600,
        records: const [
          WorkoutRecord(
            exerciseName: 'Bench press',
            kind: WorkoutRecordKind.heaviestSet,
            value: 80,
            previousValue: 75,
          ),
          WorkoutRecord(
            exerciseName: 'Barbell row',
            kind: WorkoutRecordKind.sessionVolume,
            value: 900,
            previousValue: 0,
          ),
        ],
      ),
    );

    await _revealInSummary(tester, find.text('2 PERSONAL RECORDS'));
    expect(find.text('2 PERSONAL RECORDS'), findsOneWidget);
    expect(find.text('PR'), findsNWidgets(2));
    expect(find.text('Heaviest set · 80 kg · +5 kg'), findsOneWidget);
    expect(
      find.text('Best session volume · 900 kg · first time logged'),
      findsOneWidget,
    );
  });

  testWidgets('omits the record section when nothing was beaten', (
    tester,
  ) async {
    await _openSheet(
      tester,
      _summary(completedSessionCount: 2, previousVolumeKg: 640),
    );

    expect(find.text('PR'), findsNothing);
    expect(find.textContaining('PERSONAL RECORD'), findsNothing);
    // The volume chart still renders for the session itself.
    await _revealInSummary(tester, find.text('VOLUME BY EXERCISE'));
    expect(find.text('VOLUME BY EXERCISE'), findsOneWidget);
  });

  testWidgets('closes when the done action is used', (tester) async {
    await _openSheet(tester, _summary());

    await tester.tap(find.byKey(const Key('summary-done-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('workout-summary-sheet')), findsNothing);
  });
}
