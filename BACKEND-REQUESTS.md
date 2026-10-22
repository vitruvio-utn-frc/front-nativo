# Pedidos al backend (`vitruvio-backend-2025`)

Última actualización: 2026-10-21. Origen: change `training-execution-model` (archivado en `openspec/changes/archive/2026-10-21-training-execution-model/`) y la revisión de backend vs. app nativa.

La app nativa funciona hoy **sin ningún cambio en el backend**. Cada pedido mejora algo que la app resuelve con un límite o un rodeo; la columna "Hoy en la app" dice cuál.

## A. Modelo de entrenamiento (lo que el cliente registra)

Contexto: el cliente sigue una `TrainingSession` prescrita y registra lo que hizo en `TrainingSessionCompletion` y `ExerciseCompletion`. La prescripción es de solo lectura para el cliente.

| # | Pedido | Por qué | Hoy en la app |
|---|---|---|---|
| A1 | **Series realizadas.** Nueva entidad `SetCompletion` (`Id`, `ExerciseCompletionId`, `ExerciseSetId?`, `Reps`, `Weight?`) con CRUD estándar. | No hay dónde guardar cuántas reps o qué peso hizo realmente el cliente; `ExerciseCompletion` solo tiene fechas y kcal. | Las series se marcan solo en el dispositivo; no se persisten reps ni peso reales. |
| A2 | **`Id` opcional en los `POST`** de `training-session-completions` y `exercise-completions`: si viene se usa, si no `Guid.NewGuid()`. | El servidor ignora el id que manda el cliente. Con ids del cliente el modo offline se simplifica (hoy hay ids locales que se remapean) y el vínculo con el workout de HealthKit se podría escribir aunque la sesión arranque sin conexión. | Cola offline con ids locales y mapa `local → servidor`. Si la sesión arranca offline, el workout de HealthKit queda sin `External UUID`. |
| A3 | **`TrainingSessionCompletion`**: agregar `CaloriesBurnedInTotal double?` y `HealthKitWorkoutId string?` (entidad, inputs de create/update, migración). | Guardar el total de kcal de la sesión y el id del workout de HealthKit. | El total se calcula en el cliente sumando los ejercicios; el id del workout no se guarda (el vínculo va al revés: el id de la completion se escribe en la metadata del workout). |
| A4 | **`ExerciseCompletion.CaloriesBurnedInTotal` pasa a `double?`** y nuevo campo `CaloriesSource` (`healthkit` / `estimated`). | Distinguir "sin medición" de "0 kcal" y no mezclar kcal medidas por el Watch con estimadas por el catálogo. | Se guarda siempre un número (medido o estimado) y el origen queda solo en el dispositivo que registró la sesión. |
| A5 | **`TrainingSession.Name`** ("Día A") y **`Order`**; también **`Order` en `ExerciseExecution`**. | Hoy no hay forma de nombrar ni ordenar las sesiones de un plan ni los ejercicios de una sesión. | Las sesiones se muestran como "Sesión 1", "Sesión 2" según el orden en que llegan de la API (por `Guid`, estable pero arbitrario). |
| A6 | **Filtros por query o `Include`**: `?memberId=` y `?trainingPlanId=` en `training-session-completions`; `?trainingSessionCompletionId=` en `exercise-completions`; o devolver los hijos con `Include`. | Las listas devuelven la tabla completa sin filtrar. | El cliente baja las tablas enteras y filtra localmente. |
| A7 | *(Opcional, futuro)* `ExerciseCompletion.ExerciseId` directo y `ExerciseExecutionId` nullable. | Permitiría ejercicios fuera de lo prescrito. | El cliente solo puede seguir lo que armó el staff. |

## B. Generales (detectados en la revisión)

| # | Pedido | Por qué |
|---|---|---|
| B1 | **Autenticación y autorización**: validar el JWT del realm de Keycloak y `[Authorize]` en los controllers. | Hoy el Bearer que manda la app se ignora y los listados responden sin token (por ejemplo `GET api/exercise-completions`). Cualquiera puede leer los datos de todos los usuarios. Es el prerrequisito pendiente más importante. |
| B2 | **Seed de roles con ids fijos**: `1` cliente, `2` staff, `3` admin, `4` superadmin; y una forma de dar de alta el **primer admin**. | La app mapea el rol por id (`AppRole`). Sin esos roles el contexto de gym no funciona, y sin un admin inicial nadie puede asignar roles a los demás. |
| B3 | **Endpoints para las tablas puente** `GymMachines`, `GymExercises` y `GymActivities`. | Las tablas existen en el modelo pero no hay API para llenarlas: máquinas, ejercicios y actividades son **globales para todos los gimnasios**. |
| B4 | **`Include` y filtros en general** (además de A6). | Las navegaciones llegan siempre vacías (`null`) y no hay paginación ni filtros, lo que obliga a varias consultas por pantalla. |

## C. Limpieza de datos (opcional)

Datos que dejó la versión anterior de la app, vistos el 2026-10-21. No rompen nada, pero ensucian listados:

- **`exercise-completions` sin sesión** (`trainingSessionCompletionId: null`), con kcal en `0` y horas inventadas: unas 33 filas.
- **`training-sessions` vacías** dentro de planes de clientes, creadas por el botón "Iniciar" de la versión anterior. La app nueva las oculta, pero siguen en la base.
- **Una `training-session-completion` vacía** (`a33030c8-…`, 0 ejercicios, 22 segundos) de una prueba. La versión actual ya no guarda sesiones sin ejercicios completados.

## Notas para quien lo implemente

- El cliente ya tolera propiedades de navegación ausentes (`ReferenceHandler.IgnoreCycles`) y campos nuevos opcionales en las respuestas.
- Fechas: `DateTimeOffset` en ISO 8601; el cliente envía segundos enteros.
- Cuando una feature nueva necesite un endpoint o campo que no existe, `AGENTS.md` indica implementarlo primero en el backend (controller, servicio, `Inputs`/`Requests` y migración EF) y recién después consumirlo desde `VitruvioCore`.
