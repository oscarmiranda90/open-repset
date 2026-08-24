# Feature comparison: legacy RepSet vs remaster

Legend: **Built** means working code exists in the remaster. **Foundation** means the boundary or dependency exists but the feature is not wired into the app. **Planned** means documented only.

| Capability | Legacy RepSet | Remaster v0.0.1 | Decision |
| --- | --- | --- | --- |
| Start and finish a workout | Implemented modular training flow | **Built core** SQLite-backed start, recovery, editing, and finish flow | Add finish safeguards and history integration. |
| Log sets, reps, weights, RPE, notes | Implemented through training widgets/providers | **Built core** editable warm-up/working sets with optional RPE badge and notes | Add lb presentation, timed/bodyweight/unilateral variants, and previous-set hints. |
| Rest, warm-up, and post-workout timers | Implemented | **Planned** | Keep rest and warm-up. Keep post-workout only if it serves recovery tracking. |
| Supersets / grouped exercises | Implemented combined-set details | **Planned** | Keep. Model it in SQLite, not with widget maps. |
| Reorder, replace, duplicate, remove exercises | Implemented | **Planned** | Keep. |
| Exercise library | Firestore catalog, Hive cache, descriptions, favorites, blacklist | **Built core** configurable catalogue, SQLite cache, search, filters, favorites, details, and lazy GIF cache | Add custom exercises and blacklist only if blacklist still proves useful. |
| Custom exercises | Implemented | **Planned** | Keep as user-owned SQLite data. |
| Templates / routines | Implemented creation, detail, save, sync | **Planned** | Keep. It is central to repeatable training. |
| Training blocks / fitness plans | Implemented | **Planned** | Fold into templates first. Do not recreate multiple overlapping planning systems. |
| Workout history | Implemented summary pages, editing, session cards | **Planned** | Keep, but derive it from immutable session rows. |
| Exercise history and PRs | Implemented | **Planned** | Keep. This is a core logger feature. |
| Volume / muscle insights / weekly analytics | Implemented | **Planned** | Keep a focused version: volume, e1RM, PRs, consistency. |
| Calendar and cycle planning | Implemented | **Planned** | Add after history and templates. |
| Feelings / recovery log | Implemented | **Planned** | Optional phase-two feature. |
| Badges / merits | Implemented | Not planned | Drop initially. It does not improve basic training logging. |
| Authentication | Email, Google, Apple | Not planned for v1 | Keep guest/local use first; add only with a privacy-reviewed purpose. |
| Offline data | Hive local storage | **Built foundation** SQLite repository | Replace Hive completely. SQLite becomes the local source of truth. |
| Cloud synchronization | Firestore for workouts, settings, templates | Not planned for v1 | Any future sync needs a durable SQLite outbox and explicit privacy review. |
| Exercise GIFs / images | Firebase Storage plus remote URLs | **Built core** fetched when a visible card or detail requests one, then cached | Community forks configure their own authorized source. |
| Import / export | CSV, sharing, PDF | **Planned** | Keep CSV and JSON export. Add PDF only if it has a clear user purpose. |
| Subscription / paywall | RevenueCat, credits, several paywalls | **Foundation** RevenueCat dependency and existing Function pattern | Keep one premium entitlement. Remove credits and duplicate paywall flows. |
| Push notifications | OneSignal | Not planned | Drop until a genuinely useful reminder feature exists. |
| AI coaching, generated routines, history analysis | Gemini/OpenAI features | Intentionally removed, future interface only | Keep out of v1. Add only as read-only suggestions later. |
| Machine scanning and image enhancement | Implemented experimental feature | Not planned | Drop. |
| GymCrush / social-oriented flow | Implemented | Not planned | Drop. |
| Onboarding, profile, settings, legal pages | Implemented | **Planned** | Keep streamlined onboarding, profile, units, sync, privacy, and account deletion. |
| Localization | English and Spanish | **Planned** | Keep after training flow is stable. The catalog already supports both collections. |

## Actual coverage today

The old app has roughly 60 feature-facing pages plus supporting services. The remaster has 13 Dart files and only these working user-visible functions:

- Navigate among Today, Library, and Progress.
- Display a small demo exercise catalog.
- Start, recover, edit, and finish an active workout through `WorkoutBloc`.
- Persist ordered workout exercises and editable sets atomically in SQLite v2,
  including nullable set-level RPE.

So the remaster is **not at feature parity**. It is an intentionally clean starting point for achieving it without carrying forward the legacy architecture.

## Recommended feature order

1. Complete active workout: session recovery, exercise picker, set rows, edit/reorder/delete, timers, finish flow, and SQLite tests.
2. Complete exercise library: configured catalogue, GIF rendering/cache, search, filters, details, favorites, and custom exercises.
3. Add templates and history: create, apply, edit, calendar, per-exercise history, PRs, volume, and export.
4. Add account/sync only after a separate privacy review and an explicit server design.
5. Add RevenueCat around one explicit premium entitlement, restore purchases, and one paywall.
6. Add preferences, English/Spanish UI, recovery tracking, and reminders only after the core loop is reliable.

## Features deliberately left behind

AI runtime features, GymCrush, machine scanning, image enhancement, credits, multiple paywalls, OneSignal, background startup work, and badge gamification are not necessary for a serious gym logger. They can return only after the core product has reliable workout logging, history, and sync.
