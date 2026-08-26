import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keyboard_actions/keyboard_actions.dart';

import '../../core/account/max_access.dart';
import '../../core/ads/official_ads_service.dart';
import '../../core/motion/repset_motion.dart';
import '../../domain/exercise.dart';
import '../../domain/workout_repository.dart';
import '../../domain/workout_session.dart';
import '../../domain/workout_summary.dart';
import '../library/exercise_media.dart';
import '../library/library_bloc.dart';
import '../templates/template_bloc.dart';
import 'rest_countdown_rail.dart';
import 'summary/workout_summary_sheet.dart';
import 'workout_bloc.dart';
import 'workout_elapsed_time.dart';

class ActiveWorkoutPage extends StatelessWidget {
  const ActiveWorkoutPage({this.onBack, this.adsService, super.key});

  final VoidCallback? onBack;
  final OfficialAdsService? adsService;

  @override
  Widget build(BuildContext context) => BlocConsumer<WorkoutBloc, WorkoutState>(
    listenWhen: (previous, current) =>
        current.message != null && current.message != previous.message,
    listener: (context, state) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.message!)));
    },
    builder: (context, state) {
      final session = state.session;
      if (session == null) return const SizedBox.shrink();
      final activeRestSetId = _latestCompletedSetId(session);
      return Material(
        color: Colors.transparent,
        child: KeyboardActions(
          navigation: KeyboardNavigation.none,
          theme: const KeyboardActionsThemeData(
            barColor: Color(0xff202620),
            foregroundColor: Color(0xffd7ff4f),
            integratedBar: true,
          ),
          child: Stack(
            children: [
              CustomScrollView(
                key: const Key('active-workout-page'),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    sliver: SliverPersistentHeader(
                      pinned: true,
                      delegate: _WorkoutHeaderDelegate(
                        session: session,
                        onBack: onBack,
                        adsService: adsService,
                      ),
                    ),
                  ),
                  if (session.exercises.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyWorkout(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 104),
                      sliver: SliverReorderableList(
                        itemCount: session.exercises.length,
                        onReorderItem: (oldIndex, newIndex) {
                          context.read<WorkoutBloc>().add(
                            WorkoutExerciseMoved(
                              entryId: session.exercises[oldIndex].id,
                              toIndex: newIndex,
                            ),
                          );
                        },
                        itemBuilder: (context, index) => Padding(
                          key: ValueKey(
                            'reorder-${session.exercises[index].id}',
                          ),
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _ExerciseCard(
                            exercise: session.exercises[index],
                            activeRestSetId: activeRestSetId,
                            reorderIndex: index,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Positioned(
                right: 18,
                bottom: 12,
                child: SafeArea(
                  minimum: const EdgeInsets.only(bottom: 6),
                  child: RepSetEntrance(
                    child: RepSetPress(
                      scale: .96,
                      child: FloatingActionButton.extended(
                        key: const Key('add-exercise-button'),
                        heroTag: 'active-workout-add-exercise',
                        onPressed: () => _pickExercise(context),
                        backgroundColor: const Color(0xffd7ff4f),
                        foregroundColor: const Color(0xff171914),
                        elevation: 5,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text(
                          'Add Exercise',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Future<void> _pickExercise(BuildContext context) async {
    final selection = await showModalBottomSheet<_ExerciseSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: RepSetMotion.sheetAnimation,
      builder: (_) => const _ExercisePickerSheet(),
    );
    if (selection != null && context.mounted) {
      context.read<WorkoutBloc>().add(
        WorkoutExercisesAdded(
          selection.exercises,
          asSuperset: selection.asSuperset,
        ),
      );
    }
  }
}

enum _FinishWorkoutChoice { finish, saveTemplate, discard }

class _WorkoutHeaderDelegate extends SliverPersistentHeaderDelegate {
  _WorkoutHeaderDelegate({
    required this.session,
    required this.onBack,
    required this.adsService,
  });

  final WorkoutSession session;
  final VoidCallback? onBack;
  final OfficialAdsService? adsService;

  @override
  double get minExtent => 64;

  @override
  double get maxExtent => 136;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final collapseProgress = (shrinkOffset / (maxExtent - minExtent)).clamp(
      0.0,
      1.0,
    );
    return _WorkoutHeader(
      session: session,
      onBack: onBack,
      adsService: adsService,
      collapseProgress: collapseProgress,
    );
  }

  @override
  bool shouldRebuild(covariant _WorkoutHeaderDelegate oldDelegate) =>
      oldDelegate.session != session ||
      oldDelegate.onBack != onBack ||
      oldDelegate.adsService != adsService;
}

class _WorkoutHeader extends StatelessWidget {
  const _WorkoutHeader({
    required this.session,
    required this.onBack,
    required this.adsService,
    required this.collapseProgress,
  });

  final WorkoutSession session;
  final VoidCallback? onBack;
  final OfficialAdsService? adsService;
  final double collapseProgress;

  @override
  Widget build(BuildContext context) {
    final detailVisibility = (1 - collapseProgress).clamp(0.0, 1.0);
    return ClipRRect(
      key: const Key('workout-header-panel'),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xff202620),
          border: Border.all(color: const Color(0xff344037)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 50,
                child: Row(
                  children: [
                    if (onBack != null)
                      IconButton(
                        key: const Key('back-to-home-button'),
                        tooltip: 'Back to home',
                        onPressed: onBack,
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(
                          width: 40,
                          height: 40,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: const Key('workout-title-button'),
                          onTap: () => _renameWorkout(context),
                          borderRadius: BorderRadius.circular(9),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ACTIVE WORKOUT',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        session.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -.55,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.edit_rounded,
                                      size: 13,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      key: const Key('finish-workout-button'),
                      onPressed: () => _finishWorkout(context, session),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xffd7ff4f),
                        foregroundColor: const Color(0xff171914),
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text(
                        'Finish',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10 * detailVisibility),
              ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: detailVisibility,
                  child: Opacity(
                    opacity: detailVisibility,
                    child: Transform.translate(
                      offset: Offset(0, -10 * collapseProgress),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'SESSION TIME',
                                    style: TextStyle(
                                      color: Color(0xff91a184),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.05,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  WorkoutElapsedTime(
                                    key: const Key('workout-elapsed-time'),
                                    startedAt: session.startedAt,
                                    style: const TextStyle(
                                      color: Color(0xffd7ff4f),
                                      fontSize: 30,
                                      height: 1,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1.2,
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _WorkoutMetric(
                              label: 'SETS',
                              value: '${session.completedSetCount}',
                            ),
                            const SizedBox(width: 18),
                            _WorkoutMetric(
                              label: 'VOLUME',
                              value: '${_formatLoad(session.volumeKg)} kg',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _renameWorkout(BuildContext context) async {
    final title = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      sheetAnimationStyle: RepSetMotion.sheetAnimation,
      builder: (_) => _RenameWorkoutSheet(initialTitle: session.title),
    );
    if (title == null || !context.mounted) return;
    context.read<WorkoutBloc>().add(WorkoutRenamed(title));
  }

  Future<void> _finishWorkout(
    BuildContext context,
    WorkoutSession session,
  ) async {
    final choice = await showModalBottomSheet<_FinishWorkoutChoice>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: RepSetMotion.sheetAnimation,
      builder: (_) => _FinishWorkoutSheet(session: session),
    );
    if (choice == null || !context.mounted) return;

    if (choice == _FinishWorkoutChoice.discard) {
      final shouldDiscard = await showModalBottomSheet<bool>(
        context: context,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        sheetAnimationStyle: RepSetMotion.sheetAnimation,
        builder: (_) => const _DiscardWorkoutSheet(),
      );
      if (shouldDiscard == true && context.mounted) {
        context.read<WorkoutBloc>().add(const WorkoutDiscarded());
      }
      return;
    }

    if (choice == _FinishWorkoutChoice.saveTemplate) {
      context.read<TemplateBloc>().add(TemplateSavedFromWorkout(session));
    }

    // The summary must read history that does NOT yet include this session:
    // the repository counts only completed sessions, so persisting first would
    // fold the session into its own baseline and no record could ever beat it.
    // Starting the read here captures that pre-save state; awaiting it later
    // keeps the finish itself instant.
    final repository = context.read<WorkoutRepository>();
    final summary = buildWorkoutSummary(
      session: session.copyWith(completedAt: DateTime.now()),
      repository: repository,
    );

    context.read<WorkoutBloc>().add(const WorkoutFinished());

    await showWorkoutSummarySheet(context, load: () => summary);
    if (!context.mounted || adsService == null) return;

    try {
      final result = await summary;
      if (!context.mounted) return;
      // Persistence is asynchronous. If the bloc has not published the saved
      // state yet, skip the ad instead of risking overlap with an active
      // workout or delaying navigation to wait for monetization.
      if (context.read<WorkoutBloc>().state.hasActiveSession) return;
      final max = context.read<MaxAccessCubit>().state;
      adsService!.maybeShowCompletedWorkoutInterstitial(
        // The summary is calculated before this session is saved.
        completedWorkoutCount: result.completedSessionCount + 1,
        hasMaxAccess:
            !adsService!.isTestMode &&
            (!max.isAvailable || !max.hasResolved || max.isActive),
      );
    } catch (error) {
      // A summary failure never turns into an ad or delays the saved workout.
      debugPrint('Post-workout ad skipped: $error');
    }
  }
}

class _FinishWorkoutSheet extends StatelessWidget {
  const _FinishWorkoutSheet({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xff202620),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xff3a463a)),
        boxShadow: const [
          BoxShadow(
            color: Color(0xaa091009),
            blurRadius: 32,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xff687468),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xffd7ff4f),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xff171914),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finish workout',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.8,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Lock in today\'s work and view your recap.',
                      style: TextStyle(color: muted),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: muted,
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                child: const Text('Not yet'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xff171d18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _FinishMetric(
                  label: 'SETS',
                  value: '${session.completedSetCount}',
                ),
                const SizedBox(width: 18),
                _FinishMetric(
                  label: 'VOLUME',
                  value: '${_formatLoad(session.volumeKg)} kg',
                ),
                const Spacer(),
                _FinishMetric(
                  label: 'TIME',
                  value: _formatDuration(
                    DateTime.now().difference(session.startedAt).inSeconds,
                  ),
                  alignEnd: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              key: const Key('confirm-finish-workout-button'),
              onPressed: () =>
                  Navigator.pop(context, _FinishWorkoutChoice.finish),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xffd7ff4f),
                foregroundColor: const Color(0xff171914),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text(
                'Finish & view recap',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            key: const Key('save-template-and-finish-button'),
            onPressed: () =>
                Navigator.pop(context, _FinishWorkoutChoice.saveTemplate),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 50),
              foregroundColor: const Color(0xffeef5e9),
              side: const BorderSide(color: Color(0xff465246)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bookmark_add_outlined, size: 18),
                SizedBox(width: 8),
                Text(
                  'Save as template, then finish',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            key: const Key('discard-workout-button'),
            onPressed: () =>
                Navigator.pop(context, _FinishWorkoutChoice.discard),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Cancel workout and discard everything'),
          ),
        ],
      ),
    );
  }
}

class _FinishMetric extends StatelessWidget {
  const _FinishMetric({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: Color(0xff93a093),
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        style: const TextStyle(
          color: Color(0xfff0f5ed),
          fontSize: 15,
          fontWeight: FontWeight.w900,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );
}

class _DiscardWorkoutSheet extends StatelessWidget {
  const _DiscardWorkoutSheet();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
    decoration: BoxDecoration(
      color: const Color(0xff29201d),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: const Color(0xff5a3931)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xff8f7068),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Discard this workout?',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 7),
        const Text(
          'Exercises, sets, and logged results will be deleted from this device. This can\'t be undone.',
          style: TextStyle(color: Color(0xffccb8b0), height: 1.35),
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 50,
          child: FilledButton(
            key: const Key('confirm-discard-workout-button'),
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffdf725c),
              foregroundColor: const Color(0xff24110d),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Discard workout',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Keep workout'),
        ),
      ],
    ),
  );
}

class _RenameWorkoutSheet extends StatefulWidget {
  const _RenameWorkoutSheet({required this.initialTitle});

  final String initialTitle;

  @override
  State<_RenameWorkoutSheet> createState() => _RenameWorkoutSheetState();
}

class _RenameWorkoutSheetState extends State<_RenameWorkoutSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialTitle,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    Navigator.pop(context, title);
  }

  @override
  Widget build(BuildContext context) => AnimatedPadding(
    duration: RepSetMotion.fast,
    curve: Curves.easeOutCubic,
    padding: EdgeInsets.only(
      left: 20,
      top: 12,
      right: 20,
      bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Workout name',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('workout-name-field'),
          controller: _controller,
          autofocus: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
          decoration: const InputDecoration(
            hintText: "Today's Workout",
            counterText: '',
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('save-workout-name'),
            onPressed: _save,
            child: const Text('Save name'),
          ),
        ),
      ],
    ),
  );
}

class _WorkoutMetric extends StatelessWidget {
  const _WorkoutMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: Color(0xff91a184),
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: .9,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        maxLines: 1,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );
}

class _EmptyWorkout extends StatelessWidget {
  const _EmptyWorkout();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(36, 26, 36, 120),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.playlist_add_rounded,
          size: 58,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 18),
        Text(
          'Ready when you are.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Add your first exercise to start this session.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.activeRestSetId,
    required this.reorderIndex,
  });

  final WorkoutExercise exercise;
  final String? activeRestSetId;
  final int reorderIndex;

  @override
  Widget build(BuildContext context) => RepSetEntrance(
    key: ValueKey('exercise-entry-${exercise.id}'),
    delay: Duration(milliseconds: exercise.position * 45),
    child: Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xff252d28),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: EdgeInsets.zero,
                child: Row(
                  children: [
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: Key('exercise-details-${exercise.position}'),
                          onTap: () => _openExerciseDetails(context),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                if (exercise.supersetId != null) ...[
                                  Container(
                                    key: Key(
                                      'superset-badge-${exercise.position}',
                                    ),
                                    width: 25,
                                    height: 25,
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xffd7ff4f,
                                      ).withValues(alpha: .12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.link_rounded,
                                      size: 15,
                                      color: Color(0xffd7ff4f),
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                ],
                                Flexible(
                                  child: Text(
                                    exercise.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: const Color(0xffd7ff4f),
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -.5,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Container(
                                  width: 25,
                                  height: 25,
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xffd7ff4f,
                                    ).withValues(alpha: .12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(
                                        0xffd7ff4f,
                                      ).withValues(alpha: .28),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.info_outline_rounded,
                                    size: 15,
                                    color: Color(0xffd7ff4f),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(6, 9),
                      child: PopupMenuButton<String>(
                        tooltip: 'Exercise unit and actions',
                        color: const Color(0xff252d28),
                        padding: EdgeInsets.zero,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: const Color(0xff2d352f),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(
                            Icons.more_horiz_rounded,
                            size: 13,
                            color: Color(0xffd7ff4f),
                          ),
                        ),
                        onSelected: (value) {
                          switch (value) {
                            case 'kg':
                              context.read<WorkoutBloc>().add(
                                WorkoutExerciseWeightUnitChanged(
                                  entryId: exercise.id,
                                  weightUnit: WorkoutWeightUnit.kilograms,
                                ),
                              );
                              break;
                            case 'lb':
                              context.read<WorkoutBloc>().add(
                                WorkoutExerciseWeightUnitChanged(
                                  entryId: exercise.id,
                                  weightUnit: WorkoutWeightUnit.pounds,
                                ),
                              );
                              break;
                            case 'remove':
                              context.read<WorkoutBloc>().add(
                                WorkoutExerciseRemoved(exercise.id),
                              );
                              break;
                            case 'duplicate':
                              context.read<WorkoutBloc>().add(
                                WorkoutExerciseDuplicated(exercise.id),
                              );
                              break;
                            case 'replace':
                              _replaceExercise(context);
                              break;
                          }
                        },
                        itemBuilder: (_) => [
                          CheckedPopupMenuItem(
                            value: 'kg',
                            checked:
                                exercise.weightUnit ==
                                WorkoutWeightUnit.kilograms,
                            child: const Text('Use kilograms (kg)'),
                          ),
                          CheckedPopupMenuItem(
                            value: 'lb',
                            checked:
                                exercise.weightUnit == WorkoutWeightUnit.pounds,
                            child: const Text('Use pounds (lb)'),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'replace',
                            child: Text('Replace exercise'),
                          ),
                          const PopupMenuItem(
                            value: 'duplicate',
                            child: Text('Duplicate exercise'),
                          ),
                          const PopupMenuItem(
                            value: 'remove',
                            child: Text('Remove exercise'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: -10,
                right: -10,
                child: ReorderableDragStartListener(
                  key: Key('reorder-exercise-${exercise.position}'),
                  index: reorderIndex,
                  child: Container(
                    width: 30,
                    height: 27,
                    decoration: BoxDecoration(
                      color: const Color(0xff3c4638),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(14),
                        bottomLeft: Radius.circular(11),
                      ),
                      border: Border(
                        left: BorderSide(
                          color: const Color(0xff91a184).withValues(alpha: .34),
                        ),
                        bottom: BorderSide(
                          color: const Color(0xff91a184).withValues(alpha: .34),
                        ),
                      ),
                    ),
                    child: Transform.rotate(
                      angle: -.16,
                      child: const Icon(
                        Icons.drag_indicator_rounded,
                        size: 16,
                        color: Color(0xffb9c8ad),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _SetTableHeader(weightUnit: exercise.weightUnit),
          const SizedBox(height: 4),
          if (exercise.sets.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
              child: Text(
                'No sets yet.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ..._buildSetRows(context),
          const SizedBox(height: 8),
          _AddSetButton(
            key: Key('add-set-${exercise.position}'),
            onPressed: () =>
                context.read<WorkoutBloc>().add(WorkoutSetAdded(exercise.id)),
          ),
        ],
      ),
    ),
  );

  List<Widget> _buildSetRows(BuildContext context) {
    double? inheritedLoadKg;
    int? inheritedRepetitions;
    final rows = <Widget>[];
    for (final entry in exercise.sets.asMap().entries) {
      final set = entry.value;
      final isActiveRest = set.id == activeRestSetId;
      rows.add(
        _SetRow(
          exercise: exercise,
          set: set,
          previous: entry.key == 0 ? null : exercise.sets[entry.key - 1],
          inheritedLoadKg: inheritedLoadKg,
          inheritedRepetitions: inheritedRepetitions,
          showRestRail: entry.key != exercise.sets.length - 1 || isActiveRest,
          restStartedAt: isActiveRest ? set.completedAt : null,
          onRestDurationTap: () => _editRestDuration(context),
        ),
      );
      if (set.loadKg > 0) inheritedLoadKg = set.loadKg;
      if (set.repetitions > 0) inheritedRepetitions = set.repetitions;
    }
    return rows;
  }

  Future<void> _editRestDuration(BuildContext context) async {
    final seconds = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      sheetAnimationStyle: RepSetMotion.sheetAnimation,
      builder: (_) => _RestDurationSheet(initialSeconds: exercise.restSeconds),
    );
    if (seconds == null || !context.mounted) return;
    context.read<WorkoutBloc>().add(
      WorkoutExerciseRestChanged(entryId: exercise.id, seconds: seconds),
    );
  }

  Future<void> _openExerciseDetails(BuildContext context) async {
    final libraryExercises = context.read<LibraryBloc>().state.exercises;
    final catalogExercise = libraryExercises.firstWhere(
      (item) => item.id == exercise.exerciseId,
      orElse: () => Exercise(
        id: exercise.exerciseId,
        name: exercise.name,
        bodyPart: '',
        target: '',
        equipment: '',
        secondaryMuscles: const [],
        instructions: const [],
      ),
    );
    context.read<WorkoutBloc>().add(
      WorkoutExerciseHistoryRequested(exercise.exerciseId),
    );
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      sheetAnimationStyle: RepSetMotion.sheetAnimation,
      builder: (_) => _WorkoutExerciseDetailSheet(exercise: catalogExercise),
    );
  }

  Future<void> _replaceExercise(BuildContext context) async {
    final replacement = await showModalBottomSheet<Exercise>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      sheetAnimationStyle: RepSetMotion.sheetAnimation,
      builder: (_) => const _SingleExercisePickerSheet(),
    );
    if (replacement == null || !context.mounted) return;
    context.read<WorkoutBloc>().add(
      WorkoutExerciseReplaced(entryId: exercise.id, replacement: replacement),
    );
  }
}

class _WorkoutExerciseDetailSheet extends StatelessWidget {
  const _WorkoutExerciseDetailSheet({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final workout = context.watch<WorkoutBloc>().state;
    final stats = workout.exerciseHistory[exercise.id];
    final isLoading = workout.loadingExerciseHistory.contains(exercise.id);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .92,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 10, 8),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const Spacer(),
                const Text(
                  'Exercise details',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                IconButton(
                  key: const Key('close-exercise-details'),
                  tooltip: 'Close exercise details',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: ExerciseMedia(exercise: exercise),
                ),
                const SizedBox(height: 18),
                Text(
                  exercise.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.5,
                  ),
                ),
                if (_exerciseSummary(exercise).isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _exerciseSummary(exercise),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _SectionTitle(
                  icon: Icons.query_stats_rounded,
                  title: 'Previous training',
                ),
                const SizedBox(height: 10),
                _ExerciseHistoryPanel(stats: stats, isLoading: isLoading),
                const SizedBox(height: 26),
                _SectionTitle(
                  icon: Icons.format_list_numbered_rounded,
                  title: 'How to perform it',
                ),
                const SizedBox(height: 12),
                if (exercise.instructions.isEmpty)
                  Text(
                    'Instructions are not available for this exercise yet.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  ...exercise.instructions.indexed.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 25,
                            height: 25,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xffd7ff4f,
                              ).withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${entry.$1 + 1}',
                              style: const TextStyle(
                                color: Color(0xffd7ff4f),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Text(
                              entry.$2,
                              style: const TextStyle(height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: const Color(0xffd7ff4f)),
      const SizedBox(width: 8),
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
      ),
    ],
  );
}

class _ExerciseHistoryPanel extends StatelessWidget {
  const _ExerciseHistoryPanel({required this.stats, required this.isLoading});

  final ExerciseHistoryStats? stats;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading && stats == null) {
      return const SizedBox(
        height: 92,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (stats == null || !stats!.hasHistory) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xff252d28),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.history_rounded, color: Color(0xff91a184)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your completed workouts will build this exercise history.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.15,
      children: [
        _HistoryMetric(label: 'Workouts', value: '${stats!.sessionCount}'),
        _HistoryMetric(
          label: 'Completed sets',
          value: '${stats!.completedSetCount}',
        ),
        _HistoryMetric(
          label: 'Best weight',
          value: '${_formatLoad(stats!.bestLoadKg)} kg',
        ),
        _HistoryMetric(
          label: 'Total volume',
          value: '${_formatLoad(stats!.totalVolumeKg)} kg',
        ),
      ],
    );
  }
}

class _HistoryMetric extends StatelessWidget {
  const _HistoryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xff252d28),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xffd7ff4f),
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

String _exerciseSummary(Exercise exercise) => [
  exercise.target,
  exercise.equipment,
].where((value) => value.isNotEmpty).join(' • ');

class _AddSetButton extends StatelessWidget {
  const _AddSetButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => RepSetPress(
    scale: .94,
    child: Tooltip(
      message: 'Add set',
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(40),
          foregroundColor: const Color(0xffd7ff4f),
          side: const BorderSide(color: Color(0xff344437)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add set',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    ),
  );
}

class _SetTableHeader extends StatelessWidget {
  const _SetTableHeader({required this.weightUnit});

  final WorkoutWeightUnit weightUnit;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 40, child: _HeaderLabel('Set', centered: true)),
      SizedBox(width: 6),
      Expanded(flex: 4, child: _HeaderLabel('Previous', centered: true)),
      SizedBox(width: 6),
      Expanded(flex: 3, child: _HeaderLabel(weightUnit.label, centered: true)),
      SizedBox(width: 6),
      Expanded(flex: 3, child: _HeaderLabel('Reps', centered: true)),
      SizedBox(width: 40, child: Icon(Icons.check_rounded, size: 18)),
    ],
  );
}

class _HeaderLabel extends StatelessWidget {
  const _HeaderLabel(this.text, {this.centered = false});

  final String text;
  final bool centered;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: centered ? TextAlign.center : TextAlign.start,
    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
  );
}

class _SetRow extends StatefulWidget {
  const _SetRow({
    required this.exercise,
    required this.set,
    required this.previous,
    required this.inheritedLoadKg,
    required this.inheritedRepetitions,
    required this.showRestRail,
    required this.restStartedAt,
    required this.onRestDurationTap,
  });

  final WorkoutExercise exercise;
  final WorkoutSet set;
  final WorkoutSet? previous;
  final double? inheritedLoadKg;
  final int? inheritedRepetitions;
  final bool showRestRail;
  final DateTime? restStartedAt;
  final VoidCallback onRestDurationTap;

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  final FocusNode _loadFocusNode = FocusNode();
  final FocusNode _repsFocusNode = FocusNode();

  @override
  void dispose() {
    _loadFocusNode.dispose();
    _repsFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocListener<WorkoutBloc, WorkoutState>(
    listenWhen: (previous, current) =>
        previous.focusSequence != current.focusSequence &&
        current.focusedSetId == widget.set.id,
    listener: (context, state) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Scrollable.ensureVisible(
          context,
          duration: RepSetMotion.standard,
          curve: Curves.easeOutCubic,
          alignment: .28,
        );
        _loadFocusNode.requestFocus();
      });
    },
    child: RepSetFoldIn(
      key: ValueKey('set-entry-${widget.set.id}'),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Material(
                  color: const Color(0xff1a211d),
                  borderRadius: BorderRadius.circular(11),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: Key(
                      'workout-set-row-${widget.exercise.position}-${widget.set.position}',
                    ),
                    onTap: () => _pickRpe(context),
                    onLongPress: () => _editSet(context),
                    child: Center(
                      child: Text(
                        widget.set.type == WorkoutSetType.warmup
                            ? 'W'
                            : '${widget.set.position + 1}',
                        style: TextStyle(
                          color: widget.set.type == WorkoutSetType.warmup
                              ? const Color(0xffd7ff4f)
                              : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 4,
                child: SizedBox(
                  key: Key(
                    'set-previous-${widget.exercise.position}-${widget.set.position}',
                  ),
                  height: 40,
                  child: Center(
                    child: Text(
                      widget.previous == null ||
                              (widget.inheritedLoadKg == null &&
                                  widget.inheritedRepetitions == null)
                          ? '—'
                          : '${_formatLoad(_displayLoad(widget.inheritedLoadKg ?? 0, widget.exercise.weightUnit))} ${widget.exercise.weightUnit.label} × ${widget.inheritedRepetitions ?? 0}',
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: widget.previous == null
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 3,
                child: _InlineSetField(
                  key: Key(
                    'set-load-${widget.exercise.position}-${widget.set.position}',
                  ),
                  focusNode: _loadFocusNode,
                  value: widget.set.loadKg == 0
                      ? ''
                      : _formatLoad(
                          _displayLoad(
                            widget.set.loadKg,
                            widget.exercise.weightUnit,
                          ),
                        ),
                  hint: widget.inheritedLoadKg == null
                      ? '0'
                      : _formatLoad(
                          _displayLoad(
                            widget.inheritedLoadKg!,
                            widget.exercise.weightUnit,
                          ),
                        ),
                  decimal: true,
                  semanticsLabel:
                      'Weight in ${widget.exercise.weightUnit.label}',
                  onCommit: (value) {
                    if (value.isEmpty) {
                      if (widget.set.loadKg != 0) {
                        _updateSet(context, loadKg: 0);
                      }
                      return;
                    }
                    final displayLoad = double.tryParse(
                      value.replaceAll(',', '.'),
                    );
                    if (displayLoad == null) return;
                    final loadKg = _loadInKilograms(
                      displayLoad,
                      widget.exercise.weightUnit,
                    );
                    if (loadKg == widget.set.loadKg) return;
                    _updateSet(context, loadKg: loadKg);
                  },
                  onSubmitted: _repsFocusNode.requestFocus,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 3,
                child: _RepsWithRpe(
                  exercise: widget.exercise,
                  set: widget.set,
                  inheritedRepetitions: widget.inheritedRepetitions,
                  focusNode: _repsFocusNode,
                  onCommit: (value) {
                    if (value.isEmpty) {
                      if (widget.set.repetitions != 0) {
                        _updateSet(context, repetitions: 0);
                      }
                      return;
                    }
                    final repetitions = int.tryParse(value);
                    if (repetitions == null ||
                        repetitions == widget.set.repetitions) {
                      return;
                    }
                    _updateSet(context, repetitions: repetitions);
                  },
                  onSubmitted: () => _completeSet(context),
                ),
              ),
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  key: Key(
                    'complete-set-${widget.exercise.position}-${widget.set.position}',
                  ),
                  tooltip: widget.set.isCompleted
                      ? 'Mark incomplete'
                      : 'Complete set',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  onPressed: () => context.read<WorkoutBloc>().add(
                    WorkoutSetCompletionToggled(
                      entryId: widget.exercise.id,
                      setId: widget.set.id,
                      inheritedRepetitions: widget.inheritedRepetitions,
                      inheritedLoadKg: widget.inheritedLoadKg,
                    ),
                  ),
                  icon: AnimatedSwitcher(
                    duration: RepSetMotion.fast,
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutBack,
                      ),
                      child: child,
                    ),
                    child: Icon(
                      widget.set.isCompleted
                          ? Icons.check_circle_rounded
                          : Icons.check_rounded,
                      key: ValueKey(widget.set.isCompleted),
                      color: widget.set.isCompleted
                          ? const Color(0xffd7ff4f)
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (widget.showRestRail)
            RestCountdownRail(
              key: Key(
                'rest-timer-${widget.exercise.position}-${widget.set.position}',
              ),
              durationSeconds: widget.exercise.restSeconds,
              startedAt: widget.restStartedAt,
              onDurationTap: widget.onRestDurationTap,
            ),
        ],
      ),
    ),
  );

  void _completeSet(BuildContext context) {
    if (widget.set.isCompleted) return;
    context.read<WorkoutBloc>().add(
      WorkoutSetCompletionToggled(
        entryId: widget.exercise.id,
        setId: widget.set.id,
        inheritedRepetitions: widget.inheritedRepetitions,
        inheritedLoadKg: widget.inheritedLoadKg,
      ),
    );
  }

  void _updateSet(BuildContext context, {double? loadKg, int? repetitions}) {
    context.read<WorkoutBloc>().add(
      WorkoutSetUpdated(
        entryId: widget.exercise.id,
        setId: widget.set.id,
        repetitions: repetitions ?? widget.set.repetitions,
        loadKg: loadKg ?? widget.set.loadKg,
        rpe: widget.set.rpe,
        notes: widget.set.notes,
        type: widget.set.type,
      ),
    );
  }

  Future<void> _editSet(BuildContext context) async {
    final draft = await showModalBottomSheet<_SetDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: RepSetMotion.sheetAnimation,
      builder: (_) => _SetEditorSheet(
        set: widget.set,
        weightUnit: widget.exercise.weightUnit,
      ),
    );
    if (draft == null || !context.mounted) return;
    if (draft.remove) {
      context.read<WorkoutBloc>().add(
        WorkoutSetRemoved(entryId: widget.exercise.id, setId: widget.set.id),
      );
      return;
    }
    context.read<WorkoutBloc>().add(
      WorkoutSetUpdated(
        entryId: widget.exercise.id,
        setId: widget.set.id,
        repetitions: draft.repetitions,
        loadKg: draft.loadKg,
        rpe: draft.rpe,
        notes: draft.notes,
        type: draft.type,
      ),
    );
  }

  Future<void> _pickRpe(BuildContext context) async {
    final selection = await showModalBottomSheet<_RpeSelection>(
      context: context,
      useSafeArea: true,
      sheetAnimationStyle: RepSetMotion.sheetAnimation,
      builder: (_) => _RpePickerSheet(selectedRpe: widget.set.rpe),
    );
    if (selection == null || !context.mounted) return;
    final currentSet = context
        .read<WorkoutBloc>()
        .state
        .session
        ?.exercises
        .where((entry) => entry.id == widget.exercise.id)
        .firstOrNull
        ?.sets
        .where((entry) => entry.id == widget.set.id)
        .firstOrNull;
    context.read<WorkoutBloc>().add(
      WorkoutSetUpdated(
        entryId: widget.exercise.id,
        setId: widget.set.id,
        repetitions: currentSet?.repetitions ?? widget.set.repetitions,
        loadKg: currentSet?.loadKg ?? widget.set.loadKg,
        rpe: selection.value,
        notes: currentSet?.notes ?? widget.set.notes,
        type: currentSet?.type ?? widget.set.type,
      ),
    );
  }
}

class _RpeSelection {
  const _RpeSelection(this.value);

  final double? value;
}

class _RpePickerSheet extends StatelessWidget {
  const _RpePickerSheet({required this.selectedRpe});

  final double? selectedRpe;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Choose RPE',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          'How hard did this set feel?',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var value = 6.0; value <= 10; value += .5)
              ChoiceChip(
                key: Key('rpe-${_formatRpe(value)}'),
                label: Text(_formatRpe(value)),
                selected: selectedRpe == value,
                onSelected: (_) => Navigator.pop(context, _RpeSelection(value)),
              ),
          ],
        ),
        if (selectedRpe != null) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            key: const Key('clear-rpe'),
            onPressed: () => Navigator.pop(context, const _RpeSelection(null)),
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Clear RPE'),
          ),
        ],
      ],
    ),
  );
}

class _RepsWithRpe extends StatelessWidget {
  const _RepsWithRpe({
    required this.exercise,
    required this.set,
    required this.inheritedRepetitions,
    required this.onCommit,
    required this.focusNode,
    required this.onSubmitted,
  });

  final WorkoutExercise exercise;
  final WorkoutSet set;
  final int? inheritedRepetitions;
  final ValueChanged<String> onCommit;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          top: 0,
          child: _InlineSetField(
            key: Key('set-reps-${exercise.position}-${set.position}'),
            value: set.repetitions == 0 ? '' : '${set.repetitions}',
            hint: inheritedRepetitions?.toString() ?? '0',
            semanticsLabel: 'Repetitions',
            onCommit: onCommit,
            focusNode: focusNode,
            onSubmitted: onSubmitted,
          ),
        ),
        Positioned(
          top: -5,
          left: -5,
          child: Semantics(
            key: const Key('set-rpe-badge'),
            label: set.rpe == null ? null : 'RPE ${_formatRpe(set.rpe!)}',
            child: AnimatedSwitcher(
              duration: RepSetMotion.fast,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutBack,
                  ),
                  child: child,
                ),
              ),
              child: set.rpe == null
                  ? const SizedBox.shrink(key: ValueKey('no-rpe-value'))
                  : Container(
                      key: ValueKey('rpe-value-${set.rpe}'),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xffd7ff4f),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xff252d28),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _formatRpe(set.rpe!),
                        style: const TextStyle(
                          color: Color(0xff171914),
                          fontSize: 7.5,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _InlineSetField extends StatefulWidget {
  const _InlineSetField({
    required this.value,
    required this.hint,
    required this.semanticsLabel,
    required this.onCommit,
    this.focusNode,
    this.onSubmitted,
    this.decimal = false,
    super.key,
  });

  final String value;
  final String hint;
  final String semanticsLabel;
  final ValueChanged<String> onCommit;
  final FocusNode? focusNode;
  final VoidCallback? onSubmitted;
  final bool decimal;

  @override
  State<_InlineSetField> createState() => _InlineSetFieldState();
}

class _InlineSetFieldState extends State<_InlineSetField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  bool get _ownsFocusNode => widget.focusNode == null;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocus);
  }

  @override
  void didUpdateWidget(covariant _InlineSetField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  void _handleFocus() {
    if (!_focusNode.hasFocus) widget.onCommit(_controller.text.trim());
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocus);
    if (_ownsFocusNode) _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KeyboardField(
    focusNode: _focusNode,
    showArrows: false,
    showDone: false,
    toolbarButtons: [
      (_) => TextButton(
        key: Key('keyboard-next-${widget.key}'),
        onPressed: _submit,
        child: const Text(
          'Next',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    ],
    child: Semantics(
      label: widget.semanticsLabel,
      textField: true,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.numberWithOptions(decimal: widget.decimal),
        inputFormatters: [
          if (widget.decimal)
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
          else
            FilteringTextInputFormatter.digitsOnly,
        ],
        textInputAction: TextInputAction.next,
        onSubmitted: (_) => _submit(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: const TextStyle(color: Color(0xff69706c)),
          filled: true,
          fillColor: const Color(0xff1a211d),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 3,
            vertical: 6,
          ),
          constraints: const BoxConstraints.tightFor(height: 40),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xffd7ff4f), width: 1.5),
          ),
        ),
      ),
    ),
  );

  void _submit() {
    widget.onCommit(_controller.text.trim());
    widget.onSubmitted?.call();
  }
}

class _RestDurationSheet extends StatefulWidget {
  const _RestDurationSheet({required this.initialSeconds});

  final int initialSeconds;

  @override
  State<_RestDurationSheet> createState() => _RestDurationSheetState();
}

class _RestDurationSheetState extends State<_RestDurationSheet> {
  late int _seconds = widget.initialSeconds;

  void _adjust(int delta) => setState(() {
    _seconds = (_seconds + delta).clamp(15, 600).toInt();
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Rest between sets',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          'Used for every set in this exercise.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              key: const Key('rest-minus-15'),
              tooltip: 'Remove 15 seconds',
              onPressed: _seconds <= 15 ? null : () => _adjust(-15),
              icon: const Icon(Icons.remove_rounded),
            ),
            SizedBox(
              width: 112,
              child: Text(
                _formatDuration(_seconds),
                key: const Key('rest-duration-value'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xffd7ff4f),
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            IconButton.filledTonal(
              key: const Key('rest-plus-15'),
              tooltip: 'Add 15 seconds',
              onPressed: _seconds >= 600 ? null : () => _adjust(15),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final seconds in const [30, 60, 90, 120, 180])
              ChoiceChip(
                key: Key('rest-preset-$seconds'),
                label: Text(_formatDuration(seconds)),
                selected: _seconds == seconds,
                onSelected: (_) => setState(() => _seconds = seconds),
              ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('save-rest-duration'),
            onPressed: () => Navigator.pop(context, _seconds),
            child: const Text('Save rest time'),
          ),
        ),
      ],
    ),
  );
}

class _SetDraft {
  const _SetDraft({
    required this.repetitions,
    required this.loadKg,
    required this.rpe,
    required this.notes,
    required this.type,
    this.remove = false,
  });

  final int repetitions;
  final double loadKg;
  final double? rpe;
  final String notes;
  final WorkoutSetType type;
  final bool remove;
}

class _SetEditorSheet extends StatefulWidget {
  const _SetEditorSheet({required this.set, required this.weightUnit});
  final WorkoutSet set;
  final WorkoutWeightUnit weightUnit;

  @override
  State<_SetEditorSheet> createState() => _SetEditorSheetState();
}

class _SetEditorSheetState extends State<_SetEditorSheet> {
  late final TextEditingController _loadController = TextEditingController(
    text: _formatLoad(_displayLoad(widget.set.loadKg, widget.weightUnit)),
  );
  late final TextEditingController _repsController = TextEditingController(
    text: widget.set.repetitions == 0 ? '' : '${widget.set.repetitions}',
  );
  late final TextEditingController _notesController = TextEditingController(
    text: widget.set.notes,
  );
  late double? _rpe = widget.set.rpe;
  late WorkoutSetType _type = widget.set.type;

  @override
  void dispose() {
    _loadController.dispose();
    _repsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      12,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Edit set',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          SegmentedButton<WorkoutSetType>(
            segments: const [
              ButtonSegment(
                value: WorkoutSetType.working,
                label: Text('Working'),
              ),
              ButtonSegment(
                value: WorkoutSetType.warmup,
                label: Text('Warm-up'),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (value) => setState(() => _type = value.single),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('set-load-field'),
                  controller: _loadController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Weight',
                    suffixText: widget.weightUnit.label,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const Key('set-reps-field'),
                  controller: _repsController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Repetitions',
                    suffixText: 'reps',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Text(
                'RPE',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'optional • effort for this set',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              ChoiceChip(
                label: const Text('—'),
                selected: _rpe == null,
                onSelected: (_) => setState(() => _rpe = null),
              ),
              for (var value = 6.0; value <= 10; value += .5)
                ChoiceChip(
                  key: Key('rpe-${_formatRpe(value)}'),
                  label: Text(_formatRpe(value)),
                  selected: _rpe == value,
                  onSelected: (_) => setState(() => _rpe = value),
                ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Set notes',
              hintText: 'Tempo, technique, pain, setup…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('save-set-button'),
              onPressed: _save,
              child: const Text('Save set'),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(
                context,
                _SetDraft(
                  repetitions: widget.set.repetitions,
                  loadKg: widget.set.loadKg,
                  rpe: widget.set.rpe,
                  notes: widget.set.notes,
                  type: widget.set.type,
                  remove: true,
                ),
              ),
              child: const Text('Remove set'),
            ),
          ),
        ],
      ),
    ),
  );

  void _save() {
    final repetitions = int.tryParse(_repsController.text) ?? 0;
    final load =
        double.tryParse(_loadController.text.replaceAll(',', '.')) ?? 0;
    Navigator.pop(
      context,
      _SetDraft(
        repetitions: repetitions,
        loadKg: _loadInKilograms(load, widget.weightUnit),
        rpe: _rpe,
        notes: _notesController.text.trim(),
        type: _type,
      ),
    );
  }
}

class _ExercisePickerSheet extends StatefulWidget {
  const _ExercisePickerSheet();

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  String _query = '';
  final Set<String> _selectedIds = {};
  final List<Exercise> _createdExercises = [];
  String? _selectedTarget;
  String? _selectedEquipment;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryBloc>().state;
    final normalized = _query.trim().toLowerCase();
    final allExercises = <String, Exercise>{
      for (final exercise in library.exercises) exercise.id: exercise,
      for (final exercise in _createdExercises) exercise.id: exercise,
    }.values.toList(growable: false);
    final exercises = allExercises
        .where(
          (exercise) =>
              (_selectedTarget == null || exercise.target == _selectedTarget) &&
              (_selectedEquipment == null ||
                  exercise.equipment == _selectedEquipment) &&
              (normalized.isEmpty ||
                  exercise.name.toLowerCase().contains(normalized) ||
                  exercise.target.toLowerCase().contains(normalized) ||
                  exercise.equipment.toLowerCase().contains(normalized)),
        )
        .toList(growable: false);
    final selected = allExercises
        .where((exercise) => _selectedIds.contains(exercise.id))
        .toList(growable: false);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .88,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selected.isEmpty
                      ? 'Select exercises'
                      : '${selected.length} selected',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: FilledButton.icon(
                        key: const Key('picker-add-selected'),
                        onPressed: selected.isEmpty
                            ? null
                            : () => Navigator.pop(
                                context,
                                _ExerciseSelection(selected),
                              ),
                        icon: const Icon(Icons.add_rounded, size: 17),
                        label: const Text('Add exercises'),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              key: const Key('create-custom-exercise-button'),
                              onPressed: _createCustomExercise,
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xffd7ff4f),
                                minimumSize: const Size(0, 28),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text(
                                'New',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          OutlinedButton.icon(
                            key: const Key('picker-add-superset'),
                            onPressed: selected.length == 2
                                ? () => Navigator.pop(
                                    context,
                                    _ExerciseSelection(
                                      selected,
                                      asSuperset: true,
                                    ),
                                  )
                                : null,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 34),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.link_rounded, size: 16),
                            label: const Text('Superset'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  selected.length == 2
                      ? 'Add them separately, or create one linked superset.'
                      : 'Select two exercises to enable Superset.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('workout-exercise-search'),
                  autofocus: true,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search exercises',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _PickerFilterButton(
                        key: const Key('picker-muscle-filter'),
                        label: _selectedTarget ?? 'Muscle',
                        icon: Icons.accessibility_new_rounded,
                        active: _selectedTarget != null,
                        onTap: () => _pickFilter(
                          title: 'Filter by muscle',
                          values: library.targets,
                          selected: _selectedTarget,
                          onSelected: (value) =>
                              setState(() => _selectedTarget = value),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _PickerFilterButton(
                        key: const Key('picker-machine-filter'),
                        label: _selectedEquipment ?? 'Machine',
                        icon: Icons.precision_manufacturing_outlined,
                        active: _selectedEquipment != null,
                        onTap: () => _pickFilter(
                          title: 'Filter by machine',
                          values: library.equipment,
                          selected: _selectedEquipment,
                          onSelected: (value) =>
                              setState(() => _selectedEquipment = value),
                        ),
                      ),
                      if (_selectedTarget != null || _selectedEquipment != null)
                        TextButton(
                          key: const Key('picker-clear-filters'),
                          onPressed: () => setState(() {
                            _selectedTarget = null;
                            _selectedEquipment = null;
                          }),
                          child: const Text('Clear'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: exercises.isEmpty
                ? Center(
                    child: Text(
                      library.isLoading
                          ? 'Loading exercises…'
                          : 'No exercises found.',
                    ),
                  )
                : ListView.builder(
                    itemCount: exercises.length,
                    itemBuilder: (context, index) {
                      final exercise = exercises[index];
                      final isSelected = _selectedIds.contains(exercise.id);
                      return ListTile(
                        key: Key('picker-exercise-${exercise.id}'),
                        selected: isSelected,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        leading: ExerciseMedia(exercise: exercise, size: 48),
                        title: Text(exercise.name),
                        subtitle: Text(
                          '${exercise.target} • ${exercise.equipment}',
                        ),
                        trailing: AnimatedSwitcher(
                          duration: RepSetMotion.fast,
                          child: Icon(
                            isSelected
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            key: ValueKey(isSelected),
                            color: isSelected ? const Color(0xffd7ff4f) : null,
                          ),
                        ),
                        onTap: () => setState(() {
                          if (isSelected) {
                            _selectedIds.remove(exercise.id);
                          } else {
                            _selectedIds.add(exercise.id);
                          }
                        }),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFilter({
    required String title,
    required List<String> values,
    required String? selected,
    required ValueChanged<String?> onSelected,
  }) async {
    final value = await showModalBottomSheet<String?>(
      context: context,
      useSafeArea: true,
      sheetAnimationStyle: RepSetMotion.sheetAnimation,
      builder: (context) =>
          _PickerFilterSheet(title: title, values: values, selected: selected),
    );
    if (!mounted) return;
    onSelected(value);
  }

  Future<void> _createCustomExercise() async {
    final library = context.read<LibraryBloc>().state;
    final bodyParts =
        library.exercises
            .map((exercise) => exercise.bodyPart)
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final exercise = await showModalBottomSheet<Exercise>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      sheetAnimationStyle: RepSetMotion.sheetAnimation,
      builder: (_) => _CreateCustomExerciseSheet(
        bodyParts: bodyParts,
        targets: library.targets,
        equipment: library.equipment,
      ),
    );
    if (exercise == null || !mounted) return;

    context.read<LibraryBloc>().add(LibraryCustomExerciseCreated(exercise));
    setState(() {
      _createdExercises.removeWhere((item) => item.id == exercise.id);
      _createdExercises.add(exercise);
      _selectedIds.add(exercise.id);
      _query = exercise.name;
      _selectedTarget = null;
      _selectedEquipment = null;
    });
  }
}

class _ExerciseSelection {
  const _ExerciseSelection(this.exercises, {this.asSuperset = false});

  final List<Exercise> exercises;
  final bool asSuperset;
}

class _CreateCustomExerciseSheet extends StatefulWidget {
  const _CreateCustomExerciseSheet({
    required this.bodyParts,
    required this.targets,
    required this.equipment,
  });

  final List<String> bodyParts;
  final List<String> targets;
  final List<String> equipment;

  @override
  State<_CreateCustomExerciseSheet> createState() =>
      _CreateCustomExerciseSheetState();
}

class _CreateCustomExerciseSheetState
    extends State<_CreateCustomExerciseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _bodyPart;
  String? _target;
  String? _equipment;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    Navigator.pop(
      context,
      Exercise(
        id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        bodyPart: _bodyPart!,
        target: _target!,
        equipment: _equipment!,
        secondaryMuscles: const [],
        instructions: const [],
        isCustom: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Create exercise',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Create the movement, then classify it using your existing library categories.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              key: const Key('custom-exercise-name-field'),
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Exercise name',
                hintText: 'e.g. Hammer Strength incline press',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter an exercise name.'
                  : null,
              onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('custom-exercise-category-field'),
              initialValue: _bodyPart,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: widget.bodyParts
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(growable: false),
              validator: (value) => value == null ? 'Choose a category.' : null,
              onChanged: (value) => setState(() => _bodyPart = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('custom-exercise-target-field'),
              initialValue: _target,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Primary muscle',
                border: OutlineInputBorder(),
              ),
              items: widget.targets
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(growable: false),
              validator: (value) => value == null ? 'Choose a muscle.' : null,
              onChanged: (value) => setState(() => _target = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('custom-exercise-equipment-field'),
              initialValue: _equipment,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Machine or equipment',
                border: OutlineInputBorder(),
              ),
              items: widget.equipment
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(growable: false),
              validator: (value) => value == null ? 'Choose equipment.' : null,
              onChanged: (value) => setState(() => _equipment = value),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const Key('save-custom-exercise-button'),
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Create & select'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PickerFilterButton extends StatelessWidget {
  const _PickerFilterButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: Icon(
      icon,
      size: 17,
      color: active ? const Color(0xff171914) : null,
    ),
    label: Text(label),
    labelStyle: TextStyle(
      color: active ? const Color(0xff171914) : null,
      fontWeight: FontWeight.w800,
    ),
    backgroundColor: active
        ? const Color(0xffd7ff4f)
        : Theme.of(context).colorScheme.surfaceContainerHighest,
    side: active ? BorderSide.none : null,
    onPressed: onTap,
  );
}

class _PickerFilterSheet extends StatelessWidget {
  const _PickerFilterSheet({
    required this.title,
    required this.values,
    required this.selected,
  });

  final String title;
  final List<String> values;
  final String? selected;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .68,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Any'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: values.length,
              itemBuilder: (context, index) {
                final value = values[index];
                return ListTile(
                  title: Text(value),
                  trailing: selected == value
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xffd7ff4f),
                        )
                      : null,
                  onTap: () => Navigator.pop(context, value),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _SingleExercisePickerSheet extends StatefulWidget {
  const _SingleExercisePickerSheet();

  @override
  State<_SingleExercisePickerSheet> createState() =>
      _SingleExercisePickerSheetState();
}

class _SingleExercisePickerSheetState
    extends State<_SingleExercisePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryBloc>().state;
    final query = _query.trim().toLowerCase();
    final exercises = library.exercises
        .where(
          (exercise) =>
              query.isEmpty ||
              exercise.name.toLowerCase().contains(query) ||
              exercise.target.toLowerCase().contains(query) ||
              exercise.equipment.toLowerCase().contains(query),
        )
        .toList(growable: false);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .88,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replace exercise',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'The existing set rows will be cleared.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('replace-exercise-search'),
                  autofocus: true,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search exercises',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: exercises.length,
              itemBuilder: (context, index) {
                final exercise = exercises[index];
                return ListTile(
                  key: Key('replace-picker-exercise-${exercise.id}'),
                  title: Text(exercise.name),
                  subtitle: Text('${exercise.target} • ${exercise.equipment}'),
                  trailing: const Icon(Icons.arrow_forward_rounded),
                  onTap: () => Navigator.pop(context, exercise),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _formatLoad(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);

double _displayLoad(double kilograms, WorkoutWeightUnit unit) =>
    unit == WorkoutWeightUnit.pounds ? kilograms * 2.2046226218 : kilograms;

double _loadInKilograms(double displayLoad, WorkoutWeightUnit unit) =>
    unit == WorkoutWeightUnit.pounds ? displayLoad / 2.2046226218 : displayLoad;

String _formatRpe(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);

String _formatDuration(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String? _latestCompletedSetId(WorkoutSession session) {
  WorkoutSet? latest;
  final now = DateTime.now();
  for (final exercise in session.exercises) {
    for (final set in exercise.sets) {
      final completedAt = set.completedAt;
      if (!set.isCompleted || completedAt == null) continue;
      final endsAt = completedAt.add(Duration(seconds: exercise.restSeconds));
      if (!endsAt.isAfter(now)) continue;
      if (latest?.completedAt == null ||
          completedAt.isAfter(latest!.completedAt!)) {
        latest = set;
      }
    }
  }
  if (latest == null) return null;
  final owner = session.exercises.firstWhere(
    (exercise) => exercise.sets.any((set) => set.id == latest!.id),
  );
  final groupId = owner.supersetId;
  if (groupId != null) {
    final group =
        session.exercises
            .where((exercise) => exercise.supersetId == groupId)
            .toList(growable: false)
          ..sort((a, b) => a.position.compareTo(b.position));
    if (owner.id != group.last.id) return null;
  }
  return latest.id;
}
