## Purpose

Persists training session timestamps and Apple Watch HealthKit workout summary fields (calories and workout id) so iPhone history can sort and display them from the API.

## ADDED Requirements

### Requirement: Session has a creation timestamp
Each training session MUST have a server-assigned creation timestamp exposed to clients for ordering history.

#### Scenario: New session has createdAt
- **WHEN** a training session is created
- **THEN** the API response includes a `createdAt` (or equivalent) timestamp

### Requirement: Persist Watch workout summary on session end
When a client ends a training session and a Watch HealthKit workout was finished for that session, the system MUST persist total active energy (calories) and the HealthKit workout identifier on the server.

#### Scenario: End with HK workout
- **WHEN** the Watch finishes an HK workout and the session is ended with calories and/or workout id
- **THEN** subsequent GET of that training session includes those persisted values

### Requirement: History ordered by date
The client session list for a plan MUST present sessions ordered by session date (newest first) using the server timestamp.

#### Scenario: Plan session list
- **WHEN** the client loads sessions for a plan
- **THEN** sessions are ordered by `createdAt` descending
