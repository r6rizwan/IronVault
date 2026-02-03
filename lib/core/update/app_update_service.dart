import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateInfo {
  final String latestVersion;
  final String apkUrl;
  final String releaseNotes;

  AppUpdateInfo({
    required this.latestVersion,
    required this.apkUrl,
    required this.releaseNotes,
  });
}

class AppUpdateService {
  // TODO: Replace with your GitHub owner/repo
  static const String owner = 'r6rizwan';
  static const String repo = 'Password-Manager';
  static const String apiBase = 'https://api.github.com/repos/$owner/$repo';

  Future<AppUpdateInfo?> checkForUpdate() async {
    final info = await PackageInfo.fromPlatform();
    final current = info.version;

    final res = await http.get(Uri.parse('$apiBase/releases/latest'));
    if (res.statusCode != 200) return null;

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final tag = (json['tag_name'] ?? '').toString().replaceFirst('v', '');
    final notes = (json['body'] ?? '').toString();
    final assets = (json['assets'] as List<dynamic>? ?? []);

    // Find the first APK asset
    String? apkUrl;
    for (final a in assets) {
      final name = (a['name'] ?? '').toString().toLowerCase();
      if (name.endsWith('.apk')) {
        apkUrl = (a['browser_download_url'] ?? '').toString();
        break;
      }
    }

    if (apkUrl == null || tag.isEmpty) return null;

    if (_isNewerVersion(tag, current)) {
      return AppUpdateInfo(
        latestVersion: tag,
        apkUrl: apkUrl,
        releaseNotes: notes,
      );
    }

    return null;
  }

  bool _isNewerVersion(String latest, String current) {
    List<int> parse(String v) => v
        .split('.')
        .map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();

    final l = parse(latest);
    final c = parse(current);
    final len = l.length > c.length ? l.length : c.length;

    for (var i = 0; i < len; i++) {
      final lv = i < l.length ? l[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
  }
}
