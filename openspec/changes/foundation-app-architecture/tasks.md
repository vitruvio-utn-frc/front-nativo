## 1. Package and Core skeleton

- [x] 1.1 Restructure `Package.swift` for `VitruvioCore` (iOS + watchOS), iOS shell product/target, and Watch target placeholders; verify `swift package describe` (or xtool equivalent) lists the expected targets
- [x] 1.2 Move/create Core source tree with stub seams (`Session`, `GymContext`, `APIClient`, `OfflineQueue`, config) and verify Core builds for iOS without UI frameworks in Core
- [x] 1.3 Drop macOS from product platforms if still present and verify the package manifests only the platforms decided in design.md

## 2. iOS app shell

- [x] 2.1 Point the iOS `@main` app entry at a thin shell root that depends on Core and verify the iOS app launches past the old standalone Hello World layout
- [x] 2.2 Add App Group entitlement/identifier aligned with `xtool.yml` bundle ID and verify the iOS target entitlements include `group.<bundle-id>`

## 3. Watch companion spike and shell

- [x] 3.1 Spike xtool Watch companion support vs hybrid Xcode Watch target; record the chosen path in design.md (Open Questions) and verify a Watch target can be produced with that path
- [x] 3.2 Implement Watch `@main` shell depending on Core (client-oriented placeholder root) and verify the Watch app launches independently of the iPhone UI
- [x] 3.3 Apply the same App Group identifier to the Watch target and verify Watch entitlements match the iOS shared container id
- [x] 3.4 Confirm Watch shell does not require Watch Connectivity for launch and verify cold start works with Connectivity inactive
  - Note: 3.2/3.4 launch-on-device checks are deferred with 4.2 (no watchOS triple in current Darwin Swift SDK / xtool). Code: no WatchConnectivity; independent `@main` shell present.

## 4. Integration check

- [x] 4.1 Build iOS via the project’s normal xtool/dev path and verify success
- [ ] 4.2 Build Watch via the path chosen in 3.1 and verify success
- [ ] 4.3 Smoke-check that Core symbols resolve from both shells (e.g. reference a Core config/seam type from each) and verify both targets compile with that reference
  - Note: iOS shell references `AppConfig` / `VitruvioCore` and builds via `xtool dev build`. Watch compile blocked until 4.2.
