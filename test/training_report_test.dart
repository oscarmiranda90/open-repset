import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:repset/data/memory_body_weight_repository.dart';
import 'package:repset/data/memory_training_analytics_repository.dart';
import 'package:repset/data/memory_workout_repository.dart';
import 'package:repset/domain/body_weight.dart';
import 'package:repset/domain/training_report.dart';
import 'package:repset/domain/workout_session.dart';

void main() {
  test('builds a portable report without account data or notes', () async {
    final workouts = MemoryWorkoutRepository();
    final bodyWeight = MemoryBodyWeightRepository();
    final completedAt = DateTime(2026, 8, 25, 10);
    await workouts.save(
      WorkoutSession(
        id: 'session-1',
        title: 'Private workout title',
        startedAt: completedAt.subtract(const Duration(hours: 1)),
        completedAt: completedAt,
        exercises: [
          WorkoutExercise(
            id: 'entry-1',
            exerciseId: 'bench',
            name: 'Barbell bench press',
            position: 0,
            sets: [
              WorkoutSet(
                id: 'set-1',
                exerciseId: 'bench',
                position: 0,
                repetitions: 5,
                loadKg: 100,
                rpe: 8,
                notes: 'Private set note',
                isCompleted: true,
                completedAt: completedAt,
              ),
            ],
          ),
        ],
      ),
    );
    await bodyWeight.save(
      BodyWeightEntry(measuredOn: completedAt, weightKg: 80, notes: 'Private'),
    );

    final report = await TrainingReportBuilder(
      workouts: workouts,
      analytics: MemoryTrainingAnalyticsRepository(workouts),
      bodyWeight: bodyWeight,
    ).build();
    final json = jsonDecode(report.json) as Map<String, dynamic>;

    expect(json['schema_version'], 1);
    expect(json['overview']['total_sessions'], 1);
    expect(
      json['recent_workouts'].single['exercises'].single['sets'].single['rpe'],
      8,
    );
    expect(report.json, isNot(contains('Private')));
    expect(report.markdown, contains('RepSet training report'));
  });
}
