## Why

The native app must authenticate users with a self-hosted Keycloak realm instead of Auth0. Without a session layer that obtains OIDC tokens, stores them securely, and shares them with the Watch via the App Group, no API-backed feature can proceed.

## What Changes

- Add Keycloak OIDC login/logout (PKCE) on iPhone
- Persist tokens in Keychain; restore session on launch
- Attach Bearer access tokens to Core API client requests; refresh on expiry/401
- Share session material with the Watch through the App Group / Keychain access group reserved in foundation
- Map Keycloak `sub` as the identity used later for Tenant linking (linking itself is in onboarding)
- Document external dependency: backend MUST validate Keycloak JWTs (work outside this repo)

## Capabilities

### New Capabilities

- `keycloak-auth`: OIDC sign-in/out, token lifecycle, and authenticated API requests from Core
- `companion-session-share`: Secure sharing of auth session from iPhone to Watch companion

### Modified Capabilities

- (none)

## Impact

- **Code**: Core `Session` / `APIClient` seams, iOS auth UI entry, Watch read-only session consumption
- **Deps**: Keycloak client config (realm, client id, redirect URIs); App Group already from foundation
- **External**: `vitruvio-backend-2025` JWT validation — not implemented in this change
- **Out of scope**: Profile completion, Tenant/User creation, gym roles, training
