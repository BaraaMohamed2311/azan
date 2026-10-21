/// Non-web stub — the web prayer-call engine only exists in browsers.
String permissionStatus() => 'unsupported';

Future<String> requestPermission() async => 'unsupported';

int schedule(String itemsJson) => 0;

void cancel() {}

void stop() {}

void test(String itemJson) {}
