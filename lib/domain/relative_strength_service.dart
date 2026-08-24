import 'body_weight.dart';
import 'training_analytics.dart';

/// An exercise insight with its bodyweight ratio attached.
class ExerciseInsightWithStrength {
  const ExerciseInsightWithStrength({
    required this.insight,
    required this.relativeStrength,
  });

  final ExerciseInsight insight;

  /// Null when no session for this lift falls on or after a weigh-in.
  final RelativeStrength? relativeStrength;

  bool get hasRelativeStrength => relativeStrength != null;
}

/// Reads training analytics and body weight together.
///
/// Kept out of both repositories on purpose: training history and body weight
/// are separate concerns, and making either depend on the other would couple
/// two independently useful stores. Composition happens here instead.
class RelativeStrengthService {
  const RelativeStrengthService(this._analytics, this._bodyWeight);

  final TrainingAnalyticsRepository _analytics;
  final BodyWeightRepository _bodyWeight;

  /// Exercise insights, each paired with its best bodyweight-relative lift.
  ///
  /// With no weigh-ins recorded every entry simply carries a null ratio — the
  /// training numbers stay intact rather than the whole list disappearing.
  Future<List<ExerciseInsightWithStrength>> getInsights({int limit = 8}) async {
    final insights = await _analytics.getExerciseInsights(limit: limit);
    if (insights.isEmpty) return const [];

    // One read of the weight history, reused for every exercise.
    final weights = await _bodyWeight.getEntries(limit: 365);
    if (weights.isEmpty) {
      return insights
          .map(
            (insight) => ExerciseInsightWithStrength(
              insight: insight,
              relativeStrength: null,
            ),
          )
          .toList(growable: false);
    }

    final results = <ExerciseInsightWithStrength>[];
    for (final insight in insights) {
      final progress = await _analytics.getExerciseProgress(insight.exerciseId);
      results.add(
        ExerciseInsightWithStrength(
          insight: insight,
          relativeStrength: bestRelativeStrength(
            exerciseId: insight.exerciseId,
            exerciseName: insight.exerciseName,
            points: progress
                .map(
                  (point) => (
                    date: point.date,
                    estimatedOneRepMaxKg: point.estimatedOneRepMaxKg,
                  ),
                )
                .toList(growable: false),
            weightsNewestFirst: weights,
          ),
        ),
      );
    }
    return results;
  }
}
