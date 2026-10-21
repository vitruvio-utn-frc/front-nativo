## Context

Staff role shell from gym-context. Remaps RN staff (clients + exercises + plans) onto 2025 training domain.

## Goals / Non-Goals

**Goals:** Clients list, exercise CRUD, plan assignment/structure.  
**Non-Goals:** Role approval, machines admin, Watch staff UI.

## Decisions

### D1: Plan authoring depth
v1 supports enough structure for client-training + Watch execution (session → executions → sets). Templates optional if timeboxed.

### D2: Permissions
UI assumes staff role; rely on future API authz. No local fake permission matrix.

## Risks / Trade-offs

- **[Risk] Incomplete nested create APIs** → Mitigation: multiple calls matching controllers; document UX limits

## Open Questions

- Whether staff can delete plans — default allow if API delete exists
