# RepSet rebuild plan

Each phase ends with a usable feature, database migrations, BLoC tests, widget tests, and a manual mobile smoke test. A phase is complete only when it works offline and survives an app restart.

Every phase also follows [DESIGN.md](DESIGN.md): meaningful actions and state
changes require purposeful motion, shared motion tokens, compact-phone testing,
and a reduced-motion fallback. Animation is part of feature completion, not a
final polish pass.

## Phase 1: Exercise library

- Load the configured English or Spanish static exercise catalogue.
- Store the catalog in SQLite and open cached data immediately.
- Search names, muscles, body parts, and equipment without accents or case sensitivity.
- Filter by muscle and equipment.
- View instructions, secondary muscles, and an authorized preview URL. A GIF is fetched only when its library card or detail view becomes visible, then served from the local media cache.
- Favorite exercises locally.
- Handle loading, cached, empty, refresh, media-error, and network-error states.

Acceptance: after one successful sync, airplane mode still provides the complete searchable catalog and favorites. A GIF is available offline only after its card or detail has been viewed once.

## Phase 2: Active workout

Current vertical slice: **in progress**. Session recovery, exercise picking,
editable warm-up/working sets, kg, reps, optional RPE, set notes, completion,
elapsed time, removal, finish flow, per-exercise kg/lb and rest duration, an
automatic dotted rest countdown with the original alarm, and SQLite v4
persistence are built. RPE is stored on the set and displayed as a compact
badge above its repetitions. Exercise reorder/replace/duplicate/group and
background timer notifications are still pending before the phase is complete.

- Create or resume one active session.
- Add exercises from the library.
- Log warm-up and working sets with kg/lb, reps, RPE, notes, and completion state.
- Reorder, replace, duplicate, group, and remove exercises.
- Rest timer and elapsed workout timer.
- Recover every edit after process death.

Acceptance: a full workout can be logged and finished without an account or network.

## Phase 3: Templates

- Create, edit, duplicate, archive, reorder, and start templates.
- Preserve exercise order, set targets, notes, rest time, and groups.
- Offer recent and favorite templates on Today.

Acceptance: a repeated workout starts in two taps and remains editable after creation.

## Phase 4: History and editing

- Session list and calendar.
- Session detail, safe edit, soft delete, and restore window.
- Exercise history with previous-set hints.
- CSV and JSON export.

Acceptance: every completed session is queryable and export totals match SQLite records.

## Phase 5: Progress

- Personal records, total volume, estimated one-rep max, consistency, and muscle distribution.
- Weekly and monthly ranges with unit-aware display.
- Explicit formulas and tests for every metric.

Acceptance: calculations are deterministic and derived only from completed sessions.

## Phase 6: Authentication and sync

- Guest mode, email authentication, Apple/Google sign-in, and account linking.
- Any future sync must use an idempotent SQLite outbox, retry state, tombstones, and revisions.
- Restore a user backup onto a clean installation.
- Account deletion and local-data deletion.

Acceptance: logging never waits on a network service, and reinstall recovery does not duplicate sessions.

## Phase 7: RevenueCat

- Identify RevenueCat with a privacy-preserving app user identifier.
- One `Premium` entitlement, offerings, purchase, restore, and entitlement refresh.
- Keep core workout logging free. Gate only genuinely costly or advanced features.

Acceptance: entitlement changes propagate without restarting and purchases restore on a second device.

## Phase 8: Settings and localization

- kg/lb, language, theme, timer preferences, data/export, privacy, and legal screens.
- English and Spanish UI plus matching static catalogue manifests.
- Accessibility, dynamic text, screen-reader labels, and reduced motion.

Acceptance: changing language or units never mutates stored canonical values.

## Phase 9: Optional recovery and reminders

- Session feeling/recovery note.
- Local workout reminders if they prove useful.
- No remote notification provider until there is a real server-driven use case.

## Future AI boundary

AI remains absent. A future read-only coaching adapter may receive sanitized completed-session summaries and return suggestions. It cannot write workouts, change billing, or access raw authentication credentials.
