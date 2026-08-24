import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repset/features/workout/rest_countdown_rail.dart';

void main() {
  testWidgets('counts down and fires its alarm callback once', (tester) async {
    var alarmCount = 0;
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
    );

    final startedAt = tester.binding.clock.now();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RestCountdownRail(
            durationSeconds: 1,
            startedAt: startedAt,
            onDurationTap: () {},
            onFinished: () async => alarmCount++,
            now: tester.binding.clock.now,
          ),
        ),
      ),
    );

    expect(find.text('0:01'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('0:00'), findsOneWidget);
    expect(alarmCount, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(alarmCount, 1);
  });
}
