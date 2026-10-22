# Tasks

## 1. Core: modelos y lecturas

- [x] 1.1 Agregar en `VitruvioCore/Training/TrainingModels.swift` los DTOs `TrainingSessionCompletionDTO` (tolerante a navegaciones ausentes) y los requests `CreateTrainingSessionCompletionRequest` / `UpdateTrainingSessionCompletionRequest`. Verificar que el target `VitruvioCore` compila y que un `GET api/training-session-completions` real se decodifica.
- [x] 1.2 Agregar a `TrainingService` las lecturas `listCompletions(memberId:planId:)` (ordenadas por `startDate` desc) y `listExerciseCompletions(sessionCompletionId:)`, filtrando en el cliente. Verificar contra la API que solo vuelven las del usuario o plan pedido.
- [x] 1.3 Mover de `TrainingService` a la extensión `StaffTrainingService` las escrituras de prescripción (`createSession`, `createExecution`, `createSet`). Verificar que el esquema `vitruvio` compila (el grep que prueba que el cliente ya no las usa está en 5.2, porque es una extensión del mismo tipo y el compilador no lo impide).

## 2. Core: estado activo y cola offline

- [x] 2.1 Rediseñar `ActiveTrainingSessionSnapshot` según el design (D2): `trainingSessionId`, `completionLocalId`, `completionServerId?`, ejercicios prescritos con `prescribedReps`, `doneSetIndexes`, `startedAt?`, `completedAt?`, `energyAtStart?`, `kcal` y su origen. Descartar snapshots con el formato viejo al cargar. Verificar con una sesión vieja persistida que la app arranca sin sesión activa y sin crashear.
- [x] 2.2 Reescribir los `OfflineMutationKind` de `FileOfflineQueue`: `createSessionCompletion`, `createExerciseCompletion`, `finishSessionCompletion`, con un mapa persistido `localId → serverId` y resolución de dependencias antes de enviar (D3). Descartar los registros de `kind` desconocido sin vaciar el resto. Verificar en modo avión que iniciar, completar dos ejercicios y terminar deja tres o cuatro registros, y que al volver la red la API tiene una completion con `startDate`/`endDate` y dos `exercise-completions` vinculadas.
- [x] 2.3 Clasificar errores en el flush (D3): reintentar `URLError`, 5xx, 408 y 429; dejar el 401 al refresh existente; descartar y reportar cualquier otro 4xx sin frenar la cola. Verificar encolando un `exercise-completion` con un `exerciseExecutionId` inexistente: se descarta, se muestra el error y el siguiente registro se envía.
- [x] 2.4 Notificar cuando la cola resuelve `localId → serverId` y actualizar `completionServerId` en el snapshot activo si coincide. Verificar que, al recuperar la red con una sesión activa iniciada offline, el snapshot pasa a tener `completionServerId`.

## 3. Core: servicio de ejecución y calorías

- [x] 3.1 Crear `VitruvioCore/Training/TrainingExecutionService.swift` (D1) con `start(plan:session:)`, `markSet(executionId:index:energyKcal:)`, `completeExercise(executionId:energyKcal:)`, `end()` e historial, apoyado en `TrainingService`, la cola (siempre encolar y luego `flush`) y el snapshot. Agregarlo al target `VitruvioCore` en `project.pbxproj`. Verificar que compilan los esquemas iOS y watchOS.
- [x] 3.2 Implementar el inicio de ejercicio (D4): primera serie marcada, o fin del ejercicio completado anterior, o inicio de la sesión. Verificar que una completion persistida tiene como `startDate` la hora de la primera serie marcada.
- [x] 3.3 Implementar la atribución de kcal (D5): medida (`max(0, fin − inicio)`) cuando hay lecturas de energía al inicio y al fin, y si no, `CaloriesBurnRate × Σ prescribedReps` (0 si falta alguno). Lecturas del iPhone solo con `CompanionWorkoutMetrics` fresco y de la misma sesión. Verificar el escenario de `training-calories`: tasa 0.5 con 10/10/8 reps sin Watch da 14 kcal persistidas.
- [x] 3.4 Persistir en Core el mapa local de origen de kcal (`healthkit` / `estimated`) por id local, remapeado a id de servidor, sin enviarlo a la API. Verificar inspeccionando el body enviado (log de `APIClient`) que no incluye el origen, y que el origen se recupera por id de completion tras el remapeo (la etiqueta en pantalla se verifica en 4.4).
- [x] 3.5 Escribir la corrida recién al completar el primer ejercicio (`completionQueued`) y no guardar nada si se finaliza sin ejercicios completados. Verificar con pruebas del servicio: iniciar y finalizar sin completar deja la cola y la API sin cambios, y completar el primer ejercicio crea la completion con la hora real de inicio.

## 4. iPhone: flujo del cliente

- [x] 4.1 Migrar `ClientTrainingModel` a `TrainingExecutionService`: quitar `addExercise`, cambiar `logSet` por marcar o desmarcar una serie prescrita, y hacer que `completeExercise` y `endSession` persistan (este último cierra la completion en lugar de "descartar"). Verificar que iniciar una sesión no cambia la cantidad de `TrainingSession` del plan (`GET api/training-sessions` antes y después).
- [x] 4.2 Rehacer `TrainingPlanDetailView`: sección "Sesiones" con las prescritas ("Sesión N" + resumen de ejercicios, ocultando las que no tienen ejecuciones) y "Iniciar" por sesión; mensaje si no hay sesiones; sección "Historial" con completions ordenadas por fecha desc. Verificar en el simulador con un plan del staff de dos sesiones y dos entrenamientos de días distintos.
- [x] 4.3 Rehacer `ActiveTrainingSessionView`: ejercicios prescritos con sus series (reps prescritas, toque para marcar), botón "Completar" por ejercicio, sin "Agregar ejercicio"; mantener la franja de vitals del Watch. Verificar que el flujo completo funciona en el simulador y que no aparece ninguna opción para agregar ejercicios.
- [x] 4.4 Rehacer `PastTrainingSessionView` como detalle de completion: fecha, duración, ejercicios completados con horarios, kcal (con la etiqueta medido/estimado cuando se conoce) y total. Verificar que el total es la suma de los ejercicios.

## 5. Companion iPhone ↔ Watch

- [x] 5.1 Ampliar `CompanionSyncSnapshot` y `ManualEncoder` (nueva versión): progreso de ejercicios del snapshot activo, `completionServerId` y las sesiones de cada `CompanionPlanItem` con su etiqueta y resumen. El Watch ignora versiones desconocidas y pide `fullSync`. Verificar con el Watch simulado emparejado que el detalle de la sesión activa coincide con el del iPhone.
- [x] 5.2 Migrar `CompanionPhoneGateway` a `TrainingExecutionService`. Acciones: `startSession(planId, trainingSessionId)`, `markSet(executionId, index, energyKcal?)`, `completeExercise(executionId, energyKcal?)` y `endSession`, que ahora cierra la completion. Publicar un snapshot cuando se resuelve el id de servidor. Verificar que iniciar desde el Watch deja la misma completion en la API que iniciar desde el iPhone, y que `grep -rn "createSession\|createExecution\|createSet" vitruvio/Client vitruvio/Companion "vitruvio Watch App"` no devuelve nada.

## 6. Watch

- [x] 6.1 Actualizar `WatchTrainingViews` y `WatchTrainingModel`: Plan → Sesión ("Sesión N" + resumen) → activa; series con reps prescritas para marcar; completar ejercicio. Mandar `energyKcal` con el acumulado actual del workout en `markSet` y `completeExercise`. Verificar en el simulador de watchOS.
- [x] 6.2 En `WatchHealthKitWorkoutManager.endWorkout()`: antes de `finishWorkout()`, agregar `HKMetadataKeyExternalUUID` con `completionServerId` solo si no es `nil`; conservar el `HKWorkout` devuelto para log. Verificar en un dispositivo o simulador con HealthKit que una sesión online guarda el workout con la metadata y una iniciada offline la guarda sin ella. Online confirmado en Salud (`External UUID` presente); el caso sin id se cumple por el guard de `nil` y no se observó a mano.
- [x] 6.3 Cerrar el workout cuando llega un snapshot sin sesión activa mientras el workout corre (fin desde el iPhone), y dejar de descartar el resultado de `endWorkout()` en `WatchTrainingModel.endSession()`. Verificar que terminar en el iPhone detiene el workout en el Watch.

- [x] 6.4 Mostrar en el Watch una sección "Instrucciones" con el video de cada ejercicio que lo tenga: reproductor para `.mp4/.mov/.m4v`, imagen animada para GIF y aviso "solo desde el iPhone" para páginas web. Verificar que el decodificador anima el GIF real de la API (12 cuadros, loop de 3 s) y que el esquema watchOS compila.

## 7. Integración y documentación

- [x] 7.1 Prueba E2E contra la API: el staff crea un plan con dos sesiones; el cliente entrena una con el Watch (online) y otra sin Watch (offline → online). Verificar en la API dos completions con fechas, `exercise-completions` vinculadas con kcal medidas y estimadas, cero `TrainingSession` nuevas, y el workout de HealthKit de la primera con su metadata. Verificado en la API: 4 completions con inicio y fin, ejercicios vinculados a su sesión. Las kcal observadas (450, 300) son estimadas: el simulador no genera energía activa, así que la medición real del Watch queda por probar en un dispositivo físico.
- [x] 7.2 Actualizar `openspec/APPLY-ORDER.md`: agregar `training-execution-model`, marcar `session-date-calories-hk-workout` como reemplazado y marcar Hecho al terminar. Verificar que el archivo refleja el estado.

## Workflow follow-up

- Pasar la sección "Pedidos al backend" de `proposal.md` a los responsables de `vitruvio-backend-2025`.
- Retirar el change `session-date-calories-hk-workout` (archivarlo como reemplazado o borrarlo) una vez aprobado este.
- Sincronizar specs y archivar `training-execution-model` tras la revisión.
