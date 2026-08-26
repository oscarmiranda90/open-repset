# RepSet

RepSet is an offline-first workout logger built with Flutter. It helps people
run a training session, track sets and rests, and browse a curated exercise
library.

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

## Features

- Active workout logging with set, rep, and rest tracking
- Offline-first local workout persistence
- Curated exercise catalogue with cached media
- Reduced-motion-aware interface
- A debug-only animation lab for motion studies

## Run locally

Requirements: a current Flutter SDK compatible with Dart `^3.12.1` and a
configured Android, iOS, macOS, or web development environment.

```bash
flutter pub get
flutter run
```

Without `REPSET_CATALOGUE_ORIGIN`, the app uses the demo exercise data. This is
intentional: a clone should not consume RepSet's production media service.

Community builds also have official advertising disabled. AdMob is created
only when protected release configuration explicitly enables it and supplies
RepSet's public app/ad-unit identifiers. Forks show no ads and never send ad
requests unless their maintainer deliberately implements and configures their
own monetization.

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
