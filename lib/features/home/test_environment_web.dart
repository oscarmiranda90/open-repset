/// The web build has no process environment to inspect, and never runs under
/// `flutter test` in a way that needs this gate.
bool get isWidgetTestEnvironment => false;
