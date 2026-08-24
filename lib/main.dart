import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:repset/app/repset_app.dart';
import 'package:repset/core/notifications/rest_notification_service.dart';
import 'package:repset/core/database/app_database.dart';
import 'package:repset/data/demo_exercise_repository.dart';
import 'package:repset/data/r2_exercise_source.dart';
import 'package:repset/data/memory_workout_repository.dart';
import 'package:repset/data/offline_first_exercise_repository.dart';
import 'package:repset/data/sqlite_body_weight_repository.dart';
import 'package:repset/data/sqlite_exercise_store.dart';
import 'package:repset/data/sqlite_muscle_coverage_repository.dart';
import 'package:repset/data/sqlite_training_analytics_repository.dart';
import 'package:repset/data/sqlite_workout_repository.dart';
import 'package:repset/domain/body_weight.dart';
import 'package:repset/domain/exercise_repository.dart';
import 'package:repset/domain/muscle_map.dart';
import 'package:repset/domain/training_analytics.dart';
import 'package:repset/domain/workout_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RestNotificationService.initialize();

  ExerciseRepository exerciseRepository = DemoExerciseRepository();
  WorkoutRepository workoutRepository = MemoryWorkoutRepository();
  TrainingAnalyticsRepository? analyticsRepository;
  BodyWeightRepository? bodyWeightRepository;
  MuscleCoverageRepository? muscleCoverageRepository;

  if (!kIsWeb) {
    try {
      final database = AppDatabase.open();
      workoutRepository = SqliteWorkoutRepository(database);
      // Aggregates in SQL rather than loading a training history into memory
      // to sum it, so cost stays flat as the history grows.
      analyticsRepository = SqliteTrainingAnalyticsRepository(database);
      bodyWeightRepository = SqliteBodyWeightRepository(database);
      muscleCoverageRepository = SqliteMuscleCoverageRepository(database);

      if ((defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS) &&
          R2ExerciseSource.isConfigured) {
        exerciseRepository = OfflineFirstExerciseRepository(
          SqliteExerciseStore(database),
          R2ExerciseSource(),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Startup fallback activated: $error\n$stackTrace');
    }
  }

  runApp(
    RepSetApp(
      exerciseRepository: exerciseRepository,
      workoutRepository: workoutRepository,
      analyticsRepository: analyticsRepository,
      bodyWeightRepository: bodyWeightRepository,
      muscleCoverageRepository: muscleCoverageRepository,
    ),
  );
}
