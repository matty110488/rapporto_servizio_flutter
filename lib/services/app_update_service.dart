import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_update_service_stub.dart'
    if (dart.library.js_interop) 'app_update_service_web.dart' as platform;

const _compiledAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '2.0.2+20',
);

bool get appUpdateSupported => platform.appUpdateSupported;

String get currentAppVersionLabel => _formatVersion(_compiledAppVersion);

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
  });

  final String currentVersion;
  final String latestVersion;

  String get latestVersionLabel => _formatVersion(latestVersion);
}

Future<AppUpdateInfo?> checkForAppUpdate() async {
  if (!appUpdateSupported) return null;

  final baseUri = Uri.base.resolve('version.json');
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
  return appUpdateFromVersionPayload(
    payload,
    currentVersion: _compiledAppVersion,
  );
}

AppUpdateInfo? appUpdateFromVersionPayload(
  Map<String, dynamic> payload, {
  required String currentVersion,
}) {
  final version = payload['version']?.toString().trim() ?? '';
  final buildNumber = payload['build_number']?.toString().trim() ?? '';
  if (version.isEmpty) return null;
  final latestVersion = buildNumber.isEmpty ? version : '$version+$buildNumber';
  if (latestVersion == currentVersion) return null;
  return AppUpdateInfo(
    currentVersion: currentVersion,
    latestVersion: latestVersion,
  );
}

Future<void> forceAppUpdate() => platform.forceAppUpdate();

String _formatVersion(String value) {
  final parts = value.split('+');
  if (parts.length != 2 || parts.last.trim().isEmpty) return value;
  return '${parts.first} (${parts.last})';
}
