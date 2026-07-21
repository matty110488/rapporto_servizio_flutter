import 'dart:js_interop';

const appUpdateSupported = true;

@JS('forceAppUpdate')
external JSPromise<JSAny?> _forceAppUpdate();

Future<void> forceAppUpdate() async {
  await _forceAppUpdate().toDart;
}
