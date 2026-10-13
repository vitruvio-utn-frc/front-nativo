## 1. Watch training UI

- [ ] 1.1 Continue an iPhone-started active session on Watch and verify exercise/set progress renders
- [ ] 1.2 Start a session from Watch when none is active and verify Core active session updates
- [ ] 1.3 Log sets/completions from Watch through Core/offline queue and verify sync when online

## 2. HealthKit

- [ ] 2.1 Request HealthKit workout + heart-rate authorization and verify denied state still allows logging without HR
- [ ] 2.2 Start/stop `traditionalStrengthTraining` HK workout with session lifecycle and verify HK session ends when training ends
- [ ] 2.3 Display live HR during workout when available and verify UI updates with samples

## 3. Guardrails

- [ ] 3.1 Confirm no staff/admin Watch destinations and verify navigation remains client-training only
- [ ] 3.2 Confirm Watch Connectivity is not required for session progress sync and verify URLSession/Core path works with Connectivity off
