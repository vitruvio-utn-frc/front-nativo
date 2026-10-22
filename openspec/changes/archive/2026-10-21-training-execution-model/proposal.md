# Proposal

## Why

Hoy la app del cliente registra el entrenamiento escribiendo sobre la **prescripción** del entrenador: "Iniciar" crea una `TrainingSession` vacía nueva dentro del plan, y "agregar ejercicio" / "registrar serie" crean `ExerciseExecution` y `ExerciseSet`. Nunca se crea un `TrainingSessionCompletion`, los `ExerciseCompletion` quedan sueltos (`trainingSessionCompletionId = nil`), con hora de inicio inventada (`ahora − 5 min`) y `0` kcal, aunque el Watch mide la energía activa. El resultado es que el plan del staff se llena de sesiones basura y el "historial" del cliente muestra prescripciones, no lo que realmente entrenó.

El backend ya tiene el modelo de ejecución (`TrainingSessionCompletion` → `ExerciseCompletion`). Este change hace que la app lo use, **sin modificar el backend**: los huecos del schema quedan documentados abajo como pedidos para sus responsables.

## What Changes

- **BREAKING (comportamiento):** el cliente deja de crear `TrainingSession`, `ExerciseExecution` y `ExerciseSet`. La prescripción pasa a ser de solo lectura para el rol cliente.
- Iniciar entrenamiento = elegir una `TrainingSession` **existente** del plan y crear un `TrainingSessionCompletion` (`StartDate`). Terminar = `PUT` con `EndDate`.
- El cliente **solo sigue lo prescrito**: no puede agregar ejercicios fuera de la sesión.
- Las series se marcan como hechas **solo de forma local** (progreso en la UI); no se persisten reps reales porque la API no tiene dónde guardarlas.
- Completar un ejercicio = `POST exercise-completions` apuntando a la `ExerciseExecution` prescrita y al `TrainingSessionCompletion` activo, con hora de inicio real.
- **kcal por ejercicio:**
  - Con Watch y HealthKit activos: diferencia del acumulado de energía activa entre el inicio y el fin del ejercicio.
  - Sin Watch: estimación con `Exercise.CaloriesBurnRate` (kcal por repetición) × reps prescritas.
  - El origen (medido/estimado) se guarda solo localmente.
- **HKWorkout ↔ completion:** el Watch escribe el id del `TrainingSessionCompletion` en la metadata del workout (`HKMetadataKeyExternalUUID`) **solo si ya tiene el id del servidor** al terminar; nunca se escribe un id temporal ni inventado.
- Historial del cliente = `TrainingSessionCompletion` propios, ordenados por `StartDate`, con detalle de ejercicios completados, duración y kcal.
- Cola offline:
  - Soporta crear y cerrar la completion y crear ejercicios completados mientras la completion todavía no tiene id de servidor (ids temporales locales que se remapean al sincronizar).
  - Descarta los errores no recuperables en vez de bloquear la cola para siempre.
- **Reemplaza** al change `session-date-calories-hk-workout`: `CreatedAt` en `TrainingSession` deja de ser necesario y kcal / id de workout se resuelven acá dentro de lo que permite la API.

## Capabilities

### New Capabilities
- `training-calories`: cómo se obtienen y se atribuyen las kcal de un entrenamiento (medidas por el Watch o estimadas por ejercicio) y cómo se muestran.

### Modified Capabilities
- `client-training-session`:
  - Iniciar elige una sesión prescrita y crea una completion.
  - El registro deja de escribir en la prescripción.
  - Nuevo requisito de finalizar sesión.
  - La cola offline admite dependencias entre mutaciones.
- `iphone-session-history`: el historial pasa a listar ejecuciones reales (`TrainingSessionCompletion`), no sesiones prescritas.
- `watch-training-ui`:
  - Iniciar desde el Watch elige una sesión del plan.
  - "Registrar serie" pasa a "marcar serie hecha" (progreso local).
- `watch-healthkit-workout`: al terminar, la energía y el vínculo con la completion (metadata) se entregan al iPhone y al workout.

## Impact

- **Native:**
  - `VitruvioCore/Training` (`TrainingModels`, `TrainingService`, `ActiveTrainingSessionStore`).
  - `VitruvioCore/Offline/OfflineQueue.swift`.
  - `VitruvioCore/Connectivity/WatchConnectivityBridge.swift` (snapshot y acciones).
  - `vitruvio/Client/ClientTrainingModel.swift` y `ClientTrainingViews.swift`.
  - `vitruvio/Companion/CompanionPhoneGateway.swift`.
  - `vitruvio Watch App/WatchTrainingModel.swift`, `WatchTrainingViews.swift` y `WatchHealthKitWorkoutManager.swift`.
- **API usada (sin cambios):**
  - `training-session-completions` (GET, POST, PUT).
  - `exercise-completions` (GET, POST).
  - Lectura de `training-sessions`, `exercise-executions`, `exercise-sets` y `exercises`.
- **Datos existentes:**
  - Las `TrainingSession` vacías que ya creó el cliente siguen en la base; su limpieza queda fuera de este change.
  - Los registros viejos de la cola offline (`createExerciseExecution` / `createExerciseSet`) se descartan.
- **OpenSpec:** `session-date-calories-hk-workout` queda reemplazado; se actualiza `APPLY-ORDER.md`.

## Pedidos al backend (para los responsables de `vitruvio-backend-2025`)

Ordenados por prioridad. Ninguno bloquea este change; cada uno mejora algo que hoy queda limitado.

1. **Series realizadas** — nueva entidad `SetCompletion` (`Id`, `ExerciseCompletionId`, `ExerciseSetId?`, `Reps`, `Weight?`) con CRUD estándar. Hoy no hay forma de guardar cuántas reps o qué peso hizo el cliente.
2. **`Id` opcional en los `POST`** de `training-session-completions` y `exercise-completions` (si viene, se usa; si no, `Guid.NewGuid()`). Permite generar ids en el cliente, simplifica el modo offline y deja escribir el vínculo HKWorkout aunque la sesión arranque sin conexión.
3. **`TrainingSessionCompletion`**: `CaloriesBurnedInTotal double?` y `HealthKitWorkoutId string?` en entidad, inputs de create/update y migración.
4. **`ExerciseCompletion.CaloriesBurnedInTotal` → `double?`** y nuevo campo `CaloriesSource` (`healthkit` / `estimated`), para no confundir "sin medición" con "0 kcal" ni mezclar medidas con estimadas.
5. **`TrainingSession.Name` y orden**: un nombre ("Día A") y un `Order` en `TrainingSession`, más un `Order` en `ExerciseExecution`. Hoy no hay forma de nombrar ni ordenar sesiones o ejercicios de un plan.
6. **Filtros o `Include`**: `?memberId=` / `?trainingPlanId=` en `training-session-completions` y `?trainingSessionCompletionId=` en `exercise-completions`, o devolver los hijos con `Include`. Hoy el cliente baja tablas completas.
7. *(Opcional, futuro)* `ExerciseCompletion.ExerciseId` directo y `ExerciseExecutionId` nullable, si se quiere permitir ejercicios fuera de lo prescrito.

Pendientes generales detectados en la revisión, fuera de este change:

- Validación JWT de Keycloak y `[Authorize]`.
- Seed de roles con ids fijos (`1` cliente, `2` staff, `3` admin, `4` superadmin) y alta del primer admin.
- Endpoints para las tablas puente `GymMachines` / `GymExercises` / `GymActivities`.
- `Include` en general.
