## 1. Core context

- [x] 1.1 Load UserGymRole memberships into Core GymContext and verify memberships appear for a user with roles
- [x] 1.2 Persist and restore active (gymId, roleId) and verify relaunch restores a still-valid selection
- [x] 1.3 Auto-select single membership and show picker for multiple; verify both behaviors

## 2. iPhone roots

- [x] 2.1 Mount client/staff/admin root shells from active role kind and verify each role opens the correct root
- [x] 2.2 Provide switcher UI for multi-membership users and verify switching reloads the matching root

## 3. Watch constraint

- [x] 3.1 Ensure Watch does not present staff/admin roots and verify only client-oriented shell remains
