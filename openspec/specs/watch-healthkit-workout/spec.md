# watch-healthkit-workout Specification

## Purpose

Runs HealthKit workout sessions during client training on Watch and surfaces heart-rate and workout metrics while keeping raw HR out of the business API.

## Requirements

### Requirement: Start HealthKit workout with strength type
When a training session becomes active on Watch, the system MUST start a HealthKit workout using `traditionalStrengthTraining` (or the project’s configured strength type).

#### Scenario: HK session starts with training
- **WHEN** the client begins an active training session on Watch
- **THEN** a HealthKit workout session of the strength training type is started

### Requirement: Show live heart rate
During an active HealthKit workout, the Watch UI MUST display live heart-rate data when available from HealthKit. While the workout is active, the Watch MUST also publish companion-safe vitals (current heart rate when available, elapsed workout time, and active energy when available) to the iPhone over Watch Connectivity on a throttled cadence so the phone can display them during the active training session.

#### Scenario: HR visible during workout
- **WHEN** heart-rate samples are available during the workout
- **THEN** the Watch training UI shows the current heart rate

#### Scenario: Vitals published to iPhone
- **WHEN** a HealthKit strength workout is running for the active training session
- **THEN** the Watch periodically delivers current HR (if available), elapsed duration, and active energy (if available) to the paired iPhone companion without uploading raw HR samples to the business API

### Requirement: End workout with session
Ending or completing the training session on Watch MUST end the HealthKit workout and MAY contribute duration/calories to API completions without uploading raw HR samples to the API.

#### Scenario: End session ends HK workout
- **WHEN** the client ends the training session on Watch
- **THEN** the HealthKit workout is stopped and completion metrics usable by Core may include duration/calories

### Requirement: HealthKit authorization
The system MUST request HealthKit authorization required for workout and heart-rate before starting a workout, and fail gracefully if denied.

#### Scenario: Auth denied
- **WHEN** the user denies HealthKit authorization
- **THEN** training progress logging can still proceed without live HR, and the UI indicates HR is unavailable
