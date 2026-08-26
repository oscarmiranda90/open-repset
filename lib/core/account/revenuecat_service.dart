import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Purchases are an official-release integration. The public SDK keys are
/// identifiers rather than secrets, but they deliberately have no source-code
/// default so community builds cannot consume RepSet's RevenueCat project.
class RevenueCatService {
  RevenueCatService._();

  static const _appleKey = String.fromEnvironment(
    'REPSET_REVENUECAT_APPLE_PUBLIC_KEY',
  );
  static const _googleKey = String.fromEnvironment(
    'REPSET_REVENUECAT_GOOGLE_PUBLIC_KEY',
  );

  bool _configured = false;

  static Future<RevenueCatService?> initializeIfConfigured({
    String? appUserId,
  }) async {
    if (kIsWeb) return null;
    final key = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => _appleKey,
      TargetPlatform.android => _googleKey,
      _ => '',
    };
    if (key.isEmpty) return null;

    try {
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }
      final service = RevenueCatService._();
      await Purchases.configure(
        PurchasesConfiguration(key)..appUserID = appUserId,
      );
      service._configured = true;
      return service;
    } catch (error) {
      debugPrint('RevenueCat is unavailable: $error');
      return null;
    }
  }

  /// The entitlement every Max subscription grants.
  ///
  /// Products come and go — weekly, monthly, yearly, whatever ships next — but
  /// they all unlock this one permission, so nothing downstream has to know
  /// which product a subscriber bought.
  static const maxEntitlement = 'max';

  /// The offering that groups the Max plans shown on the paywall.
  static const maxOffering = 'maxv1';

  bool get isConfigured => _configured;

  /// Whether the current customer holds an active Max subscription.
  ///
  /// This is a display signal only. The server verifies entitlement itself
  /// before serving AI, because a client can always be made to lie.
  Future<bool> hasMaxAccess() async {
    if (!_configured) return false;
    try {
      var info = await Purchases.getCustomerInfo();
      if (info.entitlements.active.containsKey(maxEntitlement)) return true;

      // A granted entitlement is changed outside the app, so RevenueCat's
      // cached CustomerInfo can still say "inactive" immediately afterwards.
      // Keep a cached active entitlement usable offline, but force one fresh
      // lookup before treating an apparently inactive customer as free.
      await Purchases.invalidateCustomerInfoCache();
      info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(maxEntitlement);
    } catch (error) {
      debugPrint('Entitlement lookup failed: $error');
      return false;
    }
  }

  /// The Max plans available to this customer, cheapest period first.
  Future<List<Package>> maxPackages() async {
    if (!_configured) return const [];
    try {
      final offerings = await Purchases.getOfferings();
      // Named explicitly so the paywall keeps working even when this offering
      // is not the project's current default, and falls back when it is.
      final offering = offerings.all[maxOffering] ?? offerings.current;
      if (kDebugMode) {
        final available = offerings.all.keys.join(', ');
        final packages = offering?.availablePackages
            .map(
              (package) =>
                  '${package.identifier}:${package.storeProduct.identifier}'
                  '=${package.storeProduct.priceString}',
            )
            .join(', ');
        debugPrint(
          'RevenueCat offerings=[$available], '
          'current=${offerings.current?.identifier ?? 'none'}, '
          'selected=${offering?.identifier ?? 'none'}, '
          'packages=[${packages ?? ''}]',
        );
      }
      if (offering == null) return const [];
      return offering.availablePackages;
    } catch (error) {
      debugPrint('Offerings are unavailable: $error');
      return const [];
    }
  }

  /// Buys [package] and reports whether Max is active afterwards.
  Future<bool> purchase(Package package) async {
    if (!_configured) return false;
    final result = await Purchases.purchase(PurchaseParams.package(package));
    return result.customerInfo.entitlements.active.containsKey(maxEntitlement);
  }

  /// Restores prior purchases, for a reinstall or a second device.
  Future<bool> restore() async {
    if (!_configured) return false;
    final info = await Purchases.restorePurchases();
    return info.entitlements.active.containsKey(maxEntitlement);
  }

  Future<void> logIn(String firebaseUid) async {
    if (!_configured) return;
    await Purchases.logIn(firebaseUid);
  }

  Future<void> logOut() async {
    if (!_configured) return;
    await Purchases.logOut();
  }
}
