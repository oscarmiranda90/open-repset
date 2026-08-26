import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/body_weight.dart';
import '../../domain/relative_strength_service.dart';
import '../../domain/training_analytics.dart';
import '../../domain/training_report.dart';
import '../../domain/workout_repository.dart';
import 'progress_bloc.dart';
import 'training_report_sheet.dart';

const _accent = Color(0xffd7ff4f);

/// Progress derived entirely from logged sessions.
///
/// Every number on this page comes from completed sets in the database. When
/// there is no history it says so rather than showing zeroes that read as data.
class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key, this.onBack});

  final VoidCallback? onBack;

  Future<void> _openTrainingReport(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => TrainingReportSheet(
          builder: TrainingReportBuilder(
            workouts: context.read<WorkoutRepository>(),
            analytics: context.read<TrainingAnalyticsRepository>(),
            bodyWeight: context.read<BodyWeightRepository>(),
          ),
        ),
      );

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ProgressBloc, ProgressState>(
    builder: (context, state) => SingleChildScrollView(
      key: const Key('progress-page'),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (onBack != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('progress-back-button'),
                  onPressed: onBack,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Today'),
                ),
              ),
              const SizedBox(height: 6),
            ],
            Row(
              children: [
                Text(
                  'PROGRESS',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  key: const Key('progress-share-training-report'),
                  onPressed: () => _openTrainingReport(context),
                  style: TextButton.styleFrom(
                    foregroundColor: _accent,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.ios_share_rounded, size: 17),
                  label: const Text('Report'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (state.isLoading && state.overview == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.hasError)
              const _ProgressMessage(
                icon: Icons.error_outline_rounded,
                title: 'Progress unavailable',
                body: 'Your sessions are safe. The summary could not be read.',
              )
            else if (state.isEmpty)
              const _ProgressMessage(
                icon: Icons.insights_outlined,
                title: 'No training logged yet',
                body:
                    'Finish a workout and this page fills with your own '
                    'numbers — volume, records, and how each lift is trending.',
              )
            else
              _ProgressContent(state: state),
          ],
        ),
      ),
    ),
  );
}

class _ProgressMessage extends StatelessWidget {
  const _ProgressMessage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 34, color: scheme.onSurfaceVariant),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressContent extends StatelessWidget {
  const _ProgressContent({required this.state});

  final ProgressState state;

  @override
  Widget build(BuildContext context) {
    final overview = state.overview!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeadlineStats(overview: overview, medianRest: state.medianRest),
        const SizedBox(height: 28),
        const _SectionTitle('Weekly volume'),
        const SizedBox(height: 12),
        _WeeklyVolumeChart(points: state.weeklyVolume),
        if (state.exercises.isNotEmpty) ...[
          const SizedBox(height: 28),
          const _SectionTitle('Lifts'),
          const SizedBox(height: 12),
          ...state.exercises.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ExerciseInsightTile(entry: entry),
            ),
          ),
        ],
        if (state.muscleGroups.isNotEmpty) ...[
          const SizedBox(height: 18),
          const _SectionTitle('Volume by muscle group'),
          const SizedBox(height: 12),
          ...state.muscleGroups.map(
            (share) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MuscleShareRow(share: share),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 11,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.2,
    ),
  );
}

class _HeadlineStats extends StatelessWidget {
  const _HeadlineStats({required this.overview, required this.medianRest});

  final TrainingOverview overview;
  final Duration? medianRest;

  @override
  Widget build(BuildContext context) {
    final change = overview.volumeWeekChange;
    final tiles = <Widget>[
      _StatTile(
        value: '${overview.totalSessions}',
        label: 'sessions logged',
        emphasised: true,
      ),
      _StatTile(
        value: _formatKg(overview.totalVolumeKg),
        label: 'total volume (kg)',
      ),
      _StatTile(
        value: '${overview.sessionsThisWeek}',
        label: 'sessions this week',
      ),
      _StatTile(
        value: _formatKg(overview.volumeThisWeekKg),
        label: 'volume this week (kg)',
        footnote: change == null
            ? null
            : '${change >= 0 ? '+' : ''}${(change * 100).round()}% vs last week',
        footnotePositive: change != null && change >= 0,
      ),
      _StatTile(
        value: '${overview.currentStreakWeeks}',
        label: overview.currentStreakWeeks == 1 ? 'week streak' : 'week streak',
      ),
      _StatTile(
        value: '${overview.averageSessionDuration.inMinutes}',
        label: 'avg session (min)',
      ),
      if (medianRest != null)
        _StatTile(value: '${medianRest!.inSeconds}', label: 'median rest (s)'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final columns = constraints.maxWidth < 340 ? 2 : 3;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: 14,
          children: tiles
              .map((tile) => SizedBox(width: width, child: tile))
              .toList(growable: false),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    this.footnote,
    this.footnotePositive = true,
    this.emphasised = false,
  });

  final String value;
  final String label;
  final String? footnote;
  final bool footnotePositive;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: emphasised ? _accent : scheme.onSurface,
            fontSize: emphasised ? 26 : 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -.9,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          maxLines: 2,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (footnote != null) ...[
          const SizedBox(height: 3),
          Text(
            footnote!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: footnotePositive ? _accent : scheme.error,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }
}

class _WeeklyVolumeChart extends StatelessWidget {
  const _WeeklyVolumeChart({required this.points});

  final List<TrainingPoint> points;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (points.isEmpty) {
      return Text(
        'Not enough history to chart yet.',
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
      );
    }
    final peak = points.fold<double>(
      0,
      (best, point) => point.volumeKg > best ? point.volumeKg : best,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 132,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: points
                .map((point) {
                  final fraction = peak > 0 ? point.volumeKg / peak : 0.0;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // A zero-volume week keeps a hairline so the gap in
                          // training is visible instead of blank.
                          Container(
                            height: (fraction * 112).clamp(2.0, 112.0),
                            decoration: BoxDecoration(
                              color: point.volumeKg > 0
                                  ? _accent.withValues(
                                      alpha: .35 + fraction * .65,
                                    )
                                  : scheme.onSurface.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                })
                .toList(growable: false),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${points.length} weeks ago',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'peak ${_formatKg(peak)} kg',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'this week',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ExerciseInsightTile extends StatelessWidget {
  const _ExerciseInsightTile({required this.entry});

  final ExerciseInsightWithStrength entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final insight = entry.insight;
    final strength = entry.relativeStrength;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      insight.exerciseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${insight.sessionCount} sessions  ·  best '
                      '${_formatKg(insight.bestLoadKg)} kg  ·  '
                      '${_formatKg(insight.totalVolumeKg)} kg total',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _TrendBadge(trend: insight.trend, change: insight.trendChange),
            ],
          ),
          // Only rendered when a weigh-in covers one of this lift's sessions;
          // an absent ratio is left absent rather than filled with a guess.
          if (strength != null) ...[
            const SizedBox(height: 10),
            _RelativeStrengthRow(strength: strength),
          ],
        ],
      ),
    );
  }
}

/// Bodyweight ratio for a lift, shown against the weight carried that day.
class _RelativeStrengthRow extends StatelessWidget {
  const _RelativeStrengthRow({required this.strength});

  final RelativeStrength strength;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.accessibility_new_rounded, size: 14, color: _accent),
          const SizedBox(width: 7),
          Text(
            '${strength.ratio.toStringAsFixed(2)}x',
            style: const TextStyle(
              color: _accent,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'bodyweight  ·  ${_formatKg(strength.estimatedOneRepMaxKg)} kg '
              'est. 1RM at ${_formatKg(strength.bodyWeightKg)} kg',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  const _TrendBadge({required this.trend, required this.change});

  final ProgressTrend trend;
  final double change;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, color, icon) = switch (trend) {
      ProgressTrend.improving => (
        '+${(change * 100).round()}%',
        _accent,
        Icons.trending_up_rounded,
      ),
      ProgressTrend.declining => (
        '${(change * 100).round()}%',
        scheme.error,
        Icons.trending_down_rounded,
      ),
      ProgressTrend.plateaued => (
        'flat',
        scheme.onSurfaceVariant,
        Icons.trending_flat_rounded,
      ),
      // Saying "not enough data" beats inventing a direction from three points.
      ProgressTrend.insufficientData => (
        'new',
        scheme.onSurfaceVariant,
        Icons.schedule_rounded,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MuscleShareRow extends StatelessWidget {
  const _MuscleShareRow({required this.share});

  final MuscleGroupShare share;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                share.target,
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
              '${(share.share * 100).round()}%  ·  ${share.setCount} sets',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: share.share.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: scheme.onSurface.withValues(alpha: .09),
            valueColor: const AlwaysStoppedAnimation<Color>(_accent),
          ),
        ),
      ],
    );
  }
}

String _formatKg(double value) {
  final rounded = value.round();
  final text = '$rounded';
  final buffer = StringBuffer();
  for (var index = 0; index < text.length; index++) {
    if (index > 0 && (text.length - index) % 3 == 0) buffer.write(',');
    buffer.write(text[index]);
  }
  return buffer.toString();
}
