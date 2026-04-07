import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ironvault/core/services/crash_reporter.dart';

class AppUpdateInfo {
  final String latestVersion;
  final String apkUrl;
  final String releaseNotes;

  AppUpdateInfo({
    required this.latestVersion,
    required this.apkUrl,
    required this.releaseNotes,
  });

  String get displayVersion => AppUpdateService.displayVersion(latestVersion);
}

class AppUpdateCheckResult {
  final AppUpdateInfo? info;
  final bool success;
  final bool offline;

  const AppUpdateCheckResult({
    required this.info,
    required this.success,
    this.offline = false,
  });
}

class AppUpdateService {
  // Replace with your GitHub owner/repo
  static const String owner = 'r6rizwan';
  static const String repo = 'IronVault';
  static const String apiBase = 'https://api.github.com/repos/$owner/$repo';
  static const Duration _requestTimeout = Duration(seconds: 12);

  static String displayVersion(String version) {
    return version.trim().split('+').first;
  }

  Future<AppUpdateInfo?> checkForUpdate() async {
    final result = await checkForUpdateResult();
    return result.success ? result.info : null;
  }

  Future<bool> hasNetworkConnection() async {
    final connectivityResults = await Connectivity().checkConnectivity();
    return connectivityResults.any(
      (result) => result != ConnectivityResult.none,
    );
  }

  Future<AppUpdateCheckResult> checkForUpdateResult() async {
    try {
      final hasConnection = await hasNetworkConnection();
      if (!hasConnection) {
        return const AppUpdateCheckResult(
          info: null,
          success: false,
          offline: true,
        );
      }

      final info = await PackageInfo.fromPlatform();
      final current = _currentInstalledVersion(info);

      final res = await http
          .get(Uri.parse('$apiBase/releases/latest'))
          .timeout(_requestTimeout);
      if (res.statusCode != 200) {
        await CrashReporter.captureMessage(
          'Update check returned non-200 status',
          feature: 'updates',
          action: 'check_for_update',
          extras: {'status_code': res.statusCode},
        );
        return const AppUpdateCheckResult(info: null, success: false);
      }

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final tag = (json['tag_name'] ?? '').toString().replaceFirst('v', '');
      final notes = (json['body'] ?? '').toString();
      final assets = (json['assets'] as List<dynamic>? ?? []);

      String? apkUrl;
      for (final a in assets) {
        final name = (a['name'] ?? '').toString().toLowerCase();
        if (name.endsWith('.apk')) {
          apkUrl = (a['browser_download_url'] ?? '').toString();
          break;
        }
      }

      if (apkUrl == null || tag.isEmpty) {
        return const AppUpdateCheckResult(info: null, success: false);
      }

      if (_isNewerVersion(tag, current)) {
        return AppUpdateCheckResult(
          info: AppUpdateInfo(
            latestVersion: tag,
            apkUrl: apkUrl,
            releaseNotes: notes,
          ),
          success: true,
        );
      }

      return const AppUpdateCheckResult(info: null, success: true);
    } on TimeoutException catch (error, stackTrace) {
      await CrashReporter.captureException(
        error,
        stackTrace,
        feature: 'updates',
        action: 'check_for_update',
        extras: {'timeout_seconds': _requestTimeout.inSeconds},
      );
      return const AppUpdateCheckResult(info: null, success: false);
    } catch (error, stackTrace) {
      await CrashReporter.captureException(
        error,
        stackTrace,
        feature: 'updates',
        action: 'check_for_update',
      );
      return const AppUpdateCheckResult(info: null, success: false);
    }
  }

  String _currentInstalledVersion(PackageInfo info) {
    final build = info.buildNumber.trim();
    if (build.isEmpty) return info.version.trim();
    return '${info.version.trim()}+$build';
  }

  bool _isNewerVersion(String latest, String current) {
    final latestParts = _parseVersionParts(latest);
    final currentParts = _parseVersionParts(current);
    final len = latestParts.length > currentParts.length
        ? latestParts.length
        : currentParts.length;

    for (var i = 0; i < len; i++) {
      final lv = i < latestParts.length ? latestParts[i] : 0;
      final cv = i < currentParts.length ? currentParts[i] : 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
  }

  List<int> _parseVersionParts(String version) {
    final normalized = version.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final segments = normalized.split('+');
    final semverParts = segments.first
        .split('.')
        .map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0);
    final buildPart = segments.length > 1
        ? int.tryParse(segments[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0
        : 0;

    return [...semverParts, buildPart];
  }
}
