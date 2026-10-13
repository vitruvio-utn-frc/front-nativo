## 1. Routing and lookups

- [ ] 1.1 After auth, resolve Tenant by Keycloak `sub` and verify users without Tenant enter onboarding
- [ ] 1.2 Prefill onboarding from OIDC claims and verify email/name appear when provided by Keycloak

## 2. Profile creation

- [ ] 2.1 Load genders and collect CreateUser fields; verify validation blocks incomplete submit
- [ ] 2.2 POST User then POST Tenant `{ id: sub, userId }` and verify both exist for the signed-in subject
- [ ] 2.3 Handle create failures/retries without silent duplicates and verify error UI is shown

## 3. Pending approval

- [ ] 3.1 Detect zero UserGymRoles and show pending approval UI with refresh + logout; verify feature shells are not reachable
- [ ] 3.2 After admin assigns a role, refresh transitions out of pending and verify gym-context can proceed
