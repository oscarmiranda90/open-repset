import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/workout_repository.dart';
import '../../domain/workout_session.dart';

sealed class HistoryEvent {
  const HistoryEvent();
}

class HistoryLoaded extends HistoryEvent {
  const HistoryLoaded();
}

class HistorySessionDeleted extends HistoryEvent {
  const HistorySessionDeleted(this.sessionId);
  final String sessionId;
}

class HistoryState {
  const HistoryState({this.sessions = const [], this.isLoading = false});

  final List<WorkoutSession> sessions;
  final bool isLoading;

  HistoryState copyWith({List<WorkoutSession>? sessions, bool? isLoading}) =>
      HistoryState(
        sessions: sessions ?? this.sessions,
        isLoading: isLoading ?? this.isLoading,
      );
}

class HistoryBloc extends Bloc<HistoryEvent, HistoryState> {
  HistoryBloc(this._repository) : super(const HistoryState()) {
    on<HistoryLoaded>(_load);
    on<HistorySessionDeleted>(_delete);
  }

  final WorkoutRepository _repository;

  Future<void> _load(HistoryLoaded event, Emitter<HistoryState> emit) async {
    emit(state.copyWith(isLoading: true));
    emit(
      state.copyWith(
        sessions: await _repository.getCompletedSessions(),
        isLoading: false,
      ),
    );
  }

  Future<void> _delete(
    HistorySessionDeleted event,
    Emitter<HistoryState> emit,
  ) async {
    await _repository.deleteSession(event.sessionId);
    emit(
      state.copyWith(
        sessions: state.sessions
            .where((session) => session.id != event.sessionId)
            .toList(growable: false),
      ),
    );
  }
}
