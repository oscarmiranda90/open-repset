# RepSet open-source operating model

This document is the durable operating agreement for RepSet. When a proposed
change conflicts with it, stop and obtain an explicit maintainer decision
before proceeding.

## Source of truth and repositories

Until the public launch, this repository is the private official development
workspace. At launch, create a **new public `repset` repository with clean
history**. It becomes the canonical home for all shared Flutter application
code.

Do not maintain two actively developed copies of the Flutter app. After the
cutover:

```text
public repset/main -> all shared application code and community contributions
official release CI -> builds a tagged public commit with protected settings
private AI backend -> protected service code and server-side secrets
```

The original private repository may retain private release notes, store assets,
or operational records, but it must not become a second feature branch of the
application. A private-only feature is merged into public source before it can
ship in an official app release.

## Product promise

The free product is a capable offline workout logger. Workouts, templates,
history, and body-weight records stay on the device in SQLite by default.
Premium must never block a person from logging a workout.

The intended paid offering is optional: remove ads and receive an AI allowance.
AI has an ongoing serving cost, so it must be quota- or subscription-backed;
never promise unlimited lifetime AI access without an explicit cost model.

## Build modes

### Community build

- Starts with the built-in demo exercise library.
- Contains no RepSet production catalogue origin, ad account, private API key,
  signing credential, or privileged backend credential.
- A fork may configure its own catalogue with
  `REPSET_CATALOGUE_ORIGIN` and must ensure it has rights to every asset it
  hosts.

### Official release build

- Is built only from a tagged commit of the public repository.
- Injects non-secret release settings, such as the official catalogue origin,
  through protected CI configuration.
- Uses protected CI secrets for signing and server deployment only. A Dart
  define is embedded in the app and therefore is never a secret.

## Exercise catalogue and media

`REPSET_CATALOGUE_ORIGIN` has no production default in source code. This is a
deliberate cost and licensing boundary: a fork must not silently consume
RepSet's production R2 service.

The Gym Visual exercise GIFs are copyrighted third-party media redistributed
by official RepSet with permission. They are not part of the open-source code
license, are not committed to Git, and must not be relicensed, extracted,
rehosted, or bundled as a media pack. The authoritative wording is in
[MEDIA_NOTICE.md](MEDIA_NOTICE.md).

Only authorized RepSet maintainers may operate the media migration scripts.
Those scripts must not be presented as a way for forks to obtain or mirror the
GIF library.

## Monetization and AI boundary

- Use App Store / Google Play in-app purchase mechanisms for digital app
  functionality where their policies require them.
- A RevenueCat public SDK key may be embedded in an official client; secret
  RevenueCat keys are server-only.
- Ads never interrupt an active workout. Show required consent and a durable
  privacy-options entry point before requesting ads where applicable.
- The AI provider key, entitlement verification, cost controls, rate limits,
  and abuse protections live behind the private server API. Never put an AI
  provider key, RevenueCat secret, R2 write credential, or server token in
  Flutter source, Dart defines, client configuration, or GitHub Actions logs.
- AI receives only the user-approved, minimal workout summary and is read-only:
  it cannot modify workouts, purchases, or entitlements.

## Public-repository release gate

Before the first public push, and before every release:

1. Review all tracked files and complete Git history for credentials.
2. Remove Firebase client configuration and unused integrations unless they
   have a currently approved role.
3. Ignore local operational state such as `.wrangler/`, `.dev.vars`, `.env`,
   signing files, exports, and build artifacts.
4. Keep third-party notices and `MEDIA_NOTICE.md` accurate.
5. Run the repository safety check, static analysis, and tests.
6. Publish only after choosing and adding the source-code license and a
   trademark/branding policy.

Fork pull requests never receive deployment or production secrets. Releases
run only from protected branches/tags and protected CI environments.

## Change protocol

For every new external service, document its purpose, data handled, whether
its client identifier is public, where its secret is stored, deletion/retention
behavior, and how a community fork replaces or disables it. If any of those
answers is unclear, do not add the integration yet.
