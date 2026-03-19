# IronVault

IronVault is an offline-first private vault built with Flutter.  
It stores vault data locally on the device and protects it with strong encryption and app-level authentication.

## Project Overview
- Local-first vault for passwords and sensitive records
- Master PIN authentication with optional biometric unlock
- Encrypted storage for vault entries
- Android document scan/import support
- Manual and startup update checks via GitHub Releases
- In-app privacy, update, issue-reporting, and project-license links from the About screen

## Key Features
- Vault item types:
  - Passwords
  - Bank accounts
  - Cards
  - Secure notes
  - Documents
- Search and filtering
- Category support
- Password health analytics
- Auto-lock with configurable timer and app-switch behavior
- Recovery key flow for PIN recovery with protected reveal
- Recovery key setup that can be resumed until the user confirms it has been saved
- Recovery key regeneration from Settings after re-authentication
- PIN retry cooldown after repeated failed attempts
- Encrypted backup restore plus CSV password import/export

## Security Model
- Vault data is encrypted before storage
- Master PIN is stored as a hash, not plain text
- Optional biometric auth uses platform APIs
- Recovery key is hidden by default and requires re-authentication before reveal
- Recovery key reveal supports biometrics or PIN fallback
- Recovery key raw value is only kept temporarily until the user confirms it has been saved
- Repeated wrong PIN attempts trigger a persistent cooldown
- Clipboard clearing is supported for copied sensitive fields
- Android screenshot and recents-preview protection is enabled at the activity level
- Screenshot/privacy behavior can still vary by platform and OEM implementation

## Ownership, License, and Brand Use
This repository is licensed under MIT for source code reuse as defined in `LICENSE`.

Important:
- The MIT license covers code.
- The project name **IronVault**, logo, icon, and brand assets are not granted as a trademark license.
- If you fork or redistribute, use your own app name, package ID, and branding.

## Tech Stack
- Flutter
- Dart
- Riverpod
- Drift (SQLite) for vault items
- sqflite for category storage
- flutter_secure_storage
- local_auth
- AES-based encryption utilities

## Supported Platforms
- Android: supported
- iOS: code exists but not production-validated in this repo

## Run Locally
```bash
flutter pub get
flutter run
```

## Build Release
APK:
```bash
flutter build apk --release
```

AAB:
```bash
flutter build appbundle --release
```

Output paths:
- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`

## Versioning
Version is maintained in `pubspec.yaml`:
- `versionName` comes from `version`
- `versionCode` comes from the build number suffix

Use Git tags for releases:
- Tags follow the app version format in `pubspec.yaml`

## GitHub Releases Update Flow
The app checks your GitHub Releases and can indicate when a newer version exists.

Recommended release process:
1. Update version in `pubspec.yaml`
2. Build release APK/AAB
3. Create GitHub release with matching tag
4. Upload release artifact(s)

## Repository Structure
```text
lib/
  core/
  data/
  features/
android/
ios/
assets/
```

## Security Rules For Contributors
Never commit signing credentials or keystores:
- `android/app/keystore.jks`
- `android/key.properties`
- `*.keystore`
- `*.jks`
- `.env`
- `.env.*`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `android/local.properties`

## Quality Commands
```bash
dart format .
flutter analyze
```

## Known Limitations
- Some platform behaviors (recents preview/privacy handling) can vary by OEM launcher and Android version.
- Biometric availability depends on device hardware and enrollment state.
- Autofill service integration is currently disabled/limited by design decisions in this project stage.
- Categories still use a separate local database path from the main vault items.

## Disclaimer
This repository is not a Play Store submission package and does not claim Play Store policy compliance by default.
