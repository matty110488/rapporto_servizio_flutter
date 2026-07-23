import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import 'app_update_exception.dart';

const _androidManifestUrl = String.fromEnvironment(
  'ANDROID_UPDATE_MANIFEST_URL',
  defaultValue: 'https://github.com/matty110488/rapporto_servizio_flutter/'
      'releases/latest/download/android-update.json',
);

const _updateChannel = MethodChannel('com.mattia.app_kronos/app_update');

bool get appUpdateSupported => Platform.isAndroid;
bool get requiresDownloadMetadata => true;
Uri get appUpdateManifestUri => Uri.parse(_androidManifestUrl);

Future<void> forceAppUpdate({
  required String apkUrl,
  required String sha256Digest,
}) async {
  if (!Platform.isAndroid) {
    throw const AppUpdateException(
      'L’aggiornamento APK è disponibile solo su Android.',
    );
  }

  final uri = Uri.tryParse(apkUrl);
  if (uri == null || uri.scheme != 'https') {
    throw const AppUpdateException('Indirizzo APK non valido.');
  }

  final response = await http.get(
    uri,
    headers: const {'Cache-Control': 'no-cache'},
  );
  if (response.statusCode != 200) {
    throw AppUpdateException(
      'Download APK non riuscito (${response.statusCode}).',
    );
  }

  final actualDigest = sha256.convert(response.bodyBytes).toString();
  if (actualDigest.toLowerCase() != sha256Digest.trim().toLowerCase()) {
    throw const AppUpdateException(
      'Il file scaricato non ha superato il controllo di integrità.',
    );
  }

  final directory = await getTemporaryDirectory();
  final apk = File('${directory.path}${Platform.pathSeparator}'
      'crono-valtellinesi-update.apk');
  await apk.writeAsBytes(response.bodyBytes, flush: true);

  final result = await OpenFile.open(
    apk.path,
    type: 'application/vnd.android.package-archive',
  );
  if (result.type == ResultType.done) return;
  if (result.type == ResultType.permissionDenied) {
    await _updateChannel.invokeMethod<void>('openInstallPermissionSettings');
    throw const AppUpdateException(
      'Abilita “Consenti da questa fonte”, torna nell’app e premi nuovamente '
      'Aggiorna.',
    );
  }
  throw AppUpdateException(
    result.message.trim().isEmpty
        ? 'Android non è riuscito ad aprire l’APK.'
        : result.message,
  );
}
