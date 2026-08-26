import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/account/account_service.dart';
import '../../core/account/revenuecat_service.dart';
import '../../core/motion/repset_motion.dart';
import '../you/account_card.dart';

const _accent = Color(0xffd7ff4f);

/// Keeps the purchase flow attached to a stable account from its first screen.
/// Workouts remain available anonymously; only Max requires an identity.
Future<bool> requireSignInForMax(
  BuildContext context,
  AccountService? account,
) async {
  if (account == null) return false;
  if (account.currentUser != null) return true;
  final signedIn = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    sheetAnimationStyle: RepSetMotion.sheetAnimation,
    builder: (_) => _SignInSheet(account: account),
  );
  return signedIn == true && account.currentUser != null;
}

/// What a Max subscription unlocks. Kept short: three real benefits read
/// faster than a feature grid, and the first one is why people subscribe.
const _benefits = [
  (
    Icons.auto_awesome_rounded,
    'AI session planning',
    'Describe a session in your own words and get it built.',
  ),
  (
    Icons.block_rounded,
    'No ads, anywhere',
    'Never an interruption between you and a set.',
  ),
  (
    Icons.favorite_rounded,
    'Support development',
    'RepSet is built by one person. Max is what keeps it going.',
  ),
];

/// The Max subscription surface.
///
/// Offerings come from RevenueCat rather than from hard-coded prices: the
/// store is the authority on what a plan costs in a given country, and a
/// price written into the app is wrong the moment it changes.
class MaxPaywallPage extends StatefulWidget {
  const MaxPaywallPage({super.key, required this.purchases, this.account});

  final RevenueCatService purchases;

  /// Present when this build can sign someone in. A purchase made without an
  /// account belongs to an anonymous customer, which the server cannot match
  /// to anyone later — so signing in comes first.
  final AccountService? account;

  @override
  State<MaxPaywallPage> createState() => _MaxPaywallPageState();
}

class _MaxPaywallPageState extends State<MaxPaywallPage> {
  List<Package> _packages = const [];
  Package? _selected;
  bool _loading = true;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final packages = await widget.purchases.maxPackages();
    if (!mounted) return;
    final ordered = _orderedByValue(packages);
    setState(() {
      _packages = ordered;
      // The longest plan is both the best value and the one worth defaulting
      // to, so it starts selected rather than merely labelled.
      _selected = ordered.isEmpty ? null : ordered.last;
      _loading = false;
      _message = ordered.isEmpty
          ? 'Plans are unavailable right now. Try again shortly.'
          : null;
    });
  }

  /// Shortest period first, so the annual plan lands last where the eye
  /// finishes and the saving is easiest to compare against what came before.
  static List<Package> _orderedByValue(List<Package> packages) {
    const rank = {
      PackageType.weekly: 0,
      PackageType.monthly: 1,
      PackageType.twoMonth: 2,
      PackageType.threeMonth: 3,
      PackageType.sixMonth: 4,
      PackageType.annual: 5,
      PackageType.lifetime: 6,
    };
    return packages.toList(growable: false)..sort(
      (a, b) =>
          (rank[a.packageType] ?? 99).compareTo(rank[b.packageType] ?? 99),
    );
  }

  /// Asks for a sign-in before buying, when nobody is signed in.
  ///
  /// Max is verified server-side against an account. A purchase made while
  /// anonymous is recorded against a customer that no account will ever claim,
  /// which is how someone ends up having paid without having access.
  Future<bool> _ensureSignedIn() async {
    final signedIn = await requireSignInForMax(context, widget.account);
    return mounted && signedIn;
  }

  Future<void> _purchase() async {
    final package = _selected;
    if (package == null || _busy) return;
    if (!await _ensureSignedIn()) {
      if (mounted) {
        setState(
          () => _message = 'Sign in first so your subscription follows you.',
        );
      }
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final unlocked = await widget.purchases.purchase(package);
      if (!mounted) return;
      if (unlocked) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() => _message = 'That purchase did not activate Max.');
    } on PlatformException catch (error) {
      if (!mounted) return;
      // A cancelled purchase is a decision, not a failure to report.
      final cancelled =
          PurchasesErrorHelper.getErrorCode(error) ==
          PurchasesErrorCode.purchaseCancelledError;
      setState(() => _message = cancelled ? null : _messageFor(error));
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'The purchase could not be completed.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final unlocked = await widget.purchases.restore();
      if (!mounted) return;
      if (unlocked) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() => _message = 'No previous Max subscription was found.');
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Purchases could not be restored.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _messageFor(PlatformException error) =>
      switch (PurchasesErrorHelper.getErrorCode(error)) {
        PurchasesErrorCode.purchaseNotAllowedError =>
          'Purchases are not allowed on this device.',
        PurchasesErrorCode.paymentPendingError =>
          'The payment is pending. Max activates once it clears.',
        PurchasesErrorCode.networkError =>
          'Check your connection and try again.',
        PurchasesErrorCode.productAlreadyPurchasedError =>
          'You already own this plan. Try restoring purchases.',
        _ => 'The purchase could not be completed.',
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _PaywallHeader(onClose: () => Navigator.of(context).pop(false)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                children: [
                  const _PaywallHero(),
                  const SizedBox(height: 26),
                  for (final benefit in _benefits) ...[
                    _BenefitRow(
                      icon: benefit.$1,
                      title: benefit.$2,
                      detail: benefit.$3,
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 10),
                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: CircularProgressIndicator(color: _accent),
                      ),
                    )
                  else
                    for (final package in _packages)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PlanCard(
                          package: package,
                          annual: _annualOf(_packages),
                          selected: identical(package, _selected),
                          onTap: () => setState(() => _selected = package),
                        ),
                      ),
                  if (_message != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: scheme.error,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _PaywallFooter(
              busy: _busy,
              canPurchase: _selected != null,
              onPurchase: _purchase,
              onRestore: _restore,
            ),
          ],
        ),
      ),
    );
  }

  static Package? _annualOf(List<Package> packages) {
    for (final package in packages) {
      if (package.packageType == PackageType.annual) return package;
    }
    return null;
  }
}

/// Sign-in, offered at the moment it is needed.
class _SignInSheet extends StatelessWidget {
  const _SignInSheet({required this.account});

  final AccountService account;

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: account.authStateChanges,
    initialData: account.currentUser,
    builder: (context, snapshot) {
      if (snapshot.data != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) Navigator.pop(context, true);
        });
        return const SizedBox.shrink();
      }
      return _content(context);
    },
  );

  Widget _content(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _accent.withValues(alpha: .3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sign in to continue',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Max is tied to your account, so it follows you to a new phone. '
            'Your workouts stay on this device either way.',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          AccountCard(service: account),
        ],
      ),
    );
  }
}

class _PaywallHeader extends StatelessWidget {
  const _PaywallHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
    child: Row(
      children: [
        const Spacer(),
        IconButton(
          key: const Key('close-paywall'),
          tooltip: 'Close',
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
  );
}

class _PaywallHero extends StatelessWidget {
  const _PaywallHero();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: _accent.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _accent.withValues(alpha: .45)),
        ),
        child: const Text(
          'REPSET MAX',
          style: TextStyle(
            color: _accent,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.3,
          ),
        ),
      ),
      const SizedBox(height: 16),
      Text(
        'Train with a plan,\nnot a blank page.',
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w900,
          height: 1.06,
          letterSpacing: -1,
        ),
      ),
    ],
  );
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 18, color: _accent),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One selectable plan.
///
/// The saving against the annual plan is computed from the store's own prices
/// rather than written down, so it stays true in every currency and through
/// every price change.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.package,
    required this.annual,
    required this.selected,
    required this.onTap,
  });

  final Package package;
  final Package? annual;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isAnnual = package.packageType == PackageType.annual;
    final saving = _savingAgainstAnnual();

    return RepSetPress(
      scale: .985,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
          decoration: BoxDecoration(
            color: selected
                ? _accent.withValues(alpha: .11)
                : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: selected
                  ? _accent
                  : scheme.outlineVariant.withValues(alpha: .55),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              _SelectionDot(selected: selected),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _titleFor(package.packageType),
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.2,
                          ),
                        ),
                        if (isAnnual) ...[
                          const SizedBox(width: 7),
                          const _BestValueTag(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      saving == null
                          ? _cadenceFor(package.packageType)
                          : 'Save $saving% with the yearly plan',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                package.storeProduct.priceString,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// How much cheaper the annual plan is per year than paying this cadence.
  /// Returns null for the annual plan itself and whenever the comparison
  /// cannot be made honestly — a different currency, or a missing price.
  String? _savingAgainstAnnual() {
    final reference = annual;
    if (reference == null || identical(reference, package)) return null;
    if (reference.storeProduct.currencyCode !=
        package.storeProduct.currencyCode) {
      return null;
    }
    final periods = _periodsPerYear(package.packageType);
    if (periods == null) return null;
    final yearlyCost = package.storeProduct.price * periods;
    if (yearlyCost <= 0) return null;
    final saving = (1 - reference.storeProduct.price / yearlyCost) * 100;
    if (saving < 1) return null;
    return saving.round().toString();
  }

  static double? _periodsPerYear(PackageType type) => switch (type) {
    PackageType.weekly => 52,
    PackageType.monthly => 12,
    PackageType.twoMonth => 6,
    PackageType.threeMonth => 4,
    PackageType.sixMonth => 2,
    _ => null,
  };

  static String _titleFor(PackageType type) => switch (type) {
    PackageType.weekly => 'Weekly',
    PackageType.monthly => 'Monthly',
    PackageType.twoMonth => 'Every 2 months',
    PackageType.threeMonth => 'Quarterly',
    PackageType.sixMonth => 'Every 6 months',
    PackageType.annual => 'Yearly',
    PackageType.lifetime => 'Lifetime',
    _ => 'Max',
  };

  static String _cadenceFor(PackageType type) => switch (type) {
    PackageType.weekly => 'Billed every week',
    PackageType.monthly => 'Billed every month',
    PackageType.annual => 'Billed once a year',
    PackageType.lifetime => 'One payment, forever',
    _ => 'Recurring subscription',
  };
}

class _SelectionDot extends StatelessWidget {
  const _SelectionDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    width: 20,
    height: 20,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: selected ? _accent : Colors.transparent,
      border: Border.all(
        color: selected
            ? _accent
            : Theme.of(context).colorScheme.outlineVariant,
        width: 1.6,
      ),
    ),
    child: selected
        ? const Icon(Icons.check_rounded, size: 13, color: Color(0xff171914))
        : null,
  );
}

class _BestValueTag extends StatelessWidget {
  const _BestValueTag();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: _accent,
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Text(
      'BEST VALUE',
      style: TextStyle(
        color: Color(0xff171914),
        fontSize: 8.5,
        fontWeight: FontWeight.w900,
        letterSpacing: .6,
      ),
    ),
  );
}

class _PaywallFooter extends StatelessWidget {
  const _PaywallFooter({
    required this.busy,
    required this.canPurchase,
    required this.onPurchase,
    required this.onRestore,
  });

  final bool busy;
  final bool canPurchase;
  final VoidCallback onPurchase;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: .5)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepSetPress(
            child: FilledButton(
              key: const Key('subscribe-to-max'),
              onPressed: busy || !canPurchase ? null : onPurchase,
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: const Color(0xff171914),
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Color(0xff171914),
                      ),
                    )
                  : const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.2,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            key: const Key('restore-purchases'),
            onPressed: busy ? null : onRestore,
            child: Text(
              'Restore purchases',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            'Renews automatically. Cancel any time in your store account.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurfaceVariant.withValues(alpha: .8),
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
