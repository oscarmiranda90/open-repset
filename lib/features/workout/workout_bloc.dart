import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/exercise.dart';
import '../../domain/workout_repository.dart';
import '../../domain/workout_session.dart';
import '../../domain/workout_template.dart';

sealed class WorkoutEvent {
  const WorkoutEvent();
}

class WorkoutRestored extends WorkoutEvent {
  const WorkoutRestored();
}

class WorkoutStarted extends WorkoutEvent {
  const WorkoutStarted({this.title});
  final String? title;
}

class WorkoutStartedFromTemplate extends WorkoutEvent {
  const WorkoutStartedFromTemplate(this.template);
  final WorkoutTemplate template;
}

class WorkoutRenamed extends WorkoutEvent {
  const WorkoutRenamed(this.title);
  final String title;
}

class WorkoutExerciseAdded extends WorkoutEvent {
  const WorkoutExerciseAdded(this.exercise);
  final Exercise exercise;
}

class WorkoutExercisesAdded extends WorkoutEvent {
  const WorkoutExercisesAdded(this.exercises, {this.asSuperset = false});

  final List<Exercise> exercises;
  final bool asSuperset;
}

class WorkoutExerciseRemoved extends WorkoutEvent {
  const WorkoutExerciseRemoved(this.entryId);
  final String entryId;
}

class WorkoutExerciseMoved extends WorkoutEvent {
  const WorkoutExerciseMoved({required this.entryId, required this.toIndex});

  final String entryId;
  final int toIndex;
}

class WorkoutExerciseDuplicated extends WorkoutEvent {
  const WorkoutExerciseDuplicated(this.entryId);
  final String entryId;
}

class WorkoutExerciseReplaced extends WorkoutEvent {
  const WorkoutExerciseReplaced({
    required this.entryId,
    required this.replacement,
  });

  final String entryId;
  final Exercise replacement;
}

class WorkoutExerciseWeightUnitChanged extends WorkoutEvent {
  const WorkoutExerciseWeightUnitChanged({
    required this.entryId,
    required this.weightUnit,
  });

  final String entryId;
  final WorkoutWeightUnit weightUnit;
}

class WorkoutExerciseRestChanged extends WorkoutEvent {
  const WorkoutExerciseRestChanged({
    required this.entryId,
    required this.seconds,
  });

  final String entryId;
  final int seconds;
}

class WorkoutExerciseHistoryRequested extends WorkoutEvent {
  const WorkoutExerciseHistoryRequested(this.exerciseId);
  final String exerciseId;
}

class WorkoutSetAdded extends WorkoutEvent {
  const WorkoutSetAdded(this.entryId);
  final String entryId;
}

class WorkoutSetUpdated extends WorkoutEvent {
  const WorkoutSetUpdated({
    required this.entryId,
    required this.setId,
    required this.repetitions,
    required this.loadKg,
    required this.type,
    this.rpe,
    this.notes = '',
  });

  final String entryId;
  final String setId;
  final int repetitions;
  final double loadKg;
  final double? rpe;
  final String notes;
  final WorkoutSetType type;
}

class WorkoutSetCompletionToggled extends WorkoutEvent {
  const WorkoutSetCompletionToggled({
    required this.entryId,
    required this.setId,
    this.inheritedRepetitions,
    this.inheritedLoadKg,
  });
  final String entryId;
  final String setId;
  final int? inheritedRepetitions;
  final double? inheritedLoadKg;
}

class WorkoutSetRemoved extends WorkoutEvent {
  const WorkoutSetRemoved({required this.entryId, required this.setId});
  final String entryId;
  final String setId;
}

class WorkoutFinished extends WorkoutEvent {
  const WorkoutFinished();
}

class WorkoutState {
  const WorkoutState({
    this.session,
    this.isLoading = false,
    this.isSaving = false,
    this.exerciseHistory = const {},
    this.loadingExerciseHistory = const {},
    this.focusedSetId,
    this.focusSequence = 0,
    this.message,
  });

  final WorkoutSession? session;
  final bool isLoading;
  final bool isSaving;
  final Map<String, ExerciseHistoryStats> exerciseHistory;
  final Set<String> loadingExerciseHistory;
  final String? focusedSetId;
  final int focusSequence;
  final String? message;

  bool get hasActiveSession => session?.isActive ?? false;

  WorkoutState copyWith({
    WorkoutSession? session,
    bool clearSession = false,
    bool? isLoading,
    bool? isSaving,
    Map<String, ExerciseHistoryStats>? exerciseHistory,
    Set<String>? loadingExerciseHistory,
    String? focusedSetId,
    int? focusSequence,
    String? message,
    bool clearMessage = false,
  }) => WorkoutState(
    session: clearSession ? null : session ?? this.session,
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    exerciseHistory: exerciseHistory ?? this.exerciseHistory,
    loadingExerciseHistory:
        loadingExerciseHistory ?? this.loadingExerciseHistory,
    focusedSetId: focusedSetId ?? this.focusedSetId,
    focusSequence: focusSequence ?? this.focusSequence,
    message: clearMessage ? null : message ?? this.message,
  );
}

class WorkoutBloc extends Bloc<WorkoutEvent, WorkoutState> {
  WorkoutBloc(this._repository) : super(const WorkoutState()) {
    on<WorkoutRestored>(_restore);
    on<WorkoutStarted>(_start);
    on<WorkoutStartedFromTemplate>(_startFromTemplate);
    on<WorkoutRenamed>(_rename);
    on<WorkoutExerciseAdded>(_addExercise);
    on<WorkoutExercisesAdded>(_addExercises);
    on<WorkoutExerciseRemoved>(_removeExercise);
    on<WorkoutExerciseMoved>(_moveExercise);
    on<WorkoutExerciseDuplicated>(_duplicateExercise);
    on<WorkoutExerciseReplaced>(_replaceExercise);
    on<WorkoutExerciseWeightUnitChanged>(_changeExerciseWeightUnit);
    on<WorkoutExerciseRestChanged>(_changeExerciseRest);
    on<WorkoutExerciseHistoryRequested>(_loadExerciseHistory);
    on<WorkoutSetAdded>(_addSet);
    on<WorkoutSetUpdated>(_updateSet);
    on<WorkoutSetCompletionToggled>(_toggleSet);
    on<WorkoutSetRemoved>(_removeSet);
    on<WorkoutFinished>(_finish);
  }

  final WorkoutRepository _repository;
  int _idSequence = 0;

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_idSequence++}';

  Future<void> _restore(
    WorkoutRestored event,
    Emitter<WorkoutState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearMessage: true));
    try {
      final active = await _repository.getActive();
      emit(
        state.copyWith(
          session: active,
          clearSession: active == null,
          isLoading: false,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          message: 'The saved workout could not be restored.',
        ),
      );
    }
  }

  Future<void> _start(WorkoutStarted event, Emitter<WorkoutState> emit) async {
    if (state.hasActiveSession) return;
    final session = WorkoutSession(
      id: _newId(),
      title: _normalizedTitle(event.title) ?? "Today's Workout",
      startedAt: DateTime.now(),
      exercises: const [],
    );
    await _save(session, emit);
  }

  Future<void> _startFromTemplate(
    WorkoutStartedFromTemplate event,
    Emitter<WorkoutState> emit,
  ) async {
    if (state.hasActiveSession) return;
    final groupIds = <String, String>{};
    final exercises = event.template.exercises.asMap().entries.map((entry) {
      final source = entry.value;
      final group = source.supersetId;
      final newGroup = group == null
          ? null
          : groupIds.putIfAbsent(group, _newId);
      return WorkoutExercise(
        id: _newId(),
        exerciseId: source.exerciseId,
        name: source.name,
        position: entry.key,
        weightUnit: source.weightUnit,
        restSeconds: source.restSeconds,
        supersetId: newGroup,
        notes: source.notes,
        sets: source.sets
            .asMap()
            .entries
            .map(
              (set) => WorkoutSet(
                id: _newId(),
                exerciseId: source.exerciseId,
                position: set.key,
                repetitions: set.value.repetitions,
                loadKg: set.value.loadKg,
                rpe: set.value.rpe,
                notes: set.value.notes,
                type: set.value.type,
              ),
            )
            .toList(),
      );
    }).toList();
    await _save(
      WorkoutSession(
        id: _newId(),
        title: event.template.title,
        startedAt: DateTime.now(),
        exercises: exercises,
      ),
      emit,
    );
  }

  Future<void> _rename(WorkoutRenamed event, Emitter<WorkoutState> emit) async {
    final active = state.session;
    final title = _normalizedTitle(event.title);
    if (active == null || title == null || title == active.title) return;
    await _save(active.copyWith(title: title), emit);
  }

  Future<void> _addExercise(
    WorkoutExerciseAdded event,
    Emitter<WorkoutState> emit,
  ) => _addExerciseEntries([event.exercise], asSuperset: false, emit: emit);

  Future<void> _addExercises(
    WorkoutExercisesAdded event,
    Emitter<WorkoutState> emit,
  ) => _addExerciseEntries(
    event.exercises,
    asSuperset: event.asSuperset,
    emit: emit,
  );

  Future<void> _addExerciseEntries(
    List<Exercise> catalogExercises, {
    required bool asSuperset,
    required Emitter<WorkoutState> emit,
  }) async {
    final active = state.session;
    if (active == null || catalogExercises.isEmpty) return;
    if (asSuperset && catalogExercises.length != 2) return;
    final supersetId = asSuperset ? _newId() : null;
    final entries = catalogExercises.indexed
        .map((item) {
          final entryId = _newId();
          return WorkoutExercise(
            id: entryId,
            exerciseId: item.$2.id,
            name: item.$2.name,
            position: active.exercises.length + item.$1,
            supersetId: supersetId,
            sets: [
              WorkoutSet(id: _newId(), exerciseId: item.$2.id, position: 0),
            ],
          );
        })
        .toList(growable: false);
    await _save(
      active.copyWith(exercises: [...active.exercises, ...entries]),
      emit,
    );
  }

  Future<void> _removeExercise(
    WorkoutExerciseRemoved event,
    Emitter<WorkoutState> emit,
  ) async {
    final active = state.session;
    if (active == null) return;
    var exercises = active.exercises
        .where((exercise) => exercise.id != event.entryId)
        .toList(growable: false)
        .asMap()
        .entries
        .map((entry) => entry.value.copyWith(position: entry.key))
        .toList(growable: false);
    final groupCounts = <String, int>{};
    for (final exercise in exercises) {
      final groupId = exercise.supersetId;
      if (groupId != null) {
        groupCounts[groupId] = (groupCounts[groupId] ?? 0) + 1;
      }
    }
    exercises = exercises
        .map(
          (exercise) =>
              exercise.supersetId != null &&
                  groupCounts[exercise.supersetId] == 1
              ? exercise.copyWith(clearSuperset: true)
              : exercise,
        )
        .toList(growable: false);
    await _save(active.copyWith(exercises: exercises), emit);
  }

  Future<void> _changeExerciseWeightUnit(
    WorkoutExerciseWeightUnitChanged event,
    Emitter<WorkoutState> emit,
  ) async {
    final active = state.session;
    if (active == null) return;
    final exercises = active.exercises
        .map(
          (exercise) => exercise.id == event.entryId
              ? exercise.copyWith(weightUnit: event.weightUnit)
              : exercise,
        )
        .toList(growable: false);
    await _save(active.copyWith(exercises: exercises), emit);
  }

  Future<void> _moveExercise(
    WorkoutExerciseMoved event,
    Emitter<WorkoutState> emit,
  ) async {
    final active = state.session;
    if (active == null) return;
    final sourceIndex = active.exercises.indexWhere(
      (exercise) => exercise.id == event.entryId,
    );
    if (sourceIndex < 0) return;
    final source = active.exercises[sourceIndex];
    final moving = source.supersetId == null
        ? [source]
        : active.exercises
              .where((exercise) => exercise.supersetId == source.supersetId)
              .toList(growable: false);
    final remaining = active.exercises
        .where((exercise) => !moving.any((item) => item.id == exercise.id))
        .toList();
    final originalTarget = event.toIndex.clamp(0, active.exercises.length);
    final beforeTarget = active.exercises
        .take(originalTarget)
        .where((exercise) => !moving.any((item) => item.id == exercise.id))
        .length;
    final target = beforeTarget.clamp(0, remaining.length);
    remaining.insertAll(target, moving);
    final reordered = remaining
        .asMap()
        .entries
        .map((entry) => entry.value.copyWith(position: entry.key))
        .toList(growable: false);
    await _save(active.copyWith(exercises: reordered), emit);
  }

  Future<void> _duplicateExercise(
    WorkoutExerciseDuplicated event,
    Emitter<WorkoutState> emit,
  ) async {
    final active = state.session;
    if (active == null) return;
    final index = active.exercises.indexWhere(
      (item) => item.id == event.entryId,
    );
    if (index < 0) return;
    final source = active.exercises[index];
    final duplicate = WorkoutExercise(
      id: _newId(),
      exerciseId: source.exerciseId,
      name: source.name,
      position: index + 1,
      weightUnit: source.weightUnit,
      restSeconds: source.restSeconds,
      notes: source.notes,
      sets: source.sets
          .asMap()
          .entries
          .map(
            (entry) => WorkoutSet(
              id: _newId(),
              exerciseId: source.exerciseId,
              position: entry.key,
              repetitions: entry.value.repetitions,
              loadKg: entry.value.loadKg,
              rpe: entry.value.rpe,
              notes: entry.value.notes,
              type: entry.value.type,
            ),
          )
          .toList(growable: false),
    );
    final exercises = [...active.exercises]..insert(index + 1, duplicate);
    await _save(
      active.copyWith(
        exercises: exercises
            .asMap()
            .entries
            .map((entry) => entry.value.copyWith(position: entry.key))
            .toList(growable: false),
      ),
      emit,
    );
  }

  Future<void> _replaceExercise(
    WorkoutExerciseReplaced event,
    Emitter<WorkoutState> emit,
  ) async {
    final active = state.session;
    if (active == null) return;
    final exercises = active.exercises
        .map(
          (exercise) => exercise.id == event.entryId
              ? WorkoutExercise(
                  id: exercise.id,
                  exerciseId: event.replacement.id,
                  name: event.replacement.name,
                  position: exercise.position,
                  weightUnit: exercise.weightUnit,
                  restSeconds: exercise.restSeconds,
                  notes: exercise.notes,
                  sets: [
                    WorkoutSet(
                      id: _newId(),
                      exerciseId: event.replacement.id,
                      position: 0,
                    ),
                  ],
                )
              : exercise,
        )
        .toList(growable: false);
    await _save(active.copyWith(exercises: exercises), emit);
  }

  Future<void> _loadExerciseHistory(
    WorkoutExerciseHistoryRequested event,
    Emitter<WorkoutState> emit,
  ) async {
    if (state.loadingExerciseHistory.contains(event.exerciseId)) return;
    emit(
      state.copyWith(
        loadingExerciseHistory: {
          ...state.loadingExerciseHistory,
          event.exerciseId,
        },
      ),
    );
    try {
      final stats = await _repository.getExerciseHistory(event.exerciseId);
      emit(
        state.copyWith(
          exerciseHistory: {...state.exerciseHistory, event.exerciseId: stats},
          loadingExerciseHistory: {...state.loadingExerciseHistory}
            ..remove(event.exerciseId),
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          loadingExerciseHistory: {...state.loadingExerciseHistory}
            ..remove(event.exerciseId),
          message: 'Previous exercise stats could not be loaded.',
        ),
      );
    }
  }

  Future<void> _changeExerciseRest(
    WorkoutExerciseRestChanged event,
    Emitter<WorkoutState> emit,
  ) async {
    if (event.seconds < 15 || event.seconds > 600) return;
    final active = state.session;
    if (active == null) return;
    final exercises = active.exercises
        .map(
          (exercise) => exercise.id == event.entryId
              ? exercise.copyWith(restSeconds: event.seconds)
              : exercise,
        )
        .toList(growable: false);
    await _save(active.copyWith(exercises: exercises), emit);
  }

  Future<void> _addSet(
    WorkoutSetAdded event,
    Emitter<WorkoutState> emit,
  ) async {
    final active = state.session;
    if (active == null) return;
    final target = active.exercises.firstWhere(
      (exercise) => exercise.id == event.entryId,
    );
    final exercises = active.exercises
        .map((exercise) {
          final belongsToTarget = exercise.id == event.entryId;
          final belongsToSuperset =
              target.supersetId != null &&
              exercise.supersetId == target.supersetId;
          if (!belongsToTarget && !belongsToSuperset) return exercise;
          final previous = exercise.sets.lastOrNull;
          final set = WorkoutSet(
            id: _newId(),
            exerciseId: exercise.exerciseId,
            position: exercise.sets.length,
            type: previous?.type ?? WorkoutSetType.working,
          );
          return exercise.copyWith(sets: [...exercise.sets, set]);
        })
        .toList(growable: false);
    await _save(active.copyWith(exercises: exercises), emit);
  }

  Future<void> _updateSet(
    WorkoutSetUpdated event,
    Emitter<WorkoutState> emit,
  ) async {
    if (event.repetitions < 0 || event.loadKg < 0) return;
    if (event.rpe != null && (event.rpe! < 6 || event.rpe! > 10)) return;
    final active = state.session;
    if (active == null) return;
    final exercises = active.exercises
        .map((exercise) {
          if (exercise.id != event.entryId) return exercise;
          return exercise.copyWith(
            sets: exercise.sets
                .map(
                  (set) => set.id == event.setId
                      ? set.copyWith(
                          repetitions: event.repetitions,
                          loadKg: event.loadKg,
                          rpe: event.rpe,
                          clearRpe: event.rpe == null,
                          notes: event.notes,
                          type: event.type,
                        )
                      : set,
                )
                .toList(growable: false),
          );
        })
        .toList(growable: false);
    await _save(active.copyWith(exercises: exercises), emit);
  }

  Future<void> _toggleSet(
    WorkoutSetCompletionToggled event,
    Emitter<WorkoutState> emit,
  ) async {
    final active = state.session;
    if (active == null) return;
    final sourceExercise = active.exercises.firstWhere(
      (exercise) => exercise.id == event.entryId,
    );
    final sourceSet = sourceExercise.sets.firstWhere(
      (set) => set.id == event.setId,
    );
    final wasCompleting = !sourceSet.isCompleted;
    var invalid = false;
    final exercises = active.exercises
        .map((exercise) {
          if (exercise.id != event.entryId) return exercise;
          return exercise.copyWith(
            sets: exercise.sets
                .map((set) {
                  if (set.id != event.setId) return set;
                  final repetitions = !set.isCompleted && set.repetitions <= 0
                      ? event.inheritedRepetitions ?? 0
                      : set.repetitions;
                  final loadKg = !set.isCompleted && set.loadKg == 0
                      ? event.inheritedLoadKg ?? 0
                      : set.loadKg;
                  if (!set.isCompleted && repetitions <= 0) {
                    invalid = true;
                    return set;
                  }
                  final completed = !set.isCompleted;
                  return set.copyWith(
                    repetitions: repetitions,
                    loadKg: loadKg,
                    isCompleted: completed,
                    completedAt: completed ? DateTime.now() : null,
                    clearCompletedAt: !completed,
                  );
                })
                .toList(growable: false),
          );
        })
        .toList(growable: false);
    if (invalid) {
      emit(state.copyWith(message: 'Add at least one repetition first.'));
      return;
    }
    await _save(active.copyWith(exercises: exercises), emit);
    if (wasCompleting) {
      final nextSetId = _nextSetId(
        exercises,
        entryId: event.entryId,
        setPosition: sourceSet.position,
      );
      if (nextSetId != null) {
        emit(
          state.copyWith(
            focusedSetId: nextSetId,
            focusSequence: state.focusSequence + 1,
          ),
        );
      }
    }
  }

  String? _nextSetId(
    List<WorkoutExercise> exercises, {
    required String entryId,
    required int setPosition,
  }) {
    final current = exercises.firstWhere((exercise) => exercise.id == entryId);
    final groupId = current.supersetId;
    if (groupId == null) {
      return current.sets
          .where((set) => set.position == setPosition + 1)
          .firstOrNull
          ?.id;
    }
    final group =
        exercises
            .where((exercise) => exercise.supersetId == groupId)
            .toList(growable: false)
          ..sort((a, b) => a.position.compareTo(b.position));
    final currentIndex = group.indexWhere((exercise) => exercise.id == entryId);
    if (currentIndex < group.length - 1) {
      return group[currentIndex + 1].sets
          .where((set) => set.position == setPosition)
          .firstOrNull
          ?.id;
    }
    return group.first.sets
        .where((set) => set.position == setPosition + 1)
        .firstOrNull
        ?.id;
  }

  Future<void> _removeSet(
    WorkoutSetRemoved event,
    Emitter<WorkoutState> emit,
  ) async {
    final active = state.session;
    if (active == null) return;
    final targetExercise = active.exercises.firstWhere(
      (exercise) => exercise.id == event.entryId,
    );
    final targetSet = targetExercise.sets.firstWhere(
      (set) => set.id == event.setId,
    );
    final exercises = active.exercises
        .map((exercise) {
          final belongsToTarget = exercise.id == event.entryId;
          final belongsToSuperset =
              targetExercise.supersetId != null &&
              exercise.supersetId == targetExercise.supersetId;
          if (!belongsToTarget && !belongsToSuperset) return exercise;
          final sets = exercise.sets
              .where(
                (set) => belongsToTarget
                    ? set.id != event.setId
                    : set.position != targetSet.position,
              )
              .toList(growable: false)
              .asMap()
              .entries
              .map((entry) => entry.value.copyWith(position: entry.key))
              .toList(growable: false);
          return exercise.copyWith(sets: sets);
        })
        .toList(growable: false);
    await _save(active.copyWith(exercises: exercises), emit);
  }

  Future<void> _finish(
    WorkoutFinished event,
    Emitter<WorkoutState> emit,
  ) async {
    final active = state.session;
    if (active == null) return;
    await _repository.save(active.copyWith(completedAt: DateTime.now()));
    emit(const WorkoutState());
  }

  Future<void> _save(WorkoutSession session, Emitter<WorkoutState> emit) async {
    emit(state.copyWith(session: session, isSaving: true, clearMessage: true));
    try {
      await _repository.save(session);
      emit(state.copyWith(session: session, isSaving: false));
    } catch (_) {
      emit(
        state.copyWith(
          session: session,
          isSaving: false,
          message: 'This workout change could not be saved.',
        ),
      );
    }
  }

  String? _normalizedTitle(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized.length <= 60 ? normalized : normalized.substring(0, 60);
  }
}
