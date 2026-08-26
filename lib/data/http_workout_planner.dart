import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/exercise.dart';
import '../domain/session_plan.dart';
import '../domain/workout_planner.dart';

/// Talks to the RepSet planning API.
///
/// The AI provider key, the prompts, the cost controls, and the abuse
/// protections all live behind that API — never in this client. There is no
/// production default origin here, matching the catalogue boundary: a community
/// build has no planning backend and hides the prompt surface instead of
/// failing when it is used.
class HttpWorkoutPlanner implements WorkoutPlanner {
  HttpWorkoutPlanner({http.Client? client, this.tokenProvider})
    : _client = client ?? http.Client();

  static const _origin = String.fromEnvironment(
    'REPSET_PLANNER_ORIGIN',
    defaultValue: '',
  );

  /// A planning call waits on a language model, and the service retries once
  /// when a completion comes back empty. Thirty seconds cut those retries off
  /// as connection failures, which is the one thing they are not.
  static const _timeout = Duration(seconds: 75);

  final http.Client _client;

  /// Identifies the caller to the service, which decides on its own whether
  /// that caller may use AI. The app's own entitlement check only drives what
  /// it shows.
  final PlannerTokenProvider? tokenProvider;

  @override
  bool get isConfigured => _origin.isNotEmpty;

  @override
  Future<SessionPlanQuery> interpret({
    required String request,
    required CatalogueVocabulary vocabulary,
  }) async {
    final body = await _post('/interpret', {
      'request': request,
      'vocabulary': {
        'bodyParts': vocabulary.bodyParts,
        'targets': vocabulary.targets,
        'equipment': vocabulary.equipment,
      },
    });
    return _queryFromJson(body);
  }

  @override
  Future<SessionPlan> select({
    required String request,
    required SessionPlanQuery query,
    required List<Exercise> candidates,
  }) async {
    final body = await _post('/select', {
      'request': request,
      'query': {
        'targets': query.targets,
        'emphasis': query.emphasis,
        'exerciseCount': query.exerciseCount,
      },
      // Only what the planner needs to choose. Instructions, media, and
      // everything else stay on the device.
      'candidates': candidates
          .map((exercise) => {'id': exercise.id, 'name': exercise.name})
          .toList(growable: false),
    });
    return _planFromJson(body, candidates: candidates);
  }

  Future<Map<String, Object?>> _post(
    String path,
    Map<String, Object?> payload,
  ) async {
    if (!isConfigured) {
      throw const WorkoutPlannerException(
        'No planning service has been configured.',
      );
    }
    final token = await tokenProvider?.call();
    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$_origin$path'),
            headers: {
              'content-type': 'application/json',
              if (token != null) 'authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(_timeout);
    } catch (_) {
      throw const WorkoutPlannerException(
        'The planner took too long to answer. Try again.',
      );
    }
    if (response.statusCode == 429) {
      // Covers both the per-minute limiter and the daily allowance; the
      // service words each one, and they mean different things to wait for.
      throw WorkoutPlannerException(
        _errorFrom(response.body) ??
            'Too many requests right now. Try again in a moment.',
      );
    }
    if (response.statusCode == 401) {
      throw WorkoutPlannerException(
        _errorFrom(response.body) ?? 'Sign in to use AI session planning.',
      );
    }
    if (response.statusCode == 402 || response.statusCode == 403) {
      // The service explains its own refusals; a fixed sentence here would
      // hide whatever it actually said.
      throw WorkoutPlannerException(
        _errorFrom(response.body) ??
            'RepSet Max is required for AI session planning.',
      );
    }
    if (response.statusCode == 422) {
      // The service refused the request itself — nothing to train, an injury,
      // a plan it could not build. Its wording is the whole answer.
      throw WorkoutPlannerException(
        _errorFrom(response.body) ??
            'That did not name anything to train. Try naming a muscle or a '
                'goal.',
      );
    }
    if (response.statusCode != 200) {
      // Only the refusals above carry text meant for a person. Anything else is
      // an internal fault, and its wording would explain nothing to whoever is
      // holding the phone.
      throw const WorkoutPlannerException(
        'The planner could not answer that right now.',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const WorkoutPlannerException('The planner sent an unusable reply.');
    }
    return Map<String, Object?>.from(decoded);
  }

  /// Reads the service's own error message, when it sent one.
  static String? _errorFrom(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final message = decoded['error'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } catch (_) {
      // A non-JSON body carries nothing worth showing.
    }
    return null;
  }

  static SessionPlanQuery _queryFromJson(Map<String, Object?> body) {
    final targets = _stringList(body['targets']);
    final bodyParts = _stringList(body['bodyParts']);
    if (targets.isEmpty && bodyParts.isEmpty) {
      throw const WorkoutPlannerException(
        'That did not name anything to train. Try naming a muscle or a goal.',
      );
    }
    final count = body['exerciseCount'];
    return SessionPlanQuery(
      targets: targets,
      bodyParts: bodyParts,
      equipment: _stringList(body['equipment']),
      emphasis: (body['emphasis'] as String?)?.trim().isEmpty ?? true
          ? null
          : (body['emphasis']! as String).trim(),
      exerciseCount: count is num ? count.toInt().clamp(1, 12) : 5,
    );
  }

  /// Builds the plan, keeping only entries that name a candidate that was
  /// actually offered. The shortlist is the app's, so an unknown id is a
  /// planner error rather than something to trust.
  static SessionPlan _planFromJson(
    Map<String, Object?> body, {
    required List<Exercise> candidates,
  }) {
    final known = {for (final exercise in candidates) exercise.id};
    final rawEntries = body['exercises'];
    final entries = <PlannedExercise>[];
    if (rawEntries is List) {
      for (final raw in rawEntries) {
        if (raw is! Map) continue;
        final entry = Map<String, Object?>.from(raw);
        final id = (entry['id'] as String?)?.trim() ?? '';
        if (!known.contains(id)) continue;
        if (entries.any((item) => item.exerciseId == id)) continue;
        final sets = entry['sets'];
        final reps = entry['reps'];
        entries.add(
          PlannedExercise(
            exerciseId: id,
            setCount: sets is num ? sets.toInt().clamp(1, 10) : 3,
            repetitions: reps is num ? reps.toInt().clamp(1, 50) : 10,
            notes: (entry['notes'] as String?)?.trim() ?? '',
          ),
        );
      }
    }
    if (entries.isEmpty) {
      throw const WorkoutPlannerException(
        'No matching exercises came back. Try describing the session again.',
      );
    }
    final title = (body['title'] as String?)?.trim() ?? '';
    return SessionPlan(
      title: title.isEmpty ? 'Planned session' : title,
      entries: entries,
    );
  }

  static List<String> _stringList(Object? value) => value is List
      ? value
            .whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false)
      : const [];
}
