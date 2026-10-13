## Why

Client training is a core gym product surface and the preferred place to start a workout session that the Watch companion will continue. The 2025 API models plans, sessions, executions, sets, and completions — the iPhone client must expose these flows before Watch HealthKit work lands.

## What Changes

- Let clients view training plans for the active gym context
- Start a training session from iPhone (preferred entry point)
- Record exercise executions, sets, and completions against the API
- Enqueue mutations when offline and flush when connectivity returns
- Expose enough session state in Core for the Watch companion to attach
- Exclude store/explore mock content and awards

## Capabilities

### New Capabilities

- `client-training-plans`: Browse and open member training plans in the client shell
- `client-training-session`: Start/continue sessions, log sets/completions, offline queue on iPhone

### Modified Capabilities

- (none)

## Impact

- **APIs**: `/api/training-plans`, `/api/training-sessions`, `/api/exercise-executions`, `/api/exercise-sets`, `/api/exercise-completions`, related reads
- **Depends on**: gym-role-context (client role)
- **Unblocks**: `watch-training-companion`
- **Out of scope**: HealthKit, Watch UI, staff plan assignment (staff-operations)
