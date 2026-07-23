import 'dart:js_interop';

const appUpdateSupported = true;
const requiresDownloadMetadata = false;
Uri get appUpdateManifestUri => Uri.base.resolve('version.json');

@JS('forceAppUpdate')
external JSPromise<JSAny?> _forceAppUpdate();

Future<void> forceAppUpdate({
  required String apkUrl,
  required String sha256Digest,
}) async {
  await _forceAppUpdate().toDart;
}
