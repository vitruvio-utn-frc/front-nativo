# Design

## Context

Ver `proposal.md` (Why) para la motivación. Estado actual relevante del código:

- `ClientTrainingModel` y `CompanionPhoneGateway` duplican el flujo de entrenamiento. Ambos llaman a `TrainingService.createSession` / `createExecution` / `createSet` / `createCompletion`, y cada uno tiene su propia instancia de `ActiveTrainingSessionStore` (comparten persistencia en `UserDefaults` y en un archivo).
- El Watch no habla con la API. Manda acciones por Watch Connectivity (`startSession`, `logSet`, `completeExercise`, `endSession`, `refresh`) y recibe `CompanionSyncSnapshot`.
- `WatchHealthKitWorkoutManager`:
  - Ya acumula `totalEnergyBurnedKilocalories` y lo publica como `CompanionWorkoutMetrics` (vitals de solo display).
  - `endWorkout()` descarta el `HKWorkout` resultante, y `WatchTrainingModel.endSession()` descarta las kcal.
  - Terminar la sesión desde el iPhone no termina el workout del Watch.
- `FileOfflineQueue` solo conoce `createExerciseExecution` / `createExerciseSet` / `createExerciseCompletion`, sin dependencias entre mutaciones. Además se frena en el primer fallo, sea del tipo que sea.
- API (sin cambios posibles en este change):
  - Los `POST` generan el `Guid` en el servidor e ignoran un `id` enviado.
  - Los `PUT` reemplazan todos los campos.
  - Las listas devuelven la tabla completa sin `Include`.
  - `TrainingSession` no tiene nombre ni orden.
  - `ExerciseCompletion.CaloriesBurnedInTotal` es `double` no nulo.
  - `Exercise.CaloriesBurnRate` se carga en la UI del staff como "Kcal por repetición".

## Goals / Non-Goals

**Goals:**
- Un único flujo de entrenamiento en Core que usen igual el iPhone y el gateway del Watch.
- Una sesión entera (inicio → ejercicios → fin) funciona sin conexión y se sincroniza en orden.
- Que lo que se persiste se pueda auditar: tiempos reales, kcal con origen conocido en el dispositivo.

**Non-Goals:**
- Limpiar las `TrainingSession` vacías que ya creó el cliente en planes existentes.
- Persistir reps o peso reales (sin campo en la API; ver pedido 1 en la proposal).
- Cambios en las pantallas del staff.
- Migrar los registros viejos de la cola offline.

## Decisions

### D1. Un servicio de ejecución en Core, consumido por iPhone y gateway

Nuevo `TrainingExecutionService` (en `VitruvioCore/Training`) que concentra:

- iniciar
- marcar serie
- completar ejercicio
- terminar
- leer historial

Sobre `TrainingService` (lecturas de prescripción) y la cola offline. `ClientTrainingModel` y `CompanionPhoneGateway` pasan a llamarlo en lugar de escribir directo a la API.
*Alternativa:* corregir los dos call sites por separado. Se descarta porque hoy ya divergen (por ejemplo, el gateway no encola offline) y el bug volvería a aparecer.

### D2. Estado activo ampliado en `ActiveTrainingSessionSnapshot`

El snapshot pasa a describir una **ejecución**:

- `trainingSessionId`: el id de la sesión prescrita; hoy `sessionId` tiene otro significado.
- `completionLocalId`: UUID local, estable.
- `completionServerId?`: `nil` mientras está en cola.
- `planId` y `planName`.
- `startedAt`.
- Por ejercicio prescrito: `executionId`, `exerciseId`, nombre, `prescribedReps: [Int]`, `doneSetIndexes` y `startedAt?` (primera serie marcada).
- Por ejercicio completado: `completedAt`, `energyAtStart?` y `kcal` con su origen.

El snapshot es la fuente del progreso local. Viaja al Watch dentro de `CompanionSyncSnapshot`, que sube de versión y reemplaza `executionCount`/`setCount` por la lista de ejercicios con progreso.
*Alternativa:* volver a leer de la API en cada refresh. No sirve, porque las series marcadas no existen en la API.

### D3. Ids locales y remapeo en la cola offline

Como el servidor ignora el `id` del cliente, la cola trabaja con ids locales:

- `createSessionCompletion(localId, payload)`: al aplicarse, guarda `localId → serverId` en el archivo de la cola y actualiza `completionServerId` en el snapshot activo, si coincide.
- `createExerciseCompletion(sessionCompletionLocalId, payload)`: antes de enviarse resuelve `trainingSessionCompletionId` con el mapa.
- `finishSessionCompletion(localId, payload)`: `PUT` con todos los campos y `EndDate`, resuelto igual.

Online se usa el mismo camino: se encola y se hace `flush` enseguida. Así hay un solo código para los dos modos.
*Alternativa:* encolar solo cuando falla. Se descarta: obliga a manejar dos rutas y deja carreras cuando una mutación online depende de una que quedó en cola.

**Errores:**
- Se reintenta ante `URLError`, 5xx, 408 y 429.
- El 401 sigue el flujo de refresh actual y se reintenta.
- Cualquier otro 4xx descarta el registro, lo deja en un log de "descartados" visible para el usuario como error, y la cola sigue.
- Los registros con `kind` desconocido (los tipos viejos) se descartan al cargar, en lugar de vaciar el archivo entero como hace hoy el `try?`.

### D4. Inicio de ejercicio = primera serie marcada

`ExerciseCompletion.StartDate` es la hora de la primera serie marcada. Si se completa sin marcar series, se usa la hora de fin del ejercicio completado anterior y, si no hay ninguno, el inicio de la sesión. Se elimina el `-300s` fijo.
*Alternativa:* un botón explícito de "empezar ejercicio". Agrega un toque por ejercicio sin dar más información.

### D5. Atribución de kcal en el iPhone

La atribución la calcula Core en el iPhone, que es el que escribe en la API:

- **Lectura de energía:**
  - Si la acción viene del Watch (`markSet`, `completeExercise`), el mensaje trae `energyKcal` con el acumulado exacto de `HKLiveWorkoutBuilder` en ese instante.
  - Si la acción se hace en el iPhone, se usa el último `CompanionWorkoutMetrics.activeEnergyKilocalories` siempre que `isFresh` (≤ 30 s) y que corresponda a la misma sesión.
- **Medido:** cuando hay lectura al inicio (primera serie) y al completar: `kcal = max(0, fin − inicio)`, con origen `healthkit`.
- **Estimado:** en cualquier otro caso: `kcal = CaloriesBurnRate × Σ prescribedReps` (0 si falta alguno de los dos), con origen `estimated`.
- El origen se guarda en un mapa local `exerciseCompletion → source`, persistido en Core por id local y luego por id de servidor. **No** se envía a la API.

*Alternativa:* atribuir en el Watch. Se descarta porque las acciones del iPhone no pasan por el Watch y la lógica quedaría partida.

### D6. Vínculo HKWorkout ↔ completion

- Antes de `builder.finishWorkout()`, el Watch toma `completionServerId` del último snapshot recibido.
- Si no es `nil`, llama a `builder.addMetadata([HKMetadataKeyExternalUUID: id])`. Si es `nil`, guarda el workout sin metadata.
- `endWorkout()` deja de descartar el `HKWorkout`. Se conserva su UUID solo para log y diagnóstico, no se envía a ningún lado.
- Si el iPhone termina la sesión, el Watch detecta un snapshot sin sesión activa mientras su workout sigue corriendo, y ejecuta el mismo cierre.
- Para que el id del servidor esté disponible lo antes posible, el gateway publica un snapshot nuevo apenas la cola resuelve `localId → serverId`.

### D7. Selección de sesión prescrita e historial

- **Detalle del plan:** muestra dos secciones:
  - "Sesiones": las prescritas, ordenadas por la posición en que llegan de la API, con la etiqueta "Sesión N" y un resumen de los nombres de sus ejercicios, cada una con su botón "Iniciar".
  - "Historial": las `training-session-completions` filtradas en el cliente por `memberId` y `trainingPlanId`, ordenadas por `startDate` descendente.
- **Detalle de una entrada del historial:** `exercise-completions` filtradas por `trainingSessionCompletionId`, unidas a las ejecuciones y ejercicios para mostrar nombres, junto con la duración y la suma de kcal.
- **Watch:** `CompanionPlanItem` incluye sus sesiones con la misma etiqueta y resumen, así el Watch puede iniciar sin pedir más datos.

El orden de "Sesión N" depende del orden en que responde la API (`OrderBy Id`, un `Guid`). Es estable pero arbitrario. Queda como límite conocido hasta el pedido 5 (nombre y orden).

### D8. La corrida se escribe al completar el primer ejercicio

Iniciar solo activa la sesión en el dispositivo (`completionQueued = false`). El `TrainingSessionCompletion` se encola con `StartDate` = hora real de inicio junto con el primer `ExerciseCompletion`; finalizar sin ningún ejercicio completado limpia la sesión activa sin escribir nada.
*Alternativa:* crear la completion al iniciar y borrarla (`DELETE`) si se finaliza vacía. Se descarta: deja un registro intermedio visible en la API, falla si el borrado queda offline, y exige un nuevo tipo de mutación en la cola.
*Consecuencia:* el id del servidor aparece recién tras el primer ejercicio completado, así que un workout de HealthKit de una corrida sin ejercicios completados queda sin vínculo, que es lo correcto porque no hay completion a la que apuntar. Las sesiones activas guardadas antes de este cambio se leen como ya escritas.

## Risks / Trade-offs

- [Las kcal estimadas suponen que el cliente hizo lo prescrito] → El origen local `estimated` se muestra en el historial. El pedido 4 lo resuelve del lado del servidor.
- [El origen de las kcal se pierde en otro dispositivo o al reinstalar] → Se muestra sin etiqueta (spec `training-calories`). Es aceptable hasta el pedido 4.
- [Los vitals del iPhone llegan throttled (~cada pocos segundos), así que las kcal medidas desde acciones del iPhone tienen error de unos segundos] → Las acciones del Watch mandan el valor exacto; el error es menor a la cadencia de publicación.
- [Si la sesión arranca offline, el workout queda sin vínculo] → Decisión explícita: no inventar ids. El pedido 2 lo elimina.
- [Bajar las tablas completas de completions y exercise-completions crece con el uso] → Se filtra en el cliente y se cachea por pantalla. El pedido 6 lo resuelve.
- [Las sesiones vacías creadas antes de este change siguen en los planes y en la lista "Sesiones"] → Se ocultan del selector las sesiones sin ejecuciones prescritas. La limpieza en la base queda fuera de alcance.
- [Al subir la versión de `CompanionSyncSnapshot`, un Watch con build vieja no entiende el nuevo formato] → Ambos targets se distribuyen juntos. El Watch ignora snapshots de versión desconocida y pide `fullSync`.

## Migration Plan

1. Implementar Core (D1–D3, D5) y migrar `ClientTrainingModel` y `CompanionPhoneGateway`.
2. Actualizar el Watch (D2, D6).
3. Al primer arranque con la versión nueva, un snapshot activo con el formato viejo no se puede leer y se descarta (la sesión vieja no se puede continuar). Lo mismo pasa con los registros viejos de la cola.
4. Rollback: volver a la build anterior. Los datos que escribió este change (completions) son válidos para el backend y no rompen nada en la versión vieja, que simplemente no los muestra.
