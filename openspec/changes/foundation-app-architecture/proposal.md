## Why

The product must be a native iOS + Apple Watch client for the 2025 backend. The repo is now a full Xcode project (`vitruvio.xcodeproj`) with iOS app, Watch app, and `VitruvioCore` framework targets — not xtool/SwiftPM. Establishing module boundaries, platforms, and thin shells on that layout prevents a phone-only structure that blocks the Watch companion and later Keycloak/training work.

## What Changes

- Wire and complete the Xcode multi-target layout: shared `VitruvioCore` (iOS + watchOS), iOS app shell (`vitruvio`), Watch app shell (`vitruvio.watch Watch App`)
- Support iOS + watchOS for Core and product apps; drop macOS/visionOS from product platforms unless a concrete need appears
- Define App Group / shared container identifiers for future session sharing (no auth implementation in this change)
- Replace template Hello World / SwiftData placeholder composition with thin shells that depend on Core
- Document conventions for feature modules so later changes (auth, onboarding, training, Watch workouts) plug in without restructuring
- Validate that both iOS and Watch schemes build successfully under native Xcode (no xtool)

## Capabilities

### New Capabilities

- `shared-core`: Cross-platform shared module (models, networking seams, session/gym context placeholders) usable from iOS and watchOS without UIKit/Watch-only APIs in Core
- `ios-app-shell`: iOS application entry, root composition, and dependency wiring onto Core
- `watch-app-shell`: Independent Watch companion shell (client-oriented), wired to Core, ready for later training/HealthKit features

### Modified Capabilities

- (none — `openspec/specs/` is empty)

## Impact

- **Code**: `vitruvio.xcodeproj` targets/schemes, `VitruvioCore/` sources, `vitruvio/` and `vitruvio.watch Watch App/` shells, entitlements for App Group
- **Platforms**: iOS 18.2+ (project baseline), watchOS 11.2+ (project baseline), App Group entitlement readiness
- **Out of scope**: Keycloak auth, onboarding, gym roles UI, training features, HealthKit, API calls to production business endpoints, backend changes (separate repo)
- **Downstream changes**: `auth-keycloak`, `onboarding-profile`, `gym-context-and-roles`, `client-training`, `watch-training-companion`, staff/admin feature changes
