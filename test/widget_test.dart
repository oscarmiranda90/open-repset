import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repset/app/repset_app.dart';

void main() {
  testWidgets('shows the portfolio home screen', (tester) async {
    await tester.pumpWidget(const RepSetApp());
    await tester.pump();

    expect(find.byKey(const Key('home-templates-tile')), findsOneWidget);
    expect(find.byKey(const Key('home-progress-tile')), findsOneWidget);
    expect(find.text('Begin training'), findsOneWidget);
  });

  testWidgets('opens the debug animation lab and replays every demo', (
    tester,
  ) async {
    await tester.pumpWidget(const RepSetApp());
    await tester.pump();

    await tester.tap(find.byKey(const Key('animation-lab-tab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('animation-lab')), findsOneWidget);
    expect(find.text('Animation\nLab.'), findsOneWidget);
    expect(find.text('Set complete'), findsOneWidget);

    const demos = [
      'set-complete',
      'directional-reveal',
      'set-domino',
      'rest-timer-alert',
      'success-burst',
      'summary-shutter',
      'rolling-plate',
      'brake-slide',
      'record-ripple',
      'metric-flip',
      'folding-sets',
      'growing-chart',
      'orbit-loader',
      'curtain-reveal',
    ];

    for (final demo in demos) {
      final replay = find.byKey(Key('replay-$demo'));
      await tester.scrollUntilVisible(
        replay,
        360,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(replay);
      await tester.pump(const Duration(milliseconds: 120));
    }
    await tester.pump(const Duration(milliseconds: 1800));
  });

  testWidgets('selects two exercises as a superset', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const RepSetApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Begin training'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.tap(find.byKey(const Key('add-exercise-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(
      find.byKey(const Key('picker-exercise-barbell-bench-press')),
    );
    await tester.tap(
      find.byKey(const Key('picker-exercise-romanian-deadlift')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('picker-add-superset')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('superset-badge-0')), findsOneWidget);
    expect(find.byKey(const Key('superset-badge-1')), findsOneWidget);
  });

  testWidgets('saves a template while finishing a workout', (tester) async {
    await tester.pumpWidget(const RepSetApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Begin training'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('finish-workout-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-template-and-finish-button')));
    await tester.pumpAndSettle();

    // The summary sheet opens over the app; close it before carrying on.
    await tester.tap(find.byKey(const Key('summary-done-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-progress-tile')), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-templates-tile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('templates-page')), findsOneWidget);
    expect(find.text("Today's Workout"), findsAtLeastNWidgets(1));

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit template'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('template-editor-add-exercise-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('template-picker-barbell-bench-press')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Barbell bench press'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('template-editor-name-field')),
      'Upper body',
    );
    await tester.tap(find.byKey(const Key('save-template-editor-button')));
    await tester.pumpAndSettle();
    expect(find.text('Upper body'), findsOneWidget);
    expect(find.text('1 exercises'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete template'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-template-button')));
    await tester.pumpAndSettle();
    expect(
      find.text('No templates yet. Start a workout, then save it here.'),
      findsOneWidget,
    );
  });

  testWidgets('reaches templates and progress from the home tiles', (
    tester,
  ) async {
    await tester.pumpWidget(const RepSetApp());
    await tester.pumpAndSettle();

    // Both surfaces left the dock, so the tiles are the only way in — and the
    // back action is the only way out.
    expect(find.byKey(const Key('templates-tab')), findsNothing);

    await tester.tap(find.byKey(const Key('home-templates-tile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('templates-page')), findsOneWidget);
    await tester.tap(find.byKey(const Key('templates-back-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-templates-tile')), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-progress-tile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('progress-back-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-progress-tile')), findsOneWidget);
  });

  testWidgets('shows a finished workout in history', (tester) async {
    await tester.pumpWidget(const RepSetApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Begin training'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('finish-workout-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-finish-workout-button')));
    await tester.pumpAndSettle();

    // Finishing now opens the summary sheet; dismiss it to get back to the app.
    expect(find.byKey(const Key('workout-summary-sheet')), findsOneWidget);
    await tester.tap(find.byKey(const Key('summary-done-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('history-tab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history-page')), findsOneWidget);
    expect(find.text("Today's Workout"), findsAtLeastNWidgets(1));
  });

  testWidgets('logs reps with an elevated RPE badge', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const RepSetApp());
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Begin training'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('active-workout-page')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('workout-header-panel'))).height,
      moreOrLessEquals(136),
    );
    final sessionTimeLabel = find.text('SESSION TIME');
    expect(
      tester.getRect(find.byKey(const Key('back-to-home-button'))).bottom,
      lessThan(tester.getRect(sessionTimeLabel).top),
    );
    expect(
      tester.getRect(find.byKey(const Key('finish-workout-button'))).bottom,
      lessThan(tester.getRect(sessionTimeLabel).top),
    );
    expect(find.byKey(const Key('active-workout-tab')), findsNothing);
    expect(find.byKey(const Key('today-tab')), findsNothing);

    await tester.pump(const Duration(milliseconds: 1000));
    await tester.tap(find.byKey(const Key('back-to-home-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-progress-tile')), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.byKey(const Key('active-workout-dock')), findsOneWidget);
    expect(find.text("Today's Workout"), findsAtLeastNWidgets(1));

    await tester.tap(find.byKey(const Key('continue-workout-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('active-workout-page')), findsOneWidget);

    await tester.tap(find.byKey(const Key('back-to-home-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-progress-tile')), findsOneWidget);
    expect(find.byKey(const Key('active-workout-dock')), findsOneWidget);

    await tester.tap(find.byKey(const Key('continue-workout-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('workout-title-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('workout-name-field')),
      'Upper body',
    );
    await tester.tap(find.byKey(const Key('save-workout-name')));
    await tester.pumpAndSettle();
    expect(find.text('Upper body'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-exercise-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final benchPress = find.text('Barbell bench press').last;
    await tester.ensureVisible(benchPress);
    await tester.pump();
    await tester.tap(benchPress);
    await tester.pump();
    await tester.tap(find.byKey(const Key('picker-add-selected')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('back-to-home-button')));
    await tester.pumpAndSettle();
    expect(find.text('Barbell bench press'), findsOneWidget);
    expect(find.byKey(const Key('primary-session-action')), findsOneWidget);
    await tester.tap(find.byKey(const Key('continue-workout-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('exercise-details-0')));
    await tester.pumpAndSettle();
    expect(find.text('Exercise details'), findsOneWidget);
    expect(find.text('Previous training'), findsOneWidget);
    expect(find.text('How to perform it'), findsOneWidget);
    expect(
      find.text('Your completed workouts will build this exercise history.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('close-exercise-details')));
    await tester.pumpAndSettle();

    final firstSet = find.byKey(const Key('workout-set-row-0-0'));
    await tester.ensureVisible(firstSet);
    final loadField = find.descendant(
      of: find.byKey(const Key('set-load-0-0')),
      matching: find.byType(TextField),
    );
    final repsField = find.descendant(
      of: find.byKey(const Key('set-reps-0-0')),
      matching: find.byType(TextField),
    );
    final alignedCells = [
      firstSet,
      find.byKey(const Key('set-previous-0-0')),
      find.byKey(const Key('set-load-0-0')),
      find.byKey(const Key('set-reps-0-0')),
      find.byKey(const Key('complete-set-0-0')),
    ].map(tester.getRect).toList();
    for (final cell in alignedCells) {
      expect(cell.height, moreOrLessEquals(40));
      expect(cell.center.dy, moreOrLessEquals(alignedCells.first.center.dy));
    }
    await tester.enterText(loadField, '100');
    await tester.enterText(repsField, '8');
    await tester.tap(firstSet);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Choose RPE'), findsOneWidget);
    await tester.tap(find.byKey(const Key('rpe-8.5')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('set-rpe-badge')), findsOneWidget);
    expect(find.byKey(const ValueKey('rpe-value-8.5')), findsOneWidget);
    expect(find.text('8.5'), findsOneWidget);
    expect(tester.widget<TextField>(repsField).controller!.text, '8');

    await tester.tap(find.byKey(const Key('complete-set-0-0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('800 kg'), findsOneWidget);
    expect(find.byKey(const Key('rest-timer-0-0')), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-set-0')));
    await tester.pumpAndSettle();
    final inheritedLoadField = find.descendant(
      of: find.byKey(const Key('set-load-0-1')),
      matching: find.byType(TextField),
    );
    final inheritedRepsField = find.descendant(
      of: find.byKey(const Key('set-reps-0-1')),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(inheritedLoadField).controller!.text, '');
    expect(
      tester.widget<TextField>(inheritedLoadField).decoration!.hintText,
      '100',
    );
    expect(tester.widget<TextField>(inheritedRepsField).controller!.text, '');
    expect(
      tester.widget<TextField>(inheritedRepsField).decoration!.hintText,
      '8',
    );

    await tester.tap(find.byKey(const Key('complete-set-0-1')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(inheritedLoadField).controller!.text,
      '100',
    );
    expect(tester.widget<TextField>(inheritedRepsField).controller!.text, '8');
    expect(find.text('1600 kg'), findsOneWidget);
  });
}
