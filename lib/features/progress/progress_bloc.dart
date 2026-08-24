import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/relative_strength_service.dart';
import '../../domain/training_analytics.dart';

sealed class ProgressEvent {
  const ProgressEvent();
}

class ProgressLoaded extends ProgressEvent {
  const ProgressLoaded();
}

class ProgressState {
  const ProgressState({
    this.overview,
    this.weeklyVolume = const [],
    this.exercises = const [],
    this.muscleGroups = const [],
    this.medianRest,
    this.isLoading = false,
    this.hasError = false,
  });

  final TrainingOverview? overview;
  final List<TrainingPoint> weeklyVolume;

  /// Each lift with its bodyweight ratio, when body weight is known for it.
  final List<ExerciseInsightWithStrength> exercises;
  final List<MuscleGroupShare> muscleGroups;
  final Duration? medianRest;
  final bool isLoading;
  final bool hasError;

  /// True only once a load has finished and found nothing. Distinguishing this
  /// from "still loading" keeps the UI from flashing an empty state first.
  bool get isEmpty =>
      !isLoading && !hasError && (overview == null || !overview!.hasHistory);

  ProgressState copyWith({
    TrainingOverview? overview,
    List<TrainingPoint>? weeklyVolume,
    List<ExerciseInsightWithStrength>? exercises,
    List<MuscleGroupShare>? muscleGroups,
    Duration? medianRest,
    bool clearMedianRest = false,
    bool? isLoading,
    bool? hasError,
  }) => ProgressState(
    overview: overview ?? this.overview,
    weeklyVolume: weeklyVolume ?? this.weeklyVolume,
    exercises: exercises ?? this.exercises,
    muscleGroups: muscleGroups ?? this.muscleGroups,
    medianRest: clearMedianRest ? null : medianRest ?? this.medianRest,
    isLoading: isLoading ?? this.isLoading,
    hasError: hasError ?? this.hasError,
  );
}

class ProgressBloc extends Bloc<ProgressEvent, ProgressState> {
  ProgressBloc(this._analytics, this._relativeStrength)
    : super(const ProgressState()) {
    on<ProgressLoaded>(_load);
  }

  final TrainingAnalyticsRepository _analytics;
  final RelativeStrengthService _relativeStrength;

  Future<void> _load(ProgressLoaded event, Emitter<ProgressState> emit) async {
    emit(state.copyWith(isLoading: true, hasError: false));
    try {
      // Independent queries, so they run together rather than in sequence.
      final results = await Future.wait([
        _analytics.getOverview(),
        _analytics.getWeeklyVolume(),
        _relativeStrength.getInsights(limit: 8),
        _analytics.getMuscleGroupShares(),
        _analytics.getMedianRestBetweenSets(),
      ]);

      emit(
        ProgressState(
          overview: results[0] as TrainingOverview,
          weeklyVolume: results[1] as List<TrainingPoint>,
          exercises: results[2] as List<ExerciseInsightWithStrength>,
          muscleGroups: results[3] as List<MuscleGroupShare>,
          medianRest: results[4] as Duration?,
        ),
      );
    } catch (_) {
      emit(state.copyWith(isLoading: false, hasError: true));
    }
  }
}
