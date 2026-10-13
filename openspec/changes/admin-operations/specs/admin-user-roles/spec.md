## Purpose

Lets admins assign and revoke UserGymRole memberships so self-registered users can leave pending approval and gain gym access.

## ADDED Requirements

### Requirement: Assign gym role to user
An admin MUST be able to assign a role to a user in the active gym by creating a UserGymRole.

#### Scenario: Approve pending user as client
- **WHEN** an admin assigns the client role in the active gym to a user without roles
- **THEN** that user gains a UserGymRole and can pass pending approval on refresh

### Requirement: Revoke gym role
An admin MUST be able to revoke a user’s role in the active gym.

#### Scenario: Revoke role
- **WHEN** an admin removes a UserGymRole
- **THEN** the user no longer has that membership for the gym

### Requirement: List users needing access
The admin experience MUST support finding users to grant access (including users without gym roles when detectable).

#### Scenario: Find user to approve
- **WHEN** an admin searches or lists users eligible for role assignment
- **THEN** they can select a user and assign a role in the active gym
