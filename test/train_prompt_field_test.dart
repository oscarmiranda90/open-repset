import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repset/features/home/train_prompt_field.dart';

Widget _harness({String? disabledLabel, ValueChanged<String>? onSubmitted}) =>
    MaterialApp(
      home: Scaffold(
        body: TrainPromptField(
          disabledLabel: disabledLabel,
          onSubmitted: onSubmitted ?? (_) {},
        ),
      ),
    );

void main() {
  testWidgets('a disabled prompt says why and takes no input', (tester) async {
    var submitted = false;
    await tester.pumpWidget(
      _harness(
        disabledLabel: 'Finish your session to plan another',
        onSubmitted: (_) => submitted = true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Finish your session to plan another'), findsOneWidget);

    final field = tester.widget<TextField>(
      find.byKey(const Key('train-prompt-field')),
    );
    expect(field.enabled, isFalse);

    await tester.tap(find.byKey(const Key('train-prompt-send')));
    await tester.pump();
    expect(submitted, isFalse);
  });

  testWidgets('an enabled prompt accepts a request', (tester) async {
    String? received;
    await tester.pumpWidget(_harness(onSubmitted: (value) => received = value));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(
      find.byKey(const Key('train-prompt-field')),
      'legs, mostly quads',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('train-prompt-send')));
    await tester.pump();

    expect(received, 'legs, mostly quads');
  });
}
