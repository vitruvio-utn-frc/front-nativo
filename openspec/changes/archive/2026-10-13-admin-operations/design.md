## Context

Admin shell from gym-context. Critical path for onboarding: `admin-user-roles` must ship for pending users to become active. Remaps RN admin tabs to 2025 resources.

## Goals / Non-Goals

**Goals:** Role assignment, directories, memberships, machines, appointment schedule.  
**Non-Goals:** Store/awards, Watch, backend permission seeding (coordinate outside).

## Decisions

### D1: Approval UX
Primary admin flow: pick user → assign role+gym (active gym default) → optional note. No separate “Pending” entity; detect users with Tenant but no roles when list APIs allow.

### D2: Order inside this change
Implement `admin-user-roles` first in tasks so E2E onboarding unblocks early.

### D3: Catalog ownership
Membership and machine CRUD uses API resources; gym-membership composite keys for links.

## Risks / Trade-offs

- **[Risk] Hard to find pending users without query** → Mitigation: list users + filter client-side; note backend “pending” endpoint as future improvement
- **[Risk] Open API until JWT lands** → Mitigation: still build UI; authz follows backend

## Open Questions

- Seeded role ids/names for Client/Staff/Admin
