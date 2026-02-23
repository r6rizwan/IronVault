# IronVault Password Manager

IronVault is an offline-first password manager built with Flutter.  
It stores vault data locally on the device and protects it with strong encryption and app-level authentication.

## Project Overview
- Local-first vault for passwords and sensitive records
- Master PIN authentication with optional biometric unlock
- Encrypted storage for vault entries
- Android document scan/import support
- Manual and startup update checks via GitHub Releases

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
- Recovery key flow for PIN recovery
- Export/import flows (JSON + CSV paths in app)

## Security Model
- Vault data is encrypted before storage
- Master PIN is stored as a hash, not plain text
- Optional biometric auth uses platform APIs
- App uses secure window flags on Android to reduce screen capture/recents leakage

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
- Drift (SQLite)
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
- `versionCode` comes from the build number suffix (for example `1.0.2+3`)

Use Git tags for releases:
- Example: `v1.0.2+3`

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

Use example env files for configuration:
- `.env.example` (if needed)

## Quality Commands
```bash
dart format .
flutter analyze
```

## Known Limitations
- Some platform behaviors (recents preview/privacy handling) can vary by OEM launcher and Android version.
- Biometric availability depends on device hardware and enrollment state.
- Autofill service integration is currently disabled/limited by design decisions in this project stage.

## Disclaimer
This repository is not a Play Store submission package and does not claim Play Store policy compliance by default.

