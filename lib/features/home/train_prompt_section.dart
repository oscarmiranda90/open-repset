import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/workout_session.dart';
import '../library/library_bloc.dart';
import '../templates/template_bloc.dart';
import '../workout/workout_bloc.dart';
import 'session_plan_modal.dart';
import 'session_planner_bloc.dart';
import 'train_prompt_field.dart';

/// The plain-language entry point to a planned session.
///
/// Renders nothing when no planning backend is configured, so a build without
/// one is simply a workout logger rather than one with a dead input.
class TrainPromptSection extends StatefulWidget {
  const TrainPromptSection({super.key, this.onUpgrade, this.disabledLabel});

  /// Shown instead of planning when the customer has no Max subscription.
  final VoidCallback? onUpgrade;

  /// When set, the prompt is visible but inert, and says why.
  final String? disabledLabel;

  @override
  State<TrainPromptSection> createState() => _TrainPromptSectionState();
}

class _TrainPromptSectionState extends State<TrainPromptSection> {
  bool _modalOpen = false;

  Future<void> _plan(String request) async {
    if (_modalOpen) return;
    final planner = context.read<SessionPlannerBloc>();
    planner.add(
      SessionPlanRequested(
        request: request,
        catalogue: context.read<LibraryBloc>().state.exercises,
      ),
    );

    // The sheet opens on the request rather than on the answer, so the wait
    // has somewhere to live instead of leaving the home screen silent. It
    // starts on the working state rather than on whatever the bloc holds right
    // now: events are asynchronous, so the previous result would flash first.
    setState(() => _modalOpen = true);
    final choice = await SessionPlanModal.show(
      context,
      states: planner.stream,
      initial: const SessionPlannerState(
        stage: SessionPlanStage.interpreting,
      ),
    );
    if (!mounted) return;
    setState(() => _modalOpen = false);

    final plan = planner.state;
    // Only a ready plan can be acted on; a dismissal or a failure just closes.
    if (plan.stage == SessionPlanStage.ready) {
      switch (choice) {
        case SessionPlanChoice.train:
          _startSession(plan);
        case SessionPlanChoice.saveTemplate:
          _saveTemplate(plan);
        case SessionPlanChoice.dismissed:
        case null:
          break;
      }
    }
    planner.add(const SessionPlanDismissed());
  }

  void _startSession(SessionPlannerState plan) =>
      context.read<WorkoutBloc>().add(
        WorkoutStartedFromPlan(
          title: plan.plan!.title,
          entries: plan.planned
              .map(
                (entry) => PlannedWorkoutEntry(
                  exercise: entry.exercise,
                  setCount: entry.plan.setCount,
                  repetitions: entry.plan.repetitions,
                  notes: entry.plan.notes,
                ),
              )
              .toList(growable: false),
        ),
      );

  /// Saves the plan as a template without starting anything.
  ///
  /// The session built here is a carrier, never persisted: the template bloc
  /// takes its title and exercises, and nothing else ever sees it.
  void _saveTemplate(SessionPlannerState plan) {
    final now = DateTime.now();
    var sequence = 0;
    String nextId() => '${now.microsecondsSinceEpoch}-${sequence++}';

    final exercises = plan.planned.indexed
        .map(
          (item) => WorkoutExercise(
            id: nextId(),
            exerciseId: item.$2.exercise.id,
            name: item.$2.exercise.name,
            position: item.$1,
            notes: item.$2.plan.notes,
            sets: List.generate(
              item.$2.plan.setCount,
              (position) => WorkoutSet(
                id: nextId(),
                exerciseId: item.$2.exercise.id,
                position: position,
                repetitions: item.$2.plan.repetitions,
              ),
              growable: false,
            ),
          ),
        )
        .toList(growable: false);

    context.read<TemplateBloc>().add(
      TemplateSavedFromWorkout(
        WorkoutSession(
          id: nextId(),
          title: plan.plan!.title,
          startedAt: now,
          exercises: exercises,
        ),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved "${plan.plan!.title}" to your templates'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!context.read<SessionPlannerBloc>().isConfigured) {
      return const SizedBox.shrink();
    }
    return TrainPromptField(
      disabledLabel: widget.disabledLabel,
      isBusy: _modalOpen,
      // Planning is a Max feature. Intercepting the tap shows the offer
      // instead of letting someone type a request that cannot be served.
      onBlocked: widget.onUpgrade == null ? null : () => widget.onUpgrade!(),
      onSubmitted: _plan,
    );
  }
}
