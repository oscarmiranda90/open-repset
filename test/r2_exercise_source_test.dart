import 'package:flutter_test/flutter_test.dart';
import 'package:repset/data/r2_exercise_source.dart';

void main() {
  test('does not use a hosted catalogue by default', () {
    expect(R2ExerciseSource.isConfigured, isFalse);
  });

  test('parses a static R2 exercise catalogue', () {
    final exercises = R2ExerciseSource.parseManifest('''
      [{
        "id": "0001",
        "creatorName": "3/4 sit-up",
        "bodyPart": "waist",
        "target": "abs",
        "equipment": "body weight",
        "secondaryMuscles": ["hip flexors"],
        "instructions": ["Lie down."],
        "mediaUrl": "https://media.example.com/exercises/0001.gif"
      }]
    ''');

    expect(exercises, hasLength(1));
    expect(exercises.single.name, '3/4 sit-up');
    expect(exercises.single.mediaUrl, contains('/exercises/0001.gif'));
  });
}
