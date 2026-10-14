## MODIFIED Requirements

### Requirement: Show live heart rate
During an active HealthKit workout, the Watch UI MUST display live heart-rate data when available from HealthKit. While the workout is active, the Watch MUST also publish companion-safe vitals (current heart rate when available, elapsed workout time, and active energy when available) to the iPhone over Watch Connectivity on a throttled cadence so the phone can display them during the active training session.

#### Scenario: HR visible during workout
- **WHEN** heart-rate samples are available during the workout
- **THEN** the Watch training UI shows the current heart rate

#### Scenario: Vitals published to iPhone
- **WHEN** a HealthKit strength workout is running for the active training session
- **THEN** the Watch periodically delivers current HR (if available), elapsed duration, and active energy (if available) to the paired iPhone companion without uploading raw HR samples to the business API
