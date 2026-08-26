import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Official-release advertising backed by Google Mobile Ads and UMP.
///
/// Every identifier is embedded public client configuration. There are no
/// source-code defaults, so community builds neither create this service nor
/// request an ad. The native projects use Google's sample app identifiers only
/// to keep an unconfigured build installable; they cannot earn RepSet revenue.
class OfficialAdsService {
  OfficialAdsService._({
    required this.bannerAdUnitId,
    required this._interstitialAdUnitId,
    required this.isTestMode,
  });

  static const _enabled = bool.fromEnvironment('REPSET_OFFICIAL_ADS_ENABLED');
  static const _testMode = bool.fromEnvironment('REPSET_ADS_TEST_MODE');
  static const _androidBanner = String.fromEnvironment(
    'REPSET_ADMOB_ANDROID_BANNER_UNIT_ID',
  );
  static const _iosBanner = String.fromEnvironment(
    'REPSET_ADMOB_IOS_BANNER_UNIT_ID',
  );
  static const _androidInterstitial = String.fromEnvironment(
    'REPSET_ADMOB_ANDROID_INTERSTITIAL_UNIT_ID',
  );
  static const _iosInterstitial = String.fromEnvironment(
    'REPSET_ADMOB_IOS_INTERSTITIAL_UNIT_ID',
  );

  /// Every finished session is an ad break; the cooldown below is what keeps
  /// that from becoming relentless for someone training twice in a morning.
  static const minimumCompletedWorkouts = 1;
  static const interstitialCooldown = Duration(minutes: 20);

  final String bannerAdUnitId;
  final String _interstitialAdUnitId;

  /// Allows sample ads without requiring a configured store entitlement.
  /// Protected release configuration never enables this flag.
  final bool isTestMode;

  final ValueNotifier<bool> canRequestAds = ValueNotifier(false);
  final ValueNotifier<bool> privacyOptionsRequired = ValueNotifier(false);

  InterstitialAd? _interstitial;
  DateTime? _lastInterstitialAt;
  bool _started = false;
  bool _mobileAdsInitialized = false;
  bool _loadingInterstitial = false;
  bool _showingInterstitial = false;
  bool _monetizationAllowed = false;
  Timer? _interstitialRetryTimer;

  static OfficialAdsService? createIfConfigured() {
    if (!_enabled || kIsWeb) return null;

    final (banner, interstitial) = switch (defaultTargetPlatform) {
      TargetPlatform.android => (_androidBanner, _androidInterstitial),
      TargetPlatform.iOS => (_iosBanner, _iosInterstitial),
      _ => ('', ''),
    };
    if (banner.isEmpty || interstitial.isEmpty) {
      debugPrint(
        'Official ads are enabled but their public ad-unit IDs are missing.',
      );
      return null;
    }
    return OfficialAdsService._(
      bannerAdUnitId: banner,
      interstitialAdUnitId: interstitial,
      isTestMode: _testMode,
    );
  }

  /// Refreshes regional consent, shows a form when required, and initializes
  /// the ads SDK only after UMP says requests are permitted.
  Future<void> start() async {
    if (_started || !_monetizationAllowed) return;
    _started = true;

    if (isTestMode) {
      await _enableTestAds();
      return;
    }

    final completion = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        await _showConsentFormIfRequired();
        await _applyConsentState();
        if (!completion.isCompleted) completion.complete();
      },
      (error) async {
        debugPrint('Ad consent update failed: ${error.message}');
        // A valid choice from an earlier launch may still permit requests.
        await _applyConsentState();
        if (!completion.isCompleted) completion.complete();
      },
    );
    await completion.future;
  }

  Future<void> _enableTestAds() async {
    if (!_monetizationAllowed) return;
    if (!_mobileAdsInitialized) {
      await MobileAds.instance.initialize();
      _mobileAdsInitialized = true;
    }
    canRequestAds.value = true;
    _loadInterstitial();
  }

  Future<void> _showConsentFormIfRequired() async {
    final completion = Completer<void>();
    await ConsentForm.loadAndShowConsentFormIfRequired((error) {
      if (error != null) {
        debugPrint('Ad consent form failed: ${error.message}');
      }
      if (!completion.isCompleted) completion.complete();
    });
    await completion.future;
  }

  Future<void> _applyConsentState() async {
    final privacyStatus = await ConsentInformation.instance
        .getPrivacyOptionsRequirementStatus();
    privacyOptionsRequired.value =
        privacyStatus == PrivacyOptionsRequirementStatus.required;

    final consentPermitsAds = await ConsentInformation.instance.canRequestAds();
    final permitted = _monetizationAllowed && consentPermitsAds;
    canRequestAds.value = permitted;
    if (!permitted) {
      _interstitial?.dispose();
      _interstitial = null;
      return;
    }

    if (!_mobileAdsInitialized) {
      await MobileAds.instance.initialize();
      _mobileAdsInitialized = true;
    }
    _loadInterstitial();
  }

  /// Applies the resolved Max entitlement before any ad request is made.
  /// Losing eligibility disposes prefetched inventory immediately.
  void setMonetizationAllowed(bool allowed) {
    if (_monetizationAllowed == allowed) return;
    _monetizationAllowed = allowed;
    if (!allowed) {
      canRequestAds.value = false;
      _interstitialRetryTimer?.cancel();
      _interstitial?.dispose();
      _interstitial = null;
      return;
    }
    if (_started) {
      unawaited(isTestMode ? _enableTestAds() : _applyConsentState());
    } else {
      unawaited(start());
    }
  }

  /// Reopens the UMP privacy controls. Returns false only when the form fails.
  Future<bool> showPrivacyOptions() async {
    final completion = Completer<bool>();
    await ConsentForm.showPrivacyOptionsForm((error) {
      if (error != null) {
        debugPrint('Privacy options failed: ${error.message}');
      }
      if (!completion.isCompleted) completion.complete(error == null);
    });
    final succeeded = await completion.future;
    if (succeeded) await _applyConsentState();
    return succeeded;
  }

  /// Displays a preloaded ad after the summary has closed. It never waits for
  /// an ad to load, so finishing a workout cannot be blocked by monetization.
  bool maybeShowCompletedWorkoutInterstitial({
    required int completedWorkoutCount,
    required bool hasMaxAccess,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final eligible = isCompletedWorkoutInterstitialEligible(
      adsPermitted: canRequestAds.value,
      hasMaxAccess: hasMaxAccess,
      completedWorkoutCount: completedWorkoutCount,
      isAlreadyShowing: _showingInterstitial,
      now: currentTime,
      lastShownAt: _lastInterstitialAt,
    );
    if (!eligible) return false;

    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return false;
    }

    _interstitial = null;
    _showingInterstitial = true;
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdShowedFullScreenContent: (_) {
        _lastInterstitialAt = currentTime;
      },
      onAdDismissedFullScreenContent: (shownAd) {
        shownAd.dispose();
        _showingInterstitial = false;
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (failedAd, error) {
        debugPrint('Interstitial failed to show: $error');
        failedAd.dispose();
        _showingInterstitial = false;
        _loadInterstitial();
      },
    );
    unawaited(ad.show());
    return true;
  }

  @visibleForTesting
  static bool isCompletedWorkoutInterstitialEligible({
    required bool adsPermitted,
    required bool hasMaxAccess,
    required int completedWorkoutCount,
    required bool isAlreadyShowing,
    required DateTime now,
    DateTime? lastShownAt,
  }) =>
      adsPermitted &&
      !hasMaxAccess &&
      completedWorkoutCount >= minimumCompletedWorkouts &&
      !isAlreadyShowing &&
      (lastShownAt == null ||
          now.difference(lastShownAt) >= interstitialCooldown);

  void _loadInterstitial() {
    if (!canRequestAds.value ||
        _loadingInterstitial ||
        _interstitial != null ||
        _showingInterstitial) {
      return;
    }
    _loadingInterstitial = true;
    unawaited(
      InterstitialAd.load(
        adUnitId: _interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _loadingInterstitial = false;
            _interstitialRetryTimer?.cancel();
            if (canRequestAds.value) {
              _interstitial = ad;
            } else {
              ad.dispose();
            }
          },
          onAdFailedToLoad: (error) {
            _loadingInterstitial = false;
            debugPrint('Interstitial failed to load: $error');
            _interstitialRetryTimer?.cancel();
            _interstitialRetryTimer = Timer(
              const Duration(seconds: 30),
              _loadInterstitial,
            );
          },
        ),
      ),
    );
  }
}
