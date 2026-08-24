import 'dart:ui';

/// Converts an SVG `d` attribute into a Flutter [Path].
///
/// Supports M/L/H/V/C/S/Q/T/Z in both absolute and relative form, which covers
/// every command in the body illustration. Arc (A) is deliberately unsupported:
/// the asset contains none, and a silently wrong arc would distort a muscle
/// outline in a way that is hard to notice.
Path parseSvgPath(String pathData) {
  final path = Path();
  var current = Offset.zero;
  var control = Offset.zero;
  var subpathStart = Offset.zero;
  String? lastInstruction;

  for (final command in _tokenize(pathData)) {
    final isRelative = command.instruction == command.instruction.toLowerCase();
    final instruction = command.instruction.toUpperCase();
    final values = command.values;

    Offset resolve(double dx, double dy) =>
        isRelative ? current + Offset(dx, dy) : Offset(dx, dy);

    switch (instruction) {
      case 'M':
        for (var i = 0; i + 1 < values.length; i += 2) {
          current = resolve(values[i], values[i + 1]);
          if (i == 0) {
            path.moveTo(current.dx, current.dy);
            subpathStart = current;
          } else {
            // Extra coordinate pairs after a moveto are implicit linetos.
            path.lineTo(current.dx, current.dy);
          }
        }
      case 'L':
        for (var i = 0; i + 1 < values.length; i += 2) {
          current = resolve(values[i], values[i + 1]);
          path.lineTo(current.dx, current.dy);
        }
      case 'H':
        for (final value in values) {
          current = Offset(isRelative ? current.dx + value : value, current.dy);
          path.lineTo(current.dx, current.dy);
        }
      case 'V':
        for (final value in values) {
          current = Offset(current.dx, isRelative ? current.dy + value : value);
          path.lineTo(current.dx, current.dy);
        }
      case 'C':
        for (var i = 0; i + 5 < values.length; i += 6) {
          final c1 = resolve(values[i], values[i + 1]);
          final c2 = resolve(values[i + 2], values[i + 3]);
          final end = resolve(values[i + 4], values[i + 5]);
          path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
          control = c2;
          current = end;
        }
      case 'S':
        for (var i = 0; i + 3 < values.length; i += 4) {
          // The first control point mirrors the previous one, but only when the
          // previous command was itself a cubic.
          final c1 = (lastInstruction == 'C' || lastInstruction == 'S')
              ? current * 2 - control
              : current;
          final c2 = resolve(values[i], values[i + 1]);
          final end = resolve(values[i + 2], values[i + 3]);
          path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
          control = c2;
          current = end;
        }
      case 'Q':
        for (var i = 0; i + 3 < values.length; i += 4) {
          final c1 = resolve(values[i], values[i + 1]);
          final end = resolve(values[i + 2], values[i + 3]);
          path.quadraticBezierTo(c1.dx, c1.dy, end.dx, end.dy);
          control = c1;
          current = end;
        }
      case 'T':
        for (var i = 0; i + 1 < values.length; i += 2) {
          final c1 = (lastInstruction == 'Q' || lastInstruction == 'T')
              ? current * 2 - control
              : current;
          final end = resolve(values[i], values[i + 1]);
          path.quadraticBezierTo(c1.dx, c1.dy, end.dx, end.dy);
          control = c1;
          current = end;
        }
      case 'Z':
        path.close();
        // A closed subpath leaves the pen at its start, which the next relative
        // command measures from.
        current = subpathStart;
    }
    lastInstruction = instruction;
  }
  return path;
}

final _commandPattern = RegExp(
  r'([MmLlHhVvCcSsQqTtAaZz])([^MmLlHhVvCcSsQqTtAaZz]*)',
);
final _valuePattern = RegExp(r'[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?');

List<_SvgCommand> _tokenize(String pathData) => _commandPattern
    .allMatches(pathData)
    .map(
      (match) => _SvgCommand(
        match.group(1)!,
        _valuePattern
            .allMatches(match.group(2)!)
            .map((value) => double.parse(value.group(0)!))
            .toList(growable: false),
      ),
    )
    .toList(growable: false);

class _SvgCommand {
  const _SvgCommand(this.instruction, this.values);

  final String instruction;
  final List<double> values;
}
