# RepSet design system

This file is the durable design contract for every new RepSet feature. New UI
must follow it unless a documented accessibility or platform constraint wins.

## Product character

RepSet should feel focused, physical, and precise: dark training surfaces,
high-contrast data, acid-lime confirmation, compact typography, and motion that
resembles weight settling under control. It is a serious logger with moments of
personality, not a static database form and not a game.

## Motion is part of feature completeness

Every meaningful state change must communicate itself with motion. A feature is
not visually complete when important content simply appears or disappears.

Animate these events:

- Pressing a primary or consequential action: immediate scale feedback.
- Opening and closing a bottom sheet or dialog: one consistent route transition.
- Adding an exercise or set: the new item enters once with fade, lift, and settle.
- Removing or reordering content: preserve spatial continuity.
- Completing a set: elastic confirmation; starting a rest timer follows it.
- Saving, failing, reaching a PR, or finishing a workout: distinct state change.
- Loading remote or calculated content: purposeful progress motion, never a
  catalog-wide media prefetch.

Do not animate decoration continuously. Motion must explain cause and effect,
preserve input responsiveness, and never delay persistence or navigation.

## Motion tokens

| Token | Duration | Use |
| --- | ---: | --- |
| instant | 90 ms | press response |
| fast | 180 ms | icon/value replacement |
| standard | 320 ms | sheets and local state transitions |
| expressive | 520 ms | inserted content and celebrations |

- Default entrance curve: emphasized ease-out with a shallow settle.
- Default exit curve: ease-in, shorter than entrance.
- Stagger: 35–55 ms between related items; never exceed 250 ms total delay.
- Press scale: `0.97`; compact icon controls may use `0.94`.
- Animate transform and opacity where possible; avoid layout-heavy animation in
  long workout lists.

Production motion primitives live in `lib/core/motion/repset_motion.dart`.
Feature code should reuse those tokens instead of inventing durations.

## Accessibility and behavior

- Honor the platform's reduced-motion/disable-animations preference. Content
  must remain fully understandable with motion removed.
- Never require animation to reveal a control or convey the only copy of data.
- Do not block touch input while an entrance animation finishes.
- Preserve focus, screen-reader labels, and at least 44-point touch targets.
- Widget tests for animated lazy lists must scroll to and build important items,
  then advance through the animation to catch runtime assertions and overflow.

## Workout-specific hierarchy

- The live workout header stays within two compact rows. The first owns Back,
  the editable workout name, and Finish; the second owns LIVE, elapsed time,
  completed sets, volume, save state, and the compact exercise action.
- A new session is named `Today's Workout` by default. Renaming is an explicit
  tap on the title and must persist with the active session.
- Exercise names in the logger are interactive and carry a compact information
  affordance. Their detail sheet lazy-loads the movement media, keeps technique
  instructions readable, and separates completed-workout stats from live data.
- The exercise picker supports multi-selection. Two selected exercises may be
  linked as a persisted superset; completion follows interleaved set order
  (`A1 → B1 → A2 → B2`) and scrolls the next target into view.
- Repetitions remain the primary set value.
- RPE is optional set metadata, displayed as a compact elevated badge above the
  repetition value and edited in the same set sheet.
- Exercise cards use a dense `Set / Previous / kg / Reps / Done` table. Weight
  and repetitions remain directly editable; secondary metadata opens from the
  set number or RPE badge instead of crowding the main logging path.
- Empty weight and repetition cells inherit ghost values from the previous
  effective row in the same exercise. Completing a ghost row materializes and
  persists those values before marking the set complete.
- Use RepSet's acid lime (`#D7FF4F`) for active data, focus, and confirmation.
  Logger surfaces and input cells stay green-charcoal; blue is not part of the
  workout palette.
- The rest interval occupies a dotted rail between set rows. Idle dots remain
  muted; completing a set lights them in lime and the lit count decreases with
  the countdown. Tapping its time edits the duration for that exercise.
- Completed sets use lime confirmation without reducing number readability.
- Exercise and set insertion should feel physical and controlled; celebration
  is reserved for completion, PRs, and finished workouts.

## Review checklist

Before considering a UI feature complete:

1. Identify its meaningful state changes.
2. Map them to an existing motion primitive or add one to the shared system.
3. Verify reduced-motion behavior.
4. Test compact phone layout while the animation is active.
5. Keep persistence and BLoC state independent from animation lifecycle.
