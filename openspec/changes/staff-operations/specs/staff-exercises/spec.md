## Purpose

Lets staff manage the exercise catalog used in training plans for the gym product on iPhone.

## ADDED Requirements

### Requirement: List exercises
Staff MUST be able to list exercises available for training planning.

#### Scenario: Exercise list
- **WHEN** staff opens exercises
- **THEN** exercises are listed

### Requirement: Create and update exercises
Staff MUST be able to create and update exercises when permitted.

#### Scenario: Create exercise
- **WHEN** staff submits a valid new exercise
- **THEN** the exercise is persisted via the API

### Requirement: Delete exercise
Staff MUST be able to delete an exercise when permitted by the API.

#### Scenario: Delete exercise
- **WHEN** staff deletes an exercise
- **THEN** the exercise no longer appears in the list
