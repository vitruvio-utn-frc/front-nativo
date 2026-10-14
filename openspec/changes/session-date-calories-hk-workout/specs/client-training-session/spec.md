## MODIFIED Requirements

### Requirement: Start session from iPhone
The system MUST allow a client to start a training session from iPhone for a selected plan (preferred entry point versus Watch). Started sessions MUST receive a server creation timestamp usable for later history ordering.

#### Scenario: Start session
- **WHEN** the client starts a session from a plan on iPhone
- **THEN** a training session exists in Core/API state and becomes the active session

#### Scenario: Created timestamp available
- **WHEN** a session is created via the API
- **THEN** clients can read a creation timestamp for that session
