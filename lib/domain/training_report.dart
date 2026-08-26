import 'dart:convert';

import 'body_weight.dart';
import 'training_analytics.dart';
import 'workout_repository.dart';
import 'workout_session.dart';

/// A portable, read-only snapshot a person can explicitly share with a coach
/// or an LLM. It deliberately excludes account details and free-form notes.
class TrainingReport {
  const TrainingReport({required this.markdown, required this.json});

  final String markdown;
  final String json;
}

class TrainingReportBuilder {
  const TrainingReportBuilder({
    required this.workouts,
    required this.analytics,
    required this.bodyWeight,
  });

  final WorkoutRepository workouts;
  final TrainingAnalyticsRepository analytics;
  final BodyWeightRepository bodyWeight;

  Future<TrainingReport> build({int weeks = 12}) async {
    final result = await Future.wait<Object?>([
      analytics.getOverview(),
      analytics.getWeeklyVolume(weeks: weeks),
      analytics.getExerciseInsights(),
      analytics.getMuscleGroupShares(),
      analytics.getMedianRestBetweenSets(),
      workouts.getCompletedSessions(),
      bodyWeight.getEntries(),
    ]);
    final overview = result[0] as TrainingOverview;
    final volume = result[1] as List<TrainingPoint>;
    final insights = result[2] as List<ExerciseInsight>;
    final muscles = result[3] as List<MuscleGroupShare>;
    final medianRest = result[4] as Duration?;
    final sessions = result[5] as List<WorkoutSession>;
    final weights = result[6] as List<BodyWeightEntry>;
    final generatedAt = DateTime.now().toIso8601String();

    final payload = <String, Object?>{
      'schema_version': 1,
      'generated_at': generatedAt,
      'period_weeks': weeks,
      'privacy': {
        'includes': ['workout history', 'body weight', 'RPE'],
        'excludes': ['account identity', 'exercise notes'],
      },
      'overview': {
        'total_sessions': overview.totalSessions,
        'sessions_this_week': overview.sessionsThisWeek,
        'sessions_last_week': overview.sessionsLastWeek,
        'total_volume_kg': overview.totalVolumeKg,
        'volume_this_week_kg': overview.volumeThisWeekKg,
        'volume_last_week_kg': overview.volumeLastWeekKg,
        'total_sets': overview.totalSets,
        'total_reps': overview.totalReps,
        'average_session_duration_minutes':
            overview.averageSessionDuration.inMinutes,
        'current_streak_weeks': overview.currentStreakWeeks,
      },
      'weekly_volume': volume
          .map(
            (point) => {
              'week_start': _date(point.date),
              'volume_kg': point.volumeKg,
              'sets': point.setCount,
              'sessions': point.sessionCount,
            },
          )
          .toList(growable: false),
      'muscle_distribution': muscles
          .map(
            (muscle) => {
              'muscle': muscle.target,
              'volume_kg': muscle.volumeKg,
              'sets': muscle.setCount,
              'share': muscle.share,
            },
          )
          .toList(growable: false),
      'exercise_insights': insights
          .map(
            (insight) => {
              'exercise': insight.exerciseName,
              'sessions': insight.sessionCount,
              'last_performed': insight.lastPerformedAt == null
                  ? null
                  : _date(insight.lastPerformedAt!),
              'best_load_kg': insight.bestLoadKg,
              'best_estimated_1rm_kg': insight.bestEstimatedOneRepMaxKg,
              'total_volume_kg': insight.totalVolumeKg,
              'trend': insight.trend.name,
              'trend_change': insight.trendChange,
            },
          )
          .toList(growable: false),
      'median_rest_seconds': medianRest?.inSeconds,
      'body_weight_kg': weights
          .map(
            (weight) => {
              'date': _date(weight.measuredOn),
              'kg': weight.weightKg,
            },
          )
          .toList(growable: false),
      'recent_workouts': sessions
          .take(30)
          .map((session) {
            return {
              'started_at': session.startedAt.toIso8601String(),
              'completed_at': session.completedAt?.toIso8601String(),
              'duration_minutes': session.completedAt
                  ?.difference(session.startedAt)
                  .inMinutes,
              'exercises': session.exercises
                  .map((exercise) {
                    return {
                      'name': exercise.name,
                      'sets': exercise.sets
                          .where((set) => set.isCompleted)
                          .map(
                            (set) => {
                              'type': set.type.name,
                              'reps': set.repetitions,
                              'load_kg': set.loadKg,
                              'rpe': set.rpe,
                            },
                          )
                          .toList(growable: false),
                    };
                  })
                  .toList(growable: false),
            };
          })
          .toList(growable: false),
    };

    return TrainingReport(
      json: const JsonEncoder.withIndent('  ').convert(payload),
      markdown: _markdown(
        overview: overview,
        volume: volume,
        insights: insights,
        muscles: muscles,
        medianRest: medianRest,
        generatedAt: generatedAt,
        weeks: weeks,
      ),
    );
  }

  String _markdown({
    required TrainingOverview overview,
    required List<TrainingPoint> volume,
    required List<ExerciseInsight> insights,
    required List<MuscleGroupShare> muscles,
    required Duration? medianRest,
    required String generatedAt,
    required int weeks,
  }) {
    final lines = <String>[
      '# RepSet training report',
      '',
      'Generated: $generatedAt',
      'Window: last $weeks weeks',
      '',
      '## Overview',
      '- ${overview.totalSessions} completed sessions',
      '- ${_number(overview.totalVolumeKg)} kg total volume',
      '- ${overview.sessionsThisWeek} sessions this week (${_number(overview.volumeThisWeekKg)} kg)',
      '- ${overview.totalSets} completed sets · ${overview.totalReps} reps',
      '- ${overview.averageSessionDuration.inMinutes} min average session',
      '- ${overview.currentStreakWeeks}-week current streak',
      if (medianRest != null)
        '- ${medianRest.inSeconds}s median rest between sets',
      '',
      '## Weekly volume',
      for (final point in volume)
        '- ${_date(point.date)}: ${_number(point.volumeKg)} kg · ${point.setCount} sets · ${point.sessionCount} sessions',
      '',
      '## Exercise trends',
      for (final insight in insights)
        '- ${insight.exerciseName}: ${insight.trend.name}; best ${_number(insight.bestLoadKg)} kg; estimated 1RM ${_number(insight.bestEstimatedOneRepMaxKg)} kg',
      '',
      '## Muscle distribution',
      for (final muscle in muscles)
        '- ${muscle.target}: ${(muscle.share * 100).toStringAsFixed(0)}% · ${muscle.setCount} sets',
      '',
      '_This report excludes account identity and free-form notes. Interpret training recommendations with context and professional judgment._',
    ];
    return lines.join('\n');
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}
