## Purpose

Lets the authenticated client view and update their API User profile fields on iPhone.

## ADDED Requirements

### Requirement: View profile
The client MUST be able to view their profile fields stored on the API User resource.

#### Scenario: Profile displayed
- **WHEN** the client opens profile
- **THEN** their user profile fields are shown

### Requirement: Update profile
The client MUST be able to update editable profile fields and persist them via the API.

#### Scenario: Successful update
- **WHEN** the client saves valid profile changes
- **THEN** the User resource is updated and the UI reflects the new values

### Requirement: No payment cards in profile
Profile/membership areas MUST NOT include payment card capture or store checkout.

#### Scenario: Cards absent
- **WHEN** the user navigates profile/membership features from this change
- **THEN** no card CRUD or store cart UI is presented
