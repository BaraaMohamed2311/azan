import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_ui.dart';
import '../core/format.dart' show toArabicDigits;
import '../core/theme.dart';
import '../data/adhkar.dart';

/// Ported from app/(tabs)/athkar.tsx — daily dhikr counters persisted per day.
class AthkarScreen extends StatefulWidget {
  const AthkarScreen({super.key});

  @override
  State<AthkarScreen> createState() => _AthkarScreenState();
}

class _AthkarScreenState extends State<AthkarScreen> {
  DhikrGroup _group = DhikrGroup.morning;
  Map<String, int> _counts = {};
  bool _loaded = false;
  String? _storageKey;

  static const _groups = <({DhikrGroup group, String label})>[
    (group: DhikrGroup.morning, label: 'الصباح'),
    (group: DhikrGroup.evening, label: 'المساء'),
    (group: DhikrGroup.afterPrayer, label: 'بعد الصلاة'),
  ];

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  String get _todayKey {
    final now = DateTime.now();
    return 'athan-libya:dhikr:${now.year}-${now.month}-${now.day}';
  }

  Future<void> _loadCounts() async {
    try {
      final sp = await SharedPreferences.getInstance();
      _storageKey = _todayKey;
      final raw = sp.getString(_todayKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _counts = decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
      }
    } catch (_) {}
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _persist() async {
    if (!_loaded || _storageKey == null) return;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_storageKey!, jsonEncode(_counts));
    } catch (_) {}
  }

  void _increment(DhikrItem item) {
    setState(() {
      _counts = {
        ..._counts,
        item.id: (_counts[item.id] ?? 0) >= item.count
            ? item.count
            : (_counts[item.id] ?? 0) + 1,
      };
    });
    _persist();
  }

  void _resetGroup() {
    final items = adhkarItems.where((item) => item.group.contains(_group));
    setState(() {
      final next = Map<String, int>.from(_counts);
      for (final item in items) {
        next.remove(item.id);
      }
      _counts = next;
    });
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final items =
        adhkarItems.where((item) => item.group.contains(_group)).toList();
    final completedCount =
        items.where((item) => (_counts[item.id] ?? 0) >= item.count).length;

    return Screen(
      children: [
        PageTitle(
          title: 'الأذكار',
          subtitle: 'أذكار مختارة مع عدّاد يومي محفوظ على جهازك',
        ),
        Row(
          spacing: 8,
          children: [
            for (final g in _groups)
              Pill(
                label: g.label,
                active: _group == g.group,
                onPress: () => setState(() => _group = g.group),
              ),
          ],
        ),
        CardX(
          child: Column(
            spacing: 12,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 3,
                    children: [
                      Text(
                        'إنجاز المجموعة',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: colors.foreground,
                          fontFamily: 'Inter',
                          fontFamilyFallback: const ['NotoSansArabic'],
                        ),
                      ),
                      Text(
                        '${toArabicDigits(completedCount)} من ${toArabicDigits(items.length)} أذكار مكتملة',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.mutedForeground,
                          fontFamily: 'Inter',
                          fontFamilyFallback: const ['NotoSansArabic'],
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: _resetGroup,
                    tooltip: 'إعادة عدادات هذه المجموعة',
                    icon: Icon(Icons.refresh, size: 20, color: colors.primary),
                  ),
                ],
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 7,
                  child: LinearProgressIndicator(
                    value: items.isEmpty ? 0 : completedCount / items.length,
                    backgroundColor: colors.muted,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (final item in items) _dhikrCard(colors, item),
        Text(
          'المراجع مذكورة أسفل كل ذكر. راجع المصدر الحديثي عند الحاجة إلى التحقق التفصيلي من الألفاظ.',
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 11,
            height: 18 / 11,
            color: colors.mutedForeground,
            fontFamily: 'Inter',
            fontFamilyFallback: const ['NotoSansArabic'],
          ),
        ),
      ],
    );
  }

  Widget _dhikrCard(AppColors colors, DhikrItem item) {
    final count = (_counts[item.id] ?? 0).clamp(0, item.count);
    final done = count >= item.count;
    return CardX(
      child: Column(
        spacing: 17,
        children: [
          Text(
            item.text,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 17,
              height: 30 / 17,
              color: colors.foreground,
              fontFamily: 'Inter',
              fontFamilyFallback: const ['NotoSansArabic'],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            spacing: 8,
            children: [
              Expanded(
                child: Text(
                  item.source,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.mutedForeground,
                    fontFamily: 'Inter',
                    fontFamilyFallback: const ['NotoSansArabic'],
                  ),
                ),
              ),
              Material(
                color: done ? colors.accent : colors.secondary,
                borderRadius: BorderRadius.circular(13),
                child: InkWell(
                  borderRadius: BorderRadius.circular(13),
                  onTap: done ? null : () => _increment(item),
                  child: Container(
                    constraints:
                        const BoxConstraints(minWidth: 80, minHeight: 38),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    child: Text(
                      done
                          ? 'تمّ'
                          : '${toArabicDigits(count)} / ${toArabicDigits(item.count)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color:
                            done ? colors.accentForeground : colors.primary,
                        fontFamily: 'Inter',
                        fontFamilyFallback: const ['NotoSansArabic'],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
