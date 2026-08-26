import 'package:flutter_test/flutter_test.dart';
import 'package:repset/core/ads/official_ads_service.dart';

void main() {
  group('post-workout interstitial policy', () {
    final now = DateTime(2026, 8, 25, 12);

    bool eligible({
      bool adsPermitted = true,
      bool hasMax = false,
      int workouts = 3,
      bool showing = false,
      DateTime? lastShownAt,
    }) => OfficialAdsService.isCompletedWorkoutInterstitialEligible(
      adsPermitted: adsPermitted,
      hasMaxAccess: hasMax,
      completedWorkoutCount: workouts,
      isAlreadyShowing: showing,
      now: now,
      lastShownAt: lastShownAt,
    );

    test('follows every completed workout', () {
      // A finished session is the ad break; the cooldown, not a warm-up count,
      // is what stops two workouts in one morning from meaning two ads.
      expect(eligible(workouts: 1), isTrue);
      expect(eligible(workouts: 0), isFalse);
    });

    test('never shows without consent or to Max customers', () {
      expect(eligible(adsPermitted: false), isFalse);
      expect(eligible(hasMax: true), isFalse);
    });

    test('enforces a twenty-minute cooldown', () {
      expect(
        eligible(lastShownAt: now.subtract(const Duration(minutes: 19))),
        isFalse,
      );
      expect(
        eligible(lastShownAt: now.subtract(const Duration(minutes: 20))),
        isTrue,
      );
    });

    test('does not overlap another fullscreen ad', () {
      expect(eligible(showing: true), isFalse);
    });
  });
}
