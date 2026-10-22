# client-training-session Specification

## Purpose

Starts and continues training sessions on iPhone, logs exercise sets/completions, and queues mutations offline for later sync.

## Requirements

### Requirement: Start session from iPhone
The system MUST allow a client to start training from iPhone by choosing one of the existing prescribed sessions of a selected plan (preferred entry point versus Watch). The run MUST become the active session immediately but MUST NOT be written to the API until its first exercise is completed; it is then recorded as a new session execution (training session completion) with the start time of the run, linked to that prescribed session, the plan and the client. Starting MUST NOT create a new prescribed session.

#### Scenario: Start session
- **WHEN** the client picks a prescribed session of a plan on iPhone and starts it
- **THEN** that session becomes the active session and nothing is written to the API yet

#### Scenario: First exercise records the run
- **WHEN** the client completes the first exercise of the active session
- **THEN** a training session completion with the real start time of the run exists in Core/API state (or in the offline queue), together with that exercise's completion

#### Scenario: Plan prescription unchanged
- **WHEN** the client starts a session
- **THEN** the plan's list of prescribed sessions is the same as before starting

#### Scenario: Plan without sessions
- **WHEN** the selected plan has no prescribed sessions
- **THEN** iPhone does not offer to start and explains that the trainer has not loaded sessions yet

### Requirement: Log sets and completions
During an active session, the client MUST be able to mark prescribed sets as done and complete prescribed exercises. Marking sets MUST only update on-device progress. Completing an exercise MUST persist an exercise completion linked to the prescribed exercise execution and to the active session completion, with the exercise's real start and end times.

#### Scenario: Complete a set
- **WHEN** the client marks a prescribed set of an exercise as done
- **THEN** the set shows as done in the active session on iPhone and Watch, and nothing is written to the API

#### Scenario: Complete an exercise
- **WHEN** the client completes a prescribed exercise
- **THEN** an exercise completion is persisted (immediately or via offline queue) pointing to that exercise execution and to the active session completion

#### Scenario: Exercise start time
- **WHEN** the client completes an exercise after marking its first set at 10:05
- **THEN** the persisted exercise completion starts at 10:05, not at a fixed offset from the completion time

### Requirement: Offline mutation queue
When the device is offline or a mutation fails due to connectivity, the system MUST enqueue the mutation and flush it in order when connectivity returns. Mutations that depend on a session completion not yet created on the server MUST be queued and sent once its server id is known. A mutation rejected by the API as invalid MUST be dropped and reported instead of blocking the mutations queued after it.

#### Scenario: Offline log then sync
- **WHEN** the client logs progress while offline
- **THEN** the action is queued locally and synchronized when the network is available

#### Scenario: Whole session offline
- **WHEN** the client starts a session, completes two exercises and ends the session while offline
- **THEN** after connectivity returns the API holds one session completion with start and end times and two exercise completions linked to it

#### Scenario: Invalid mutation does not block queue
- **WHEN** a queued mutation is rejected by the API with a non-retryable client error
- **THEN** it is removed from the queue, the client sees an error, and later queued mutations are still sent

### Requirement: Active session visible to companion
Core MUST expose active/continuable session state so the Watch companion can attach without Watch Connectivity as the source of truth. That state MUST include the prescribed session's exercises with their prescribed sets and which sets and exercises are already done. iPhone MUST also expose a path from the plan's training history into session detail for the same client.

#### Scenario: Session readable from Core
- **WHEN** an active session exists after iPhone start
- **THEN** Core exposes that session identity, its prescribed exercises and the done progress to the Watch target

#### Scenario: History entry to session detail
- **WHEN** the client views the training history of a plan on iPhone
- **THEN** each recorded session can be opened to inspect what was done (read-only for non-active sessions)

### Requirement: End session
The client MUST be able to end the active session from iPhone or Watch. Ending MUST persist the end time on the session completion (immediately or via offline queue) and clear the active session on both devices. A session in which no exercise was completed MUST NOT be saved: ending it clears the active session and writes nothing.

#### Scenario: End from iPhone
- **WHEN** the client ends the active session on iPhone
- **THEN** the session completion has an end time and no session is active on iPhone or Watch

#### Scenario: End without completed exercises
- **WHEN** the client ends a session in which no exercise was completed
- **THEN** the active session is cleared on both devices and no training session completion is created

#### Scenario: End with incomplete exercises
- **WHEN** the client ends a session with prescribed exercises not completed
- **THEN** the session ends and only the completed exercises appear in its history

### Requirement: Prescription read-only for clients
The client role MUST NOT create, modify or delete prescribed sessions, exercise executions or prescribed sets, and MUST NOT add exercises outside the prescribed session.

#### Scenario: No add-exercise option
- **WHEN** the client is in an active session
- **THEN** there is no option to add an exercise that is not in the prescribed session
