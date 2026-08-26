import '../domain/exercise.dart';
import '../domain/exercise_repository.dart';

class DemoExerciseRepository implements ExerciseRepository {
  List<Exercise> _exercises = const [
    Exercise(
      id: 'barbell-bench-press',
      name: 'Barbell bench press',
      bodyPart: 'Upper body',
      target: 'Chest',
      equipment: 'Barbell',
      secondaryMuscles: ['Triceps', 'Shoulders'],
      instructions: [
        'Set your shoulder blades against the bench.',
        'Lower the bar to your lower chest with control.',
        'Press evenly until your arms are extended.',
      ],
    ),
    Exercise(
      id: 'romanian-deadlift',
      name: 'Romanian deadlift',
      bodyPart: 'Lower body',
      target: 'Hamstrings',
      equipment: 'Barbell',
      secondaryMuscles: ['Glutes', 'Lower back'],
      instructions: [
        'Hinge at the hips with soft knees.',
        'Keep the bar close to your legs.',
        'Stand tall without leaning backward.',
      ],
    ),
    Exercise(
      id: 'lat-pulldown',
      name: 'Lat pulldown',
      bodyPart: 'Upper body',
      target: 'Lats',
      equipment: 'Cable',
      secondaryMuscles: ['Biceps'],
      instructions: [
        'Brace your torso and keep your chest tall.',
        'Pull the bar toward your upper chest.',
        'Control the return to full reach.',
      ],
    ),
  ];

  @override
  Future<List<Exercise>> loadCached(String languageCode) async => _exercises;

  @override
  Future<List<Exercise>> refresh(String languageCode) async => _exercises;

  @override
  Future<void> saveCustom(String languageCode, Exercise exercise) async {
    _exercises = [
      ..._exercises.where((item) => item.id != exercise.id),
      exercise,
    ];
  }

  @override
  Future<void> setFavorite(
    String exerciseId, {
    required bool isFavorite,
  }) async {
    _exercises = _exercises
        .map(
          (exercise) => exercise.id == exerciseId
              ? exercise.copyWith(isFavorite: isFavorite)
              : exercise,
        )
        .toList(growable: false);
  }
}
