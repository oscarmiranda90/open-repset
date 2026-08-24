import '../domain/workout_repository.dart';
import '../domain/workout_session.dart';
import '../domain/workout_template.dart';

/// Used only by widget tests and browser previews. Mobile builds use SQLite.
class MemoryWorkoutRepository implements WorkoutRepository {
  final Map<String, WorkoutSession> _sessions = {};
  final Map<String, WorkoutTemplate> _templates = {};

  @override
  Future<WorkoutSession?> getActive() async =>
      _sessions.values.where((session) => session.isActive).firstOrNull;

  @override
  Future<List<WorkoutSession>> getCompletedSessions() async {
    final sessions = _sessions.values
        .where((session) => !session.isActive)
        .toList(growable: false);
    sessions.sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    return sessions;
  }

  @override
  Future<WorkoutSession?> getSession(String sessionId) async =>
      _sessions[sessionId];

  @override
  Future<ExerciseHistoryStats> getExerciseHistory(String exerciseId) async {
    final sessions = _sessions.values.where(
      (session) =>
          !session.isActive &&
          session.exercises.any(
            (exercise) => exercise.exerciseId == exerciseId,
          ),
    );
    final sets = sessions
        .expand((session) => session.exercises)
        .where((exercise) => exercise.exerciseId == exerciseId)
        .expand((exercise) => exercise.sets)
        .where((set) => set.isCompleted)
        .toList(growable: false);
    return ExerciseHistoryStats(
      sessionCount: sessions.length,
      completedSetCount: sets.length,
      bestLoadKg: sets.fold(
        0,
        (best, set) => set.loadKg > best ? set.loadKg : best,
      ),
      totalVolumeKg: sets.fold(
        0,
        (volume, set) => volume + (set.loadKg * set.repetitions),
      ),
    );
  }

  @override
  Future<void> save(WorkoutSession session) async =>
      _sessions[session.id] = session;

  @override
  Future<void> deleteSession(String sessionId) async =>
      _sessions.remove(sessionId);

  @override
  Future<List<WorkoutTemplate>> getTemplates() async {
    final templates = _templates.values
        .where((template) => !template.isArchived)
        .toList(growable: false);
    templates.sort((a, b) {
      if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return templates;
  }

  @override
  Future<void> saveTemplate(WorkoutTemplate template) async =>
      _templates[template.id] = template;

  @override
  Future<void> deleteTemplate(String templateId) async =>
      _templates.remove(templateId);
}
