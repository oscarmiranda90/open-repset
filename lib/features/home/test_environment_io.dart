import 'dart:io';

/// `flutter test` sets FLUTTER_TEST in the environment of every test process.
bool get isWidgetTestEnvironment =>
    Platform.environment.containsKey('FLUTTER_TEST');
