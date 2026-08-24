import 'package:flutter/material.dart';

import '../../domain/body_weight.dart';

const _accent = Color(0xffd7ff4f);

/// Body-weight history plotted against a real scale.
///
/// Not a sparkline: on You the weight is the subject, so the chart carries
/// labelled bounds and dated points instead of an unreadable decorative line.
class BodyWeightChart extends StatelessWidget {
  const BodyWeightChart({super.key, required this.entries, this.height = 168});

  /// Newest first, as the repository returns them.
  final List<BodyWeightEntry> entries;

  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ordered = entries.reversed.toList(growable: false);
    if (ordered.length < 2) return const SizedBox.shrink();

    final values = ordered
        .map((entry) => entry.weightKg)
        .toList(growable: false);
    final rawMin = values.reduce((a, b) => a < b ? a : b);
    final rawMax = values.reduce((a, b) => a > b ? a : b);
    // Padding the range keeps a near-flat series from rendering as a line
    // pinned to one edge, which reads as a bug rather than as stability.
    final span = (rawMax - rawMin).abs() < .4 ? 1.0 : (rawMax - rawMin) * .18;
    final min = rawMin - span;
    final max = rawMax + span;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The scale is stated, not implied: a curve without bounds cannot
              // be read as a magnitude.
              SizedBox(
                width: 34,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _AxisLabel(value: max, scheme: scheme),
                    _AxisLabel(value: (max + min) / 2, scheme: scheme),
                    _AxisLabel(value: min, scheme: scheme),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _BodyWeightChartPainter(
                      values: values,
                      min: min,
                      max: max,
                      gridColor: scheme.onSurface.withValues(alpha: .08),
                      lineColor: _accent,
                      fillColor: _accent.withValues(alpha: .14),
                      dotFill: scheme.surface,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 42),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _DateLabel(date: ordered.first.measuredOn, scheme: scheme),
              Text(
                '${ordered.length} weigh-ins',
                style: TextStyle(
                  color: scheme.onSurfaceVariant.withValues(alpha: .8),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              _DateLabel(date: ordered.last.measuredOn, scheme: scheme),
            ],
          ),
        ),
      ],
    );
  }
}

class _AxisLabel extends StatelessWidget {
  const _AxisLabel({required this.value, required this.scheme});

  final double value;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) => Text(
    value.toStringAsFixed(0),
    style: TextStyle(
      color: scheme.onSurfaceVariant.withValues(alpha: .75),
      fontSize: 10,
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}

class _DateLabel extends StatelessWidget {
  const _DateLabel({required this.date, required this.scheme});

  final DateTime date;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) => Text(
    formatShortDate(date),
    style: TextStyle(
      color: scheme.onSurfaceVariant.withValues(alpha: .8),
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _BodyWeightChartPainter extends CustomPainter {
  const _BodyWeightChartPainter({
    required this.values,
    required this.min,
    required this.max,
    required this.gridColor,
    required this.lineColor,
    required this.fillColor,
    required this.dotFill,
  });

  final List<double> values;
  final double min;
  final double max;
  final Color gridColor;
  final Color lineColor;
  final Color fillColor;
  final Color dotFill;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.isEmpty) return;
    final range = max - min;
    if (range <= 0) return;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index <= 2; index++) {
      final y = size.height * (index / 2);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    Offset pointAt(int index) => Offset(
      size.width * (index / (values.length - 1)),
      size.height * (1 - (values[index] - min) / range),
    );

    final line = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var index = 1; index < values.length; index++) {
      final point = pointAt(index);
      line.lineTo(point.dx, point.dy);
    }

    // The fill gives the curve a body so the trend reads at a glance; the
    // stroke keeps the exact values legible.
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = fillColor);

    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = lineColor,
    );

    // Only the endpoints are marked: dotting every reading turns a trend into
    // noise once the history grows.
    for (final index in [0, values.length - 1]) {
      final point = pointAt(index);
      canvas.drawCircle(point, 4.5, Paint()..color = dotFill);
      canvas.drawCircle(
        point,
        4.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = lineColor,
      );
    }
  }

  @override
  bool shouldRepaint(_BodyWeightChartPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.min != min ||
      oldDelegate.max != max ||
      oldDelegate.lineColor != lineColor;
}

const _months = [
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

String formatShortDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]}';

/// Day-precision relative label for the weigh-in list.
String formatRelativeDay(DateTime date) {
  final today = DateTime.now();
  final midnight = DateTime(today.year, today.month, today.day);
  final days = midnight.difference(date).inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days < 7) return '$days days ago';
  return formatShortDate(date);
}
