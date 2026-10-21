import 'dart:convert' show jsonDecode;

import 'package:flutter/services.dart' show rootBundle;

/// Ported from src/lib/quran.ts — full Qalun mushaf (77,431 words) loaded
/// from the bundled qalun.json asset.

class QuranSurah {
  final int number;
  final String nameAr;
  final String nameEn;
  final String revelation;
  final bool hasBasmalah;
  final int ayahCount;
  final int firstAyah;

  const QuranSurah({
    required this.number,
    required this.nameAr,
    required this.nameEn,
    required this.revelation,
    required this.hasBasmalah,
    required this.ayahCount,
    required this.firstAyah,
  });
}

class QuranAyah {
  final int number;
  final String text;
  const QuranAyah(this.number, this.text);
}

class SurahContent {
  final QuranSurah surah;
  final String? basmalah;
  final List<QuranAyah> ayahs;
  const SurahContent(this.surah, this.basmalah, this.ayahs);
}

class QuranData {
  static late final List<QuranSurah> surahs;
  static late final String riwaya;
  static late final List<String> _words;
  static late final List<int> _surahStarts;
  static late final List<int> _ayahStarts;

  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    final raw = await rootBundle.loadString('assets/data/qalun.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    riwaya = (data['mushaf'] as Map<String, dynamic>)['name_ar'] as String;
    _words = (data['words'] as List<dynamic>).cast<String>();
    _surahStarts = (data['surah_starts'] as List<dynamic>)
        .map((e) => (e as num).toInt())
        .toList();
    _ayahStarts = (data['ayah_starts'] as List<dynamic>)
        .map((e) => (e as num).toInt())
        .toList();
    surahs = (data['surahs'] as List<dynamic>)
        .map<QuranSurah>((item) => QuranSurah(
              number: (item['number'] as num).toInt(),
              nameAr: item['name_ar'] as String,
              nameEn: item['name_en'] as String,
              revelation: item['revelation'] as String,
              hasBasmalah: item['has_basmalah'] as bool,
              ayahCount: (item['ayah_count'] as num).toInt(),
              firstAyah: (item['first_ayah'] as num).toInt(),
            ))
        .toList();
    _loaded = true;
  }

  static SurahContent? getSurah(int number) {
    for (final surah in surahs) {
      if (surah.number != number) continue;

      final ayahs = List<QuranAyah>.generate(surah.ayahCount, (localIndex) {
        final globalIndex = surah.firstAyah + localIndex;
        final start = _ayahStarts[globalIndex];
        final end = globalIndex + 1 < _ayahStarts.length
            ? _ayahStarts[globalIndex + 1]
            : _words.length;
        return QuranAyah(localIndex + 1, _words.sublist(start, end).join(' '));
      });

      final firstVerseStart = _ayahStarts[surah.firstAyah];
      final surahStart = _surahStarts[number - 1];
      final sourceBasmalah =
          _words.sublist(_surahStarts[0], _ayahStarts[0]).join(' ');
      final basmalah = surah.hasBasmalah
          ? (firstVerseStart > surahStart
              ? _words.sublist(surahStart, firstVerseStart).join(' ')
              : sourceBasmalah)
          : null;

      return SurahContent(surah, basmalah, ayahs);
    }
    return null;
  }
}
