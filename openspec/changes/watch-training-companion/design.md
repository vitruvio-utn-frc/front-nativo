## Context

Depends on foundation Watch shell, companion session share, and `client-training` Core session model. Independent Watch + URLSession primary path.

## Goals / Non-Goals

**Goals:** Watch training UI, HK workout + HR, start/continue either device, offline via Core.  
**Non-Goals:** Appointments on Watch, complications, API storage of HR time series, staff UI.

## Decisions

### D1: Mirroring
Prefer iPhone start + Watch HK workout (mirrored session when both active). If Watch-only start, HK runs on Watch.

### D2: Activity type
`HKWorkoutActivityType.traditionalStrengthTraining` fixed for v1.

### D3: Metrics boundary
HR/samples stay in HealthKit/Apple Fitness. API receives completions, duration, calories as supported by existing DTOs.

### D4: Connectivity
WCSession optional for “session started” pings only; never sole data path.

## Risks / Trade-offs

- **[Risk] HK permission friction** → Mitigation: training works without HR
- **[Risk] Dual-device session races** → Mitigation: single active session id in Core with clear takeover rules

## Open Questions

- Exact takeover rule when both devices press Start simultaneously — default: highest timestamp wins, other joins
