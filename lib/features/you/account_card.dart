import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/account/account_service.dart';
import '../../core/motion/repset_motion.dart';

const _accountAccent = Color(0xffd7ff4f);

/// A deliberately small identity surface. Account sign-in is optional: it
/// establishes a stable purchase/AI identity, never a requirement to train.
class AccountCard extends StatefulWidget {
  const AccountCard({super.key, required this.service});

  final AccountService service;

  @override
  State<AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<AccountCard> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<User?> Function() operation) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _error = _messageFor(error));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Sign-in did not finish. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _messageFor(FirebaseAuthException error) => switch (error.code) {
    'account-exists-with-different-credential' =>
      'Use the sign-in method you originally chose.',
    'network-request-failed' => 'Check your connection and try again.',
    _ => 'Sign-in did not finish. Please try again.',
  };

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: widget.service.authStateChanges,
    initialData: widget.service.currentUser,
    builder: (context, snapshot) {
      final user = snapshot.data;
      return AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: .08),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: user == null
                ? _signedOut(context)
                : _signedIn(context, user),
          ),
        ),
      );
    },
  );

  Widget _signedOut(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final appleAvailable =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ACCOUNT',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Make purchases and future AI access yours.',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: -.3,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Your workouts stay on this device.',
          style: TextStyle(
            color: muted,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        _SignInButton(
          key: const Key('sign-in-google-button'),
          busy: _busy,
          provider: _SignInProvider.google,
          label: 'Sign in with Google',
          onPressed: () => _run(widget.service.signInWithGoogle),
        ),
        if (appleAvailable) ...[
          const SizedBox(height: 8),
          _SignInButton(
            key: const Key('sign-in-apple-button'),
            busy: _busy,
            provider: _SignInProvider.apple,
            label: 'Sign in with Apple',
            onPressed: () => _run(widget.service.signInWithApple),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _signedIn(BuildContext context, User user) {
    final label = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : (user.email ?? 'Signed in');
    return Row(
      children: [
        const CircleAvatar(
          radius: 18,
          backgroundColor: _accountAccent,
          foregroundColor: Color(0xff171914),
          child: Icon(Icons.person_rounded, size: 20),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ACCOUNT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  try {
                    await widget.service.signOut();
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}

enum _SignInProvider { google, apple }

class _SignInButton extends StatelessWidget {
  const _SignInButton({
    super.key,
    required this.busy,
    required this.provider,
    required this.label,
    required this.onPressed,
  });

  final bool busy;
  final _SignInProvider provider;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = !busy;
    return Semantics(
      button: true,
      label: label,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : .62,
        child: RepSetPress(
          scale: .985,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? onPressed : null,
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset(
                      switch (provider) {
                        _SignInProvider.google =>
                          'assets/images/auth/google_logo.webp',
                        _SignInProvider.apple =>
                          'assets/images/auth/apple_sign.webp',
                      },
                      height: provider == _SignInProvider.apple ? 42 : 44,
                      fit: BoxFit.contain,
                    ),
                    if (busy)
                      const Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: Color(0xb8090b09)),
                          child: Center(
                            child: SizedBox(
                              width: 21,
                              height: 21,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.3,
                                color: _accountAccent,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
