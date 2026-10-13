## Context

Depends on `auth-keycloak`. Admin approval assignment is implemented in `admin-operations`. See proposal for motivation.

## Goals / Non-Goals

**Goals:** Tenant/User bootstrap from self-register; pending UI until roles exist.  
**Non-Goals:** Invite codes, public gym join, admin UI, role shells.

## Decisions

### D1: Order of writes
Create User first, then Tenant `{ id: sub, userId, description }`. On failure of Tenant after User create, surface recoverable error and avoid duplicate User when possible (lookup by idNumber/email if API allows).

### D2: Required profile fields
Align with `CreateUserRequest`: idNumber, firstName, lastName, email, height, weight, birthDate, genderId (photo optional). Load genders from `/api/genders`.

### D3: Tenant lookup
Prefer tenants-by-id (`sub`) or by-user after user resolution; exact endpoint usage follows API (`GET /api/tenants/{id}`, `GET /api/tenants/by-user/{userId}`).

### D4: Pending detection
After Tenant exists, load UserGymRoles for user; count == 0 ⇒ pending. No local “pending” flag in API required.

## Risks / Trade-offs

- **[Risk] Duplicate User on retries** → Mitigation: idempotent checks before create
- **[Risk] No admin ever assigns role** → Mitigation: clear pending copy; admin-operations prioritized for E2E

## Open Questions

- (resolved) Tenant `description` defaults to `"keycloak"`.
