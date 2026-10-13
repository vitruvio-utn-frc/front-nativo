## 1. Routing and lookups

- [x] 1.1 After auth, resolve Tenant by Keycloak `sub` and verify users without Tenant enter onboarding
- [x] 1.2 Prefill onboarding from OIDC claims and verify email/name appear when provided by Keycloak

## 2. Profile creation

- [x] 2.1 Load genders and collect CreateUser fields; verify validation blocks incomplete submit
- [x] 2.2 POST User then POST Tenant `{ id: sub, userId }` and verify both exist for the signed-in subject
- [x] 2.3 Handle create failures/retries without silent duplicates and verify error UI is shown

## 3. Pending approval

- [x] 3.1 Detect zero UserGymRoles and show pending approval UI with refresh + logout; verify feature shells are not reachable
- [x] 3.2 After admin assigns a role, refresh transitions out of pending and verify gym-context can proceed
