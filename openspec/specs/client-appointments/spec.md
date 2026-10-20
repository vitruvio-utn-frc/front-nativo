# client-appointments Specification

## Purpose

Lets clients browse, book, and cancel appointments in their active gym on iPhone.

## Requirements

### Requirement: List appointments for member
The client shell MUST list the member’s appointments relevant to the active gym.

#### Scenario: Upcoming appointments shown
- **WHEN** a client opens appointments
- **THEN** their appointments for the active gym context are displayed

### Requirement: Book an appointment
When booking is available, the client MUST be able to book an appointment for themselves in the active gym.

#### Scenario: Successful booking
- **WHEN** the client books an available appointment
- **THEN** the appointment is associated with the member and appears in their list

### Requirement: Cancel own appointment
The client MUST be able to cancel their own cancellable appointment.

#### Scenario: Cancel
- **WHEN** the client cancels their appointment
- **THEN** the appointment is no longer active in their list

### Requirement: Active gym scoping
Appointment operations MUST use the active gym context and MUST NOT silently act on another gym.

#### Scenario: Gym scoped list
- **WHEN** the active gym changes
- **THEN** the appointments list refreshes for the new gym context
