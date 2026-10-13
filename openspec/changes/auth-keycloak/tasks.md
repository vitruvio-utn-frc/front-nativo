## 1. Configuration and Core session

- [ ] 1.1 Add Keycloak/OIDC configuration to Core config and verify values are readable without hardcoding in views
- [ ] 1.2 Implement Keychain token store in Core Session seam and verify tokens persist across process restarts on simulator/device
- [ ] 1.3 Implement Bearer attachment + 401 refresh/retry once on APIClient and verify a mocked 401 triggers a single refresh and retry

## 2. iPhone OIDC

- [ ] 2.1 Integrate Keycloak PKCE login/logout on iPhone and verify successful login stores tokens and logout clears them
- [ ] 2.2 Wire session restore on launch and verify cold start restores authenticated state with a valid refresh token

## 3. Companion share

- [ ] 3.1 Publish session material to the App Group/Keychain access group after login/refresh and verify Watch can read it without Watch Connectivity
- [ ] 3.2 Clear shared session on logout and verify Watch no longer authorizes API calls
- [ ] 3.3 Authorize Watch Core API calls with shared session and verify Bearer header is present when session exists
