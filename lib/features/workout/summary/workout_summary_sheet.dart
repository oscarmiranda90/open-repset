import 'package:flutter/material.dart';

import '../../../domain/workout_summary.dart';
import 'summary_copy.dart';
import 'summary_motion.dart';

/// Presents the finished-workout summary as a centred modal.
///
/// [load] runs while the modal is already on screen so the transition never
/// waits on a database read.
Future<void> showWorkoutSummarySheet(
  BuildContext context, {
  required Future<WorkoutSummary> Function() load,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  barrierColor: Colors.black.withValues(alpha: .72),
  builder: (dialogContext) => _WorkoutSummarySheet(load: load),
);

class _WorkoutSummarySheet extends StatefulWidget {
  const _WorkoutSummarySheet({required this.load});

  final Future<WorkoutSummary> Function() load;

  @override
  State<_WorkoutSummarySheet> createState() => _WorkoutSummarySheetState();
}

class _WorkoutSummarySheetState extends State<_WorkoutSummarySheet> {
  late final Future<WorkoutSummary> _summary = widget.load();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      backgroundColor: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: media.size.height * .86,
        ),
        child: FutureBuilder<WorkoutSummary>(
          future: _summary,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 70),
                child: Center(child: RollingPlate()),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return _SummaryError(
                onClose: () => Navigator.of(context).maybePop(),
              );
            }
            return _SummaryBody(summary: snapshot.data!);
          },
        ),
      ),
    );
  }
}

class _SummaryError extends StatelessWidget {
  const _SummaryError({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          size: 44,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 14),
        Text(
          'Workout saved',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'The summary could not be built, but the session itself is stored.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: onClose, child: const Text('Done')),
      ],
    ),
  );
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({required this.summary});

  final WorkoutSummary summary;

  @override
  Widget build(BuildContext context) {
    final records = summary.records;

    // Choreography: the receipt prints first and everything else follows it in,
    // so the modal reads as one sequence rather than a page that fades in.
    const receiptDelay = Duration(milliseconds: 260);
    const metricsDelay = Duration(milliseconds: 940);
    final recordsDelay =
        metricsDelay + Duration(milliseconds: 120 + records.length * 20);
    final chartDelay =
        recordsDelay + Duration(milliseconds: 160 + records.length * 110);

    return Column(
      key: const Key('workout-summary-sheet'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Stack(
            children: [
              Positioned(
                top: -40,
                left: 0,
                right: 0,
                height: 240,
                child: IgnorePointer(
                  child: SuccessBurst(delay: const Duration(milliseconds: 120)),
                ),
              ),
              ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                children: [
                  SummaryShutter(child: _Header(summary: summary)),
                  const SizedBox(height: 18),
                  ReceiptTickerPrint(
                    delay: receiptDelay,
                    child: _Receipt(summary: summary),
                  ),
                  const SizedBox(height: 22),
                  _MetricGrid(summary: summary, baseDelay: metricsDelay),
                  if (records.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _SectionLabel(
                      label: records.length == 1
                          ? '1 personal record'
                          : '${records.length} personal records',
                      delay: recordsDelay,
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(
                      records.length,
                      (index) => Padding(
                        padding: EdgeInsets.only(
                          bottom: index == records.length - 1 ? 0 : 10,
                        ),
                        child: FoldingRow(
                          delay:
                              recordsDelay +
                              Duration(milliseconds: 80 + index * 110),
                          child: _RecordTile(record: records[index]),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _SectionLabel(label: 'Volume by exercise', delay: chartDelay),
                  const SizedBox(height: 12),
                  _VolumeChart(summary: summary, baseDelay: chartDelay),
                ],
              ),
            ],
          ),
        ),
        const _SummaryFooter(),
      ],
    );
  }
}

/// Pinned so the summary can always be dismissed without scrolling to the
/// bottom of a long session.
class _SummaryFooter extends StatelessWidget {
  const _SummaryFooter();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: .6)),
        ),
      ),
      child: FilledButton(
        key: const Key('summary-done-button'),
        onPressed: () => Navigator.of(context).maybePop(),
        style: FilledButton.styleFrom(
          backgroundColor: summaryAccent,
          foregroundColor: const Color(0xff171914),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          'Done',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
      ),
    );
  }
}

class _Header extends StatefulWidget {
  const _Header({required this.summary});

  final WorkoutSummary summary;

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  // Resolved once: picking inside build would reshuffle the line on every
  // animation frame.
  late final SummaryHeroCopy _copy = summaryHeroCopy(widget.summary);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/icon/brand_mark.png',
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                widget.summary.isFirstSession
                    ? 'FIRST SESSION LOGGED'
                    : 'WORKOUT COMPLETE',
                style: const TextStyle(
                  color: summaryAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _copy.headline,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -1.2,
            height: 1.02,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          _copy.subline,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.summary.session.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: scheme.onSurfaceVariant.withValues(alpha: .7),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: .2,
          ),
        ),
      ],
    );
  }
}

/// Monospaced receipt, printed downward — the same motion as the lab's
/// receipt ticker, but driven by the session that actually happened.
class _Receipt extends StatelessWidget {
  const _Receipt({required this.summary});

  final WorkoutSummary summary;

  @override
  Widget build(BuildContext context) {
    final exercises = summary.session.exercises
        .where((exercise) => exercise.sets.any((set) => set.isCompleted))
        .toList(growable: false);
    // The lines are part of the paper, not separately animated: the whole
    // receipt travels in as one printed sheet, matching the lab's motion.
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 17),
      color: const Color(0xffe8eadf),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Color(0xff171914),
          fontFamily: 'monospace',
          fontSize: 11.5,
          height: 1.55,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'REPSET / SESSION RECEIPT',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: .4),
            ),
            const _ReceiptDivider(),
            ...exercises.map((exercise) {
              final done = exercise.sets
                  .where((set) => set.isCompleted)
                  .toList(growable: false);
              final topSet = done.reduce(
                (best, set) => set.loadKg > best.loadKg ? set : best,
              );
              return _ReceiptLine(
                left: exercise.name,
                right:
                    '${done.length}x${topSet.repetitions}  '
                    '${_formatKg(topSet.loadKg)}',
              );
            }),
            const _ReceiptDivider(),
            _ReceiptLine(
              left: 'TOTAL VOLUME',
              right: '${_formatKg(summary.volumeKg)} kg',
              bold: true,
            ),
            _ReceiptLine(
              left: 'DURATION',
              right: _formatDuration(summary.duration),
            ),
            const _ReceiptDivider(),
            const Text(
              'SESSION SAVED',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptDivider extends StatelessWidget {
  const _ReceiptDivider();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 3),
    child: Text('- - - - - - - - - - - - - - - - - - - -', maxLines: 1),
  );
}

class _ReceiptLine extends StatelessWidget {
  const _ReceiptLine({
    required this.left,
    required this.right,
    this.bold = false,
  });

  final String left;
  final String right;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );
    return Row(
      children: [
        Expanded(
          child: Text(
            left.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const SizedBox(width: 10),
        Text(right, maxLines: 1, style: style),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.summary, required this.baseDelay});

  final WorkoutSummary summary;
  final Duration baseDelay;

  @override
  Widget build(BuildContext context) {
    final rpe = summary.averageRpe;
    // Each tile flips in 80ms after the one before it.
    Duration step(int index) => baseDelay + Duration(milliseconds: index * 80);
    final tiles = <Widget>[
      MetricFlip(
        value: summary.volumeKg,
        label: 'total volume (kg)',
        delay: step(0),
        emphasised: true,
      ),
      MetricFlip(
        value: summary.completedSetCount.toDouble(),
        label: 'sets completed',
        delay: step(1),
      ),
      MetricFlip(
        value: summary.totalReps.toDouble(),
        label: 'total reps',
        delay: step(2),
      ),
      MetricFlip(
        value: summary.heaviestSetKg,
        label: 'heaviest set (kg)',
        fractionDigits: summary.heaviestSetKg % 1 == 0 ? 0 : 1,
        delay: step(3),
      ),
      MetricFlip(
        value: summary.duration.inMinutes.toDouble(),
        label: 'minutes trained',
        delay: step(4),
      ),
      if (rpe != null)
        MetricFlip(
          value: rpe,
          label: 'average RPE',
          fractionDigits: 1,
          delay: step(5),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final columns = constraints.maxWidth < 330 ? 2 : 3;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: 16,
          children: tiles
              .map((tile) => SizedBox(width: width, child: tile))
              .toList(growable: false),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.delay});

  final String label;
  final Duration delay;

  @override
  Widget build(BuildContext context) => FoldingRow(
    delay: delay,
    child: Text(
      label.toUpperCase(),
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
      ),
    ),
  );
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record});

  final WorkoutRecord record;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: summaryAccent.withValues(alpha: .35)),
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 44,
            child: RecordRipple(
              child: Center(
                child: Text(
                  'PR',
                  style: TextStyle(
                    color: summaryAccent,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .4,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  record.exerciseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _detail(record),
                  maxLines: 2,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _detail(WorkoutRecord record) {
    final noun = record.kind == WorkoutRecordKind.heaviestSet
        ? 'Heaviest set'
        : 'Best session volume';
    final value = '${_formatKg(record.value)} kg';
    if (record.isFirstTime) return '$noun · $value · first time logged';
    return '$noun · $value · +${_formatKg(record.improvement)} kg';
  }
}

/// Horizontal bars sized against the session's biggest contributor.
class _VolumeChart extends StatelessWidget {
  const _VolumeChart({required this.summary, required this.baseDelay});

  final WorkoutSummary summary;
  final Duration baseDelay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries =
        summary.session.exercises
            .map(
              (exercise) => (
                name: exercise.name,
                volume: exercise.sets.fold<double>(
                  0,
                  (total, set) => total + set.volumeKg,
                ),
              ),
            )
            .where((entry) => entry.volume > 0)
            .toList(growable: false)
          ..sort((a, b) => b.volume.compareTo(a.volume));

    if (entries.isEmpty) {
      return Text(
        'No completed sets to chart.',
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
      );
    }

    final peak = entries.first.volume;
    return Column(
      children: List.generate(entries.length, (index) {
        final entry = entries[index];
        final delay = baseDelay + Duration(milliseconds: index * 90);
        return Padding(
          padding: EdgeInsets.only(
            bottom: index == entries.length - 1 ? 0 : 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${_formatKg(entry.volume)} kg',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              GrowingBar(fraction: entry.volume / peak, delay: delay),
            ],
          ),
        );
      }),
    );
  }
}

String _formatKg(double value) {
  final rounded = value.round();
  if ((value - rounded).abs() > .05) return value.toStringAsFixed(1);
  final text = '$rounded';
  final buffer = StringBuffer();
  for (var index = 0; index < text.length; index++) {
    if (index > 0 && (text.length - index) % 3 == 0) buffer.write(',');
    buffer.write(text[index]);
  }
  return buffer.toString();
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}
