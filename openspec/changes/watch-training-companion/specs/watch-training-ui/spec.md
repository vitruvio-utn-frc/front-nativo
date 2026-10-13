## Purpose

Provides Watch UI for clients to run and continue training sessions and see exercise/set progress using shared Core state.

## ADDED Requirements

### Requirement: Continue active session on Watch
When an active training session exists in Core, the Watch app MUST allow the client to continue it and view current exercise progress.

#### Scenario: Continue from iPhone-started session
- **WHEN** a session was started on iPhone and is active
- **THEN** the Watch can open that session and show exercise/set progress

### Requirement: Start session from Watch
When no session is active, the Watch app MUST allow starting a session for an available plan (secondary to iPhone).

#### Scenario: Start on Watch
- **WHEN** the client starts a session on Watch with no active session
- **THEN** Core marks that session active and Watch shows the in-progress UI

### Requirement: Log progress on Watch
The Watch UI MUST support logging set/completion progress through Core (including offline queue behavior).

#### Scenario: Log set on Watch
- **WHEN** the client completes a set on Watch
- **THEN** progress is recorded via Core the same way as iPhone logging

### Requirement: Client only
The Watch training UI MUST be available only for client training use and MUST NOT expose staff/admin operations.

#### Scenario: No admin tools
- **WHEN** the user inspects Watch navigation for this capability
- **THEN** staff/admin management destinations are absent
