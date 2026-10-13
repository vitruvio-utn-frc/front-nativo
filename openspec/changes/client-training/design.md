## Context

Depends on gym client role. Watch HealthKit is a separate change. API entities: TrainingPlan, TrainingSession, ExerciseExecution, ExerciseSet, ExerciseCompletion.

## Goals / Non-Goals

**Goals:** iPhone plan browse, session start/continue, logging, offline queue, Core session surface for Watch.  
**Non-Goals:** HealthKit, staff plan editing, awards/store.

## Decisions

### D1: Active session in Core
Single `ActiveTrainingSession` store in Core (in-memory + durable snapshot) shared by iPhone and Watch.

### D2: Offline queue
Generic Core `OfflineQueue` for training mutations first; durable local storage (file/SQLite/SwiftData) chosen at implement time — behavior over engine.

### D3: Start semantics
Creating a `TrainingSession` via API (or local-first then sync) marks it active; prefer server id when online.

### D4: Calories
If HealthKit not running on iPhone-only session, completions may omit or estimate calories until Watch/HK contributes.

## Risks / Trade-offs

- **[Risk] Sparse includes from API** → Mitigation: explicit follow-up fetches for plan exercises
- **[Risk] Concurrent start on phone and Watch** → Mitigation: last-write/active-id rules documented in Watch change

## Open Questions

- Whether templates (`TrainingPlanTemplate`) are shown to clients in v1 — default hide unless assigned as plans
