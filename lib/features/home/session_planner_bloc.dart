import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/catalogue_shortlist.dart';
import '../../domain/exercise.dart';
import '../../domain/session_plan.dart';
import '../../domain/workout_planner.dart';

sealed class SessionPlannerEvent {
  const SessionPlannerEvent();
}

/// Asks for a session from a plain-language request.
///
/// The catalogue travels with the event rather than being fetched here: the
/// library already holds it in memory, and planning must not trigger a second
/// load of the same records.
class SessionPlanRequested extends SessionPlannerEvent {
  const SessionPlanRequested({required this.request, required this.catalogue});

  final String request;
  final List<Exercise> catalogue;
}

class SessionPlanDismissed extends SessionPlannerEvent {
  const SessionPlanDismissed();
}

enum SessionPlanStage { idle, interpreting, selecting, ready, failed }

class SessionPlannerState {
  const SessionPlannerState({
    this.stage = SessionPlanStage.idle,
    this.request = '',
    this.plan,
    this.planned = const [],
    this.message,
  });

  final SessionPlanStage stage;
  final String request;
  final SessionPlan? plan;

  /// The catalogue records behind [plan], in planned order, so the UI and the
  /// workout can be built without searching the catalogue again.
  final List<PlannedEntry> planned;

  final String? message;

  bool get isBusy =>
      stage == SessionPlanStage.interpreting ||
      stage == SessionPlanStage.selecting;

  SessionPlannerState copyWith({
    SessionPlanStage? stage,
    String? request,
    SessionPlan? plan,
    List<PlannedEntry>? planned,
    String? message,
    bool clearMessage = false,
  }) => SessionPlannerState(
    stage: stage ?? this.stage,
    request: request ?? this.request,
    plan: plan ?? this.plan,
    planned: planned ?? this.planned,
    message: clearMessage ? null : message ?? this.message,
  );
}

/// A planned exercise paired with the catalogue record it names.
class PlannedEntry {
  const PlannedEntry({required this.exercise, required this.plan});

  final Exercise exercise;
  final PlannedExercise plan;
}

class SessionPlannerBloc
    extends Bloc<SessionPlannerEvent, SessionPlannerState> {
  SessionPlannerBloc(this._planner) : super(const SessionPlannerState()) {
    on<SessionPlanRequested>(_plan);
    on<SessionPlanDismissed>(
      (event, emit) => emit(const SessionPlannerState()),
    );
  }

  final WorkoutPlanner _planner;

  bool get isConfigured => _planner.isConfigured;

  Future<void> _plan(
    SessionPlanRequested event,
    Emitter<SessionPlannerState> emit,
  ) async {
    final request = event.request.trim();
    if (request.isEmpty) return;
    // A request already in flight is left alone; anything else — a plan, a
    // failure, an idle bloc — is replaced by this one. Rejecting the event
    // instead would silently drop a second attempt after a failed first.
    if (state.isBusy && state.request == request) return;
    if (event.catalogue.isEmpty) {
      emit(
        state.copyWith(
          stage: SessionPlanStage.failed,
          request: request,
          message: 'The exercise library has not loaded yet.',
        ),
      );
      return;
    }

    emit(
      SessionPlannerState(
        stage: SessionPlanStage.interpreting,
        request: request,
      ),
    );

    try {
      final query = await _planner.interpret(
        request: request,
        vocabulary: CatalogueShortlist.vocabularyOf(event.catalogue),
      );
      final candidates = CatalogueShortlist.candidatesFor(
        event.catalogue,
        query: query,
      );
      if (candidates.isEmpty) {
        emit(
          state.copyWith(
            stage: SessionPlanStage.failed,
            message: 'Nothing in your library matches that yet.',
          ),
        );
        return;
      }

      emit(state.copyWith(stage: SessionPlanStage.selecting));
      final plan = await _planner.select(
        request: request,
        query: query,
        candidates: candidates,
      );

      final byId = {for (final exercise in candidates) exercise.id: exercise};
      final planned = plan.entries
          .map((entry) => (entry, byId[entry.exerciseId]))
          .where((pair) => pair.$2 != null)
          .map((pair) => PlannedEntry(exercise: pair.$2!, plan: pair.$1))
          .toList(growable: false);
      if (planned.isEmpty) {
        emit(
          state.copyWith(
            stage: SessionPlanStage.failed,
            message: 'That plan did not match your library. Try again.',
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          stage: SessionPlanStage.ready,
          plan: plan,
          planned: planned,
          clearMessage: true,
        ),
      );
    } on WorkoutPlannerException catch (error) {
      emit(
        state.copyWith(stage: SessionPlanStage.failed, message: error.message),
      );
    } catch (error, stackTrace) {
      // Anything reaching here is a defect rather than a service failure, so
      // it is logged instead of vanishing behind a friendly sentence.
      debugPrint('Session planning failed unexpectedly: $error\n$stackTrace');
      emit(
        state.copyWith(
          stage: SessionPlanStage.failed,
          message: 'The session could not be planned right now.',
        ),
      );
    }
  }
}
