import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/exercise.dart';
import '../../domain/exercise_repository.dart';

sealed class LibraryEvent {
  const LibraryEvent();
}

class LibraryStarted extends LibraryEvent {
  const LibraryStarted({this.languageCode = 'en'});
  final String languageCode;
}

class LibraryRefreshed extends LibraryEvent {
  const LibraryRefreshed();
}

class LibrarySearchChanged extends LibraryEvent {
  const LibrarySearchChanged(this.query);
  final String query;
}

class LibraryTargetChanged extends LibraryEvent {
  const LibraryTargetChanged(this.target);
  final String? target;
}

class LibraryEquipmentChanged extends LibraryEvent {
  const LibraryEquipmentChanged(this.equipment);
  final String? equipment;
}

class LibraryFavoritesChanged extends LibraryEvent {
  const LibraryFavoritesChanged(this.onlyFavorites);
  final bool onlyFavorites;
}

class LibraryFavoriteToggled extends LibraryEvent {
  const LibraryFavoriteToggled(this.exercise);
  final Exercise exercise;
}

class LibraryCustomExerciseCreated extends LibraryEvent {
  const LibraryCustomExerciseCreated(this.exercise);
  final Exercise exercise;
}

class LibraryState {
  const LibraryState({
    this.exercises = const [],
    this.query = '',
    this.languageCode = 'en',
    this.isLoading = false,
    this.isRefreshing = false,
    this.onlyFavorites = false,
    this.selectedTarget,
    this.selectedEquipment,
    this.message,
  });

  final List<Exercise> exercises;
  final String query;
  final String languageCode;
  final bool isLoading;
  final bool isRefreshing;
  final bool onlyFavorites;
  final String? selectedTarget;
  final String? selectedEquipment;
  final String? message;

  List<String> get targets =>
      exercises
          .map((exercise) => exercise.target)
          .where((target) => target.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

  List<String> get equipment =>
      exercises
          .map((exercise) => exercise.equipment)
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

  List<Exercise> get visibleExercises {
    final normalizedQuery = _normalize(query.trim());
    final filtered = exercises
        .where((exercise) {
          if (onlyFavorites && !exercise.isFavorite) return false;
          if (selectedTarget != null && exercise.target != selectedTarget) {
            return false;
          }
          if (selectedEquipment != null &&
              exercise.equipment != selectedEquipment) {
            return false;
          }
          if (normalizedQuery.isEmpty) return true;
          return [
            exercise.name,
            exercise.target,
            exercise.bodyPart,
            exercise.equipment,
            ...exercise.secondaryMuscles,
          ].any((value) => _normalize(value).contains(normalizedQuery));
        })
        .toList(growable: false);
    filtered.sort((a, b) {
      if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return filtered;
  }

  LibraryState copyWith({
    List<Exercise>? exercises,
    String? query,
    String? languageCode,
    bool? isLoading,
    bool? isRefreshing,
    bool? onlyFavorites,
    String? selectedTarget,
    String? selectedEquipment,
    bool clearTarget = false,
    bool clearEquipment = false,
    String? message,
    bool clearMessage = false,
  }) => LibraryState(
    exercises: exercises ?? this.exercises,
    query: query ?? this.query,
    languageCode: languageCode ?? this.languageCode,
    isLoading: isLoading ?? this.isLoading,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    onlyFavorites: onlyFavorites ?? this.onlyFavorites,
    selectedTarget: clearTarget ? null : selectedTarget ?? this.selectedTarget,
    selectedEquipment: clearEquipment
        ? null
        : selectedEquipment ?? this.selectedEquipment,
    message: clearMessage ? null : message ?? this.message,
  );

  static String _normalize(String input) => input
      .toLowerCase()
      .replaceAll(RegExp(r'[áàäâ]'), 'a')
      .replaceAll(RegExp(r'[éèëê]'), 'e')
      .replaceAll(RegExp(r'[íìïî]'), 'i')
      .replaceAll(RegExp(r'[óòöô]'), 'o')
      .replaceAll(RegExp(r'[úùüû]'), 'u')
      .replaceAll('ñ', 'n');
}

class LibraryBloc extends Bloc<LibraryEvent, LibraryState> {
  LibraryBloc(this._repository) : super(const LibraryState()) {
    on<LibraryStarted>(_start);
    on<LibraryRefreshed>(_refresh);
    on<LibrarySearchChanged>(
      (event, emit) => emit(state.copyWith(query: event.query)),
    );
    on<LibraryTargetChanged>(
      (event, emit) => emit(
        state.copyWith(
          selectedTarget: event.target,
          clearTarget: event.target == null,
        ),
      ),
    );
    on<LibraryEquipmentChanged>(
      (event, emit) => emit(
        state.copyWith(
          selectedEquipment: event.equipment,
          clearEquipment: event.equipment == null,
        ),
      ),
    );
    on<LibraryFavoritesChanged>(
      (event, emit) => emit(state.copyWith(onlyFavorites: event.onlyFavorites)),
    );
    on<LibraryFavoriteToggled>(_toggleFavorite);
    on<LibraryCustomExerciseCreated>(_createCustomExercise);
  }

  final ExerciseRepository _repository;

  Future<void> _start(LibraryStarted event, Emitter<LibraryState> emit) async {
    emit(state.copyWith(isLoading: true, languageCode: event.languageCode));
    final cached = await _repository.loadCached(event.languageCode);
    emit(state.copyWith(exercises: cached, isLoading: cached.isEmpty));
    await _refresh(const LibraryRefreshed(), emit);
  }

  Future<void> _refresh(
    LibraryRefreshed event,
    Emitter<LibraryState> emit,
  ) async {
    emit(state.copyWith(isRefreshing: true, clearMessage: true));
    try {
      final exercises = await _repository.refresh(state.languageCode);
      emit(
        state.copyWith(
          exercises: exercises,
          isLoading: false,
          isRefreshing: false,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          isRefreshing: false,
          message: state.exercises.isEmpty
              ? 'The exercise library is unavailable. Check your connection and try again.'
              : 'Showing saved exercises. Refresh when you are online.',
        ),
      );
    }
  }

  Future<void> _toggleFavorite(
    LibraryFavoriteToggled event,
    Emitter<LibraryState> emit,
  ) async {
    final nextValue = !event.exercise.isFavorite;
    await _repository.setFavorite(event.exercise.id, isFavorite: nextValue);
    emit(
      state.copyWith(
        exercises: state.exercises
            .map(
              (exercise) => exercise.id == event.exercise.id
                  ? exercise.copyWith(isFavorite: nextValue)
                  : exercise,
            )
            .toList(growable: false),
      ),
    );
  }

  Future<void> _createCustomExercise(
    LibraryCustomExerciseCreated event,
    Emitter<LibraryState> emit,
  ) async {
    try {
      await _repository.saveCustom(state.languageCode, event.exercise);
      emit(
        state.copyWith(
          exercises: [
            ...state.exercises.where((item) => item.id != event.exercise.id),
            event.exercise,
          ],
          clearMessage: true,
        ),
      );
    } catch (_) {
      emit(state.copyWith(message: 'This custom exercise could not be saved.'));
    }
  }
}
