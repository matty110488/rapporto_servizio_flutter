const appUpdateSupported = false;
const requiresDownloadMetadata = false;
Uri get appUpdateManifestUri => Uri.base.resolve('version.json');

Future<void> forceAppUpdate({
  required String apkUrl,
  required String sha256Digest,
}) async {
  throw UnsupportedError('Aggiornamento web non disponibile.');
}
