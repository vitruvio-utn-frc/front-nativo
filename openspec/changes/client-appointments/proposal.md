## Why

Clients need to see and manage appointments (turnos) in the active gym. This replaces the old Turno/Reserva flows against the 2025 `Appointment` model and stays on iPhone only (Watch is training-focused).

## What Changes

- List upcoming/past appointments for the member in the active gym
- Book available appointments when the API allows member booking
- Cancel a member’s own appointment when permitted
- Scope all reads/writes to the active gym context
- No Watch appointment UI

## Capabilities

### New Capabilities

- `client-appointments`: Client appointment browse, book, and cancel in the active gym

### Modified Capabilities

- (none)

## Impact

- **APIs**: `/api/appointments` and related membership/activity constraints as needed
- **Depends on**: gym-role-context (client)
- **Out of scope**: Admin bulk slot creation (admin-operations), Watch, payments for appointments unless already required by API
