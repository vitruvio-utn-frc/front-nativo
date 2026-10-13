## Context

See `proposal.md` for motivation. Today `front-nativo` is a single-library xtool SwiftPM app (`Package.swift` product `vitruvio`, iOS 17 / macOS 14) with Hello World sources only. Downstream product decisions (Keycloak, multi-gym roles, Watch training + HealthKit, offline queue) require a multi-target layout from day one. Backend auth/JWT work lives outside this repo.

## Goals / Non-Goals

**Goals:**

- Establish SPM targets/products for Core, iOS shell, and Watch shell
- Keep Core compilable on iOS + watchOS with seams for session, gym context, API, offline queue
- Reserve App Group identity for later token/session sharing
- Validate (or document fallback for) building a Watch companion with the current xtool workflow

**Non-Goals:**

- Implementing Keycloak, onboarding, role navigators, training, or HealthKit
- Calling business `/api/*` endpoints beyond optional health/ping stubs
- Staff/admin UI on Watch
- Choosing final offline persistence engine (SwiftData vs file queue) beyond a seam

## Decisions

### D1: Module layout

```
Package.swift
  products:
    - library VitruvioCore
    - library vitruvio          (iOS app library for xtool, if still required)
    - library VitruvioWatch     (Watch app library / target as tooling allows)
  targets:
    - VitruvioCore     (iOS + watchOS)
    - vitruvio         (iOS UI shell, depends on Core)
    - VitruvioWatch    (watchOS UI shell, depends on Core)
```

**Rationale:** Matches the explored “structured from day 1 + Watch companion” constraint; keeps UI out of Core.  
**Alternatives:** Single target with `#if os` — rejected (poor Watch isolation). Feature targets per domain now — deferred until auth/training exist to avoid empty packages.

Feature UI for later changes may live under `Sources/vitruvio/...` or new feature libraries; Core stays free of screens.

### D2: Platform support

- **iOS:** keep `.v17` (current scaffold).
- **watchOS:** add a modern baseline compatible with SwiftUI `App` lifecycle (prefer watchOS 10+ unless xtool forces otherwise); record exact version after the build spike.
- **macOS:** drop from Core/app products unless a concrete need appears — reduces `#if` noise for a gym phone+watch product.

**Alternatives:** Keep macOS “for free” — low value for this product, extra surface.

### D3: App Group

- Identifier pattern: `group.<ios-bundle-id>` (e.g. `group.com.santiago-alvarado.vitruvio`) unless Apple team conventions require otherwise.
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

- iOS: minimal root acknowledging the app shell (can replace Hello World copy).
- Watch: minimal client-oriented root (placeholder for training later).
- No role-based tabs yet.

### D6: xtool + Watch packaging

xtool today expects one main library product for the iOS app. Watch may require:

1. **Preferred:** xtool multi-target / companion support if available — use it.
2. **Fallback:** keep iOS on xtool; add Watch via documented Xcode/SPM companion setup, still sharing `VitruvioCore` from the same package.

This change includes a short spike task; design outcome must be noted in tasks completion notes or a brief addendum in this file if the fallback is chosen.

### D7: Watch Connectivity

Optional dependency later for optimization only. Foundation MUST NOT make WCSession the data backbone (aligned with Watch shell spec).

### D8: Configuration

Centralize API base URL and Keycloak placeholders in Core config (compile-time or plist-backed), even if unused until auth — avoids hardcoding in shells.

## Risks / Trade-offs

- **[Risk] xtool lacks first-class Watch companions** → Mitigation: spike early; fallback to hybrid Xcode Watch target + shared Core.
- **[Risk] Over-structuring empty seams** → Mitigation: seams are thin stubs/folders only; no speculative frameworks.
- **[Risk] Bundle ID / App Group mismatch with Apple Developer portal** → Mitigation: use current `xtool.yml` bundle ID as source of truth; create App Group in the team account before device runs.
- **[Trade-off] Dropping macOS** → Less casual desktop run; clearer phone+watch focus.

## Migration Plan

1. Restructure `Sources/` and `Package.swift` on a branch.
2. Confirm iOS still builds via existing xtool path.
3. Complete Watch spike; land either xtool Watch or hybrid fallback.
4. No data migration (greenfield app).
5. Rollback: revert package layout commit; no server coupling.

## Open Questions

- (resolved) watchOS deployment version: **watchOS 10** in `Package.swift`.
- (resolved) xtool Watch packaging: **hybrid fallback**. xtool 1.21 builds the iOS product (`vitruvio`) and Appex-style `extensions`; it does not ship a first-class Watch companion product. Watch sources live in `VitruvioWatch` + `Watch.entitlements` / `Watch-Info.plist` in this package; device packaging uses Xcode (or future xtool Watch support) while sharing `VitruvioCore`. iOS continues on `xtool dev`.
