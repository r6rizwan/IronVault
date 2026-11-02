# Contributing

## Development setup

Install Flutter, then fetch dependencies and run the app:

```bash
flutter pub get
flutter run
```

Before submitting changes, run:

```bash
dart format .
flutter analyze
flutter test
```

For local release builds and release credentials, follow [the release guide](docs/RELEASING.md).

## Sensitive local files

Never commit signing credentials, keystores, or local configuration files:

- `android/app/keystore.jks`
- `android/key.properties`
- `*.keystore`
- `*.jks`
- `.env` and `.env.*`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `android/local.properties`

See [Security](docs/SECURITY.md) before reporting security-sensitive issues.
