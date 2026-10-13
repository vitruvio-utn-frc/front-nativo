## Why

After Keycloak login, new users have no API `User` or `Tenant`. The product requires self-registration: collect basic OIDC claims, complete the gym profile, create User + Tenant (`id` = Keycloak `sub`), then wait for admin approval before any gym role exists.

## What Changes

- Detect missing Tenant for the authenticated `sub` and route to onboarding
- Prefill profile fields from Keycloak claims where available
- Collect remaining profile data and create `User` + `Tenant` via API
- Show a pending-approval state when the user has zero `UserGymRole` records
- Allow refresh/retry and logout from pending state
- Do not invent invite codes or public gym join in this change

## Capabilities

### New Capabilities

- `user-onboarding`: First-time profile completion, User/Tenant creation, and pending-approval experience

### Modified Capabilities

- (none)

## Impact

- **APIs used**: `POST /api/users`, `POST /api/tenants`, tenant/user lookup endpoints
- **Depends on**: `auth-keycloak`, foundation shells
- **Unblocks**: `gym-context-and-roles` (once admin assigns roles)
- **Out of scope**: Admin approval UI (in `admin-operations`), role shells, Watch training
