## Why

`front-nativo` is an empty xtool/SwiftUI scaffold while the product must become a native iOS + Apple Watch client for the 2025 backend. Establishing module boundaries, platforms, and shells now prevents a phone-only structure that blocks the Watch companion and later Keycloak/training work.

## What Changes

- Introduce a multi-target Swift package layout: shared Core (iOS + watchOS), iOS app shell, Watch app shell
- Add `watchOS` as a supported platform alongside existing iOS (and keep macOS only if it does not complicate Core; otherwise document exclusion)
- Define App Group / shared container identifiers for future session sharing (no auth implementation in this change)
- Replace the Hello World `ContentView` composition with thin shells that depend on Core
- Document conventions for feature modules so later changes (auth, onboarding, training, Watch workouts) plug in without restructuring
- Spike/validate that xtool (or the chosen build path) can produce a Watch companion target; record the outcome in design

## Capabilities

### New Capabilities

- `shared-core`: Cross-platform shared module (models, networking seams, session/gym context placeholders) usable from iOS and watchOS without UIKit/Watch-only APIs in Core
- `ios-app-shell`: iOS application entry, root composition, and dependency wiring onto Core
- `watch-app-shell`: Independent Watch companion shell (client-oriented), wired to Core, ready for later training/HealthKit features

### Modified Capabilities

- (none — `openspec/specs/` is empty)

## Impact

- **Code**: `Package.swift`, `Sources/` layout, `xtool.yml` / bundle IDs for Watch if required, removal of placeholder-only structure
- **Platforms**: iOS 17+, watchOS (version TBD in design), App Group entitlement readiness
- **Out of scope**: Keycloak auth, onboarding, gym roles UI, training features, HealthKit, API calls to production business endpoints, backend changes (separate repo)
- **Downstream changes**: `auth-keycloak`, `onboarding-profile`, `gym-context-and-roles`, `client-training`, `watch-training-companion`, staff/admin feature changes
