# IronVault Password Manager

A modern, offline-first password manager built with Flutter. IronVault stores all vault items locally with AES-256 encryption and supports PIN + biometric authentication.

## Highlights
- Offline-first: all data stored locally on device
- AES-256 encryption for every item
- Master PIN + optional biometrics
- Dynamic item types (passwords, cards, banks, notes, documents)
- Document scanning (Android)
- Categories and favorites
- Password health checks
- In-app update prompt via GitHub Releases

## Screens & Flow
1. Splash → Onboarding
2. Create Master PIN (first install only)
3. Enable biometrics (optional)
4. Auth choice: PIN or biometrics
5. Home → Vault / Search / Settings

## Tech Stack
- Flutter
- Riverpod
- Drift (SQLite)
- flutter_secure_storage
- local_auth
- encrypt (AES-GCM)

## Supported Platforms
- Android (primary)
- iOS (not yet tested)

## Setup
```bash
flutter pub get
flutter run
```

## Build (Android)
```bash
flutter build apk --release
```

Build App Bundle (Play Store format):
```bash
flutter build appbundle --release
```

APK output:
```
build/app/outputs/flutter-apk/app-release.apk
```

## Releases
If you upload demo builds, place them in:
```
/releases
```
Label builds clearly as **Demo build / Not Play Store uploaded**.

## GitHub Releases Update Flow
IronVault checks your GitHub Releases and shows a soft update prompt if a newer version is available.

Steps:
1. Build a release APK:
   ```bash
   flutter build apk --release
   ```
2. Create a GitHub Release with a version tag like `v1.0.2`
3. Upload `app-release.apk` to the release assets

The app compares its version with the release tag and prompts the user to update.

## Configuration
Update checker uses your public repo:
```
lib/core/update/app_update_service.dart
```

## Project Structure
```
lib/
  core/
    theme/
    update/
    utils/
  data/
  features/
```

## Notes
- Android only for document scanning
- Biometric support depends on device hardware and enrollment

## Repository Disclaimer
This repository is **not** a Google Play submission. No Play Store compliance guarantees are implied.

## License
MIT
