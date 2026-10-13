# gym-role-context Specification

## Purpose

Maintains the user’s active gym and role membership and supports switching when multiple UserGymRole entries exist.

## Requirements

### Requirement: Load gym-role memberships
After the user is authenticated and onboarded with at least one role, the system MUST load their `UserGymRole` memberships including gym and role identity needed for navigation.

#### Scenario: Memberships loaded
- **WHEN** the user has one or more gym roles
- **THEN** the system makes those memberships available to the app session

### Requirement: Active gym and role context
The system MUST maintain an active gym id and active role for the session and persist the selection across launches when still valid.

#### Scenario: Restore last selection
- **WHEN** the user relaunches and the previously active membership still exists
- **THEN** that gym/role remains active without forcing a new picker

### Requirement: Multi-membership switching
When the user has multiple memberships, the system MUST allow switching the active gym/role without a special “super” role.

#### Scenario: Switch membership
- **WHEN** the user selects a different gym/role membership
- **THEN** the active context updates and dependent UI reloads for that context

### Requirement: Single membership skips picker
When exactly one membership exists, the system MUST activate it without requiring a picker step.

#### Scenario: Auto-select single role
- **WHEN** the user has exactly one UserGymRole
- **THEN** that membership becomes active automatically
