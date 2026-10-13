## Purpose

Authenticates iPhone users with Keycloak OIDC and keeps Core API calls authorized with a refreshed access token.

## ADDED Requirements

### Requirement: User can sign in with Keycloak
The system MUST authenticate the user via the configured Keycloak realm using OIDC with PKCE on the iPhone app.

#### Scenario: Successful login
- **WHEN** the user completes Keycloak login successfully
- **THEN** the app obtains access and refresh tokens and enters an authenticated session state

#### Scenario: Login cancelled
- **WHEN** the user cancels the Keycloak login flow
- **THEN** the app remains unauthenticated and does not store tokens

### Requirement: Session restores on launch
The system MUST restore a valid session from secure storage on iPhone launch when refreshable tokens exist.

#### Scenario: Cold start with stored refresh token
- **WHEN** the app launches and a refresh token is available
- **THEN** the system attempts token refresh and restores authenticated state on success

### Requirement: User can sign out
The system MUST clear local tokens and end the Keycloak session where supported when the user signs out.

#### Scenario: Logout
- **WHEN** the authenticated user signs out
- **THEN** local tokens are removed and subsequent API calls are unauthenticated

### Requirement: API requests send Bearer access token
Authenticated Core API requests MUST include the current access token as a Bearer Authorization header.

#### Scenario: Authorized request
- **WHEN** an authenticated client calls the API through Core
- **THEN** the request includes `Authorization: Bearer <access_token>`

### Requirement: Access token refresh on expiry
The system MUST refresh the access token when it is expired or when the API responds with 401 due to an expired token, then retry the request once when refresh succeeds.

#### Scenario: 401 triggers refresh and retry
- **WHEN** an API call returns 401 and a refresh token is available
- **THEN** the system refreshes the access token and retries the original request once
