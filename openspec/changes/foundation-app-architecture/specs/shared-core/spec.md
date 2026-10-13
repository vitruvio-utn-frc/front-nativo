## Purpose

Defines the shared cross-platform core that iOS and watchOS clients use for domain seams, configuration, and future session/API work without embedding screen UI.

## ADDED Requirements

### Requirement: Core is shareable across iPhone and Watch
The system MUST provide a shared Core module that compiles for iOS and watchOS and exposes no screen-level UI.

#### Scenario: Core builds for both platforms
- **WHEN** the package is built for iOS and for watchOS
- **THEN** the shared Core module compiles successfully on both platforms

#### Scenario: Core excludes screen UI
- **WHEN** a consumer inspects the shared Core public surface
- **THEN** Core MUST NOT require SwiftUI app screens or platform-only UI frameworks to link for basic compilation

### Requirement: Core reserves seams for session, gym context, networking, and offline work
The shared Core MUST expose clear extension points (types or modules) for authentication/session, active gym context, HTTP API access, and offline mutation queuing, even if implementations are stubs in this change.

#### Scenario: Seams exist for downstream features
- **WHEN** a later feature change needs session, gym context, API client, or offline queue integration
- **THEN** it can depend on named Core seams without restructuring the package layout

### Requirement: Shared container identity is defined
The system MUST define a single App Group (or equivalent shared container) identifier for future secure sharing of session material between the iPhone app and the Watch app.

#### Scenario: Identifier is documented and consistent
- **WHEN** iOS and Watch targets are configured
- **THEN** both reference the same shared container identifier defined for the project
