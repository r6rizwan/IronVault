# Changelog

## v1.0.17

- Bug fixes and reliability improvements when installing or updating the Android app, including if you also run preview builds from a computer.

## v1.0.16

- Bug fixes and reliability improvements for installing and updating the Android app.

## v1.0.15

- Added proper Android release-signing support for local and GitHub Actions builds.
- Updated the release workflow to rebuild the keystore from GitHub Actions secrets before creating the APK.
- Switched GitHub Release notes from generic auto-generation to changelog-based release notes.
- Fixed the release-signing path so future APK releases can install as updates instead of conflicting with existing installs.
- Fixed encrypted backup export for document items with scanned pages.
- Fixed document sharing so scanned document files are attached instead of only sharing metadata.

## v1.0.14

- Internal maintenance release.
- Added GitHub Actions workflows for analyzer checks and automated APK releases.
- Replaced the stale default widget smoke test with a real onboarding screen smoke test.
- Cleaned up `pubspec.yaml` template comments.
