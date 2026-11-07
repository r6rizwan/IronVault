# Changelog

## v1.2.1

- Added a dedicated Settings flow to erase vault data after master PIN verification and explicit `DELETE` confirmation.
- Wiping now removes vault items, document attachments, custom categories, drafts, private app exports, and recovery/encryption keys while preserving app preferences.
- Prevented silent data loss when changing item types by confirming conversions, carrying compatible fields, and identifying fields that will be dropped.
- Added protected recovery-key copying with the clipboard preference and automatic clearing after 20 seconds; save guidance appears only when a key is displayed.
- Reduced excess spacing on the Home and Vault credential-list screens.
- Kept the privacy cover for backgrounded app states without obscuring the app when the notification shade is opened.

## v1.2.0

- Refined Home, Vault, Search, Password Health, and credential detail layouts with clearer spacing, grouping, and theme-aware contrast.
- Added an optional website URL to password items with a direct open-in-browser action.
- Improved credential sharing with selectable fields and fixed text-only shares when no files are attached.
- Made CSV migration choices explicit before column mapping: check for matches and skip/update them, or import every row as a new item.
- Upgraded encrypted backups to format v2 with SHA-256 integrity verification while retaining restore support for v1 backups.
- Validate selected backup files before requesting a password and report partial restore results clearly.
- Replaced immediate export share sheets with a success toast and an explicit Share action for CSV and encrypted backups.

## v1.1.2

- Unified Home and Vault search access through the same universal search sheet with type, category, and favorites filters.
- Reordered the Home dashboard to surface recent items sooner and compacted the Password Health action.
- Grouped add/edit form fields by item purpose and separated optional notes with contextual guidance.
- Made credential sharing a labeled, visible action while keeping deletion in the secondary menu.
- Unified onboarding and PIN-unlock backgrounds with a shared theme-aware gradient.

## v1.1.1

- Fixed Android release build configuration for Kotlin compiler options and APK staging.

## v1.1.0

- Added smaller Android APK downloads for `armeabi-v7a`, `arm64-v8a`, and `x86_64`, while keeping a universal APK available as a compatibility option.
- Updated in-app update checks to select the APK matching the device's supported ABI.

## v1.0.28

- Added a lifecycle privacy overlay that immediately obscures vault content when IronVault moves to the background, then reveals the appropriate screen only after the auto-lock decision completes.
- Improved bottom-navigation responsiveness by moving update-indicator storage refreshes off the tab-selection path.
- Completed the sensitive-flow audit for clipboard copy, sharing, encrypted backups, CSV exports, and document previews.

## v1.0.26
- Bug fixes and performance improvements 

## v1.0.26

- Fixed tab navigation performance stutter by memoizing local vault data queries.
- Fixed biometric authentication cancellation so closing or cancelling the biometrics prompt no longer triggers an unexpected PIN confirmation dialog.
- Streamlined bottom navigation to 3 core tabs (Home, Vault, Settings) with an ergonomic floating "Add" action button.
- Added universal search sheet accessible from the Home app bar and inline live search in the Vault list.
- Cleaned up the credential detail screen app bar with a 3-dots overflow menu for secondary actions.

## v1.0.25

- Fixed the Home screen update indicator so it appears after a successful manual update check without requiring a full app restart.
- Reduced the automatic startup update-check cache window from 24 hours to 12 hours so new releases are detected sooner.

## v1.0.24

- Minor bug fixes and stability improvements for this release.

## v1.0.23

- Fixed a bug, now deleting a vault item will also remove the attachment files from storage.

## v1.0.22

- Improved the credential detail screen with a shared summary block and type-specific hero sections for passwords, cards, bank accounts, documents, and secure notes.
- Fixed bank account detail rendering so account type and related fields display correctly in the detail screen.
- Preserved original document attachment filenames and now show them across add, manage, and detail views instead of generated storage names.
- Auto-filled the document label from the first picked attachment name when the label is empty.
- Added spacing polish to the document `Manage pages` bottom sheet for clearer file separation.

## v1.0.21

- Fixed document preview handling for PDF and other non-image attachments so they now render in-app instead of appearing as blank screens or filename-only placeholders.
- Improved attachment previews for document items with a proper PDF viewer for supported PDF files.
- Bumped the app version metadata for the attachment preview fix.

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
