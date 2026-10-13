## Purpose

Lets admins administer the appointment schedule for the active gym (create and remove appointments/slots as the API supports).

## ADDED Requirements

### Requirement: List gym appointments
Admins MUST be able to list appointments for the active gym.

#### Scenario: Schedule list
- **WHEN** an admin opens appointment administration
- **THEN** appointments for the active gym are shown

### Requirement: Create appointments
Admins MUST be able to create appointments/slots for the active gym.

#### Scenario: Create slot
- **WHEN** an admin creates an appointment with schedule fields
- **THEN** it appears on the gym schedule

### Requirement: Delete appointments
Admins MUST be able to delete appointments for the active gym when permitted.

#### Scenario: Delete appointment
- **WHEN** an admin deletes an appointment
- **THEN** it is removed from the schedule
