import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/motion/repset_motion.dart';
import '../dev/adapted_animations.dart';
import 'session_planner_bloc.dart';

const _accent = Color(0xffd7ff4f);

/// What the person chose to do with a proposed session.
enum SessionPlanChoice { dismissed, saveTemplate, train }

/// The planner's working state and its answer, in one sheet.
///
/// It opens the moment a request is sent rather than after the answer arrives,
/// so the wait has somewhere to live. Planning takes several seconds — long
/// enough that a silent home screen reads as a dropped request.
class SessionPlanModal extends StatelessWidget {
  const SessionPlanModal({super.key, required this.state});

  final SessionPlannerState state;

  static Future<SessionPlanChoice?> show(
    BuildContext context, {
    required Stream<SessionPlannerState> states,
    required SessionPlannerState initial,
  }) => showModalBottomSheet<SessionPlanChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // Dismissing by tapping away would discard a plan that cost a request, so
    // leaving is a deliberate choice among the three buttons.
    isDismissible: false,
    enableDrag: false,
    builder: (context) => StreamBuilder<SessionPlannerState>(
      stream: states,
      initialData: initial,
      builder: (context, snapshot) =>
          SessionPlanModal(state: snapshot.data ?? initial),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _accent.withValues(alpha: .32)),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: switch (state.stage) {
          SessionPlanStage.interpreting ||
          SessionPlanStage.selecting => _PlanningView(stage: state.stage),
          SessionPlanStage.ready => _PlanView(state: state),
          _ => _FailedView(message: state.message),
        },
      ),
    );
  }
}

/// The wait, made legible.
///
/// The stage label changes as the work moves, so the loader is reporting
/// progress rather than merely occupying the time.
class _PlanningView extends StatefulWidget {
  const _PlanningView({required this.stage});

  final SessionPlanStage stage;

  @override
  State<_PlanningView> createState() => _PlanningViewState();
}

/// What the planner is doing, in the order it does it.
///
/// The first two lines track real stage changes. The rest advance on their own
/// while the second call runs, because that call is one long wait with no
/// reportable progress inside it — and a wait that shows nothing reads as a
/// wait that has stalled.
const _interpretingSteps = [
  'Reading your request',
  'Matching it to your library',
];

const _selectingSteps = [
  'Shortlisting exercises',
  'Ordering compounds first',
  'Setting sets and reps',
  'Finishing your session',
];

class _PlanningViewState extends State<_PlanningView> {
  Timer? _loop;
  Timer? _steps;
  int _pulse = 0;
  final _log = <String>[];

  @override
  void initState() {
    super.initState();
    // The lab's loader plays once per trigger; planning has no fixed length,
    // so it is restarted for as long as the work runs.
    _loop = Timer.periodic(
      const Duration(milliseconds: 1300),
      (_) => mounted ? setState(() => _pulse++) : null,
    );
    _appendFor(widget.stage);
  }

  @override
  void didUpdateWidget(_PlanningView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stage != widget.stage) _appendFor(widget.stage);
  }

  /// Starts the line sequence for a stage, and keeps it moving.
  void _appendFor(SessionPlanStage stage) {
    _steps?.cancel();
    final lines = stage == SessionPlanStage.interpreting
        ? _interpretingSteps
        : _selectingSteps;
    var index = 0;
    setState(() => _log.add(lines[index++]));
    _steps = Timer.periodic(const Duration(milliseconds: 1600), (timer) {
      if (!mounted || index >= lines.length) return timer.cancel();
      setState(() => _log.add(lines[index++]));
    });
  }

  @override
  void dispose() {
    _loop?.cancel();
    _steps?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The lab's loader lays its cells out from the left inside a box that
        // does not match their measured width, so it is centred here rather
        // than by changing a widget the lab also uses.
        Center(
          child: SizedBox(
            width: 139,
            child: MatrixGridLoader(trigger: _pulse),
          ),
        ),
        const SizedBox(height: 30),
        // Completed lines stay on screen: a log that replaces itself shows
        // activity, one that accumulates shows progress.
        for (final (index, line) in _log.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: _LogLine(text: line, done: index < _log.length - 1),
          ),
      ],
    ),
  );
}

/// One step of the planner's work.
class _LogLine extends StatelessWidget {
  const _LogLine({required this.text, required this.done});

  final String text;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RepSetEntrance(
      key: ValueKey(text),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 15,
            height: 15,
            child: done
                ? const Icon(Icons.check_rounded, size: 13, color: _accent)
                : const _PendingDot(),
          ),
          const SizedBox(width: 9),
          Text(
            text,
            style: TextStyle(
              color: done ? scheme.onSurfaceVariant : scheme.onSurface,
              fontSize: 13,
              fontWeight: done ? FontWeight.w600 : FontWeight.w800,
              letterSpacing: -.15,
            ),
          ),
        ],
      ),
    );
  }
}

/// The marker on the line still being worked on.
class _PendingDot extends StatefulWidget {
  const _PendingDot();

  @override
  State<_PendingDot> createState() => _PendingDotState();
}

class _PendingDotState extends State<_PendingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: FadeTransition(
      opacity: _pulse.drive(Tween(begin: .35, end: 1)),
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: _accent,
          shape: BoxShape.circle,
        ),
      ),
    ),
  );
}

/// The proposed session, and the three things you can do with it.
class _PlanView extends StatelessWidget {
  const _PlanView({required this.state});

  final SessionPlannerState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final plan = state.plan!;
    final totalSets = state.planned.fold<int>(
      0,
      (sum, entry) => sum + entry.plan.setCount,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RepSetEntrance(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 15,
                        color: _accent,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'PLANNED FOR YOU',
                        style: TextStyle(
                          color: _accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                RepSetEntrance(
                  delay: const Duration(milliseconds: 60),
                  child: Text(
                    plan.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                      letterSpacing: -.8,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                RepSetEntrance(
                  delay: const Duration(milliseconds: 90),
                  child: Text(
                    '${state.planned.length} exercises  ·  $totalSets sets',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                // Each exercise folds in behind the one before it, so the
                // session assembles rather than appearing all at once.
                for (final (index, entry) in state.planned.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: RepSetEntrance(
                      delay: Duration(milliseconds: 140 + index * 70),
                      child: _PlannedRow(entry: entry, position: index + 1),
                    ),
                  ),
              ],
            ),
          ),
        ),
        _PlanActions(),
      ],
    );
  }
}

class _PlannedRow extends StatelessWidget {
  const _PlannedRow({required this.entry, required this.position});

  final PlannedEntry entry;
  final int position;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 14, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$position',
              style: TextStyle(
                color: scheme.onSurfaceVariant.withValues(alpha: .7),
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.exercise.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.2,
                  ),
                ),
                if (entry.plan.notes.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.plan.notes,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${entry.plan.setCount} × ${entry.plan.repetitions}',
              style: const TextStyle(
                color: _accent,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: .45)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: RepSetPress(
              child: TextButton(
                key: const Key('plan-dismiss'),
                onPressed: () =>
                    Navigator.of(context).pop(SessionPlanChoice.dismissed),
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurfaceVariant,
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'No',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: RepSetPress(
              child: OutlinedButton(
                key: const Key('plan-save-template'),
                onPressed: () =>
                    Navigator.of(context).pop(SessionPlanChoice.saveTemplate),
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.onSurface,
                  side: BorderSide(color: scheme.outlineVariant),
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Save template',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: RepSetPress(
              child: FilledButton.icon(
                key: const Key('plan-train'),
                onPressed: () =>
                    Navigator.of(context).pop(SessionPlanChoice.train),
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: const Color(0xff171914),
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.bolt_rounded, size: 18),
                label: const Text(
                  'Train',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 30, color: scheme.error),
          const SizedBox(height: 14),
          Text(
            message ?? 'The session could not be planned right now.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 22),
          RepSetPress(
            child: FilledButton(
              key: const Key('plan-close'),
              onPressed: () =>
                  Navigator.of(context).pop(SessionPlanChoice.dismissed),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.surfaceContainerHigh,
                foregroundColor: scheme.onSurface,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Close',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
