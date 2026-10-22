# Spec Delta

## MODIFIED Requirements

### Requirement: Start session from Watch
When no session is active, the Watch app MUST allow starting a session by choosing a plan and then one of its prescribed sessions (secondary to iPhone). Starting from the Watch MUST record the session the same way as starting from iPhone.

#### Scenario: Start on Watch
- **WHEN** the client picks a plan and a prescribed session on Watch with no active session
- **THEN** Core marks that session active and Watch shows the in-progress UI with the prescribed exercises

#### Scenario: Prescribed sessions identifiable
- **WHEN** the client browses the prescribed sessions of a plan on Watch
- **THEN** each session is shown with a position label and a summary of its exercises so the client can tell them apart

### Requirement: Log progress on Watch
The Watch UI MUST support marking prescribed sets as done and completing prescribed exercises through Core, with the same behavior as iPhone logging (including offline queue behavior). The Watch MUST show each set's prescribed repetitions.

#### Scenario: Log set on Watch
- **WHEN** the client marks a prescribed set as done on Watch
- **THEN** the set shows as done on Watch and iPhone, the same way as iPhone logging

#### Scenario: Complete exercise on Watch
- **WHEN** the client completes an exercise on Watch
- **THEN** an exercise completion is recorded via Core the same way as completing it on iPhone

## ADDED Requirements

### Requirement: Exercise instructions on Watch
During an active session, the Watch MUST list under an "Instrucciones" section every exercise of the session that has an instructions link, and MUST show its content: a playable video for video files, an animated image for GIFs, and a notice that it can only be viewed on iPhone for pages it cannot render. Exercises without a link MUST NOT appear in that section.

#### Scenario: Exercise with a GIF
- **WHEN** the client opens the instructions of an exercise whose link is an animated GIF
- **THEN** the Watch shows the GIF looping

#### Scenario: Exercise with a web page
- **WHEN** the client opens the instructions of an exercise whose link is a web page
- **THEN** the Watch shows that it can only be viewed on iPhone

#### Scenario: Exercise without link
- **WHEN** no exercise of the active session has an instructions link
- **THEN** the "Instrucciones" section is not shown

### Requirement: Return after ending on Watch
When the client ends the active session from the Watch and it ends successfully, the Watch MUST leave the active-session screen and go back to the previous screen. If it cannot be ended, the Watch MUST stay on the active-session screen and show the error.

#### Scenario: End from Watch
- **WHEN** the client ends the session from the active-session screen on Watch
- **THEN** the Watch shows the previous screen with no active session

#### Scenario: iPhone unreachable
- **WHEN** the client taps to end the session but the iPhone cannot be reached
- **THEN** the Watch stays on the active-session screen with an error and the session remains active

