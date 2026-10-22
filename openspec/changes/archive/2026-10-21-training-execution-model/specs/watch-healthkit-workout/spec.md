# Spec Delta

## MODIFIED Requirements

### Requirement: Start HealthKit workout with strength type
When a training session becomes active on Watch, the system MUST start a HealthKit workout of the generic `other` activity type, and the iPhone MUST request the same type when it asks the Watch to start one.

#### Scenario: HK session starts with training
- **WHEN** the client begins an active training session on Watch
- **THEN** a HealthKit workout session of the `other` activity type is started

### Requirement: End workout with session
Ending the training session on Watch, or on iPhone while the Watch workout runs, MUST end and save the HealthKit workout. The workout's accumulated active energy MUST be available to Core for exercise kcal attribution. Raw HR samples MUST NOT be uploaded to the API.

#### Scenario: End session ends HK workout
- **WHEN** the client ends the training session on Watch
- **THEN** the HealthKit workout is stopped and saved, and its active energy has been made available to Core for the exercise completions

#### Scenario: End from iPhone ends HK workout
- **WHEN** the client ends the training session on iPhone while the Watch workout is running
- **THEN** the Watch ends and saves the HealthKit workout

## ADDED Requirements

### Requirement: Link workout to session completion
When saving the HealthKit workout, the Watch MUST write the server id of the session completion into the workout's external identifier metadata if that id is known at that moment. If it is not known, the workout MUST be saved without that metadata; a temporary or made-up id MUST NOT be written.

#### Scenario: Online session
- **WHEN** the session completion was created on the server before the workout is saved
- **THEN** the saved HealthKit workout carries that session completion id as its external identifier

#### Scenario: Offline session
- **WHEN** the session completion is still only queued on the iPhone when the workout is saved
- **THEN** the saved HealthKit workout has no external identifier metadata
