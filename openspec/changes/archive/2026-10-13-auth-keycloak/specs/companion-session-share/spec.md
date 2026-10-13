## Purpose

Shares the iPhone Keycloak session with the Watch companion through the project shared container so Watch can call the API independently.

## ADDED Requirements

### Requirement: iPhone publishes session to shared container
After a successful iPhone login or token refresh, the system MUST write the session material needed for API auth into the shared App Group / Keychain access group used by the companion.

#### Scenario: Session available after login
- **WHEN** the user signs in on iPhone
- **THEN** the Watch app can read a usable access token (or refresh capability) from the shared container without requiring Watch Connectivity

### Requirement: Watch consumes shared session
The Watch app MUST use the shared session for Core API authorization when present.

#### Scenario: Watch authorized with shared token
- **WHEN** a valid shared session exists and the Watch makes an API call through Core
- **THEN** the request is authorized with that session’s access token

### Requirement: Logout clears shared session
iPhone logout MUST remove shared session material so the Watch can no longer authorize as that user.

#### Scenario: Shared session cleared on logout
- **WHEN** the user signs out on iPhone
- **THEN** shared session material is deleted and Watch API calls are unauthenticated until a new login
