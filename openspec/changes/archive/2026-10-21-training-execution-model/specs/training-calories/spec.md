# Spec Delta

## Purpose

Defines how the calories of a client training session are obtained (measured by the Apple Watch or estimated from exercise data), attributed per completed exercise, and shown in history.

## ADDED Requirements

### Requirement: Measured calories per exercise
When a HealthKit workout is running on the Watch for the active training session and its active energy is available and recent, the kcal recorded for a completed exercise MUST be the active energy accumulated between that exercise's start and its completion.

#### Scenario: Exercise completed with Watch running
- **WHEN** the client completes an exercise while the Watch workout reports recent active energy
- **THEN** the persisted exercise completion carries the active energy accumulated during that exercise as its kcal

#### Scenario: Consecutive exercises do not double count
- **WHEN** the client completes two exercises in a row with the Watch running
- **THEN** each completion carries only the energy accumulated during its own interval

### Requirement: Estimated calories without Watch
When measured energy is not available for an exercise, the system MUST estimate its kcal as the exercise's calorie burn rate (kcal per repetition) multiplied by the total prescribed repetitions of that exercise execution. If the rate or prescribed repetitions are missing, the estimate MUST be 0.

#### Scenario: No Watch paired
- **WHEN** the client completes an exercise with burn rate 0.5 and prescribed sets of 10, 10 and 8 reps, without Watch metrics
- **THEN** the persisted exercise completion carries 14 kcal

#### Scenario: Missing rate
- **WHEN** the completed exercise has no burn rate or no prescribed sets
- **THEN** the persisted exercise completion carries 0 kcal

### Requirement: Calorie source kept on device
The system MUST remember on the device whether each exercise completion's kcal was measured or estimated, and MUST NOT send that flag to the API.

#### Scenario: Source shown in history on same device
- **WHEN** the client opens a past session on the device that recorded it
- **THEN** each exercise's kcal is labeled as measured or estimated

#### Scenario: Source unknown elsewhere
- **WHEN** the client opens a past session on a device that did not record it
- **THEN** kcal are shown without a measured/estimated label

### Requirement: Session total calories
The total kcal of a training session MUST be the sum of the kcal of its exercise completions.

#### Scenario: Total in history
- **WHEN** the client views a completed session with exercise completions of 42, 55 and 33 kcal
- **THEN** the session shows 130 kcal in total
