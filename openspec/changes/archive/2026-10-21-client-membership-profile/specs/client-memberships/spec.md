## Purpose

Shows the client their membership status related to the active gym without payment-card or store features.

## ADDED Requirements

### Requirement: View memberships
The client shell MUST display the user’s memberships relevant to the active gym context.

#### Scenario: Memberships listed
- **WHEN** the client opens memberships
- **THEN** current membership information is shown

#### Scenario: No memberships
- **WHEN** the user has no memberships
- **THEN** an empty/inactive state is shown
