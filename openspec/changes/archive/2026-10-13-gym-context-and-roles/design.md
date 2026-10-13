## Context

Depends on auth + onboarding. Role names come from API `Role` records (seed/admin-defined). No global super role.

## Goals / Non-Goals

**Goals:** Active gym/role context in Core; iPhone roots for three roles; multi-switcher.  
**Non-Goals:** Feature screens inside tabs; permission matrix UI; Watch staff tools.

## Decisions

### D1: Context in Core
`GymContext` holds `userId`, `gymId`, `roleId`, role name/kind, and membership list. Shells observe it.

### D2: Role kind mapping
Map API role names (or ids) to app kinds: `client | staff | admin`. Unknown roles show a safe fallback message.

`admin` and `superadmin` have **full shell access**: they can present client, staff, and admin roots for the active gym (switcher “View as”), without needing separate `UserGymRole` rows for each. Default shell for both remains admin.

### D3: Persistence
Store last `(gymId, roleId)` in App Group-friendly defaults so Watch can read active gym for client training later.

### D4: Empty shells
This change may ship roots with placeholder tabs; feature changes fill them.

## Risks / Trade-offs

- **[Risk] No “me/roles” endpoint** → Mitigation: filter `user-gym-roles` client-side until backend adds convenience API
- **[Risk] Ambiguous role names** → Mitigation: document expected seed names with backend owners

## Open Questions

- Canonical role name strings once seeded in DB
