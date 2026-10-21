import 'dart:typed_data';

/// Non-web stub: IndexedDB is only available in browsers.
Future<Uint8List?> idbGet(String key) async => null;

Future<bool> idbPut(String key, Uint8List bytes) async => false;

String blobUrl(Uint8List bytes) =>
    throw UnsupportedError('Blob URLs are only available on web');
