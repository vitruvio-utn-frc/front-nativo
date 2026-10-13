## Context

Depends on `foundation-app-architecture` (Core session/API seams, App Group). Backend JWT validation is an external prerequisite (not in this repo). See proposal for motivation.

## Goals / Non-Goals

**Goals:**

- OIDC PKCE against self-hosted Keycloak on iPhone
- Secure token storage + refresh + Bearer injection in Core
- Session share to Watch via App Group/Keychain

**Non-Goals:**

- Creating User/Tenant (onboarding)
- Embedding gym roles in tokens as source of truth
- Implementing ASP.NET JWT middleware

## Decisions

### D1: Identity bridge
Keycloak `sub` is the stable subject; API `Tenant.Id` will equal `sub` in onboarding. Auth change only exposes `sub` + tokens.

### D2: Token storage
Keychain on iPhone; shared Keychain access group / App Group for Watch-readable secrets. Prefer refresh-on-Watch only if Apple constraints allow; otherwise Watch uses access token with iPhone refresh publisher.

### D3: OIDC library
Prefer a maintained Swift OIDC/AppAuth-style client compatible with Keycloak; avoid embedding WebViews manually unless required.

### D4: API client integration
Single Core authenticator middleware: attach Bearer, handle 401→refresh→retry once, then force re-auth.

### D5: Config
Realm URL, client id, redirect URI, scopes (`openid`, `profile`, `email`, offline if refresh required) in Core config — not hardcoded in views.

## Risks / Trade-offs

- **[Risk] Backend not ready for JWT** → Mitigation: document contract; feature-flag or mock authenticator for UI-only until API accepts tokens
- **[Risk] Watch cannot run full OIDC** → Mitigation: iPhone is login surface; Watch consumes shared session
- **[Trade-off] Roles not in JWT** → API remains source of gym roles (intentional)

## Migration Plan

Ship after foundation. No RN migration of Auth0 tokens. Users re-login with Keycloak.

## Open Questions

- Exact Keycloak client IDs / redirect URI host for xtool bundle id (config-time)
- Whether refresh tokens are readable on Watch or only access tokens are shared
