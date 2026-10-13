## Why

Admins operate the gym on iPhone: staff/customers, memberships, machines, appointment schedule, and — critically — assigning `UserGymRole` so self-registered users can leave pending approval. Without this, onboarding cannot complete in production.

## What Changes

- Admin shell features for managing staff and clients in the active gym
- Assign and revoke `UserGymRole` (approve access / change roles)
- Membership catalog management for the gym
- Machines management
- Appointment schedule administration (create/remove slots or appointments as the API supports)
- Exclude RN mock store and awards surfaces

## Capabilities

### New Capabilities

- `admin-user-roles`: Assign/revoke gym roles for users (including approving pending users)
- `admin-directory`: Admin management of staff and clients in the active gym
- `admin-memberships`: Membership catalog administration
- `admin-machines`: Machines administration
- `admin-appointments`: Appointment schedule administration

### Modified Capabilities

- (none)

## Impact

- **APIs**: `/api/user-gym-roles`, users, memberships, gym-memberships, machines, appointments, etc.
- **Depends on**: gym-role-context (admin)
- **Unblocks**: Real end-to-end onboarding (pending → active)
- **Out of scope**: Backend permission engine design, Watch, store/awards
