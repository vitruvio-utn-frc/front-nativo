## Why

Roles in the 2025 API are per-gym (`UserGymRole`), not a global category. Authenticated users with completed profiles need an active gym + role context and iPhone root navigators for client, staff, and admin — including a multi-role switcher instead of a legacy “super” role.

## What Changes

- Load the user’s gym-role memberships after auth/onboarding
- Persist and expose an active gym + role context in Core
- Present a gym/role picker when the user has multiple memberships
- Mount iPhone root shells for client, staff, and admin based on the active role
- Keep Watch client-only: Watch consumes active client-capable context when present
- Users with zero roles remain on the pending-approval experience from onboarding

## Capabilities

### New Capabilities

- `gym-role-context`: Active gym/role selection, persistence, and multi-membership switching
- `role-root-navigation`: iPhone root navigators for client, staff, and admin shells

### Modified Capabilities

- (none)

## Impact

- **APIs**: `UserGymRole` and related user/gym reads (exact query path may use list endpoints until a “me” API exists)
- **Depends on**: auth, onboarding
- **Unblocks**: all client/staff/admin feature changes
- **Out of scope**: Feature screens inside each shell (separate changes), assigning roles (admin-operations)
