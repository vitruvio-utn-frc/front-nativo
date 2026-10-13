## Context

See `proposal.md` for motivation. The repo is a native Xcode multi-target app (`vitruvio.xcodeproj`) with three targets: `vitruvio` (iOS), `vitruvio.watch Watch App` (watchOS), and `VitruvioCore` (framework). There is no `Package.swift` / xtool workflow. Downstream product decisions (Keycloak, multi-gym roles, Watch training + HealthKit, offline queue) require Core seams, App Group readiness, and green iOS + Watch builds from day one. Backend auth/JWT work lives outside this repo.

**Reset note (2026-10-13):** Prior task completion assumed an xtool/SwiftPM layout that no longer exists. Foundation is re-applied against the Xcode project; previous `[x]` marks were invalidated.

## Goals / Non-Goals

**Goals:**

- Establish Xcode targets for Core, iOS shell, and Watch shell with Core shared by both apps
- Keep Core compilable on iOS + watchOS with seams for session, gym context, API, offline queue
- Reserve App Group identity for later token/session sharing
- Validate building iOS and Watch via native Xcode schemes

**Non-Goals:**

- Implementing Keycloak, onboarding, role navigators, training, or HealthKit
- Calling business `/api/*` endpoints beyond optional health/ping stubs
- Staff/admin UI on Watch
- Choosing final offline persistence engine (SwiftData vs file queue) beyond a seam

## Decisions

### D1: Module layout

```
vitruvio.xcodeproj
  targets:
    - VitruvioCore              (framework, iOS + watchOS)
    - vitruvio                  (iOS UI shell, links Core)
    - vitruvio.watch Watch App  (watchOS UI shell, links Core; embedded in iOS)
```

**Rationale:** Matches Apple’s native companion layout; keeps UI out of Core; Watch is a first-class Xcode target (no hybrid xtool path).  
**Alternatives:** Single target with `#if os` — rejected (poor Watch isolation). Feature targets per domain now — deferred until auth/training exist to avoid empty frameworks. SwiftPM `Package.swift` — rejected; project is full Xcode.

Feature UI for later changes may live under `vitruvio/...` (or new feature frameworks); Core stays free of screens.

### D2: Platform support

- **iOS:** project baseline `IPHONEOS_DEPLOYMENT_TARGET = 18.2`.
- **watchOS:** project baseline `WATCHOS_DEPLOYMENT_TARGET = 11.2` (SwiftUI `App` lifecycle).
- **macOS / visionOS:** drop from `SUPPORTED_PLATFORMS` on product/Core targets unless a concrete need appears — reduces `#if` noise for a gym phone+watch product.

### D3: App Group

- Identifier: `group.com.santiago-alvarado.vitruvio` (pattern `group.<ios-bundle-id>`).
- iOS and Watch entitlements both include it in this change; no Keychain access-group wiring beyond what’s needed to declare the group (full Keychain sharing lands in `auth-keycloak`).

### D4: Core seams (stubs OK)

Named areas inside Core (folders or small types), implementations can be no-ops:

| Seam | Later owner change |
|------|--------------------|
| `Session` / auth token store | `auth-keycloak` |
| `GymContext` | `gym-context-and-roles` |
| `APIClient` / base URL config | auth + features |
| `OfflineQueue` | `watch-training-companion` / `client-training` |

No SwiftUI Views in Core.

### D5: Shell UX for this change only

- iOS: minimal root acknowledging the app shell (replace SwiftData template / Hello World).
- Watch: minimal client-oriented root (placeholder for training later).
- No role-based tabs yet.

### D6: Build path (Xcode native)

Build and run exclusively via Xcode / `xcodebuild` schemes:

- `vitruvio` — iOS app (embeds Watch content)
- `vitruvio.watch Watch App` — Watch app
- `VitruvioCore` — shared framework

`VitruvioCore` MUST include watchOS in `SUPPORTED_PLATFORMS` so the Watch target can link it. Both app targets MUST have an explicit target dependency + framework link on Core.

### D7: Watch Connectivity

Optional dependency later for optimization only. Foundation MUST NOT make WCSession the data backbone (aligned with Watch shell spec).

### D8: Configuration

Centralize API base URL and Keycloak placeholders in Core config (compile-time or plist-backed), even if unused until auth — avoids hardcoding in shells.

## Risks / Trade-offs

- **[Risk] Core not built for watchOS** → Mitigation: set Core `SUPPORTED_PLATFORMS` to include `watchos` / `watchsimulator`; verify Watch scheme links Core.
- **[Risk] Over-structuring empty seams** → Mitigation: seams are thin stubs/folders only; no speculative frameworks.
- **[Risk] Bundle ID / App Group mismatch with Apple Developer portal** → Mitigation: use `com.santiago-alvarado.vitruvio` as source of truth; create App Group in the team account before device runs.
- **[Trade-off] Dropping macOS/visionOS** → Less casual desktop/spatial run; clearer phone+watch focus.

## Migration Plan

1. Complete Core seams + enable watchOS on Core; link from both shells.
2. Add App Group entitlements to iOS and Watch.
3. Replace template shell UI; smoke-check Core symbols from both apps.
4. Verify `xcodebuild` success for iOS and Watch schemes.
5. No data migration (greenfield app). Rollback: revert project/source commits; no server coupling.

## Open Questions

- (resolved) watchOS deployment version: **watchOS 11.2** (Xcode project baseline).
- (resolved) packaging path: **full native Xcode** — iOS + Watch + Core in `vitruvio.xcodeproj`. xtool / SwiftPM are out of scope.
