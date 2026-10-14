## Why

Clients can run an active session on iPhone and Watch, but past sessions in a plan are only listed by id with no drill-down. During an active workout the Watch already has live HealthKit vitals (HR, elapsed time, active energy) that never appear on iPhone, so the phone cannot show companion effort while training.

## What Changes

- Add read-only **session detail** on iPhone: open a past (or non-active) session from a plan’s session list and show exercises, sets, and completion state loaded via Core/API.
- While a session is **active** and the Watch companion is delivering workout metrics, show a compact **Apple Watch vitals** strip on the iPhone active-session screen (heart rate, elapsed workout time, and active energy / effort when available).
- Extend Watch → iPhone companion sync with throttled workout metrics (no raw HR samples uploaded to the business API).

## Capabilities

### New Capabilities
- `iphone-session-history`: Browse and inspect training session detail (exercises/sets) from plan history on iPhone.
- `iphone-watch-vitals`: Surface live Watch HealthKit workout metrics on iPhone during an active companion-backed session.

### Modified Capabilities
- `client-training-session`: Add navigation/entry to session history detail from plan session lists; keep active-session logging unchanged.
- `watch-healthkit-workout`: Clarify that Watch MUST publish companion-safe vitals (HR, elapsed, active energy) to the iPhone while a workout is active, without sending raw samples to the API.

## Impact

- iPhone: `ClientTrainingViews`, `ClientTrainingModel`, routing (`TrainingRoute`), optional use of `TrainingService.getSession` + existing `listExecutions` / `listSets`.
- Shared: `CompanionSyncSnapshot` / bridge encoding for vitals fields; Watch publisher from `WatchHealthKitWorkoutManager` / `WatchTrainingModel`.
- Watch: throttled WC updates while workout active; no change to API calorie upload of raw HR.
- Simulator: vitals strip depends on Watch Connectivity + HealthKit samples (may be sparse in sim).
