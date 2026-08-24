# RepSet gym training logger - architecture

## Product decision

RepSet is a full gym training logger. It is not a marketing experiment, but it should remain financially modest to operate. The app must work during a workout without a network. SQLite is the source of truth; cloud sync is not part of the current product.

The definitive public-repository and official-release rules are in
[OPEN_SOURCE_OPERATING_MODEL.md](OPEN_SOURCE_OPERATING_MODEL.md). This report
describes the application architecture; it must not override that operating
model.

## Core stack

| Concern | Choice | Reason |
| --- | --- | --- |
| Presentation state | BLoC | Explicit events and testable state for active training, library, auth, history, preferences, and entitlement state. |
| Offline persistence | SQLite | Relational workout history, atomic writes, migrations, queries, and exports. SQLite is the source of truth. |
| Exercise catalogue | Configurable static JSON | Official releases use their configured catalogue; community builds use demo data until a fork configures its own authorized source. |
| Monetization | Future RevenueCat + store billing | Optional ads and paid AI/ad-free entitlement; server-side features never trust the client alone. |
| AI | Private backend boundary | The client sends only approved summaries; provider keys and authorization stay server-side. |

## Features to build

### Training

- Start an empty workout or a template.
- Add, reorder, replace, duplicate, and remove exercises.
- Log weight, reps, RPE, notes, warm-up sets, working sets, timed sets, bodyweight, and unilateral work.
- Rest timer, active-session recovery, finish, edit, and delete safeguards.
- Supersets and exercise groups.
- Unit choice: kg or lb, with storage normalized to kg.

### Library and plans

- Search, filter by muscle/equipment, favorites, custom exercises, instructions, and authorized GIF preview.
- Reusable templates, folders, and schedule-ready routines.
- The read-only English and Spanish exercise catalogues are static JSON served
  from Cloudflare R2. User-created exercises belong to their account.

### History and progress

- Calendar, session history, exercise history, volume, estimated one-rep max, streaks, and PRs.
- CSV and JSON export from SQLite.
- All summaries are queries over completed local sessions. No widget-owned aggregate state.

### Premium and AI (future)

- Optional ad-free and AI entitlement, with purchase/restore flow.
- AI authorization is enforced by a private backend, not by a client flag.
- Premium is never required to log a workout.

## Data design

```
SQLite
  workout_sessions  1 -> many  workout_exercises  1 -> many  workout_sets
  templates         1 -> many  template_exercises 1 -> many  template_sets
  exercises (cached catalog)    favorites    custom_exercises
  sync_outbox       app_preferences

Configured object storage
  exercises.en.json / exercises.es.json  optional read-only catalogue
  official media                         official-release-only configuration
```

Every user-owned record has a UUID, `createdAt`, `updatedAt`, `deletedAt`, and sync revision. A completed session is immutable except through an explicit edit that creates a new revision. That makes sync, metrics, and future coaching features trustworthy.

## App layers

```
lib/
  app/                    composition, routing, theme, bootstrap
  core/                   database, sync, errors, design tokens
  domain/                 entities, repository ports, calculations
  data/                   SQLite, static catalogue, future service adapters
  features/
    auth/ library/ workout/ templates/ history/ progress/ settings/ paywall/
    each feature: bloc, events, state, pages, widgets
  future/ai/              interfaces only, no provider SDK or keys
```

Dependencies only point inward. UI talks to BLoCs. BLoCs talk to use cases and repository interfaces. SQLite, catalogue delivery, and future billing adapters are swappable. No provider should own text controllers, widgets, focus nodes, and domain state together.

## What we retain from the old app

- Exercise catalogue record shape: `id`, `name`, `bodyPart`, `equipment`,
  `target`, `secondaryMuscles`, `instructions`, `mediaUrl`.
- Authorized exercise GIF delivery for the official release, subject to
  [MEDIA_NOTICE.md](MEDIA_NOTICE.md).
- Domain knowledge: set calculation, workload metrics, units, personal records, import/export, and templates.

## What we do not carry forward

- Hive and the old local-cache schema.
- Giant stateful providers and widget maps.
- Paywall-first product behavior, credits, commercial ledger, and duplicated subscription concepts.
- Gemini or OpenAI runtime calls, key fetching, prompt logic, scans, and image enhancement.
- OneSignal, background service startup, remote configuration, and marketing/store surfaces until a real requirement exists.

## Current v0.0.1 foundation

- Flutter app shell with a BLoC-controlled active workout logger, exercise picker,
  elapsed time, editable set sheets, and finish flow.
- SQLite v2 `workout_sessions -> workout_exercises -> workout_sets` repository
  with atomic saves, v1 migration, and nullable set-level RPE.
- Offline-first exercise library with local SQLite cache, BLoC search and
  filters, favorites, details, and lazy GIF caching only after a visible card
  or detail requests media.
- The app uses its demo library unless a release config provides an authorized
  static catalogue origin. RevenueCat remains uninitialized until its feature
  phase.

## AI-ready boundary

If coaching returns later, it gets a sanitized read-only `TrainingInsightService` input: a date range and completed session summaries. It returns suggestions only. It cannot write workouts, alter records, call RevenueCat, or hold API keys in the client.
