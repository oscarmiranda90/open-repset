import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'official_firebase_options.dart';

/// Official identity is opt-in at build time. Community builds remain entirely
/// local-first and never initialise or contact RepSet's Firebase project.
class AuthService {
  AuthService._(this._auth)
    : _googleSignIn = GoogleSignIn(
        clientId: defaultTargetPlatform == TargetPlatform.iOS
            ? OfficialFirebaseOptions.googleIosClientId
            : null,
        serverClientId: OfficialFirebaseOptions.googleWebClientId,
      );

  static const _enabled = bool.fromEnvironment(
    'REPSET_OFFICIAL_AUTH_ENABLED',
    defaultValue: false,
  );

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  static Future<AuthService?> initializeIfEnabled() async {
    if (!_enabled || kIsWeb || !OfficialFirebaseOptions.isConfigured) {
      return null;
    }
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return null;
    }

    try {
      await Firebase.initializeApp(
        options: OfficialFirebaseOptions.currentPlatform,
      );
      return AuthService._(FirebaseAuth.instance);
    } on FirebaseException catch (error) {
      debugPrint('Official authentication is unavailable: ${error.code}.');
      return null;
    } catch (error) {
      debugPrint('Official authentication could not start: $error');
      return null;
    }
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<User?> signInWithGoogle() async {
    final credential = await _googleCredential();
    if (credential == null) return null;
    return (await _auth.signInWithCredential(credential)).user;
  }

  Future<User?> signInWithApple() async {
    final credential = await _appleCredential();
    return (await _auth.signInWithCredential(credential)).user;
  }

  /// Deletes only the Firebase identity. Local workout data never leaves the
  /// device, so deleting it is a separate, user-controlled device action.
  Future<void> deleteCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await user.delete();
    } on FirebaseAuthException catch (error) {
      if (error.code != 'requires-recent-login') rethrow;
      final credential = await _reauthenticationCredential(user);
      await user.reauthenticateWithCredential(credential);
      await user.delete();
    }
  }

  Future<AuthCredential?> _googleCredential() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null;
    final authentication = await account.authentication;
    return GoogleAuthProvider.credential(
      accessToken: authentication.accessToken,
      idToken: authentication.idToken,
    );
  }

  Future<AuthCredential> _appleCredential() async {
    final rawNonce = _randomNonce();
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: _sha256(rawNonce),
    );
    return OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
      accessToken: appleCredential.authorizationCode,
    );
  }

  Future<AuthCredential> _reauthenticationCredential(User user) async {
    final providers = user.providerData
        .map((profile) => profile.providerId)
        .toSet();
    if (providers.contains('google.com')) {
      final credential = await _googleCredential();
      if (credential != null) return credential;
    }
    if (providers.contains('apple.com')) return _appleCredential();
    throw StateError('This sign-in method must be reauthenticated first.');
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  static String _randomNonce([int length = 32]) {
    const alphabet =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }

  static String _sha256(String value) =>
      sha256.convert(utf8.encode(value)).toString();
}
