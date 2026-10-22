# Spec Delta

## MODIFIED Requirements

### Requirement: Open session detail from plan history
From a plan's training history on iPhone, the client MUST be able to open a recorded session (training session completion) and see what was done, loaded through Core/API: date, duration, completed exercises with their times and kcal, and total kcal. The history MUST only list the signed-in client's own sessions, newest first.

#### Scenario: Drill into past session
- **WHEN** the client selects an entry in a plan's training history
- **THEN** iPhone shows that session's date, duration, completed exercises with kcal and the total kcal (read-only when the session is not the active session)

#### Scenario: History ordered by date
- **WHEN** the client has trained a plan on Monday and on Wednesday
- **THEN** the Wednesday session is listed before the Monday one

#### Scenario: Prescribed sessions are not history
- **WHEN** the plan has prescribed sessions that the client never trained
- **THEN** they do not appear in the training history

### Requirement: Active session remains interactive
If the selected session is the current active session, the system MUST continue to allow logging and completion actions (existing active-session behavior), not force a read-only mode.

#### Scenario: Open active session from list
- **WHEN** the client opens the currently active session from the plan's training history
- **THEN** the interactive active-session UI is shown (or navigates to it) rather than a locked read-only copy
