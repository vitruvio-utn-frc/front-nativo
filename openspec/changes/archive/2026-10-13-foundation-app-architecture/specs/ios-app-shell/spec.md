## Purpose

Defines the iPhone application shell that owns process entry, root UI composition, and wiring onto the shared Core for all phone-side features.

## ADDED Requirements

### Requirement: iOS app launches from a dedicated shell
The system MUST provide an iOS application entry that presents a root composition owned by the iOS shell and depends on the shared Core.

#### Scenario: Cold launch shows shell root
- **WHEN** the user launches the iPhone app
- **THEN** the process starts from the iOS app shell and displays its root composition (not an unrelated placeholder outside the module layout)

### Requirement: iOS shell is the composition root for phone features
The iOS app shell MUST be the place where phone feature UI is attached in later changes, without moving Core responsibilities into the shell beyond wiring and presentation.

#### Scenario: Feature attachment point
- **WHEN** a later change adds an iPhone feature screen
- **THEN** that screen is composed from the iOS shell (or a feature module it hosts) while shared logic remains in Core

### Requirement: iOS shell participates in the shared container
The iOS app target MUST be configured to use the project shared container identifier reserved for companion session sharing.

#### Scenario: App Group entitlement on iOS
- **WHEN** the iOS app target entitlements are inspected
- **THEN** the shared container identifier defined for the project is present
