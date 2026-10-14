## Why

The Watch companion’s product scope is client training only: active workouts, exercise progress, and HealthKit heart-rate/workout data. Sessions may start on either device (prefer iPhone); the Watch must continue or start sessions using shared Core, offline queue, and HealthKit — not Watch Connectivity as the source of truth.

## What Changes

- Attach Watch UI to active/continuable training sessions from Core
- Allow starting a session from Watch when none is active (secondary to iPhone)
- Run `HKWorkoutSession` with `traditionalStrengthTraining` during active workouts
- Surface live heart rate and workout metrics from HealthKit on Watch
- Persist progress via Core API + offline queue; keep HR primarily in HealthKit (API gets completions/duration/calories)
- Client-only; no staff/admin Watch surfaces

## Capabilities

### New Capabilities

- `watch-training-ui`: Watch surfaces for active training session and exercise/set progress
- `watch-healthkit-workout`: HealthKit workout session and heart-rate display for client workouts

### Modified Capabilities

- (none)

## Impact

- **Depends on**: foundation Watch shell, companion session share, client-training session model in Core
- **Frameworks**: HealthKit, shared App Group session
- **Out of scope**: Appointments on Watch, complications (unless trivial), staff features, storing raw HR samples in the API
