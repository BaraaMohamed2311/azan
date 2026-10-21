import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWasm, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio_io_stub.dart'
    if (dart.library.io) 'audio_io_mobile.dart' as audio_io;
import 'audio_web_stub.dart'
    if (dart.library.js_interop) 'audio_web.dart' as audio_web;

/// Ported from src/lib/audio.ts — Qalun reciters from MP3Quran, streaming
/// playback, and per-surah offline caching (IndexedDB on web, files on
/// mobile).

class QalunReciter {
  final int id;
  final String name;
  final String server;
  final List<int> surahList;
  const QalunReciter(this.id, this.name, this.server, this.surahList);
}

const _recitersUrl =
    'https://www.mp3quran.net/api/v3/reciters?language=ar&rewaya=5';
const _downloadPrefix = 'athan-libya:qalun-audio:';

String audioFilename(int surahNumber, int reciterId) =>
    'qalun-$reciterId-${surahNumber.toString().padLeft(3, '0')}.mp3';

String downloadKey(int surahNumber, int reciterId) =>
    '$_downloadPrefix$surahNumber:$reciterId';

String getRecitationUrl(QalunReciter reciter, int surahNumber) =>
    '${reciter.server}${surahNumber.toString().padLeft(3, '0')}.mp3';

Future<List<QalunReciter>> fetchQalunReciters() async {
  http.Response response;
  try {
    response = await http.get(Uri.parse(_recitersUrl)).timeout(
          const Duration(seconds: 12),
        );
  } catch (_) {
    throw Exception('لا يوجد اتصال بالإنترنت لجلب قائمة القرّاء.');
  }
  if (response.statusCode != 200) {
    throw Exception('تعذّر الوصول إلى قائمة القرّاء.');
  }
  final result = jsonDecode(response.body) as Map<String, dynamic>;
  final reciters = result['reciters'] as List<dynamic>? ?? [];
  final parsed = <QalunReciter>[];
  for (final reciter in reciters) {
    final moshafList = reciter['moshaf'] as List<dynamic>? ?? [];
    for (final moshaf in moshafList) {
      final rewayaId = (moshaf['rewaya_id'] as num).toInt();
      final surahTotal = (moshaf['surah_total'] as num).toInt();
      if (rewayaId != 5 || surahTotal != 114) continue;
      final surahList = (moshaf['surah_list'] as String)
          .split(',')
          .map((e) => int.tryParse(e.trim()))
          .whereType<int>()
          .toList();
      if (surahList.length != 114) continue;
      parsed.add(QalunReciter(
        (reciter['id'] as num).toInt(),
        reciter['name'] as String,
        moshaf['server'] as String,
        surahList,
      ));
    }
  }
  return parsed;
}

// ---------------------------------------------------------------------------
// Offline storage
// ---------------------------------------------------------------------------

/// Downloads the surah recording and stores it for offline playback.
/// Returns a playback URI (blob: URL on web, file path on mobile).
Future<String> downloadSurahAudio(
  int surahNumber,
  String url,
  int reciterId,
) async {
  http.Response response;
  try {
    response = await http.get(Uri.parse(url)).timeout(
          const Duration(minutes: 5),
        );
  } catch (_) {
    throw Exception('لا يوجد اتصال بالإنترنت لتنزيل التسجيل.');
  }
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('تعذّر تنزيل التسجيل.');
  }
  final bytes = response.bodyBytes;

  if (kIsWeb || kIsWasm) {
    final stored = await audio_web.idbPut(downloadKey(surahNumber, reciterId), bytes);
    if (!stored) {
      throw Exception('التخزين دون إنترنت غير متاح في هذا المتصفح.');
    }
    final sp = await SharedPreferences.getInstance();
    await sp.setString(downloadKey(surahNumber, reciterId), 'idb');
    return 'idb://${downloadKey(surahNumber, reciterId)}';
  }

  // Mobile: store in the app documents directory via path_provider.
  final dir = await _mobileAudioDirectory();
  final path = '$dir/${audioFilename(surahNumber, reciterId)}';
  await _writeFile(path, bytes);
  final sp = await SharedPreferences.getInstance();
  await sp.setString(downloadKey(surahNumber, reciterId), path);
  return path;
}

/// Returns a playable URI for a previously downloaded recording, if any.
Future<String?> getDownloadedSurahAudio(
  int surahNumber, [
  int? reciterId,
]) async {
  final sp = await SharedPreferences.getInstance();
  String? saved;
  if (reciterId != null) {
    saved = sp.getString(downloadKey(surahNumber, reciterId));
  } else {
    final prefix = '$_downloadPrefix$surahNumber:';
    for (final key in sp.getKeys()) {
      if (key.startsWith(prefix)) {
        saved = sp.getString(key);
        break;
      }
    }
  }
  if (saved == null) return null;

  if (kIsWeb || kIsWasm) {
    if (saved.startsWith('idb://')) {
      saved = saved.substring('idb://'.length);
    }
    final bytes = await audio_web.idbGet(saved);
    return bytes == null ? null : 'idb://$saved';
  }
  return (await _fileExists(saved)) ? saved : null;
}

// ---------------------------------------------------------------------------
// Mobile file helpers (implemented with conditional import)
// ---------------------------------------------------------------------------

Future<String> _mobileAudioDirectory() => audio_io.MobileIo().audioDirectory();

Future<bool> _fileExists(String path) => audio_io.MobileIo().fileExists(path);

Future<void> _writeFile(String path, List<int> bytes) =>
    audio_io.MobileIo().writeFile(path, bytes);

// ---------------------------------------------------------------------------
// Player
// ---------------------------------------------------------------------------

class RecitationPlayer {
  final AudioPlayer _player = AudioPlayer();
  String? _currentUri;

  AudioPlayer get raw => _player;

  /// Resolves `idb://` pseudo-URIs to blob URLs on web before playing.
  Future<void> play(String uri) async {
    var resolved = uri;
    if ((kIsWeb || kIsWasm) && uri.startsWith('idb://')) {
      final key = uri.substring('idb://'.length);
      final bytes = await audio_web.idbGet(key);
      if (bytes == null) {
        throw Exception('تعذّر تشغيل التسجيل. أعد تنزيله.');
      }
      resolved = audio_web.blobUrl(bytes);
    }
    if (resolved != _currentUri) {
      await _player.setUrl(resolved);
      _currentUri = resolved;
    }
    await _player.play();
  }

  /// Loads (if needed) and starts playback; completes once playback starts.
  Future<void> setUrlAndPlay(String uri) async {
    await play(uri);
  }

  Future<void> pause() => _player.pause();

  Future<void> dispose() => _player.dispose();
}


