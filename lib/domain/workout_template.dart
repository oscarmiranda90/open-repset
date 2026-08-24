import 'dart:convert';

import 'workout_session.dart';

class WorkoutTemplate {
  const WorkoutTemplate({
    required this.id,
    required this.title,
    required this.exercises,
    required this.updatedAt,
    this.isArchived = false,
    this.isFavorite = false,
  });

  final String id;
  final String title;
  final List<WorkoutExercise> exercises;
  final DateTime updatedAt;
  final bool isArchived;
  final bool isFavorite;

  String get encodedExercises =>
      jsonEncode(exercises.map(_exerciseJson).toList());

  static List<WorkoutExercise> decodeExercises(String encoded) =>
      (jsonDecode(encoded) as List<Object?>)
          .cast<Map<String, Object?>>()
          .map(_exerciseFromJson)
          .toList(growable: false);

  static Map<String, Object?> _exerciseJson(WorkoutExercise exercise) => {
    'id': exercise.id,
    'exerciseId': exercise.exerciseId,
    'name': exercise.name,
    'position': exercise.position,
    'unit': exercise.weightUnit.name,
    'rest': exercise.restSeconds,
    'superset': exercise.supersetId,
    'notes': exercise.notes,
    'sets': exercise.sets
        .map(
          (set) => {
            'id': set.id,
            'position': set.position,
            'reps': set.repetitions,
            'load': set.loadKg,
            'rpe': set.rpe,
            'notes': set.notes,
            'type': set.type.name,
          },
        )
        .toList(),
  };

  static WorkoutExercise _exerciseFromJson(Map<String, Object?> json) {
    final exerciseId = json['exerciseId']! as String;
    final sets = (json['sets']! as List<Object?>).cast<Map<String, Object?>>();
    return WorkoutExercise(
      id: json['id']! as String,
      exerciseId: exerciseId,
      name: json['name']! as String,
      position: json['position']! as int,
      weightUnit: json['unit'] == 'pounds'
          ? WorkoutWeightUnit.pounds
          : WorkoutWeightUnit.kilograms,
      restSeconds: json['rest']! as int,
      supersetId: json['superset'] as String?,
      notes: json['notes']! as String,
      sets: sets
          .map(
            (set) => WorkoutSet(
              id: set['id']! as String,
              exerciseId: exerciseId,
              position: set['position']! as int,
              repetitions: set['reps']! as int,
              loadKg: (set['load']! as num).toDouble(),
              rpe: (set['rpe'] as num?)?.toDouble(),
              notes: set['notes']! as String,
              type: set['type'] == 'warmup'
                  ? WorkoutSetType.warmup
                  : WorkoutSetType.working,
            ),
          )
          .toList(growable: false),
    );
  }
}
