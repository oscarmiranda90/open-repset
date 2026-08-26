import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/account/account_service.dart';
import '../../core/account/max_access.dart';
import '../../core/account/revenuecat_service.dart';
import '../../core/ads/official_ads_service.dart';
import '../../core/motion/repset_motion.dart';
import '../dev/animation_lab_page.dart';
import '../paywall/max_paywall_page.dart';

const _accent = Color(0xffd7ff4f);
final _privacyUri = Uri.parse('https://crescente.dev/repset/privacy');
final _termsUri = Uri.parse('https://crescente.dev/repset/terms');

/// The app's settings surface.
///
/// Also the home of developer tools, which used to sit in the navigation dock.
/// A debug-only surface does not deserve a permanent seat next to the tabs
/// people use every day.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.accountService, this.adsService});

  final AccountService? accountService;
  final OfficialAdsService? adsService;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  RevenueCatService? get _purchases => widget.accountService?.purchases;

  Future<void> _refreshEntitlement() =>
      context.read<MaxAccessCubit>().refresh();

  Future<void> _openPaywall() async {
    final purchases = _purchases;
    if (purchases == null) return;
    if (!await requireSignInForMax(context, widget.accountService) ||
        !mounted) {
      return;
    }
    final subscribed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MaxPaywallPage(
          purchases: purchases,
          account: widget.accountService,
        ),
      ),
    );
    if (subscribed ?? false) await _refreshEntitlement();
  }

  Future<void> _openPrivacyOptions() async {
    final ads = widget.adsService;
    if (ads == null) return;
    final shown = await ads.showPrivacyOptions();
    if (!shown && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Privacy options are unavailable.')),
      );
    }
  }

  Future<void> _openDocument(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This link could not be opened.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<MaxAccessCubit>().state;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          children: [
            Text(
              'SETTINGS',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            if (_purchases?.isConfigured ?? false) ...[
              _SubscriptionCard(
                hasMax: access.isActive,
                checking: !access.hasResolved,
                onSubscribe: _openPaywall,
              ),
              const SizedBox(height: 26),
            ],
            const _SectionLabel('App'),
            const SizedBox(height: 10),
            _SettingsTile(
              icon: Icons.notifications_none_rounded,
              label: 'Rest timer alerts',
              detail: 'Managed in your device settings',
              onTap: null,
            ),
            if (widget.adsService != null)
              ValueListenableBuilder<bool>(
                valueListenable: widget.adsService!.privacyOptionsRequired,
                builder: (context, required, _) => required
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: _SettingsTile(
                          key: const Key('settings-privacy-options'),
                          icon: Icons.privacy_tip_outlined,
                          label: 'Privacy choices',
                          detail: 'Review advertising consent',
                          onTap: _openPrivacyOptions,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            const SizedBox(height: 26),
            const _SectionLabel('Legal'),
            const SizedBox(height: 10),
            _SettingsTile(
              key: const Key('settings-privacy-policy'),
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy policy',
              detail: 'How RepSet handles your data',
              onTap: () => _openDocument(_privacyUri),
            ),
            const SizedBox(height: 10),
            _SettingsTile(
              key: const Key('settings-terms'),
              icon: Icons.description_outlined,
              label: 'Terms of service',
              detail: 'Terms for using RepSet',
              onTap: () => _openDocument(_termsUri),
            ),
            if (widget.accountService != null) ...[
              const SizedBox(height: 26),
              const _SectionLabel('Account'),
              const SizedBox(height: 10),
              _AccountDeletionTile(service: widget.accountService!),
            ],
            if (kDebugMode) ...[
              const SizedBox(height: 26),
              const _SectionLabel('Developer'),
              const SizedBox(height: 10),
              _SettingsTile(
                key: const Key('settings-animation-lab'),
                icon: Icons.science_outlined,
                label: 'Animation lab',
                detail: 'Motion primitives and timing',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AnimationLabPage()),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccountDeletionTile extends StatefulWidget {
  const _AccountDeletionTile({required this.service});

  final AccountService service;

  @override
  State<_AccountDeletionTile> createState() => _AccountDeletionTileState();
}

class _AccountDeletionTileState extends State<_AccountDeletionTile> {
  bool _busy = false;
  String? _error;

  Future<void> _delete() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: RepSetMotion.sheetAnimation,
      builder: (context) => _DeleteAccountSheet(
        onCancel: () => Navigator.pop(context, false),
        onConfirm: () => Navigator.pop(context, true),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.deleteAccount();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'We could not delete your account. Sign in again and try once more.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: widget.service.authStateChanges,
    initialData: widget.service.currentUser,
    builder: (context, snapshot) {
      if (snapshot.data == null) return const SizedBox.shrink();
      return Column(
        children: [
          _SettingsTile(
            key: const Key('settings-delete-account'),
            icon: Icons.delete_outline_rounded,
            label: _busy ? 'Deleting account…' : 'Delete account',
            detail: 'Remove your sign-in account',
            destructive: true,
            onTap: _busy ? null : _delete,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
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
    },
  );
}

class _DeleteAccountSheet extends StatelessWidget {
  const _DeleteAccountSheet({required this.onCancel, required this.onConfirm});

  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(12),
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
    decoration: BoxDecoration(
      color: const Color(0xff29201d),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: const Color(0xff5a3931)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xff8f7068),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Delete your account?',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'This removes your sign-in account. Workouts stay on this device. Active subscriptions must be cancelled in the App Store or Google Play.',
          style: TextStyle(color: Color(0xffccb8b0), height: 1.35),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 50,
          child: FilledButton(
            key: const Key('confirm-delete-account-button'),
            onPressed: onConfirm,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffdf725c),
              foregroundColor: const Color(0xff24110d),
            ),
            child: const Text(
              'Delete account',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
        TextButton(onPressed: onCancel, child: const Text('Keep account')),
      ],
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 10.5,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.1,
    ),
  );
}

/// The Max status card: an upsell when inactive, a receipt when active.
class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({
    required this.hasMax,
    required this.checking,
    required this.onSubscribe,
  });

  final bool hasMax;
  final bool checking;
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (checking) {
      return Container(
        height: 96,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: _accent),
          ),
        ),
      );
    }

    if (hasMax) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
        decoration: BoxDecoration(
          color: _accent.withValues(alpha: .11),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _accent.withValues(alpha: .5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: _accent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RepSet Max is active',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.25,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Manage or cancel in your store account.',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RepSetPress(
      scale: .985,
      child: GestureDetector(
        onTap: onSubscribe,
        child: Container(
          padding: const EdgeInsets.fromLTRB(17, 17, 17, 17),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _accent.withValues(alpha: .45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4.5,
                ),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'REPSET MAX',
                  style: TextStyle(
                    color: _accent,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 11),
              const Text(
                'AI session planning,\nand no ads.',
                style: TextStyle(
                  fontSize: 18,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.5,
                ),
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Text(
                    'See plans',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
    this.destructive = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = destructive ? scheme.error : scheme.onSurface;
    final secondary = destructive
        ? scheme.error.withValues(alpha: .78)
        : scheme.onSurfaceVariant;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          child: Row(
            children: [
              Icon(icon, size: 19, color: secondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.15,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      detail,
                      style: TextStyle(
                        color: secondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, size: 19, color: secondary),
            ],
          ),
        ),
      ),
    );
  }
}
