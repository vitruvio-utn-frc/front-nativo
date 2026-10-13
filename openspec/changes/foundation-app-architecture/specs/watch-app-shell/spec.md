## Purpose

Defines the independent Apple Watch companion shell for client-oriented use, wired to shared Core and ready for later training and HealthKit features.

## ADDED Requirements

### Requirement: Watch app launches as an independent companion shell
The system MUST provide a watchOS application entry that launches independently of the iPhone UI process and depends on the shared Core.

#### Scenario: Cold launch on Watch
- **WHEN** the user opens the Watch app
- **THEN** the Watch process starts from the Watch app shell and displays its root composition

### Requirement: Watch shell is client-oriented and training-ready
The Watch app shell MUST be scoped as a client companion surface (not staff/admin navigation) and MUST provide a composition root for later training/workout UI.

#### Scenario: No staff or admin roots on Watch
- **WHEN** the Watch shell root navigation is inspected
- **THEN** it MUST NOT present staff or admin role shells as primary destinations

#### Scenario: Training attachment point exists
- **WHEN** a later change adds Watch training UI
- **THEN** that UI can be attached from the Watch shell without restructuring Core module boundaries

### Requirement: Watch shell participates in the shared container
The Watch app target MUST be configured to use the same shared container identifier as the iPhone app for future session sharing.

#### Scenario: App Group entitlement on Watch
- **WHEN** the Watch app target entitlements are inspected
- **THEN** the shared container identifier defined for the project is present

### Requirement: Watch Connectivity is not the primary data path
The Watch shell MUST NOT treat Watch Connectivity as the sole or primary source of truth for domain data; network/API access via Core remains the intended primary path for later features.

#### Scenario: Shell does not require phone reachability for structure
- **WHEN** the Watch app launches without an active Watch Connectivity session
- **THEN** the shell still launches and presents its root composition
