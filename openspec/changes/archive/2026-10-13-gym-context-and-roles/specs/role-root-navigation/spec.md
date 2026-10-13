## Purpose

Presents iPhone root navigators for client, staff, and admin based on the active gym role, while keeping Watch client-oriented.

## ADDED Requirements

### Requirement: Client root for client role
When the active role is client, the iPhone app MUST present the client root shell.

#### Scenario: Enter client shell
- **WHEN** the active membership role is client
- **THEN** the user sees the client root navigation

### Requirement: Staff root for staff role
When the active role is staff, the iPhone app MUST present the staff root shell.

#### Scenario: Enter staff shell
- **WHEN** the active membership role is staff
- **THEN** the user sees the staff root navigation

### Requirement: Admin root for admin role
When the active role is admin, the iPhone app MUST present the admin root shell.

#### Scenario: Enter admin shell
- **WHEN** the active membership role is admin
- **THEN** the user sees the admin root navigation

### Requirement: Watch remains client-oriented
The Watch app MUST NOT present staff or admin root navigators; it only proceeds with training-capable client context when available.

#### Scenario: Staff user on Watch
- **WHEN** the shared session’s active role is staff or admin and no client membership is active for Watch use
- **THEN** the Watch shell does not show staff/admin operational UI
