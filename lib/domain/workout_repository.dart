import 'workout_session.dart';
import 'workout_template.dart';

class ExerciseHistoryStats {
  const ExerciseHistoryStats({
    this.sessionCount = 0,
    this.completedSetCount = 0,
    this.bestLoadKg = 0,
    this.totalVolumeKg = 0,
  });

  final int sessionCount;
  final int completedSetCount;
  final double bestLoadKg;
  final double totalVolumeKg;

  bool get hasHistory => sessionCount > 0;
}

abstract interface class WorkoutRepository {
  Future<WorkoutSession?> getActive();
  Future<List<WorkoutSession>> getCompletedSessions();
  Future<WorkoutSession?> getSession(String sessionId);
  Future<ExerciseHistoryStats> getExerciseHistory(String exerciseId);
  Future<void> save(WorkoutSession session);
  Future<void> deleteSession(String sessionId);
  Future<List<WorkoutTemplate>> getTemplates();
  Future<void> saveTemplate(WorkoutTemplate template);
  Future<void> deleteTemplate(String templateId);
}
