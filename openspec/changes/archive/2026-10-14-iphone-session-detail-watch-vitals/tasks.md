## 1. Session history detail (iPhone)

- [x] 1.1 Add `TrainingRoute.session(String)` and navigation from plan session list rows; verify tapping a past session opens a detail screen
- [x] 1.2 Implement `ClientTrainingModel.loadSessionDetail(sessionId:)` using `listExecutions` + `listSets` (and `getSession` if useful); verify exercises/sets render for a non-active session
- [x] 1.3 When the selected session id equals the active session, route to interactive `ActiveTrainingSessionView` instead of read-only detail; verify logging still works from that path

## 2. Watch → iPhone vitals pipeline

- [x] 2.1 Add a companion vitals payload (`CompanionWorkoutMetrics` or equivalent fields) and iPhone-side store that does not overwrite training apply; verify encode/decode round-trip
- [x] 2.2 From Watch, throttle-publish HR, elapsed, and active energy while `HKWorkoutSession` is active; verify iPhone store updates when Watch is reachable
- [x] 2.3 Apply staleness/unreachable rules (hide or unavailable after timeout); verify strip clears when Watch stops publishing

## 3. iPhone active-session vitals UI

- [x] 3.1 Add Watch vitals strip to `ActiveTrainingSessionView` (HR, elapsed, active energy when present); verify metrics appear during a live Watch workout and stay omitted/idle when unavailable
- [x] 3.2 Confirm no raw HR series is sent to the training API; verify complete/log requests unchanged aside from any intentional calorie wiring already in scope elsewhere
