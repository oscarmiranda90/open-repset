import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Non-secret Firebase client configuration supplied only by the official
/// release environment. A Firebase API key identifies a client; it is not a
/// server credential and must still be restricted in Google Cloud.
class OfficialFirebaseOptions {
  OfficialFirebaseOptions._();

  static const _apiKey = String.fromEnvironment('REPSET_FIREBASE_API_KEY');
  static const _androidAppId = String.fromEnvironment(
    'REPSET_FIREBASE_ANDROID_APP_ID',
  );
  static const _iosAppId = String.fromEnvironment('REPSET_FIREBASE_IOS_APP_ID');
  static const _projectId = String.fromEnvironment(
    'REPSET_FIREBASE_PROJECT_ID',
  );
  static const _senderId = String.fromEnvironment(
    'REPSET_FIREBASE_MESSAGING_SENDER_ID',
  );
  static const googleWebClientId = String.fromEnvironment(
    'REPSET_GOOGLE_WEB_CLIENT_ID',
  );
  static const googleIosClientId = String.fromEnvironment(
    'REPSET_GOOGLE_IOS_CLIENT_ID',
  );

  static bool get isConfigured {
    final appId = defaultTargetPlatform == TargetPlatform.iOS
        ? _iosAppId
        : _androidAppId;
    return _apiKey.isNotEmpty &&
        appId.isNotEmpty &&
        _projectId.isNotEmpty &&
        _senderId.isNotEmpty &&
        googleWebClientId.isNotEmpty &&
        (defaultTargetPlatform != TargetPlatform.iOS ||
            googleIosClientId.isNotEmpty);
  }

  static FirebaseOptions get currentPlatform {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    return FirebaseOptions(
      apiKey: _apiKey,
      appId: ios ? _iosAppId : _androidAppId,
      messagingSenderId: _senderId,
      projectId: _projectId,
      androidClientId: null,
      iosClientId: ios ? googleIosClientId : null,
      iosBundleId: ios ? 'com.repset.repSetApp' : null,
    );
  }
}
