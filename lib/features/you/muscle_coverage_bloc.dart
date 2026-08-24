import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/muscle_map.dart';

sealed class MuscleCoverageEvent {
  const MuscleCoverageEvent();
}

class MuscleCoverageRequested extends MuscleCoverageEvent {
  const MuscleCoverageRequested({this.days = 30});
  final int days;
}

class MuscleSelected extends MuscleCoverageEvent {
  const MuscleSelected(this.group);

  /// Null clears the selection.
  final MuscleGroup? group;
}

class MuscleCoverageState {
  const MuscleCoverageState({
    this.coverage,
    this.selected,
    this.days = 30,
    this.isLoading = false,
    this.hasError = false,
  });

  final MuscleCoverage? coverage;
  final MuscleGroup? selected;
  final int days;
  final bool isLoading;
  final bool hasError;

  /// True only after a load finished with nothing, so the empty state never
  /// flashes before the first result arrives.
  bool get isEmpty =>
      !isLoading && !hasError && (coverage == null || !coverage!.hasData);

  MuscleCoverageState copyWith({
    MuscleCoverage? coverage,
    MuscleGroup? selected,
    bool clearSelection = false,
    int? days,
    bool? isLoading,
    bool? hasError,
  }) => MuscleCoverageState(
    coverage: coverage ?? this.coverage,
    selected: clearSelection ? null : selected ?? this.selected,
    days: days ?? this.days,
    isLoading: isLoading ?? this.isLoading,
    hasError: hasError ?? this.hasError,
  );
}

class MuscleCoverageBloc
    extends Bloc<MuscleCoverageEvent, MuscleCoverageState> {
  MuscleCoverageBloc(this._repository) : super(const MuscleCoverageState()) {
    on<MuscleCoverageRequested>(_load);
    on<MuscleSelected>(_select);
  }

  final MuscleCoverageRepository _repository;

  Future<void> _load(
    MuscleCoverageRequested event,
    Emitter<MuscleCoverageState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, hasError: false, days: event.days));
    try {
      emit(
        MuscleCoverageState(
          coverage: await _repository.getCoverage(days: event.days),
          days: event.days,
          // The previous selection may not exist in the new window, so it is
          // dropped rather than pointing at a muscle with no data.
          selected: null,
        ),
      );
    } catch (_) {
      emit(state.copyWith(isLoading: false, hasError: true));
    }
  }

  void _select(MuscleSelected event, Emitter<MuscleCoverageState> emit) {
    emit(
      event.group == null
          ? state.copyWith(clearSelection: true)
          : state.copyWith(selected: event.group),
    );
  }
}
