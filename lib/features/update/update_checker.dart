import 'dart:convert';

import 'package:http/http.dart' as http;

const _repo = 'thunyataps/food_diary';

class ReleaseInfo {
  ReleaseInfo({required this.version, required this.apkDownloadUrl});
  final String version;
  final String apkDownloadUrl;
}

/// Compares two `MAJOR.MINOR.PATCH`-shaped version strings (a leading `v`
/// and any missing trailing component are tolerated). Returns true when
/// [latest] is strictly newer than [current].
bool isNewerVersion({required String latest, required String current}) {
  final l = _parseVersion(latest);
  final c = _parseVersion(current);
  for (var i = 0; i < 3; i++) {
    if (l[i] != c[i]) return l[i] > c[i];
  }
  return false;
}

List<int> _parseVersion(String version) {
  final cleaned = version.startsWith('v') ? version.substring(1) : version;
  // Drop a build suffix like "+3" (pubspec-style) before splitting.
  final core = cleaned.split('+').first;
  final parts = core.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  return List.generate(3, (i) => i < parts.length ? parts[i] : 0);
}

ReleaseInfo parseLatestRelease(Map<String, dynamic> json) {
  final tagName = json['tag_name'] as String;
  final version = tagName.startsWith('v') ? tagName.substring(1) : tagName;
  final assets = json['assets'] as List;
  final apkAsset = assets.cast<Map<String, dynamic>>().firstWhere(
    (a) => (a['name'] as String).endsWith('.apk'),
    orElse: () => throw Exception('Release $tagName has no .apk asset'),
  );
  return ReleaseInfo(
    version: version,
    apkDownloadUrl: apkAsset['browser_download_url'] as String,
  );
}

class UpdateChecker {
  /// Returns the latest release's info if it's newer than [currentVersion],
  /// or null if the app is already up to date.
  Future<ReleaseInfo?> checkForUpdate(String currentVersion) async {
    final response = await http.get(
      Uri.parse('https://api.github.com/repos/$_repo/releases/latest'),
      headers: {'Accept': 'application/vnd.github+json'},
    );
    if (response.statusCode != 200) {
      throw Exception('Could not check for updates (${response.statusCode})');
    }
    final release = parseLatestRelease(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    if (!isNewerVersion(latest: release.version, current: currentVersion)) {
      return null;
    }
    return release;
  }
}
