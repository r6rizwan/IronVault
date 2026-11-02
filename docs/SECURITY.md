# Security

## Security model

IronVault is an offline-first vault. Vault data is encrypted before storage, the master PIN is stored as a hash, and the app does not use cloud sync. Optional biometric authentication uses platform APIs.

Recovery keys are hidden by default and require re-authentication before reveal. Reveal supports biometrics or PIN fallback. The raw recovery key is kept temporarily until the user confirms it has been saved. Repeated incorrect PIN attempts trigger a persistent cooldown.

The app also supports clipboard clearing for copied sensitive fields. On Android, screenshot and recents-preview protection is enabled at the activity level. Sentry crash reporting is enabled in release builds with safe metadata capture.

## Limitations

- Screenshot and recents privacy behavior can vary by Android version, launcher, and device manufacturer.
- Biometric availability depends on device hardware and enrollment state.
- Auto-lock applies to app background/resume behavior, not true on-screen idle time.
- iOS code exists but has not been production-validated in this repository.
- Autofill service integration is currently disabled or limited by design.

These controls reduce specific risks but do not make a compromised or unsupported device safe for storing secrets.

## Reporting a vulnerability

Do not post recovery keys, vault contents, credentials, or exploitable details in a public issue. Use GitHub's private vulnerability reporting for this repository if available; otherwise contact the maintainer privately through the `r6rizwan` GitHub account before public disclosure.
