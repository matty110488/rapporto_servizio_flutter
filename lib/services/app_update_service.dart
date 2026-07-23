import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'app_update_exception.dart';
import 'app_update_service_stub.dart'
    if (dart.library.io) 'app_update_service_io.dart'
    if (dart.library.js_interop) 'app_update_service_web.dart' as platform;

const _compiledAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '2.1.1+22',
);

bool get appUpdateSupported => platform.appUpdateSupported;

String get currentAppVersionLabel => _formatVersion(_compiledAppVersion);

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    this.androidApkUrl = '',
    this.androidSha256 = '',
  });

  final String currentVersion;
  final String latestVersion;
  final String androidApkUrl;
  final String androidSha256;

  String get latestVersionLabel => _formatVersion(latestVersion);
}

AppUpdateInfo? _lastAvailableUpdate;

Future<AppUpdateInfo?> checkForAppUpdate() async {
  if (!appUpdateSupported) return null;

  final baseUri = platform.appUpdateManifestUri;
  final uri = baseUri.replace(
    queryParameters: {
      ...baseUri.queryParameters,
      '_update_check': DateTime.now().millisecondsSinceEpoch.toString(),
    },
  );
  final response = await http.get(
    uri,
    headers: const {'Cache-Control': 'no-cache'},
  );
  if (response.statusCode != 200) return null;

  final payload = jsonDecode(response.body);
  if (payload is! Map<String, dynamic>) return null;
  final packageInfo = await PackageInfo.fromPlatform();
  final buildNumber = packageInfo.buildNumber.trim();
  final installedVersion = buildNumber.isEmpty
      ? packageInfo.version
      : '${packageInfo.version}+$buildNumber';
  final update = appUpdateFromVersionPayload(
    payload,
    currentVersion: installedVersion,
  );
  _lastAvailableUpdate = update;
  return update;
}

AppUpdateInfo? appUpdateFromVersionPayload(
  Map<String, dynamic> payload, {
  required String currentVersion,
}) {
  final version = payload['version']?.toString().trim() ?? '';
  final buildNumber = payload['build_number']?.toString().trim() ?? '';
  if (version.isEmpty) return null;
  final latestVersion = buildNumber.isEmpty ? version : '$version+$buildNumber';
  if (!_isNewerVersion(latestVersion, currentVersion)) return null;
  final android = payload['android'];
  final androidPayload =
      android is Map ? Map<String, dynamic>.from(android) : const {};
  return AppUpdateInfo(
    currentVersion: currentVersion,
    latestVersion: latestVersion,
    androidApkUrl: androidPayload['apk_url']?.toString().trim() ?? '',
    androidSha256:
        androidPayload['sha256']?.toString().trim().toLowerCase() ?? '',
  );
}

Future<void> forceAppUpdate() async {
  if (!appUpdateSupported) {
    throw const AppUpdateException(
      'Aggiornamento non disponibile su questo dispositivo.',
    );
  }
  final update = _lastAvailableUpdate ?? await checkForAppUpdate();
  if (!platform.requiresDownloadMetadata) {
    await platform.forceAppUpdate(apkUrl: '', sha256Digest: '');
    return;
  }
  if (update == null) {
    throw const AppUpdateException('L’app è già aggiornata.');
  }
  if (update.androidApkUrl.isEmpty || update.androidSha256.isEmpty) {
    throw const AppUpdateException(
      'La release Android non contiene APK o checksum.',
    );
  }
  await platform.forceAppUpdate(
    apkUrl: update.androidApkUrl,
    sha256Digest: update.androidSha256,
  );
}

bool _isNewerVersion(String candidate, String current) {
  final candidateParts = _versionParts(candidate);
  final currentParts = _versionParts(current);
  final candidateBuild = candidateParts.$2;
  final currentBuild = currentParts.$2;
  if (candidateBuild != null && currentBuild != null) {
    return candidateBuild > currentBuild;
  }

  final candidateVersion = candidateParts.$1;
  final currentVersion = currentParts.$1;
  final maxLength = candidateVersion.length > currentVersion.length
      ? candidateVersion.length
      : currentVersion.length;
  for (var index = 0; index < maxLength; index++) {
    final candidateValue =
        index < candidateVersion.length ? candidateVersion[index] : 0;
    final currentValue =
        index < currentVersion.length ? currentVersion[index] : 0;
    if (candidateValue != currentValue) {
      return candidateValue > currentValue;
    }
  }
  return false;
}

(List<int>, int?) _versionParts(String value) {
  final split = value.trim().split('+');
  final version =
      split.first.split('.').map((part) => int.tryParse(part) ?? 0).toList();
  final build = split.length > 1 ? int.tryParse(split.last) : null;
  return (version, build);
}

String _formatVersion(String value) {
  final parts = value.split('+');
  if (parts.length != 2 || parts.last.trim().isEmpty) return value;
  return '${parts.first} (${parts.last})';
}
