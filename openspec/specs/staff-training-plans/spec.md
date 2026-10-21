# staff-training-plans Specification

## Purpose

Lets staff create and edit member training plans and their structure so clients can execute them on iPhone/Watch.

## Requirements

### Requirement: Create training plan for member
Staff MUST be able to create a training plan for a client member.

#### Scenario: Plan created
- **WHEN** staff creates a plan for a member with required fields
- **THEN** the plan is persisted and associated with that member

### Requirement: Edit plan structure
Staff MUST be able to add or update plan structure (sessions/exercises/sets as supported by the API model).

#### Scenario: Add exercise structure
- **WHEN** staff adds an exercise execution/set structure to a plan’s session
- **THEN** the changes are persisted for client execution later

### Requirement: Active gym scoping
Staff plan operations MUST run in the active gym context for member selection.

#### Scenario: Members from active gym
- **WHEN** staff picks a member for a plan
- **THEN** selectable members are those available in the active gym context
