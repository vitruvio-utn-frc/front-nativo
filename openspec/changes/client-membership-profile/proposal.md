## Why

Clients need to view membership status and manage their profile in the new API (User fields, user-memberships). Payment cards and the mock store from the RN app stay out of scope.

## What Changes

- Show the client’s memberships for the active gym (or linked user-memberships)
- View and edit profile fields owned by the API `User` resource
- Keep payment card CRUD and store/catalog out of scope
- iPhone client shell only

## Capabilities

### New Capabilities

- `client-memberships`: View client membership status in context of the active gym
- `client-profile`: View and update the authenticated user’s profile

### Modified Capabilities

- (none)

## Impact

- **APIs**: `/api/users`, `/api/user-memberships`, `/api/memberships` as needed
- **Depends on**: gym-role-context (client), completed onboarding User
- **Out of scope**: Tarjetas/store/awards, admin membership catalog management
