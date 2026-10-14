## Why

Clients need plan session history ordered by date, and when ending a session that had an Apple Watch HealthKit workout they need calories and the HK workout UUID persisted. The current API `TrainingSession` only exposes `id` + plan ids — without backend fields this cannot be the source of truth.

## What Changes

**Backend first (blocker — do not ship client until this lands):**
- Add `CreatedAt` on `TrainingSession` (set on create); list/sort by newest first.
- Persist at session end (when Watch finished an HK workout): `CaloriesBurnedInTotal` and `HealthKitWorkoutId` on the session and/or `TrainingSessionCompletion`.
- Expose those fields on GET `api/training-sessions` (and completion create/update as needed).

**Client after backend is ready (do not implement until then):**
- Decode/sort sessions by `createdAt`.
- On end session from Watch: send calories + HK workout UUID; iPhone writes them via API.
- Show date, calories, and workout id in plan session list + session detail.

## Capabilities

### New Capabilities
- `session-workout-persistence`: Persist and display session date, Watch calories, and HealthKit workout id for completed training sessions.

### Modified Capabilities
- `client-training-session`: End-session path MUST persist completion metrics when a Watch workout was recorded; history list MUST order by session date.

## Impact

- Backend: `Domain/TrainingSession` (+ optionally `TrainingSessionCompletion`), EF migration, create/update/list responses.
- Native (later): `TrainingSessionDTO`, `TrainingService`, `CompanionPhoneGateway` / Watch `endWorkout` → `endSession` params, plan/session UI.
- **Blocked:** no further app work on this change until backend fields exist and are deployed.
