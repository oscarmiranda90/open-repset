import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/body_weight.dart';

sealed class BodyWeightEvent {
  const BodyWeightEvent();
}

class BodyWeightRequested extends BodyWeightEvent {
  const BodyWeightRequested();
}

class BodyWeightRecorded extends BodyWeightEvent {
  const BodyWeightRecorded({required this.weightKg, this.measuredOn});

  final double weightKg;

  /// Defaults to today. Provided when back-filling a missed day.
  final DateTime? measuredOn;
}

class BodyWeightRemoved extends BodyWeightEvent {
  const BodyWeightRemoved(this.measuredOn);
  final DateTime measuredOn;
}

class BodyWeightState {
  const BodyWeightState({
    this.entries = const [],
    this.trend,
    this.isLoading = false,
    this.message,
  });

  final List<BodyWeightEntry> entries;
  final BodyWeightTrend? trend;
  final bool isLoading;
  final String? message;

  BodyWeightEntry? get latest => entries.isEmpty ? null : entries.first;

  bool get hasHistory => entries.isNotEmpty;

  BodyWeightState copyWith({
    List<BodyWeightEntry>? entries,
    BodyWeightTrend? trend,
    bool? isLoading,
    String? message,
    bool clearMessage = false,
  }) => BodyWeightState(
    entries: entries ?? this.entries,
    trend: trend ?? this.trend,
    isLoading: isLoading ?? this.isLoading,
    message: clearMessage ? null : message ?? this.message,
  );
}

class BodyWeightBloc extends Bloc<BodyWeightEvent, BodyWeightState> {
  BodyWeightBloc(this._repository) : super(const BodyWeightState()) {
    on<BodyWeightRequested>(_load);
    on<BodyWeightRecorded>(_record);
    on<BodyWeightRemoved>(_remove);
  }

  final BodyWeightRepository _repository;

  Future<void> _load(
    BodyWeightRequested event,
    Emitter<BodyWeightState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearMessage: true));
    try {
      final entries = await _repository.getEntries();
      final trend = await _repository.getTrend();
      emit(BodyWeightState(entries: entries, trend: trend));
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          message: 'Body weight history could not be read.',
        ),
      );
    }
  }

  Future<void> _record(
    BodyWeightRecorded event,
    Emitter<BodyWeightState> emit,
  ) async {
    // The domain asserts a plausible range; guard here so a typo in the field
    // surfaces as a message instead of crashing the app in release.
    if (event.weightKg <= 0 || event.weightKg >= 500) {
      emit(state.copyWith(message: 'Enter a weight between 1 and 499 kg.'));
      return;
    }
    try {
      await _repository.save(
        BodyWeightEntry(
          measuredOn: event.measuredOn ?? DateTime.now(),
          weightKg: event.weightKg,
        ),
      );
      add(const BodyWeightRequested());
    } catch (_) {
      emit(state.copyWith(message: 'That weigh-in could not be saved.'));
    }
  }

  Future<void> _remove(
    BodyWeightRemoved event,
    Emitter<BodyWeightState> emit,
  ) async {
    try {
      await _repository.delete(event.measuredOn);
      add(const BodyWeightRequested());
    } catch (_) {
      emit(state.copyWith(message: 'That weigh-in could not be removed.'));
    }
  }
}
