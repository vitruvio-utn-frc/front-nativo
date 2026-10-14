## 0. Blocker

- [ ] 0.1 **Backend ready:** migration + API expose `createdAt`, session (and/or completion) `caloriesBurnedInTotal` + `healthKitWorkoutId`; verify with GET/POST against a running API before any client work

## 1. Backend (vitruvio-backend-2025)

- [ ] 1.1 Add `CreatedAt` to `TrainingSession`, set on create, order list by `CreatedAt` desc; verify new sessions return the field
- [ ] 1.2 Add `CaloriesBurnedInTotal` + `HealthKitWorkoutId` to session and/or completion create/update; verify persist + GET round-trip
- [ ] 1.3 Ship/apply migration to the environments the app uses; verify migrate succeeds

## 2. Client (only after 0.1)

- [ ] 2.1 Decode new fields on `TrainingSessionDTO` / completion DTOs and sort `listSessions` by `createdAt`; verify list order
- [ ] 2.2 On Watch end: pass calories + HK workout UUID; iPhone persists via API then clears active session; verify GET shows values
- [ ] 2.3 Show date, calories, workout id in plan session list + session detail; verify UI with a completed Watch workout
