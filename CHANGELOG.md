# Changelog

## v1.0.20

- Fixed document preview handling for PDF and other non-image attachments so they no longer appear as blank screens.
- Improved attachment previews for document items to show file-style fallback UI for non-image files.
- Bumped the app version metadata for the attachment preview fix.

## v1.0.19

- Added support for attaching and storing broader document files, including PDFs and other non-image formats, in document items.
- Improved document attachment previews so non-image files are displayed with a file-style preview instead of being treated like images.
- Updated the app version metadata for the new attachment support.

## v1.0.18

- Refined recovery-key management and re-authentication behavior.
- Improved password-health guidance and draft-restore protections.
- Tightened security, privacy, and update-check reliability across core flows.

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
