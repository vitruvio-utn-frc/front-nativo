## Purpose

Lets admins administer the membership catalog and gym membership associations needed for the active gym.

## ADDED Requirements

### Requirement: Membership catalog CRUD
Admins MUST be able to create, update, list, and delete membership definitions when permitted.

#### Scenario: Create membership
- **WHEN** an admin creates a membership with required fields
- **THEN** it appears in the catalog

### Requirement: Associate membership to gym
Admins MUST be able to associate memberships to the active gym when the API uses gym-membership links.

#### Scenario: Link membership to gym
- **WHEN** an admin links a membership to the active gym
- **THEN** the association is persisted
