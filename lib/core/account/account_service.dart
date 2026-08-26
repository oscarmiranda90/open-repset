import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';
import 'revenuecat_service.dart';

/// Keeps the Firebase identity and RevenueCat customer identity in lockstep.
/// It intentionally never uploads locally stored workouts or body metrics.
class AccountService {
  AccountService(this._auth, this._purchases);

  final AuthService _auth;
  final RevenueCatService? _purchases;

  Stream<User?> get authStateChanges => _auth.authStateChanges;
  User? get currentUser => _auth.currentUser;

  /// Null when purchases are not configured for this build, which is the
  /// community case: no store keys, so no subscription surface.
  RevenueCatService? get purchases => _purchases;

  Future<User?> signInWithGoogle() => _complete(_auth.signInWithGoogle());
  Future<User?> signInWithApple() => _complete(_auth.signInWithApple());

  Future<User?> _complete(Future<User?> operation) async {
    final user = await operation;
    if (user != null) await _purchases?.logIn(user.uid);
    return user;
  }

  Future<void> signOut() async {
    await _purchases?.logOut();
    await _auth.signOut();
  }

  /// Removes the sign-in identity. Store subscriptions remain managed by the
  /// App Store or Play Store, and local workouts remain on this device.
  Future<void> deleteAccount() async {
    await _auth.deleteCurrentUser();
    try {
      await _purchases?.logOut();
    } catch (_) {
      // The identity is already deleted; a RevenueCat logout failure must not
      // turn a successful deletion into a false failure for the person.
    }
  }
}
