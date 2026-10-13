## 1. Xcode targets and Core skeleton

- [x] 1.1 Confirm `vitruvio.xcodeproj` has `VitruvioCore`, `vitruvio` (iOS), and `vitruvio.watch Watch App` targets/schemes; enable Core for iOS + watchOS (`SUPPORTED_PLATFORMS`) and verify `xcodebuild -list` shows all three
- [x] 1.2 Create Core Swift source tree with stub seams (`Session`, `GymContext`, `APIClient`, `OfflineQueue`, config) and verify Core builds for iOS without UI frameworks in Core
- [x] 1.3 Drop macOS/visionOS from product/Core `SUPPORTED_PLATFORMS` if present and verify platforms match design.md (iOS + watchOS only)

## 2. iOS app shell

- [x] 2.1 Point the iOS `@main` app entry at a thin shell root that depends on Core (remove SwiftData template / Hello World as the product root) and verify the iOS app launches past the template layout
- [x] 2.2 Add App Group entitlement `group.com.santiago-alvarado.vitruvio` to the iOS target and verify entitlements include that identifier

## 3. Watch companion shell

- [x] 3.1 Record native Xcode Watch packaging as the chosen path in design.md and verify the Watch target exists and is embedded by the iOS app
- [x] 3.2 Implement Watch `@main` shell depending on Core (client-oriented placeholder root) with target dependency + framework link; verify the Watch app can build/launch independently of iPhone UI code
- [x] 3.3 Apply the same App Group identifier to the Watch target and verify Watch entitlements match the iOS shared container id
- [x] 3.4 Confirm Watch shell does not require Watch Connectivity for launch and verify cold start structure works with Connectivity inactive

## 4. Integration check

- [x] 4.1 Build iOS via `xcodebuild` scheme `vitruvio` and verify success
- [x] 4.2 Build Watch via `xcodebuild` scheme `vitruvio.watch Watch App` and verify success
- [x] 4.3 Smoke-check that Core symbols resolve from both shells (e.g. reference a Core config/seam type from each) and verify both targets compile with that reference
