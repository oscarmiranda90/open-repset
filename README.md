# RepSet

<p align="center">
  <img src="assets/icon/brand_mark.png" width="112" alt="RepSet icon">
</p>

<p align="center">
  <strong>An offline-first workout logger for focused training.</strong><br>
  Plan a session, log every set, rest with intention, and keep your history on your device.
</p>

RepSet is a Flutter app for people who want a capable workout log without
turning their training data into a cloud product. It runs locally, starts with
demo exercise data, and remains useful without an account.

## Privacy-first by design

RepSet does **not** provide file, photo, document, or health-record uploads.
Workout sessions stay on the device in SQLite. The exercise library is supplied
by a configurable static catalogue; there is no user-data cloud sync.

RepSet's official exercise catalogue and previews are selected by its release
configuration. The exercise GIFs are
copyrighted Gym Visual media redistributed by RepSet with permission; they are
not open-source assets. They are not provided to forks through a default URL.
See [MEDIA_NOTICE.md](MEDIA_NOTICE.md) for the boundary.

## Exercise catalogue configuration

The open-source build starts with the small built-in demo library. A fork that
has its own authorized catalogue and media can enable it at build time:

```bash
flutter run --dart-define=REPSET_CATALOGUE_ORIGIN=https://example.com/catalog
```

The catalogue must provide `exercises.en.json` and `exercises.es.json` with the
same shape as `Exercise`. Each record's `mediaUrl` must point to media that the
fork is authorized to host. RepSet's production R2 origin is injected only by
the official release pipeline. The migration scripts are operational tools for
authorized RepSet maintainers only; never commit Cloudflare credentials.

Do not add user-data uploads or sync without an explicit privacy and security
review. The complete policy is in [SECURITY.md](SECURITY.md).

## What it does

- Build workouts from templates or start a session from scratch.
- Log sets, repetitions, load, RPE, notes, supersets, and rest intervals.
- Keep active workouts, training history, templates, body weight, and analytics
  on-device in SQLite.
- Browse and search a configurable exercise library, with local caching when a
  fork supplies an authorized catalogue.
- Review progress through volume, muscle coverage, body-weight, and relative
  strength views.
- Use an optional account only for official-release purchase identity;
  workout data is never uploaded or synchronized.
- Respect reduced-motion settings throughout the interface.

## Screens and product media

The public source repository intentionally does not include App Store
screenshots or Gym Visual exercise artwork. Those deliverables belong in the
official store listing, and the exercise media is third-party copyrighted
content. See [MEDIA_NOTICE.md](MEDIA_NOTICE.md) for the exact boundary.

## Run locally

Requirements: Flutter with Dart `^3.12.1`, plus an Android, iOS, macOS, or web
target configured on your machine.

### Terminal

```bash
flutter pub get
flutter run
```

Select a specific target when more than one is available:

```bash
flutter devices
flutter run -d ios
flutter run -d chrome
```

Run the quality checks before opening a pull request:

```bash
flutter analyze
flutter test
./scripts/check-public-repo.sh
```

### VS Code or Android Studio

1. Open the repository root.
2. Install the Flutter and Dart plugins.
3. Choose a simulator, emulator, browser, or connected device.
4. Launch with **Run and Debug** / `F5` (VS Code) or the Run button (Android
   Studio).

The same `flutter run` command remains available in the integrated terminal.
Hot reload is available while running a debug build.

Without `REPSET_CATALOGUE_ORIGIN`, the app uses the demo exercise data. This is
intentional: a clone should not consume RepSet's production media service.

Community builds also have official advertising disabled. AdMob is created
only when protected release configuration explicitly enables it and supplies
RepSet's public app/ad-unit identifiers. Forks show no ads and never send ad
requests unless their maintainer deliberately implements and configures their
own monetization.

## Animation Lab

Debug builds expose **Settings → Developer → Animation Lab**. It is a
replayable collection of native Flutter motion studies for interactions such as
set completion, timers, workout summaries, cards, charts, loaders, and
confirmation feedback. Tap a study to replay it.

The lab is a development tool: it is removed from profile and release builds.
Motion is implemented in Flutter rather than shipped as external animation
assets, and production screens should continue to honor the user's
reduced-motion preference.

## Before publishing or contributing

Never commit credentials, service accounts, signing keys, `.env` files,
database exports, or real user data. Check the working tree before every pull
request:

```bash
./scripts/check-public-repo.sh
flutter test
```

The same repository-safety check runs in GitHub Actions on pull requests and
pushes to `main`. It catches common credential filenames and patterns, but it
is a safety net—not a substitute for reviewing each change.

## Project notes

Debug builds include a **Lab** destination with replayable native Flutter
motion studies. It is compiled out of profile and release builds.

- [DESIGN.md](DESIGN.md) — visual and motion rules
- [ARCHITECTURE_REPORT.md](ARCHITECTURE_REPORT.md) — scope, architecture, and roadmap
- [OPEN_SOURCE_OPERATING_MODEL.md](OPEN_SOURCE_OPERATING_MODEL.md) — public-repo, release, media, and service rules
- [OFFICIAL_SERVICES.md](OFFICIAL_SERVICES.md) — official Firebase Auth and RevenueCat boundary
- [FEATURE_COMPARISON.md](FEATURE_COMPARISON.md) — legacy/remaster feature comparison
- [REBUILD_PLAN.md](REBUILD_PLAN.md) — implementation phases and acceptance criteria
- [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) — open-source attribution
- [TRADEMARKS.md](TRADEMARKS.md) — branding rules for forks

## License

RepSet source code is licensed under [Apache-2.0](LICENSE). Third-party media
and RepSet branding are excluded; see [MEDIA_NOTICE.md](MEDIA_NOTICE.md) and
[TRADEMARKS.md](TRADEMARKS.md).
