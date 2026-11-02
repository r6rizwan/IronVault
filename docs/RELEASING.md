# Releasing IronVault

## Version and changelog

The version is maintained in `pubspec.yaml`. Flutter uses the version name and build number from that value. Increment both for each new app release and add a matching `CHANGELOG.md` heading, such as `## v1.2.0`.

Releases through `v1.1.1` were published under MIT. Later releases are licensed under GPL-3.0-only. See [LICENSE](../LICENSE), [the archived MIT license](../LICENSES/MIT-v1.1.1-and-earlier.txt), and [NOTICE](../NOTICE).

## Automated release

The **Release APK** workflow runs when a `v*` tag is pushed. It builds a universal APK and ABI-specific APKs, verifies them, creates or updates a GitHub Release, and uploads the artifacts. Release notes are taken from the matching `## <tag>` section in `CHANGELOG.md`.

Recommended sequence:

1. Update `version` in `pubspec.yaml`.
2. Add the matching release notes section to `CHANGELOG.md`.
3. Commit and push the release changes to `main`.
4. Create and push the matching tag, for example:

   ```bash
   git tag -a v1.2.0 -m "v1.2.0"
   git push origin v1.2.0
   ```

The workflow can also be started manually. The checked-out ref and the supplied tag input must refer to the same commit; the workflow does not currently validate that they match. Prefer the tag-push trigger unless a manual run is needed.

Artifacts include the universal APK and APKs for `armeabi-v7a`, `arm64-v8a`, and `x86_64`. Most current Android phones use `arm64-v8a`; the universal APK is the fallback. The in-app updater selects an ABI-specific APK when available.

## Android signing

Configure these repository secrets in GitHub Actions settings:

| Secret | Purpose |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded release keystore |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Signing key alias |
| `ANDROID_KEY_PASSWORD` | Signing key password |

The workflow writes the keystore and `android/key.properties` on the runner. Do not commit either file. Local signed release builds also require `android/key.properties` and the keystore; release builds intentionally fail when the signing configuration is absent.

## Verify an APK

Verify provenance for an official release APK with GitHub CLI:

```bash
gh attestation verify APK_FILE --repo r6rizwan/IronVault
```

Official signing certificate SHA-256: `51:CC:6A:52:5F:82:BA:52:E5:A7:15:39:AB:D7:B2:86:89:DA:36:F5:73:BA:49:FB:D7:1C:D6:EF:13:61:D5:2E` (signing key created 13 May 2026).

## Repository provenance

- Repository created on GitHub: 2025-11-16.
- First commit: 2025-11-16.
- `com.ironvault.app` first appears in the repository: 2025-11-17.
- First release `v1.0.0`: 2026-02-03.
- Latest release at the time this guide was updated, `v1.1.1`: 2026-10-21.

Archive records:

- [Wayback Machine: repository](https://web.archive.org/web/20261102063033/https://github.com/r6rizwan/IronVault)
- [Wayback Machine: releases](https://web.archive.org/web/20261102063514/https://github.com/r6rizwan/IronVault/releases)
- [Software Heritage snapshot](https://archive.softwareheritage.org/swh:1:snp:3479f9ef2c24b41599aa73f35dfccb4da9295136;origin=https://github.com/r6rizwan/IronVault)
