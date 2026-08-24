import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';

// Mirrors the wave maths in dot_pattern.dart. If the loop is seamless, the
// displacement at phase 1.0 must equal the displacement at phase 0.0.
double primary(double x, double y, double phase) {
  final t = phase * 2 * math.pi;
  return math.sin((x + y) / 190.0 * 2 * math.pi + t * 1.0);
}

double secondary(double x, double y, double phase) {
  final t = phase * 2 * math.pi;
  return math.sin((x - y * .6) / 310.0 * 2 * math.pi + 2.4 - t * 2.0);
}

void main() {
  test('wave loops seamlessly from phase 1 back to phase 0', () {
    for (var x = 0.0; x < 400; x += 37) {
      for (var y = 0.0; y < 800; y += 53) {
        expect(
          primary(x, y, 1.0),
          closeTo(primary(x, y, 0.0), 1e-9),
          reason: 'primary seam at ($x,$y)',
        );
        expect(
          secondary(x, y, 1.0),
          closeTo(secondary(x, y, 0.0), 1e-9),
          reason: 'secondary seam at ($x,$y)',
        );
      }
    }
  });
}
