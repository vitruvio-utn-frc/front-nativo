## Context

Uses `/api/users` and `/api/user-memberships` (and membership catalog reads). Explicitly excludes RN tarjeta/store flows.

## Goals / Non-Goals

**Goals:** Membership visibility + profile edit.  
**Non-Goals:** Payments, cards, awards, admin catalog edits.

## Decisions

### D1: Profile edits
`PUT /api/users/{id}` with UpdateUserRequest fields; identity email may be read-only if Keycloak is source — prefer API as editable profile store per product decision (identity in KC, profile in API).

### D2: Membership display
Join user-memberships with membership + gym-membership data as needed for names/dates.

## Risks / Trade-offs

- **[Risk] Email divergence KC vs API** → Mitigation: show API profile email; note sync is out of scope

## Open Questions

- None blocking
