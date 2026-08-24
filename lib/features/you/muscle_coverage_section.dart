import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/motion/repset_motion.dart';
import 'body_map.dart';
import 'muscle_coverage_bloc.dart';

const _accent = Color(0xffd7ff4f);

/// Body map of what has been trained, and what has not.
class MuscleCoverageSection extends StatelessWidget {
  const MuscleCoverageSection({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<MuscleCoverageBloc, MuscleCoverageState>(
        builder: (context, state) {
          final scheme = Theme.of(context).colorScheme;
          return Column(
            key: const Key('muscle-coverage-section'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'MUSCLES TRAINED',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  _WindowPicker(days: state.days),
                ],
              ),
              const SizedBox(height: 14),
              if (state.hasError)
                Text(
                  'Muscle coverage could not be read. Your sessions are safe.',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                )
              else if (state.isEmpty)
                Text(
                  'Finish a workout and the muscles you trained light up here, '
                  'so the gaps are as visible as the work.',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                )
              else if (state.coverage != null) ...[
                BodyMap(
                  coverage: state.coverage!,
                  selected: state.selected,
                  onSelected: (group) => context.read<MuscleCoverageBloc>().add(
                    MuscleSelected(group),
                  ),
                ),
                const SizedBox(height: 14),
                const BodyMapLegend(),
                const SizedBox(height: 18),
                _CoverageReadout(state: state),
              ],
            ],
          );
        },
      );
}

class _WindowPicker extends StatelessWidget {
  const _WindowPicker({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [7, 30, 90]
          .map((option) {
            final isActive = option == days;
            return Padding(
              padding: const EdgeInsets.only(left: 6),
              child: RepSetPress(
                scale: .94,
                child: Material(
                  color: isActive
                      ? _accent.withValues(alpha: .16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    key: Key('coverage-window-$option'),
                    onTap: () => context.read<MuscleCoverageBloc>().add(
                      MuscleCoverageRequested(days: option),
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      child: Text(
                        '${option}d',
                        style: TextStyle(
                          color: isActive ? _accent : scheme.onSurfaceVariant,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

/// Either the selected muscle's numbers, or the untrained groups.
class _CoverageReadout extends StatelessWidget {
  const _CoverageReadout({required this.state});

  final MuscleCoverageState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final coverage = state.coverage!;
    final selected = state.selected;

    if (selected != null) {
      final entry = coverage.volumes[selected];
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selected.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry == null || entry.volumeKg <= 0
                        // Naming the gap is more useful than showing a zero.
                        ? 'No volume in the last ${state.days} days'
                        : '${_formatKg(entry.volumeKg)} kg'
                              '${entry.setCount > 0 ? '  ·  ${entry.setCount} sets' : ''}'
                              '  ·  ${(coverage.intensityOf(selected) * 100).round()}% of your top muscle',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const Key('clear-muscle-selection'),
              tooltip: 'Clear selection',
              onPressed: () => context.read<MuscleCoverageBloc>().add(
                const MuscleSelected(null),
              ),
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
      );
    }

    final untrained = coverage.untrainedGroups;
    if (untrained.isEmpty) {
      return Text(
        'Every muscle group has volume in the last ${state.days} days.',
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 12.5,
          height: 1.45,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          // The gap is the actionable half of the map, so it is stated in words
          // rather than left for the reader to spot among the dark shapes.
          untrained.length == 1
              ? 'Untrained in the last ${state.days} days'
              : '${untrained.length} groups untrained in the last '
                    '${state.days} days',
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: untrained
              .map(
                (group) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: scheme.onSurface.withValues(alpha: .16),
                    ),
                  ),
                  child: Text(
                    group.label,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
              .toList(growable: false),
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
