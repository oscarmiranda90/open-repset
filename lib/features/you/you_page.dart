import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/account/account_service.dart';
import '../../core/motion/repset_motion.dart';
import '../../domain/body_weight.dart';
import '../progress/body_weight_bloc.dart';
import '../progress/progress_bloc.dart';
import 'body_weight_chart.dart';
import 'account_card.dart';
import 'muscle_coverage_section.dart';

const _accent = Color(0xffd7ff4f);

/// The athlete's own record: body weight now, and muscle coverage later.
///
/// Progress answers "what did I do". You answers "what is my body doing", so
/// body weight is owned here rather than shared between both surfaces.
class YouPage extends StatelessWidget {
  const YouPage({super.key, this.accountService});

  final AccountService? accountService;

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<BodyWeightBloc, BodyWeightState>(
        listenWhen: (previous, current) =>
            previous.message != current.message ||
            previous.entries.length != current.entries.length ||
            previous.latest?.weightKg != current.latest?.weightKg,
        listener: (context, state) {
          if (state.message != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message!)));
            return;
          }
          // A weigh-in moves every bodyweight ratio, so the training summary
          // has to recompute instead of showing stale numbers.
          context.read<ProgressBloc>().add(const ProgressLoaded());
        },
        builder: (context, state) => SingleChildScrollView(
          key: const Key('you-page'),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'YOU',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.circle, size: 10, color: _accent),
                  ],
                ),
                const SizedBox(height: 26),
                if (accountService != null) ...[
                  RepSetEntrance(
                    delay: const Duration(milliseconds: 25),
                    child: AccountCard(service: accountService!),
                  ),
                  const SizedBox(height: 30),
                ],
                RepSetEntrance(child: _WeightHeadline(state: state)),
                if (state.entries.length > 1) ...[
                  const SizedBox(height: 26),
                  RepSetEntrance(
                    delay: const Duration(milliseconds: 45),
                    child: BodyWeightChart(entries: state.entries),
                  ),
                ],
                const SizedBox(height: 30),
                if (state.hasHistory)
                  RepSetEntrance(
                    delay: const Duration(milliseconds: 90),
                    child: _WeighInHistory(entries: state.entries),
                  ),
                const SizedBox(height: 34),
                RepSetEntrance(
                  delay: const Duration(milliseconds: 135),
                  child: const MuscleCoverageSection(),
                ),
              ],
            ),
          ),
        ),
      );
}

/// The weight itself opens the page — it is the subject here, not a stat tile
/// competing with five others for the same visual weight.
class _WeightHeadline extends StatelessWidget {
  const _WeightHeadline({required this.state});

  final BodyWeightState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final latest = state.latest;
    final trend = state.trend;

    if (latest == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add your\nweight.',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              height: .95,
              letterSpacing: -1.8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Every lift you log gets measured against it, so your strength '
            'reads as a ratio and not just a number on the bar.',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          const _LogWeightButton(expanded: true),
        ],
      );
    }

    final canCompare = trend?.canCompare ?? false;
    final change = trend?.changeKg ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatWeight(latest.weightKg),
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w900,
                height: .9,
                letterSpacing: -3,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Text(
                'kg',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Spacer(),
            const _LogWeightButton(),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          canCompare
              // Direction only. Whether up or down is good depends on the
              // athlete's goal, which the app does not know.
              ? '${change >= 0 ? 'Up' : 'Down'} '
                    '${formatWeight(change.abs())} kg over '
                    '${trend!.spanDays} days · last weighed '
                    '${formatRelativeDay(latest.measuredOn).toLowerCase()}'
              : 'First weigh-in recorded '
                    '${formatRelativeDay(latest.measuredOn).toLowerCase()}. '
                    'Log another to see the trend.',
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _LogWeightButton extends StatelessWidget {
  const _LogWeightButton({this.expanded = false});

  final bool expanded;

  @override
  Widget build(BuildContext context) => RepSetPress(
    child: FilledButton.icon(
      key: const Key('log-body-weight-button'),
      onPressed: () => openWeighInSheet(context),
      style: FilledButton.styleFrom(
        backgroundColor: _accent,
        foregroundColor: const Color(0xff171914),
        minimumSize: Size(expanded ? double.infinity : 0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
      icon: const Icon(Icons.add_rounded, size: 19),
      label: const Text(
        'Weigh in',
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
      ),
    ),
  );
}

/// Editable log of past weigh-ins.
class _WeighInHistory extends StatelessWidget {
  const _WeighInHistory({required this.entries});

  final List<BodyWeightEntry> entries;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HISTORY',
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        ...List.generate(entries.length, (index) {
          final entry = entries[index];
          final previous = index + 1 < entries.length
              ? entries[index + 1]
              : null;
          return _WeighInRow(
            entry: entry,
            previous: previous,
            isLast: index == entries.length - 1,
          );
        }),
      ],
    );
  }
}

class _WeighInRow extends StatelessWidget {
  const _WeighInRow({
    required this.entry,
    required this.previous,
    required this.isLast,
  });

  final BodyWeightEntry entry;
  final BodyWeightEntry? previous;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final delta = previous == null ? null : entry.weightKg - previous!.weightKg;
    return Semantics(
      label:
          '${formatWeight(entry.weightKg)} kilograms on '
          '${formatShortDate(entry.measuredOn)}',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => openWeighInSheet(context, existing: entry),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            // Keeps the row above the 44pt touch target the contract requires.
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(
                      bottom: BorderSide(
                        color: scheme.onSurface.withValues(alpha: .07),
                      ),
                    ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 92,
                  child: Text(
                    formatRelativeDay(entry.measuredOn),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${formatWeight(entry.weightKg)} kg',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                if (delta != null && delta.abs() >= .05)
                  Text(
                    '${delta > 0 ? '+' : '−'}${formatWeight(delta.abs())}',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant.withValues(alpha: .6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the weigh-in editor. [existing] switches it to editing that day.
Future<void> openWeighInSheet(
  BuildContext context, {
  BodyWeightEntry? existing,
}) async {
  final bloc = context.read<BodyWeightBloc>();
  final result = await showModalBottomSheet<_WeighInResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _WeighInSheet(existing: existing),
  );
  if (result == null) return;

  if (result.delete) {
    bloc.add(BodyWeightRemoved(result.measuredOn));
    return;
  }
  bloc.add(
    BodyWeightRecorded(
      weightKg: result.weightKg!,
      measuredOn: result.measuredOn,
    ),
  );
}

class _WeighInResult {
  const _WeighInResult({
    required this.measuredOn,
    this.weightKg,
    this.delete = false,
  });

  final DateTime measuredOn;
  final double? weightKg;
  final bool delete;
}

class _WeighInSheet extends StatefulWidget {
  const _WeighInSheet({this.existing});

  final BodyWeightEntry? existing;

  @override
  State<_WeighInSheet> createState() => _WeighInSheetState();
}

class _WeighInSheetState extends State<_WeighInSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.existing == null
        ? ''
        : formatWeight(widget.existing!.weightKg),
  );
  late DateTime _measuredOn = widget.existing?.measuredOn ?? DateTime.now();
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = double.tryParse(
      _controller.text.trim().replaceAll(',', '.'),
    );
    if (parsed == null || parsed <= 0 || parsed >= 500) {
      // Names the problem and the range that would fix it.
      setState(() => _error = 'Enter a weight between 1 and 499 kg.');
      return;
    }
    Navigator.of(
      context,
    ).pop(_WeighInResult(measuredOn: _measuredOn, weightKg: parsed));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _measuredOn,
      // A weigh-in cannot be in the future, and two years back covers
      // back-filling without turning the picker into a scroll.
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked != null) setState(() => _measuredOn = picked);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        20,
        22,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isEditing ? 'Edit weigh-in' : 'New weigh-in',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('body-weight-field'),
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            onSubmitted: (_) => _submit(),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            decoration: InputDecoration(
              suffixText: 'kg',
              errorText: _error,
              border: const OutlineInputBorder(),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: _accent, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          RepSetPress(
            scale: .98,
            child: OutlinedButton.icon(
              key: const Key('weigh-in-date-button'),
              onPressed: _pickDate,
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.onSurface,
                minimumSize: const Size(double.infinity, 46),
                alignment: Alignment.centerLeft,
                side: BorderSide(
                  color: scheme.onSurface.withValues(alpha: .18),
                ),
              ),
              icon: const Icon(Icons.calendar_today_rounded, size: 17),
              label: Text(
                formatRelativeDay(_measuredOn) == 'Today'
                    ? 'Today'
                    : formatShortDate(_measuredOn),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 18),
          RepSetPress(
            child: FilledButton(
              key: const Key('save-body-weight-button'),
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: const Color(0xff171914),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: Text(
                _isEditing ? 'Update' : 'Save',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          if (_isEditing) ...[
            const SizedBox(height: 6),
            TextButton(
              key: const Key('delete-body-weight-button'),
              onPressed: () => Navigator.of(context).pop(
                _WeighInResult(
                  measuredOn: widget.existing!.measuredOn,
                  delete: true,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: scheme.error,
                minimumSize: const Size(double.infinity, 44),
              ),
              child: const Text(
                'Delete this weigh-in',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String formatWeight(double value) {
  final rounded = (value * 10).roundToDouble() / 10;
  return rounded % 1 == 0
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
}
