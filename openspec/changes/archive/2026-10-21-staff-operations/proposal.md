## Why

Staff (trainers) need iPhone tools to work with clients and training content in the active gym: see members, manage exercises, and assign/maintain training plans — parity with the RN staff role, remapped to the 2025 domain.

## What Changes

- Staff shell features for listing clients in the active gym
- Exercise catalog management appropriate to staff permissions
- Create/update training plans for members and structure sessions/exercises
- No Watch staff UI; no admin-only gym configuration

## Capabilities

### New Capabilities

- `staff-clients`: Staff view of clients in the active gym
- `staff-exercises`: Staff exercise catalog operations
- `staff-training-plans`: Staff assignment and editing of member training plans

### Modified Capabilities

- (none)

## Impact

- **APIs**: users/user-gym-roles scoped to gym, `/api/exercises`, `/api/training-plans`, related session/template endpoints as needed
- **Depends on**: gym-role-context (staff)
- **Out of scope**: Approving new users / assigning roles (admin), machines catalog if admin-owned, Watch
