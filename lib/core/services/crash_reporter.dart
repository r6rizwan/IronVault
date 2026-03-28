import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class CrashReporter {
  CrashReporter._();

  static const _dsn =
      'https://ec41b4b92efb2031a52eda1e2e06d385@o4511120882073600.ingest.de.sentry.io/4511120887382096';

  static Future<void> init(Future<void> Function() appRunner) async {
    if (!kReleaseMode) {
      await appRunner();
      return;
    }

    await SentryFlutter.init((options) {
      options.dsn = _dsn;
      options.environment = 'production';
      options.sendDefaultPii = false;
      options.enableAutoSessionTracking = true;
      options.tracesSampleRate = 0;
      options.attachScreenshot = false;
    }, appRunner: appRunner);
  }

  static Future<void> captureException(
    dynamic error,
    StackTrace? stackTrace, {
    String? feature,
    String? action,
    Map<String, Object?> extras = const {},
  }) async {
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        _applyScope(scope, feature: feature, action: action, extras: extras);
      },
    );
  }

  static Future<void> captureMessage(
    String message, {
    SentryLevel level = SentryLevel.info,
    String? feature,
    String? action,
    Map<String, Object?> extras = const {},
  }) async {
    await Sentry.captureMessage(
      message,
      level: level,
      withScope: (scope) {
        _applyScope(scope, feature: feature, action: action, extras: extras);
      },
    );
  }

  static void _applyScope(
    Scope scope, {
    String? feature,
    String? action,
    Map<String, Object?> extras = const {},
  }) {
    final safeContext = <String, Object?>{};
    if (feature != null && feature.isNotEmpty) {
      scope.setTag('feature', feature);
    }
    if (action != null && action.isNotEmpty) {
      scope.setTag('action', action);
    }
    extras.forEach((key, value) {
      if (_blockedKey(key) || value == null) return;
      safeContext[key] = value;
    });
    if (safeContext.isNotEmpty) {
      scope.setContexts('app_context', safeContext);
    }
  }

  static bool _blockedKey(String key) {
    final lower = key.toLowerCase();
    return lower.contains('password') ||
        lower.contains('pin') ||
        lower.contains('recovery') ||
        lower.contains('secret') ||
        lower.contains('token') ||
        lower.contains('title') ||
        lower.contains('notes') ||
        lower.contains('username') ||
        lower.contains('email') ||
        lower.contains('document') ||
        lower.contains('scan') ||
        lower.contains('field') ||
        lower.contains('url');
  }
}
