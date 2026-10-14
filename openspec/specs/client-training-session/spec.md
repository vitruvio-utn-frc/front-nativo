# client-training-session Specification

## Purpose

Starts and continues training sessions on iPhone, logs exercise sets/completions, and queues mutations offline for later sync.

## Requirements

### Requirement: Start session from iPhone
The system MUST allow a client to start a training session from iPhone for a selected plan (preferred entry point versus Watch).

#### Scenario: Start session
- **WHEN** the client starts a session from a plan on iPhone
- **THEN** a training session exists in Core/API state and becomes the active session

### Requirement: Log sets and completions
During an active session, the client MUST be able to record exercise sets and completions through Core to the API.

#### Scenario: Complete a set
- **WHEN** the client logs a set for an exercise execution
- **THEN** the set is persisted (immediately or via offline queue)

### Requirement: Offline mutation queue
When the device is offline or a mutation fails due to connectivity, the system MUST enqueue the mutation and flush it when connectivity returns.

#### Scenario: Offline log then sync
- **WHEN** the client logs progress while offline
- **THEN** the action is queued locally and synchronized when the network is available

### Requirement: Active session visible to companion
Core MUST expose active/continuable session state so the Watch companion can attach without Watch Connectivity as the source of truth. iPhone MUST also expose a path from plan session history into session detail for the same client.

#### Scenario: Session readable from Core
- **WHEN** an active session exists after iPhone start
- **THEN** Core exposes that session identity and progress seams to the Watch target

#### Scenario: History entry to session detail
- **WHEN** the client views sessions listed for a plan on iPhone
- **THEN** each session can be opened to inspect progress (read-only for non-active sessions)
