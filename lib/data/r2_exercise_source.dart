import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/exercise.dart';

/// Reads a configured, versioned exercise catalogue stored in object storage.
///
/// Catalogue records and preview media share an origin, so the app needs no
/// The local SQLite layer still supplies the offline-first cache. There is no
/// production catalogue default: community builds stay on the legal demo data
/// until their maintainer configures an authorized source.
class R2ExerciseSource {
  R2ExerciseSource({http.Client? client}) : _client = client ?? http.Client();

  static const _catalogueOrigin = String.fromEnvironment(
    'REPSET_CATALOGUE_ORIGIN',
    defaultValue: '',
  );

  static bool get isConfigured => _catalogueOrigin.isNotEmpty;

  final http.Client _client;

  Future<List<Exercise>> fetch(String languageCode) async {
    if (!isConfigured) {
      throw StateError('No exercise catalogue origin has been configured.');
    }
    final locale = languageCode.toLowerCase() == 'es' ? 'es' : 'en';
    final response = await _client.get(
      Uri.parse('$_catalogueOrigin/exercises.$locale.json'),
    );
    if (response.statusCode != 200) {
      throw StateError('Could not load exercise catalogue ($locale).');
    }
    return parseManifest(response.body);
  }

  static List<Exercise> parseManifest(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! List) {
      throw const FormatException('Exercise catalogue must be a JSON list.');
    }
    return decoded
        .whereType<Map>()
        .map((item) => _fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  static Exercise _fromJson(Map<String, dynamic> data) => Exercise(
    id: data['id'] as String? ?? '',
    name:
        data['creatorName'] as String? ??
        data['name'] as String? ??
        'Untitled exercise',
    bodyPart: data['bodyPart'] as String? ?? '',
    target: data['target'] as String? ?? '',
    equipment: data['equipment'] as String? ?? 'Bodyweight',
    secondaryMuscles: List<String>.from(
      data['secondaryMuscles'] as List? ?? const [],
    ),
    instructions: List<String>.from(data['instructions'] as List? ?? const []),
    mediaUrl: data['mediaUrl'] as String?,
  );
}
