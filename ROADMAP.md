# IronVault Local Roadmap

This roadmap captures the recommended next execution plan after `v1.0.5`.

## Current Focus
- Stabilize the app after recent auth/auto-lock lifecycle changes.
- Improve security controls before expanding feature surface.
- Improve import/backup reliability for real-world migration use.

## Phase 1: Stability Sprint (Highest Priority)
Target: 1 week

### Goals
- Catch and fix lifecycle/auth regressions early.
- Improve observability for production bugs.

### Tasks
- Execute full regression pass on real Android device + emulator.
- Verify critical flows:
  - PIN login
  - biometric login
  - auto-lock on app switch
  - auto-lock on phone lock/unlock
  - no lock on notification shade
  - recents privacy behavior
- Integrate crash reporting (Firebase Crashlytics or Sentry).
- Add lightweight analytics events for:
  - login success/failure
  - lock/unlock events
  - import/export usage

### Exit Criteria
- No P0/P1 auth or lock bugs open.
- Crash reporting active in release builds.

## Phase 2: Security Hardening

### Goals
- Reduce shoulder-surfing and unauthorized access risk.
- Strengthen PIN protection behavior.

### Tasks
- Add setting: re-auth before revealing sensitive fields.
- Add optional privacy overlay fallback on app background.
- Add PIN attempt throttling/cooldown (basic lockout policy).
- Audit sensitive flows:
  - share
  - copy
  - export

### Exit Criteria
- Security settings are user-controllable and persisted.
- PIN brute-force mitigation active and tested.

## Phase 3: Import/Backup Maturity

### Goals
- Make migration from other apps practical and reliable.

### Tasks
- Build CSV import mapping UI:
  - map columns
  - preview rows
  - validate required fields
- Add duplicate detection and merge/skip options.
- Add import result summary:
  - imported
  - skipped
  - failed
- Add backup restore verification (checksum + version compatibility).
- Add backup reminder option in settings.

### Exit Criteria
- CSV import works for non-IronVault exports with manual mapping.
- Import and restore outcomes are clearly reported to user.

## Phase 4: Password Health v2

### Goals
- Turn analytics into actionable security guidance.

### Tasks
- Add recommendation panels for:
  - weak passwords
  - reused passwords
  - old passwords
- Add one-tap deep links to filtered affected items.

### Exit Criteria
- User can move from health insight to fix action in 1 tap.

## Phase 5: Quality Engineering

### Goals
- Prevent regressions and standardize release quality.

### Tasks
- Add automated tests:
  - widget tests for auth and settings logic
  - integration tests for full auth + lock lifecycle
  - import/export test coverage
- Add CI checks:
  - `flutter analyze`
  - test suite execution
- Add release checklist document for repeatable releases.

### Exit Criteria
- CI is required for merge/release.
- Critical flows have regression test coverage.

## Recommended Scope for Next Release (`v1.0.6`)

Prioritize these three deliverables:
1. Stability sprint + crash reporting integration.
2. CSV mapping import flow with validation/summary.
3. Security controls:
   - re-auth before sensitive reveal
   - PIN attempt cooldown.

