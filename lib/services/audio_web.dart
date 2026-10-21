import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

const _idbName = 'athan-libya-qalun-audio-v1';
const _idbStore = 'mp3';

Completer<web.IDBDatabase>? _idbOpenCompleter;

Future<web.IDBDatabase> _openDb() {
  if (_idbOpenCompleter != null) return _idbOpenCompleter!.future;
  final completer = Completer<web.IDBDatabase>();
  _idbOpenCompleter = completer;
  final request = web.window.indexedDB.open(_idbName, 1);
  request.onupgradeneeded = ((web.IDBVersionChangeEvent event) {
    final db = (request.result) as web.IDBDatabase;
    if (!db.objectStoreNames.contains(_idbStore)) {
      db.createObjectStore(_idbStore);
    }
  }).toJS;
  request.onsuccess = ((web.Event _) {
    if (!completer.isCompleted) {
      completer.complete(request.result as web.IDBDatabase);
    }
  }).toJS;
  request.onerror = ((web.Event _) {
    if (!completer.isCompleted) {
      completer.completeError(Exception('IndexedDB unavailable'));
    }
  }).toJS;
  return completer.future;
}

Future<Uint8List?> idbGet(String key) async {
  try {
    final db = await _openDb();
    final completer = Completer<Uint8List?>();
    final tx = db.transaction(_idbStore.toJS, 'readonly');
    final store = tx.objectStore(_idbStore);
    final request = store.get(key.toJS);
    request.onsuccess = ((web.Event _) {
      final result = request.result;
      if (result == null) {
        completer.complete(null);
        return;
      }
      final buffer = (result as JSArrayBuffer).toDart;
      completer.complete(Uint8List.view(buffer));
    }).toJS;
    request.onerror = ((web.Event _) {
      if (!completer.isCompleted) completer.complete(null);
    }).toJS;
    final result = await completer.future;
    return result;
  } catch (_) {
    return null;
  }
}

Future<bool> idbPut(String key, Uint8List bytes) async {
  try {
    final db = await _openDb();
    final completer = Completer<void>();
    final tx = db.transaction(_idbStore.toJS, 'readwrite');
    final store = tx.objectStore(_idbStore);
    final request = store.put(bytes.buffer.toJS, key.toJS);
    request.onsuccess = ((web.Event _) {
      if (!completer.isCompleted) completer.complete();
    }).toJS;
    request.onerror = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('IndexedDB write failed'));
      }
    }).toJS;
    await completer.future;
    return true;
  } catch (_) {
    return false;
  }
}

String blobUrl(Uint8List bytes) {
  final blob = web.Blob(
    [bytes.buffer.toJS].toJS,
    web.BlobPropertyBag(type: 'audio/mpeg'),
  );
  return web.URL.createObjectURL(blob);
}

