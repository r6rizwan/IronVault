# IronVault

IronVault is an offline-first private vault built with Flutter.  
It stores vault data locally on the device and protects it with strong encryption and app-level authentication.

## Project Overview
- Local-first vault for passwords and sensitive records
- Master PIN authentication with optional biometric unlock
- Welcome screen plus dedicated keypad-based PIN unlock flow
- Encrypted storage for vault entries
- Onboarding focused on local privacy, secure unlock, and recovery-key safety
- Android document scan/import support
- Add-item draft restore to preserve unsaved progress after lock/interruption
- Manual and startup update checks via GitHub Releases
- In-app privacy, update, issue-reporting, and share-app links from the About screen

## Recent Highlights
- Refined Home, Vault, Search, Password Health, and credential detail layouts with theme-aware contrast and clearer spacing.
- Password items support an optional website URL and direct browser opening.
- Credential sharing lets users select which fields to include.
- CSV migration supports column mapping, preview, duplicate handling, and importing rows as new items without matching.
- Encrypted backup v2 verifies archive integrity and remains compatible with v1 backups.
- CSV and encrypted backup exports show a success message with a Share action instead of opening the share sheet immediately.

## Screenshots

<table>
  <tr>
    <td align="center"><b>Login</b><br><img src="screenshots/ironvault_login.jpeg" width="400"></td>
    <td align="center"><b>Vault Home</b><br><img src="screenshots/ironvault_dashboard.jpeg" width="400"></td>
  </tr>
  <tr>
    <td align="center"><b>Password List</b><br><img src="screenshots/ironvault_password_list.jpeg" width="400"></td>
    <td align="center"><b>Password Health</b><br><img src="screenshots/ironvault_password_health.jpeg" width="400"></td>
  </tr>
  <tr>
    <td align="center"><b>Add / Edit Item</b><br><img src="screenshots/ironvault_add_edit_item.jpeg" width="400"></td>
    <td align="center"><b>Settings</b><br><img src="screenshots/ironvault_settings.jpeg" width="400"></td>
  </tr>
</table>

## Key Features
- Vault item types:
  - Passwords
  - Bank accounts
  - Cards
  - Secure notes
  - Documents
- Search and filtering
- Optional website URL on passwords with a direct browser action
- Category support with rename propagation across existing saved items
- Password health scoring with actionable review cards for weak, reused, and old passwords
- Auto-lock with configurable timer and app-switch behavior
- Recovery key flow for PIN recovery with protected reveal
- Recovery key setup that can be resumed until the user confirms it has been saved
- Recovery key management from Settings with re-authentication and manual in-screen generation
- PIN retry cooldown after repeated failed attempts
- New-item draft restore and keep/discard draft prompt on exit
- Encrypted backup restore with integrity and format checks, plus CSV password import/export with column mapping and duplicate choices
- Pull-to-refresh on Vault, Search, and Password Health screens
- One-tap deep links from Password Health into filtered affected items

## Security Model
- Vault data is encrypted before storage; the master PIN is stored as a hash
- IronVault does not use cloud sync
- Recovery key reveal requires re-authentication and supports biometrics or PIN fallback
- PIN retry cooldown and clipboard clearing help reduce common exposure risks
- Android screenshot and recents-preview protection is enabled; behavior can vary by device and OEM
- Sentry crash reporting is enabled for release builds with safe metadata capture

See [Security](docs/SECURITY.md) for security controls, limitations, and reporting guidance.

## Authorship and releases
Early commits appear under the name Rizwan Ahmed and later ones under Rizwan Mulla; both are from GitHub account `r6rizwan`.

Releases through `v1.1.1` were published under MIT; later releases are licensed under GPL-3.0-only. See [LICENSE](LICENSE), [NOTICE](NOTICE), and [release and provenance details](docs/RELEASING.md).

The project name **IronVault**, logo, icon, and brand assets are not granted as a trademark license. If you fork or redistribute, use your own app name, package ID, and branding.

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

## Quick Start
```bash
flutter pub get
flutter run
```

See [Contributing](CONTRIBUTING.md) for development and test commands, and [Releasing](docs/RELEASING.md) for versioning, signing, and GitHub Actions instructions.

## GitHub Releases (in-app update check)
The app can check **GitHub Releases** and tell you when a newer version is available. That flow is independent of Actions: it compares your installed version to published releases.

## Repository Structure
```text
lib/
  core/
  data/
  features/
.github/
  workflows/
android/
ios/
assets/
```

## Known Limitations
- Some platform behaviors (recents preview/privacy handling) can vary by OEM launcher and Android version.
- Biometric availability depends on device hardware and enrollment state.
- Auto-lock timer currently applies to app background/resume behavior, not true on-screen idle timeout.
- Autofill service integration is currently disabled/limited by design decisions in this project stage.
- Categories still use a separate local database path from the main vault items.
- iOS code exists but has not been production-validated in this repo.

See [Security](docs/SECURITY.md) for additional security-specific limitations.

## Disclaimer
This repository is not a Play Store submission package and does not claim Play Store policy compliance by default.
