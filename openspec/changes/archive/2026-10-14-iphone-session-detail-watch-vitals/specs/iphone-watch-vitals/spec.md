## Purpose

Shows live Apple Watch workout metrics on the iPhone active-session screen while the companion Watch is running a HealthKit workout for that training session.

## ADDED Requirements

### Requirement: Show Watch vitals during active session
While a training session is active on iPhone and the Watch companion has published recent workout metrics, the iPhone active-session UI MUST show heart rate and workout elapsed time when those values are present.

#### Scenario: HR and elapsed visible
- **WHEN** the Watch is delivering non-stale heart rate and elapsed workout time during an active session
- **THEN** the iPhone active-session screen displays those metrics in a Watch vitals area

### Requirement: Show effort energy when available
When the Watch publishes active energy burned (kcal) for the workout, the iPhone MUST display it as effort/energy in the same vitals area; when absent, the UI MUST omit or mark that metric unavailable without blocking other metrics.

#### Scenario: Active energy shown
- **WHEN** companion metrics include active energy kilocalories
- **THEN** iPhone shows that effort/energy value alongside HR and elapsed time

### Requirement: Hide or idle when Watch metrics unavailable
If the Watch is not reachable or has not published recent metrics, the iPhone MUST NOT invent vitals; it MAY hide the strip or show an idle/unavailable state.

#### Scenario: No recent metrics
- **WHEN** no recent Watch workout metrics are available for the active session
- **THEN** the vitals strip is hidden or clearly indicates Watch metrics are unavailable

### Requirement: No raw HR to business API
Companion vitals on iPhone are for display only; the system MUST NOT upload raw heart-rate samples to the training business API as part of this capability.

#### Scenario: Display-only vitals
- **WHEN** Watch heart-rate values appear on iPhone
- **THEN** those samples are not persisted to the training API as raw HR series
