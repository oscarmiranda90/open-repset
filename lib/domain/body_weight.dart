/// Body weight tracking.
///
/// Stored as a series rather than a single profile value: relative strength is
/// only meaningful against the weight the athlete carried on the day of the
/// lift, so overwriting one number would silently rewrite every past ratio.
library;

/// A single weigh-in, keyed to the local day it was taken.
class BodyWeightEntry {
  BodyWeightEntry({
    required DateTime measuredOn,
    required this.weightKg,
    this.notes = '',
  }) : measuredOn = DateTime(measuredOn.year, measuredOn.month, measuredOn.day),
       assert(weightKg > 0 && weightKg < 500, 'implausible body weight');

  /// Local midnight of the day of the weigh-in.
  final DateTime measuredOn;

  /// Canonical kilograms, matching how set loads are stored. Display units are
  /// a presentation concern, never a storage one.
  final double weightKg;

  final String notes;

  BodyWeightEntry copyWith({double? weightKg, String? notes}) =>
      BodyWeightEntry(
        measuredOn: measuredOn,
        weightKg: weightKg ?? this.weightKg,
        notes: notes ?? this.notes,
      );
}

/// Weight movement over a window, for the trend readout.
class BodyWeightTrend {
  const BodyWeightTrend({
    required this.latest,
    required this.earliest,
    required this.entryCount,
  });

  final BodyWeightEntry? latest;
  final BodyWeightEntry? earliest;
  final int entryCount;

  bool get hasHistory => latest != null;

  /// Needs two weigh-ins on different days before it will claim a direction.
  bool get canCompare =>
      latest != null &&
      earliest != null &&
      latest!.measuredOn.isAfter(earliest!.measuredOn);

  double get changeKg => canCompare ? latest!.weightKg - earliest!.weightKg : 0;

  /// Fractional change over the window, or 0 without a baseline.
  double get changeFraction =>
      canCompare && earliest!.weightKg > 0 ? changeKg / earliest!.weightKg : 0;

  int get spanDays => canCompare
      ? latest!.measuredOn.difference(earliest!.measuredOn).inDays
      : 0;
}

/// A lift expressed against the athlete's own weight.
class RelativeStrength {
  const RelativeStrength({
    required this.exerciseId,
    required this.exerciseName,
    required this.estimatedOneRepMaxKg,
    required this.bodyWeightKg,
    required this.achievedOn,
  });

  final String exerciseId;
  final String exerciseName;
  final double estimatedOneRepMaxKg;

  /// Body weight in effect on [achievedOn] — not today's weight.
  final double bodyWeightKg;

  final DateTime achievedOn;

  /// Multiples of body weight. 1.5 means a 1.5x bodyweight lift.
  double get ratio =>
      bodyWeightKg > 0 ? estimatedOneRepMaxKg / bodyWeightKg : 0;
}

/// Reads and writes body-weight history.
abstract interface class BodyWeightRepository {
  /// Newest first.
  Future<List<BodyWeightEntry>> getEntries({int limit = 90});

  Future<BodyWeightEntry?> getLatest();

  /// The weight in effect on [date]: the most recent weigh-in at or before it.
  ///
  /// Returns null when the athlete had not weighed in yet, which is the honest
  /// answer — carrying today's weight backwards would fabricate the ratio.
  Future<BodyWeightEntry?> getEntryFor(DateTime date);

  /// Upserts by day, so a second weigh-in on the same date replaces the first.
  Future<void> save(BodyWeightEntry entry);

  Future<void> delete(DateTime measuredOn);

  /// Movement across the last [days], for the trend readout.
  Future<BodyWeightTrend> getTrend({int days = 90});
}

/// Picks the weigh-in in effect on [date] from a list ordered newest first.
///
/// Shared so every implementation resolves "the weight that day" identically.
BodyWeightEntry? resolveWeightFor(
  List<BodyWeightEntry> newestFirst,
  DateTime date,
) {
  final target = DateTime(date.year, date.month, date.day);
  for (final entry in newestFirst) {
    if (!entry.measuredOn.isAfter(target)) return entry;
  }
  return null;
}

/// One point of an exercise's progression, reduced to what relative strength
/// needs: when it happened and the estimated one-rep max.
typedef StrengthPoint = ({DateTime date, double estimatedOneRepMaxKg});

/// Best bodyweight-relative lift, pairing each session with the weight the
/// athlete actually carried that day.
///
/// Sessions logged before the first weigh-in are skipped rather than matched
/// against a later measurement: a ratio computed from a weight the athlete did
/// not have yet is a fabricated number, and a missing entry is the honest
/// result.
RelativeStrength? bestRelativeStrength({
  required String exerciseId,
  required String exerciseName,
  required List<StrengthPoint> points,
  required List<BodyWeightEntry> weightsNewestFirst,
}) {
  RelativeStrength? best;
  for (final point in points) {
    if (point.estimatedOneRepMaxKg <= 0) continue;
    final weight = resolveWeightFor(weightsNewestFirst, point.date);
    if (weight == null || weight.weightKg <= 0) continue;

    final candidate = RelativeStrength(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      estimatedOneRepMaxKg: point.estimatedOneRepMaxKg,
      bodyWeightKg: weight.weightKg,
      achievedOn: point.date,
    );
    if (best == null || candidate.ratio > best.ratio) best = candidate;
  }
  return best;
}
