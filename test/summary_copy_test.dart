import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:repset/domain/workout_session.dart';
import 'package:repset/domain/workout_summary.dart';
import 'package:repset/features/workout/summary/summary_copy.dart';

WorkoutSummary _summary({
  List<WorkoutRecord> records = const [],
  double previousVolumeKg = 0,
  int completedSessionCount = 0,
  double loadKg = 80,
}) => WorkoutSummary(
  session: WorkoutSession(
    id: 'session',
    title: 'Push day',
    startedAt: DateTime(2026, 8, 24, 9),
    completedAt: DateTime(2026, 8, 24, 10),
    exercises: [
      WorkoutExercise(
        id: 'entry',
        exerciseId: 'bench',
        name: 'Bench press',
        position: 0,
        sets: [
          WorkoutSet(
            id: 'set',
            exerciseId: 'bench',
            position: 0,
            repetitions: 10,
            loadKg: loadKg,
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

const _record = WorkoutRecord(
  exerciseName: 'Bench press',
  kind: WorkoutRecordKind.heaviestSet,
  value: 85,
  previousValue: 80,
);

void main() {
  test('never returns empty copy for any session shape', () {
    final shapes = [
      _summary(),
      _summary(completedSessionCount: 4, previousVolumeKg: 700),
      _summary(completedSessionCount: 4, previousVolumeKg: 400),
      _summary(completedSessionCount: 4, previousVolumeKg: 2000),
      _summary(completedSessionCount: 4, records: const [_record]),
      _summary(
        completedSessionCount: 4,
        records: const [_record, _record],
        previousVolumeKg: 600,
      ),
    ];

    // Every pool index must produce usable text, so run each shape repeatedly.
    for (final summary in shapes) {
      for (var seed = 0; seed < 24; seed++) {
        final copy = summaryHeroCopy(summary, random: Random(seed));
        expect(copy.headline.trim(), isNotEmpty);
        expect(copy.subline.trim(), isNotEmpty);
      }
    }
  });

  test('leads with the first-session pool before any history exists', () {
    final copy = summaryHeroCopy(_summary(), random: Random(1));
    expect(copy.subline, contains('first session'));
  });

  test('calls out the count when several records land together', () {
    final copy = summaryHeroCopy(
      _summary(
        completedSessionCount: 6,
        previousVolumeKg: 600,
        records: const [_record, _record, _record],
      ),
      random: Random(3),
    );
    expect(copy.subline, '3 personal records in a single session.');
  });

  test('names the exercise behind a single record', () {
    final copy = summaryHeroCopy(
      _summary(completedSessionCount: 6, records: const [_record]),
      random: Random(5),
    );
    expect(copy.subline, 'You beat your best Bench press.');
  });

  test('marks a first-time entry rather than claiming an improvement', () {
    final copy = summaryHeroCopy(
      _summary(
        completedSessionCount: 6,
        records: const [
          WorkoutRecord(
            exerciseName: 'Barbell row',
            kind: WorkoutRecordKind.sessionVolume,
            value: 500,
            previousValue: 0,
          ),
        ],
      ),
      random: Random(7),
    );
    expect(copy.subline, 'First time logging Barbell row.');
  });

  test('reports the volume swing when no record was set', () {
    // 800 kg this session against 400 kg before.
    final up = summaryHeroCopy(
      _summary(completedSessionCount: 3, previousVolumeKg: 400),
      random: Random(11),
    );
    expect(up.subline, '100% more volume than your last session.');

    final down = summaryHeroCopy(
      _summary(completedSessionCount: 3, previousVolumeKg: 1600),
      random: Random(11),
    );
    expect(down.subline, '50% less volume than your last session.');
  });

  test('varies the headline across seeds within a pool', () {
    final summary = _summary(completedSessionCount: 3, previousVolumeKg: 400);
    final seen = <String>{};
    for (var seed = 0; seed < 40; seed++) {
      seen.add(summaryHeroCopy(summary, random: Random(seed)).headline);
    }
    // A pool that always returned one line would defeat the point.
    expect(seen.length, greaterThan(1));
  });
}
