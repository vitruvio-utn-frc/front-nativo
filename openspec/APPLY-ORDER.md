# Orden de apply — migración native (front-nativo)

Última actualización: 2026-10-13  
Contexto: React Native → Swift (iOS + Watch) en Xcode nativo (`vitruvio.xcodeproj`, sin xtool), API `vitruvio-backend-2025`, Keycloak, OpenSpec en este repo.

Usar con `openspec-apply-change` (o equivalente) sobre cada change, en orden. Marcar progreso abajo al completar.

## Prerrequisitos externos (no son changes de este repo)

- [ ] Keycloak: realm, client iOS PKCE, redirect URI (`com.santiago-alvarado.vitruvio`), scopes
- [ ] Backend 2025: validación JWT del realm Keycloak
- [ ] Backend: seed roles Client / Staff / Admin (nombres/ids acordados)
- [ ] Apple Developer: App Group `group.com.santiago-alvarado.vitruvio` (+ app Watch)

## Orden de changes

| # | Change | Depende de | Notas | Hecho |
|---|--------|------------|-------|-------|
| 1 | `foundation-app-architecture` | — | Core + shells iOS/Watch + App Group + builds Xcode nativo | [x] 2026-10-13 |
| 2 | `auth-keycloak` | 1 | OIDC iPhone, Keychain, Bearer, share sesión → Watch | [x] 2026-10-13 |
| 3 | `onboarding-profile` | 2 | User + Tenant(sub), pending approval | [x] 2026-10-13 |
| 4 | `gym-context-and-roles` | 3 | Gym/rol activo, switcher, roots client/staff/admin | [x] 2026-10-13 |
| 5 | `admin-operations` (mínimo: roles) | 4 | **Priorizar** tasks `1.x` (`admin-user-roles`) para desbloquear pending → activo | [x] 2026-10-13 |
| 6 | `client-training` | 4 | Planes + sesión iPhone + offline; habilita Watch | [x] 2026-10-13 |
| 7 | `watch-training-companion` | 2, 6 | UI entrenamiento + HealthKit; solo cliente | [ ] |
| 8 | `client-appointments` | 4 | Puede ir en paralelo con 6/9 tras gym-context | [ ] |
| 9 | `client-membership-profile` | 4 | Membresías + perfil; sin tarjetas/store | [ ] |
| 10 | `staff-operations` | 4 | Clientes, ejercicios, planes (crear planes para E2E training) | [ ] |
| 11 | `admin-operations` (resto) | 5 | Directory, memberships, machines, appointments schedule | [x] 2026-10-13 |

## Grafo (referencia rápida)

```
foundation
  -> auth-keycloak
    -> onboarding-profile
      -> gym-context-and-roles
           -> admin-operations (roles primero)
           -> client-training -> watch-training-companion
           -> client-appointments
           -> client-membership-profile
           -> staff-operations
           -> admin-operations (resto)
```

## Cómo retomar

1. Abrir este archivo y ver el primer `#` con Hecho `[ ]`.
2. `openspec status --change "<nombre>" --json`
3. Apply ese change hasta tasks `[x]`.
4. Marcar Hecho aquí; opcional: archive del change al cerrarlo.
5. Siguiente fila.

## Non-goals globales (no abrir changes para esto aún)

- Store / carousels mock / awards de la RN
- Auth0
- Rol “super” global (usar multi UserGymRole)
- OpenSpec/implementación JWT dentro de este repo (backend aparte)
- Staff/admin en Apple Watch
