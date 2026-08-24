import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/motion/repset_motion.dart';
import '../../domain/workout_session.dart';
import 'history_bloc.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<HistoryBloc, HistoryState>(
    builder: (context, state) => CustomScrollView(
      key: const Key('history-page'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'History',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Every finished session, kept on this device.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (state.isLoading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (state.sessions.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _HistoryEmptyState(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList.separated(
              itemCount: state.sessions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => RepSetEntrance(
                delay: Duration(milliseconds: 35 * index.clamp(0, 6)),
                child: _HistorySessionCard(session: state.sessions[index]),
              ),
            ),
          ),
      ],
    ),
  );
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.history_toggle_off_rounded,
          size: 48,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 14),
        Text(
          'Your completed workouts will appear here.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    ),
  );
}

class _HistorySessionCard extends StatelessWidget {
  const _HistorySessionCard({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => HistorySessionDetailPage(session: session),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xffd7ff4f),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.check_rounded, color: Color(0xff171914)),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatSessionDate(session.completedAt!)} · ${_formatDuration(session)}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${session.completedSetCount} sets',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatLoad(session.volumeKg)} kg',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}

class HistorySessionDetailPage extends StatelessWidget {
  const HistorySessionDetailPage({required this.session, super.key});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Workout summary'),
      actions: [
        IconButton(
          key: const Key('delete-history-session-button'),
          tooltip: 'Delete workout',
          onPressed: () => _confirmDelete(context),
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ],
    ),
    body: RepSetDirectionalReveal(
      trigger: 0,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        children: [
          Text(
            session.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_formatSessionDate(session.completedAt!)} · ${_formatDuration(session)}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  value: '${session.completedSetCount}',
                  label: 'SETS',
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _SummaryMetric(
                  value: _formatLoad(session.volumeKg),
                  label: 'VOLUME KG',
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _SummaryMetric(
                  value: '${session.exercises.length}',
                  label: 'EXERCISES',
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Exercises',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ...session.exercises.asMap().entries.map(
            (entry) => RepSetEntrance(
              delay: Duration(milliseconds: 65 * entry.key),
              child: _HistoryExerciseCard(exercise: entry.value),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _confirmDelete(BuildContext context) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete workout?'),
        content: Text('“${session.title}” will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-delete-history-session-button'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (delete == true && context.mounted) {
      context.read<HistoryBloc>().add(HistorySessionDeleted(session.id));
      Navigator.pop(context);
    }
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            fontSize: 9,
          ),
        ),
      ],
    ),
  );
}

class _HistoryExerciseCard extends StatelessWidget {
  const _HistoryExerciseCard({required this.exercise});

  final WorkoutExercise exercise;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          exercise.name,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        ...exercise.sets
            .where((set) => set.isCompleted)
            .map(
              (set) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    Text(
                      'SET ${set.position + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Text('${_formatLoad(set.loadKg)} kg × ${set.repetitions}'),
                    if (set.rpe != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'RPE ${set.rpe}',
                        style: const TextStyle(
                          color: Color(0xffd7ff4f),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
      ],
    ),
  );
}

String _formatSessionDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String _formatDuration(WorkoutSession session) {
  final duration = session.completedAt!.difference(session.startedAt);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  return hours == 0 ? '${minutes}m' : '${hours}h ${minutes}m';
}

String _formatLoad(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);
