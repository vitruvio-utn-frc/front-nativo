# client-training-plans Specification

## Purpose

Lets clients browse and open their training plans within the active gym context on iPhone.

## Requirements

### Requirement: List member training plans
The client shell MUST list training plans belonging to the authenticated member relevant to the active context.

#### Scenario: Plans visible
- **WHEN** a client with plans opens the training area
- **THEN** their plans are listed

#### Scenario: Empty plans
- **WHEN** the member has no plans
- **THEN** the UI shows an empty state

### Requirement: Open plan detail
The user MUST be able to open a plan to see its structure enough to start or continue training (sessions/exercises as modeled by the API).

#### Scenario: Plan detail
- **WHEN** the user selects a plan
- **THEN** the app shows plan details needed to begin a session
