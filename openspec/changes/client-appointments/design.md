## Context

Maps old Turno/Reserva UX to `/api/appointments` (+ activities/membership constraints as needed). iPhone only.

## Goals / Non-Goals

**Goals:** List/book/cancel for client in active gym.  
**Non-Goals:** Admin slot factories, Watch, payments UI.

## Decisions

### D1: Booking model
Use Appointment create/update with `memberId` = current user when API allows; if slots are pre-created empty, “book” assigns `memberId`.

### D2: Filtering
Client-side filter by `gymId` + `memberId` until dedicated endpoints exist.

## Risks / Trade-offs

- **[Risk] CRUD API lacks “available slots” query** → Mitigation: define UI against list+filter; note backend gap

## Open Questions

- Whether membership is required to book — follow API/business rules when known
