# AGENTS.md

Guía para agentes de IA que trabajan en este repositorio.

## Qué es el proyecto

**Vitruvio** (nativo): app de gimnasio en Swift para iPhone y Apple Watch. Es la migración de una app React Native a SwiftUI nativo. Consume la API `vitruvio-backend-2025` y autentica con Keycloak (OIDC + PKCE).

Roles de usuario: **Client**, **Staff**, **Admin**. Un usuario puede pertenecer a varios gimnasios; el rol activo depende del gym seleccionado.

## Estructura

| Ruta | Contenido |
|------|-----------|
| `vitruvio/` | Target iPhone (SwiftUI). Un directorio por área: `Auth`, `Onboarding`, `GymContext`, `Roots` (shells por rol), `Client`, `Admin`, `Companion` (puente con el Watch) |
| `vitruvio Watch App/` | Target watchOS: entrenamiento, sesión, HealthKit workout |
| `VitruvioCore/` | Framework compartido iPhone + Watch: `AppConfig`, `Auth`, `Networking`, `Session`, `GymContext`, `Onboarding`, `Training`, `Admin`, `Offline`, `Connectivity` |
| `Config/vitruvio-Info.plist` | Info.plist con el esquema URL del callback OAuth |
| `openspec/` | Specs y changes (flujo spec-driven). Ver abajo |
| `.agents/skills/`, `.claude/skills/` | Skills (OpenSpec, SwiftUI, concurrencia, SwiftData, watchOS, widgets…) |

Proyecto: `vitruvio.xcodeproj`. Targets/esquemas: `vitruvio`, `vitruvio Watch App`, `VitruvioCore`. Sin Swift Package ni workspace; no hay tests todavía.

Plataformas: iOS 18.2+, watchOS 11.2+, `SWIFT_VERSION = 5.0`.

## Comandos

```sh
xcodebuild -project vitruvio.xcodeproj -scheme vitruvio -destination 'generic/platform=iOS Simulator' build
xcodebuild -project vitruvio.xcodeproj -scheme "vitruvio Watch App" -destination 'generic/platform=watchOS Simulator' build
```

Si el MCP `xcode-tools` está disponible, prefiere `BuildProject`, `RunProject`, `RenderPreview`, `XcodeGrep`, etc.

Los archivos nuevos deben añadirse al target correcto en `project.pbxproj` (usa las herramientas de Xcode MCP o verifica que compile).

## Arquitectura y convenciones

- **Capa Core primero**: modelos, servicios HTTP y stores van en `VitruvioCore` (`public`, `Sendable`). Las vistas **no** hardcodean URLs ni endpoints de auth: se leen de `AppConfig`.
- **Red**: `AuthenticatedAPIClient` (`APIClient`) añade el Bearer y reintenta una vez tras refrescar en un 401. Los servicios (`TrainingService`, `AdminService`, `OnboardingService`, `GymContextService`) reciben un `APIClient`.
- **UI**: SwiftUI con modelos `@MainActor @Observable` por pantalla/flujo (p. ej. `ClientTrainingModel`, `ClientAppointmentsModel`) y archivos `*Model.swift` + `*Views.swift` por feature. Las raíces por rol están en `vitruvio/Roots/`.
- **Sesión/tokens**: `SessionStore` + `KeychainTokenStore`; login en `vitruvio/Auth` (`KeycloakLoginCoordinator`, `AuthSessionModel`).
- **Companion iPhone ↔ Watch**: se sincroniza con **Watch Connectivity** (`WatchConnectivityBridge`, `CompanionPhoneGateway`), **no** con App Group (`appGroupIdentifier` es legado). El Watch es solo para el rol cliente.
- **Offline**: `OfflineQueue` y `ActiveTrainingSessionStore` para sesiones de entrenamiento.
- Código y comentarios técnicos en inglés; la documentación de OpenSpec y mensajes de producto están en español. Mantén el estilo del código vecino (densidad de comentarios, nombres, `///` en APIs públicas).
- Sigue las skills del repo para SwiftUI (`swiftui-expert-skill`), concurrencia (`swift-concurrency-pro`) y watchOS (`watchos-development`) al escribir o revisar código.

## Flujo OpenSpec

El trabajo se planifica con OpenSpec (`schema: spec-driven`):

- `openspec/specs/` — specs vigentes por capacidad (auth, onboarding, gym-context, client-training, admin-*, watch-*…).
- `openspec/changes/` — changes pendientes (`client-membership-profile`, `staff-operations`, `session-date-calories-hk-workout`, …); `archive/` los terminados.
- `openspec/APPLY-ORDER.md` — orden de aplicación y estado de cada change. **Márcalo al completar un change.**
- Skills: `openspec-propose`, `openspec-explore`, `openspec-apply-change`, `openspec-sync-specs`, `openspec-archive-change`.

Antes de implementar una feature, lee su change (`proposal`, `design`, `tasks.md`) y marca las tareas completadas a medida que avanzas. `session-date-calories-hk-workout` está bloqueado hasta que exista la API en el backend.

## Backend (`vitruvio-backend-2025`)

Repo hermano en `/Users/santiagoalvarado/Documents/dev/vitruvio-backend-2025`. Es la API que consume `AppConfig.apiBaseURL` (`https://vitruvio.santiago-alvarado.com`).

**Stack**: ASP.NET Core (.NET 9, controllers), EF Core 9 + MySQL. Solución `Vitruvio.sln` con tres proyectos: `Api` (controllers, servicios), `Database` (`AppDbContext`, configuraciones, migraciones), `Domain` (entidades).

**Correr en local**:

```sh
docker compose up -d        # MySQL + API en http://localhost:3000 (aplica migraciones al arrancar)
dotnet ef database update --project Database/Database.csproj --startup-project Api/Api.csproj --context Database.AppDbContext
```

OpenAPI solo se expone en Development (`app.MapOpenApi()`). Hay colecciones Postman en `postman/` y `.postman/`. `GET /api/health` sirve de healthcheck.

**Forma de la API** (útil al escribir servicios en `VitruvioCore`):

- Rutas `api/<recurso-en-plural>` con CRUD estándar: `GET` (lista), `GET {id}`, `POST`, `PUT {id}`, `DELETE {id}`. Crear devuelve `201`, borrar `204`, no encontrado `404`.
- Los ids son `Guid`, salvo `Role`, `Permission` y `Gender` (`int`) y `Tenant` (`string`).
- Las tablas de unión usan claves compuestas en la ruta: `user-gym-roles/{userId}/{gymId}/{roleId}`, `role-permissions/{roleId}/{permissionId}`, y similares en gym-memberships, appointment-memberships y user-awards.
- Endpoints especiales: `GET users/by-number/{idNumber}` (DNI) y `GET tenants/by-user/{userId}`.
- Entidades clave: `User` (+ `IdNumber`, `Tenants`), `Tenant` (`Id` = `sub` de Keycloak, `UserId`), `UserGymRole` (usuario + gym + rol), `Appointment` (`StartDate`/`EndDate` como `DateTimeOffset`), `TrainingSessionCompletion` (`StartDate`/`EndDate` nullables, sin kcal ni id de workout de HealthKit).
- JSON con `ReferenceHandler.IgnoreCycles`: las respuestas pueden omitir propiedades de navegación ya vistas. Las listas no filtran por gym ni por usuario; hay que filtrar en el cliente.

### APIs expuestas por área

Todas bajo `api/` con el CRUD estándar; entre paréntesis, la clave de la ruta cuando no es `{id}` (`Guid`).

| Área | Recursos | Para qué sirve |
|------|----------|----------------|
| Identidad | `users` (+ `by-number/{idNumber}`), `tenants` (+ `by-user/{userId}`, id `string`), `genders` (`int`) | Perfil del usuario y vínculo con el `sub` de Keycloak |
| Acceso y roles | `roles` (`int`), `permissions` (`int`), `role-permissions` (`{roleId}/{permissionId}`), `user-gym-roles` (`{userId}/{gymId}/{roleId}`) | Qué rol tiene cada usuario en cada gym y qué permisos da el rol |
| Gimnasios | `companies`, `gyms`, `machines`, `machine-types` (`int`) | Empresa → sedes → máquinas |
| Actividades y turnos | `activities`, `activity-types` (`int`), `appointments`, `appointment-memberships` (`{appointmentId}/{membershipId}`) | Clases/actividades del gym y turnos reservables |
| Membresías y pagos | `memberships`, `gym-memberships` (`{gymId}/{membershipId}`), `user-memberships`, `payments`, `payment-methods` (`int`) | Planes de membresía, quién los contrató y sus pagos |
| Ejercicios | `exercises`, `exercise-types` (`int`), `exercise-executions`, `exercise-sets` | Catálogo de ejercicios y su prescripción (series/reps) |
| Entrenamiento | `training-plan-templates`, `training-plans`, `training-sessions`, `training-session-completions`, `exercise-completions` | Plantillas, planes asignados a un cliente, sesiones y su ejecución real |
| Premios | `awards`, `user-awards` (`{memberId}/{awardId}`) | Logros otorgados a usuarios |
| Operación | `health` | Healthcheck |

### Modelo de dominio y relaciones

Los campos `*Id` son claves foráneas; `?` indica opcional.

```
Company 1─* Gym
Gym ─* Activity ─1 ActivityType
Gym ─* Machine ─1 MachineType
Gym ─* Exercise (gym-exercises)         Exercise ─1 ExerciseType, ─0..1 MachineType
Gym *─* Membership   (GymMembership)

User ─1 Gender
User ─* Tenant                          Tenant.Id = sub de Keycloak
User *─* Gym  vía UserGymRole ─1 Role   (un usuario puede tener varios roles por gym)
Role *─* Permission  (RolePermission)

Appointment ─1 Gym, ─1 Activity, ─0..1 User (Member)
Appointment *─* Membership  (AppointmentMembership)

User ─* UserMembership ─1 Membership    UserMembership ─* Payment ─1 PaymentMethod
User *─* Award  (UserAward, con fecha)

TrainingPlanTemplate (Trainer?) ─* TrainingSession
TrainingPlan (Member, Trainer?) ─* TrainingSession
TrainingSession ─* ExerciseExecution ─1 Exercise
ExerciseExecution ─* ExerciseSet (Reps), Duration?, Notes?

TrainingSessionCompletion ─1 TrainingSession, ─1 User (Member), ─0..1 TrainingPlan
TrainingSessionCompletion ─* ExerciseCompletion ─1 ExerciseExecution
                          (StartDate/EndDate, CaloriesBurnedInTotal por ejercicio)
```

Cómo leerlo para el flujo de la app:

- **Contexto de gym**: `Tenant` (por `sub`) → `User` → `UserGymRole` → `Gym` + `Role`. Eso alimenta `GymContextService` y el rol activo.
- **Entrenamiento**: un `TrainingPlan` (o una `TrainingPlanTemplate`, plantilla sin cliente) contiene `TrainingSession`; cada una lista `ExerciseExecution` (qué ejercicio y con qué series). El cliente registra lo realizado como `TrainingSessionCompletion` con sus `ExerciseCompletion`. `ExerciseCompletion` apunta a la ejecución prescrita, no al ejercicio directo. Una `TrainingSession` pertenece a un plan **o** a una plantilla (ambos FK son opcionales).
- **Turnos**: `Appointment` está en un `Gym` para una `Activity`; `MemberId` es opcional. `AppointmentMembership` vincula el turno con membresías.
- **Membresías**: `Membership` es el plan (precio, duración); `GymMembership` dice en qué gyms se vende; `UserMembership` es la contratación con `StartDate`/`EndDate`; `Payment` cuelga de `UserMembership`.
- Las respuestas devuelven la entidad de dominio directamente (no hay DTOs de salida), así que los modelos `Codable` de `VitruvioCore` deben tolerar propiedades de navegación ausentes por `IgnoreCycles`. Las fechas son `DateTimeOffset` (ISO 8601) y las duraciones `TimeSpan` (`"d.hh:mm:ss"`, no segundos).

**Limitaciones actuales del backend** (afectan decisiones en el cliente):

- **No hay autenticación ni autorización**: no existe validación JWT de Keycloak ni `[Authorize]`. El Bearer que manda `AuthenticatedAPIClient` hoy se ignora. Es un prerrequisito pendiente en `APPLY-ORDER.md`.
- **Roles no sembrados**: solo `Gender` tiene datos semilla (Masculino, Femenino, Otro). Los roles Client/Staff/Admin deben existir en la base para que funcione el contexto de gym.
- Sin paginación ni filtros por query string.
- Sin campos para `session-date-calories-hk-workout` (orden por fecha, kcal, id de workout HK): por eso ese change está bloqueado hasta ampliar la API.

Cuando una feature nueva necesite un endpoint o campo que no existe, impleméntalo primero en el backend (controller + servicio + `Inputs`/`Requests` + migración EF) y luego consúmelo desde `VitruvioCore`.

## Cosas a tener en cuenta

- Config de entorno en `VitruvioCore/AppConfig.swift` (API base, issuer/cliente/redirect de Keycloak). El redirect URI y el esquema URL deben coincidir con `Config/vitruvio-Info.plist` (`com.santiago-alvarado.vitruvio`).
- No commitees `build/`, `xcuserdata/` ni `DerivedData/`.
- No hagas commits ni push sin que se te pida.
