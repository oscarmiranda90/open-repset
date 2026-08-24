import 'dart:math';

import '../../../domain/workout_summary.dart';

/// Hero line shown at the top of the finished-workout modal.
///
/// The pool is chosen from what actually happened, then one line is picked at
/// random within it. A generic cheer after three personal records reads as
/// canned, so the tone follows the session instead of ignoring it.
class SummaryHeroCopy {
  const SummaryHeroCopy({required this.headline, required this.subline});

  final String headline;
  final String subline;
}

const _firstSession = ['Day one.', 'It starts here.', 'First one logged.'];

const _multipleRecords = [
  'Records broken.',
  'New territory.',
  'That was a statement.',
];

const _singleRecord = [
  'New personal best.',
  'You moved the bar.',
  'That is a PR.',
];

const _volumeUp = [
  'Amazing work!',
  'Stronger than last time.',
  'You outworked yesterday.',
];

const _steady = [
  'Session banked.',
  'Work is work.',
  'Another one in the books.',
];

const _light = [
  'Showed up anyway.',
  'Consistency counts.',
  'Kept the streak alive.',
];

/// Picks the hero copy for [summary]. Pass [random] to make the choice
/// deterministic in tests.
SummaryHeroCopy summaryHeroCopy(WorkoutSummary summary, {Random? random}) {
  final chooser = random ?? Random();
  final records = summary.records.length;

  final pool = switch (summary) {
    _ when summary.isFirstSession => _firstSession,
    _ when records >= 2 => _multipleRecords,
    _ when records == 1 => _singleRecord,
    _ when summary.hasVolumeComparison && summary.volumeDelta > .02 =>
      _volumeUp,
    _ when summary.hasVolumeComparison && summary.volumeDelta < -.15 => _light,
    _ => _steady,
  };

  return SummaryHeroCopy(
    headline: pool[chooser.nextInt(pool.length)],
    subline: _subline(summary),
  );
}

String _subline(WorkoutSummary summary) {
  if (summary.isFirstSession) {
    return 'Your first session is saved. Every future one compares to this.';
  }
  final records = summary.records.length;
  if (records >= 2) {
    return '$records personal records in a single session.';
  }
  if (records == 1) {
    final record = summary.records.single;
    return record.isFirstTime
        ? 'First time logging ${record.exerciseName}.'
        : 'You beat your best ${record.exerciseName}.';
  }
  if (!summary.hasVolumeComparison) {
    return 'Session number ${summary.completedSessionCount + 1}.';
  }
  final percent = (summary.volumeDelta.abs() * 100).round();
  if (percent < 1) return 'Volume matched your last session exactly.';
  return summary.volumeDelta > 0
      ? '$percent% more volume than your last session.'
      : '$percent% less volume than your last session.';
}
