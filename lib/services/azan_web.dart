import 'dart:js_interop';

/// Web implementation — thin bridge to web/azan_web.js (window.AzanWeb).

@JS('AzanWeb.permission')
external JSString _permission();

@JS('AzanWeb.requestPermission')
external JSPromise<JSString> _requestPermission();

@JS('AzanWeb.schedule')
external JSNumber _schedule(JSString itemsJson);

@JS('AzanWeb.cancel')
external void _cancel();

@JS('AzanWeb.stop')
external void _stop();

@JS('AzanWeb.test')
external void _test(JSString itemJson);

/// 'granted' | 'denied' | 'default' | 'unsupported'
String permissionStatus() {
  try {
    return _permission().toDart;
  } catch (_) {
    return 'unsupported';
  }
}

Future<String> requestPermission() async {
  try {
    return (await _requestPermission().toDart).toDart;
  } catch (_) {
    return 'unsupported';
  }
}

int schedule(String itemsJson) => _schedule(itemsJson.toJS).toDartInt;

void cancel() {
  try {
    _cancel();
  } catch (_) {}
}

void stop() {
  try {
    _stop();
  } catch (_) {}
}

void test(String itemJson) => _test(itemJson.toJS);
