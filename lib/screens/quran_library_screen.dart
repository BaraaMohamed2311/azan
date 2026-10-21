import 'package:flutter/material.dart';

import '../core/app_ui.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/quran.dart';
import 'surah_screen.dart';

/// Ported from app/(tabs)/quran.tsx — searchable 114-surah library.
class QuranLibraryScreen extends StatefulWidget {
  const QuranLibraryScreen({super.key});

  @override
  State<QuranLibraryScreen> createState() => _QuranLibraryScreenState();
}

class _QuranLibraryScreenState extends State<QuranLibraryScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final query = _search.trim().toLowerCase();
    final filtered = query.isEmpty
        ? QuranData.surahs
        : QuranData.surahs
            .where((surah) =>
                surah.nameAr.contains(_search.trim()) ||
                surah.nameEn.toLowerCase().contains(query) ||
                surah.number.toString() == query)
            .toList();

    return Screen(
      children: [
        PageTitle(
          title: 'القرآن الكريم',
          subtitle:
              'المصحف كاملًا برواية ${QuranData.riwaya} · ١١٤ سورة · يعمل النص دون إنترنت',
        ),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            spacing: 9,
            children: [
              Icon(Icons.search, size: 19, color: colors.mutedForeground),
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => _search = value),
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    hintText: 'ابحث باسم السورة أو رقمها',
                    hintStyle: TextStyle(
                      fontSize: 15,
                      color: colors.mutedForeground,
                      fontFamily: 'Inter',
                      fontFamilyFallback: const ['NotoSansArabic'],
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  style: TextStyle(
                    fontSize: 15,
                    color: colors.foreground,
                    fontFamily: 'Inter',
                    fontFamilyFallback: const ['NotoSansArabic'],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (filtered.isEmpty)
          CardX(
            child: Text(
              'لا توجد سورة بهذا الاسم.',
              textAlign: TextAlign.center,
              style: appText(context, fontSize: 14, color: colors.mutedForeground),
            ),
          )
        else
          Column(
            spacing: 8,
            children: [
              for (final surah in filtered) _surahCard(colors, surah),
            ],
          ),
      ],
    );
  }

  Widget _surahCard(AppColors colors, QuranSurah surah) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(colors.radius + 10),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SurahScreen(surahNumber: surah.number),
          ),
        ),
        child: CardX(
          padding: const EdgeInsets.all(12),
          child: Row(
            spacing: 12,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.secondary,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  toArabicDigits(surah.number),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                    fontFamily: 'Inter',
                    fontFamilyFallback: const ['NotoSansArabic'],
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 3,
                  children: [
                    Text(
                      surah.nameAr,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colors.foreground,
                        fontFamily: 'Inter',
                        fontFamilyFallback: const ['NotoSansArabic'],
                      ),
                    ),
                    Text(
                      '${surah.revelation == 'makki' ? 'مكية' : 'مدنية'} · ${toArabicDigits(surah.ayahCount)} آية',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.mutedForeground,
                        fontFamily: 'Inter',
                        fontFamilyFallback: const ['NotoSansArabic'],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left,
                  size: 17, color: colors.mutedForeground),
            ],
          ),
        ),
      ),
    );
  }
}
