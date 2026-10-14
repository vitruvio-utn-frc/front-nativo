# iphone-session-history Specification

## Purpose

Lets clients open a training session from plan history on iPhone and inspect exercise executions and sets in a read-only detail view.

## Requirements

### Requirement: Open session detail from plan history
From a plan’s session list on iPhone, the client MUST be able to open a session and see its exercise/set progress loaded through Core/API.

#### Scenario: Drill into past session
- **WHEN** the client selects a session row in a plan’s session list
- **THEN** iPhone shows that session’s exercises and logged sets (read-only when the session is not the active session)

### Requirement: Active session remains interactive
If the selected session is the current active session, the system MUST continue to allow logging and completion actions (existing active-session behavior), not force a read-only mode.

#### Scenario: Open active session from list
- **WHEN** the client opens the currently active session from the plan session list
- **THEN** the interactive active-session UI is shown (or navigates to it) rather than a locked read-only copy
