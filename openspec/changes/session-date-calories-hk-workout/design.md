## Context

Today ending a session clears local active state only. Watch `finishWorkout()` can return an `HKWorkout.uuid` and active energy, but nothing is stored on the server. Session list has no date field to sort by.

**Status:** Backend not started. Client must wait.

## Goals / Non-Goals

**Goals:**
- Server-side `CreatedAt` for chronological session lists.
- On end (with Watch HK workout): save calories + HealthKit workout id.
- Client sorts and displays those fields after API is ready.

**Non-Goals (for this change):**
- Local-only persistence as a substitute for the API.
- Raw HR sample upload.
- Changing exercise-level `caloriesBurnedInTotal` semantics beyond optional session totals.

## Decisions

1. **Backend fields (recommended)**
   - `TrainingSession.CreatedAt` (`DateTimeOffset`, set on create).
   - `TrainingSession.CaloriesBurnedInTotal` (`double?`).
   - `TrainingSession.HealthKitWorkoutId` (`string?`, max ~64, UUID string).
   - Also mirror calories + workout id on `TrainingSessionCompletion` when creating the completion row (`StartDate`/`EndDate` already exist).

2. **When to write metrics** — Only when Watch reports a finished HK workout (`healthKitWorkoutId` and/or calories > 0). Still create a completion with start/end when ending without Watch metrics if product wants every end recorded (open: confirm; default yes for dates).

3. **Client apply order** — After migration is applied in the target environment: wire DTOs → gateway `endSession` params → list sort → UI. Do not merge client before API returns the new JSON properties.

## Risks / Trade-offs

- Existing sessions get a backfilled `CreatedAt` (migration default) — sort order for old rows may be approximate.
- Simulator HK may yield 0 kcal / no workout — UI must tolerate nulls.
