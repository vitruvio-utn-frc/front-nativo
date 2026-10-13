## Purpose

Completes first-time API identity after Keycloak login by creating User and Tenant, then holding users without gym roles in a pending-approval state.

## ADDED Requirements

### Requirement: Missing tenant starts onboarding
When an authenticated user has no Tenant for their Keycloak `sub`, the system MUST present the profile onboarding flow.

#### Scenario: First login without tenant
- **WHEN** the user authenticates and no Tenant exists for `sub`
- **THEN** the app shows onboarding to complete the profile

### Requirement: Prefill from OIDC claims
The onboarding form MUST prefill available fields from Keycloak claims (e.g. email, name) and allow the user to complete remaining required profile fields.

#### Scenario: Email prefilled
- **WHEN** Keycloak provides an email claim
- **THEN** the onboarding form shows that email as the initial value

### Requirement: Create User and Tenant on submit
Successful onboarding MUST create an API User and a Tenant whose `id` equals the Keycloak `sub` and links to that User.

#### Scenario: Successful registration
- **WHEN** the user submits a valid onboarding profile
- **THEN** the system creates the User and Tenant and associates Tenant to the user

### Requirement: Pending approval without gym roles
When the user has a Tenant/User but zero `UserGymRole` memberships, the system MUST show a pending-approval state and MUST NOT enter client/staff/admin feature shells.

#### Scenario: Pending state
- **WHEN** the authenticated user has completed profile and has no gym roles
- **THEN** the app displays pending approval with an option to refresh status and to sign out

#### Scenario: Roles appear after refresh
- **WHEN** the user refreshes status after an admin assigns a role
- **THEN** the app exits pending approval and proceeds to gym/role context handling
