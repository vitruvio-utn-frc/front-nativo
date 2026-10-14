## MODIFIED Requirements

### Requirement: Active session visible to companion
Core MUST expose active/continuable session state so the Watch companion can attach without Watch Connectivity as the source of truth. iPhone MUST also expose a path from plan session history into session detail for the same client.

#### Scenario: Session readable from Core
- **WHEN** an active session exists after iPhone start
- **THEN** Core exposes that session identity and progress seams to the Watch target

#### Scenario: History entry to session detail
- **WHEN** the client views sessions listed for a plan on iPhone
- **THEN** each session can be opened to inspect progress (read-only for non-active sessions)
