## Context

Active training on iPhone already loads executions/sets (`ClientTrainingModel.loadActiveSession` + `ActiveTrainingSessionView`). Plan detail lists past sessions as ids only. Watch owns HealthKit vitals (`WatchHealthKitWorkoutManager`) and never publishes them; `CompanionSyncSnapshot` is iPhone→Watch UI state today.

## Goals / Non-Goals

**Goals:**
- Read-only session detail from plan history (exercises + sets) on iPhone.
- Route into interactive active UI when the selected session is the current active one.
- Throttled Watch→iPhone vitals (HR, elapsed, active kcal) shown on the active-session screen when fresh.
- Keep raw HR off the business API.

**Non-Goals:**
- Full workout mirroring / HK mirrored sessions from iPhone.
- Effort scores beyond active energy (kcal) from HealthKit.
- Redesign of Watch training UI.
- Server-side HR time series storage.

## Decisions

1. **Session detail loading** — Reuse `listExecutions` + `listSets` (same as active). Optional `getSession` only if needed for metadata; do not block on richer DTO fields that the API may not return yet.
2. **Routing** — Extend `TrainingRoute` with `.session(String)`. Plan list rows navigate there; if `sessionId == activeSession.activeSessionId`, present/reuse `ActiveTrainingSessionView` instead of a separate read-only stack.
3. **Vitals transport** — Add companion fields (or a small metrics dictionary) on the Watch→phone path via existing WC channels (`transferUserInfo` / `sendMessage` when reachable), **not** by overwriting iPhone-owned training apply. Prefer a dedicated `CompanionWorkoutMetrics` payload applied only to an iPhone vitals store so `CompanionStateApplier` does not clear training when Watch pushes HR.
4. **Throttle** — Publish vitals ~every 2–5s while workout active (and on meaningful HR/energy change), not on every HK sample callback.
5. **Staleness** — iPhone hides or marks unavailable if last metrics older than ~15–30s or Watch unreachable.
6. **Display** — Compact strip atop `ActiveTrainingSessionView`: HR (bpm), elapsed (`workoutStartedAt` → now), active energy (kcal) when present.

## Risks / Trade-offs

- **Simulator HealthKit** may yield sparse/zero HR — UI must tolerate missing metrics.
- **WC reliability** — same as companion sync; vitals are best-effort display, not source of truth for logging.
- **Payload direction confusion** — risk of Watch vitals being treated as full sync snapshots; mitigate with explicit metrics type / keys and iPhone-only consumer.
