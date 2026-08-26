# Official identity and purchases

This document governs the Firebase Authentication and RevenueCat integrations
in official RepSet releases. It is part of the operating model's required
service record.

## Purpose and data boundary

Firebase Authentication provides an optional RepSet account through **Google**
or **Sign in with Apple**. RevenueCat receives the Firebase UID only after a
successful sign-in, so store entitlements attach to a stable account.

Workout history, templates, body weight, and exercise selections remain in
local SQLite. This integration does not upload, synchronize, or back up that
data. AI is not enabled by this change.

The client handles provider identity data (the email/display name released by
the provider) and the Firebase UID. RevenueCat handles the UID and purchase
entitlement data. Firebase and RevenueCat retention/deletion settings must be
reviewed before production launch.

## Community builds and forks

`REPSET_OFFICIAL_AUTH_ENABLED` defaults to `false`. Without official build
configuration, Firebase and RevenueCat are never initialized and the account
surface is not shown. A fork may remain local-only or supply its own Firebase
and RevenueCat projects. It must never use RepSet's configuration or products.

## Official release configuration

Protected CI supplies these **non-secret client identifiers** as Dart defines:

- `REPSET_OFFICIAL_AUTH_ENABLED=true`
- `REPSET_FIREBASE_API_KEY`
- `REPSET_FIREBASE_ANDROID_APP_ID`
- `REPSET_FIREBASE_IOS_APP_ID`
- `REPSET_FIREBASE_PROJECT_ID`
- `REPSET_FIREBASE_MESSAGING_SENDER_ID`
- `REPSET_GOOGLE_WEB_CLIENT_ID`
- `REPSET_GOOGLE_IOS_CLIENT_ID`
- `REPSET_REVENUECAT_GOOGLE_PUBLIC_KEY`
- `REPSET_REVENUECAT_APPLE_PUBLIC_KEY`

They are embedded in the app and are therefore not secrets. Restrict the
Firebase API key in Google Cloud to the official Android/iOS apps and their
required Firebase APIs. Keep service-account credentials, Apple private keys,
RevenueCat secret keys, store keys, signing material, and AI keys in protected
CI or the private backend only.

The official Android OAuth client must list `com.repset.repSetApp` and every
release SHA-1/SHA-256 signing certificate. The official iOS App ID must enable
Sign in with Apple; release signing must add the Sign in with Apple entitlement
to the Runner target. Register the Android/iOS OAuth clients and Apple provider
against the existing official Firebase production project. Do not commit
`google-services.json`, `GoogleService-Info.plist`, or an Apple private key.

## Required console setup

1. Enable only Google and Apple in Firebase Authentication. Disable anonymous
   and Email/Password for the official app.
2. Keep the existing official Firebase project so existing Firebase UIDs and
   RevenueCat customer identities remain continuous.
3. Configure RevenueCat's existing iOS and Android app entries with the same
   bundle/application ID, `com.repset.repSetApp`.
4. Configure the SDK with the Firebase UID after every successful login and
   log RevenueCat out before Firebase logout. The app implements this through
   `AccountService`.
5. Test Google and Apple using release-signed internal builds before shipping.

## Deletion and launch gate

Signing out only ends the device session; it does not delete a Firebase account
or store purchase record. Before making account login available in a production
release, ship a privacy screen with a deletion request route and document how
Firebase Auth and RevenueCat records are handled. Do not claim workout-cloud
backup until an approved sync design, privacy review, and deletion flow exist.

## Official advertising

Google AdMob supplies banners on Today, Library, History, and You, plus one
eligible interstitial after the finished-workout summary closes. Ads are never
shown while a workout is active. RepSet Max suppresses all ad requests and ad
surfaces.

The Google Mobile Ads SDK and User Messaging Platform may handle device or
advertising identifiers, approximate location derived from the network,
consent choices, ad interactions, and diagnostics according to the user's
region and choices. Workout history, exercises, sets, templates, body weight,
and training analytics are never added to ad requests. Google's published
retention and deletion controls govern data handled by those services; RepSet
keeps only an in-memory timestamp for its 20-minute interstitial cooldown.

Community builds have `REPSET_OFFICIAL_ADS_ENABLED=false` by default. They do
not create the ads service, request consent, load ads, or use RepSet ad units.
The native projects carry Google's documented sample app identifiers solely so
unconfigured builds remain launchable. The ignored official iOS xcconfig
overrides that sample identifier for protected official builds.

Local development may set `REPSET_ADS_TEST_MODE=true` together with Google's
sample ad-unit IDs. This bypasses only the unresolved Max-entitlement display
gate and UMP so test creatives can be inspected without touching the official
publisher account. Debug builds use Google's sample iOS App ID. Protected
official builds never set the flag and continue to require consent and fail
closed until Max access has been resolved.

Protected official builds provide these non-secret public identifiers:

- `REPSET_OFFICIAL_ADS_ENABLED=true`
- `REPSET_ADMOB_ANDROID_BANNER_UNIT_ID`
- `REPSET_ADMOB_ANDROID_INTERSTITIAL_UNIT_ID`
- `REPSET_ADMOB_IOS_BANNER_UNIT_ID`
- `REPSET_ADMOB_IOS_INTERSTITIAL_UNIT_ID`
- Android Gradle property `REPSET_ADMOB_ANDROID_APP_ID`
- iOS build setting `REPSET_ADMOB_IOS_APP_ID` through
  `ios/Flutter/OfficialAds.xcconfig`

Before release, configure the required UMP messages in AdMob, verify the
permanent Privacy choices entry point, complete Google Play Data safety and
App Store privacy disclosures, and confirm the bundled SDK privacy manifests.
Any mediated network added later requires a new data-handling review and its
own current SKAdNetwork identifiers where applicable.
