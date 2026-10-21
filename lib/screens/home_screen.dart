import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_ui.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../logic/hijri.dart';
import '../logic/prayer.dart';
import '../state/app_settings.dart';
import 'calendar_screen.dart';
import 'root_shell.dart';
import 'settings_screen.dart';

/// Ported from app/(tabs)/index.tsx — prayer home screen.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final settings = context.watch<AppSettings>();
    final place = settings.place;
    final prefs = settings.preferences;

    final times = getPrayerTimes(
      place.latitude,
      place.longitude,
      _now,
      prefs.calculationMethod,
    );
    final next = getNextPrayer(
      times,
      _now,
      place.latitude,
      place.longitude,
      prefs.calculationMethod,
    );
    final hijri = getHijriDate(_now, prefs.hijriOffset);
    final nextEvents = getUpcomingIslamicEvents(_now, prefs.hijriOffset);
    final nextEvent = nextEvents.isEmpty ? null : nextEvents.first;
    final formattedDate = formatGregorianDate(_now);
    final methodLabel = calculationMethods
        .firstWhere((m) => m.key == prefs.calculationMethod)
        .label;

    return Screen(
      children: [
        PageTitle(
          title: 'أذان ليبيا',
          subtitle: '$formattedDate  ·  ${hijri.fullLabel}',
          right: Material(
            color: colors.secondary,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 154, minHeight: 40),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 5,
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 17, color: colors.secondaryForeground),
                    Flexible(
                      child: Text(
                        place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colors.secondaryForeground,
                          fontFamily: 'Inter',
                          fontFamilyFallback: const ['NotoSansArabic'],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Next-prayer hero card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(colors.radius + 10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 18,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'الصلاة القادمة',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                colors.primaryForeground.withValues(alpha: 0.78),
                            fontFamily: 'Inter',
                            fontFamilyFallback: const ['NotoSansArabic'],
                          ),
                        ),
                        Text(
                          next.prayer.label,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: colors.primaryForeground,
                            fontFamily: 'Inter',
                            fontFamilyFallback: const ['NotoSansArabic'],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colors.primaryForeground,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(Icons.dark_mode_outlined,
                        size: 20, color: colors.primary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.only(top: 16),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0x3Bffffff)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الوقت المتبقي',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.primaryForeground
                                .withValues(alpha: 0.78),
                            fontFamily: 'Inter',
                            fontFamilyFallback: const ['NotoSansArabic'],
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          formatCountdown(next.time.difference(_now)),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: colors.primaryForeground,
                            fontFamily: 'Inter',
                            fontFamilyFallback: const ['NotoSansArabic'],
                          ),
                        ),
                      ],
                    ),
                    Text(
                      formatPrayerTime(next.time),
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        color: colors.primaryForeground,
                        fontFamily: 'Inter',
                        fontFamilyFallback: const ['NotoSansArabic'],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Row(
          spacing: 10,
          children: [
            Expanded(
              child: ActionButton(
                label: 'اتجاه القبلة',
                secondary: true,
                icon: Icons.explore_outlined,
                onPress: () => RootShell.switchTo(context, 2),
              ),
            ),
            Expanded(
              child: ActionButton(
                label: 'القرآن الكريم',
                secondary: true,
                icon: Icons.menu_book_outlined,
                onPress: () => RootShell.switchTo(context, 3),
              ),
            ),
          ],
        ),

        const SectionHeading(title: 'مواقيت الصلاة اليوم'),
        CardX(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            children: [
              for (var index = 0; index < times.length; index++) _prayerRow(colors, times[index], next, index == times.length - 1),
            ],
          ),
        ),

        if (nextEvent != null)
          Material(
            color: colors.card,
            borderRadius: BorderRadius.circular(colors.radius + 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(colors.radius + 10),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CalendarScreen()),
              ),
              child: CardX(
                borderRadius: colors.radius + 10,
                child: Row(
                  spacing: 12,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: colors.accent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.calendar_month_outlined,
                          size: 21, color: colors.accentForeground),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 4,
                        children: [
                          Text(
                            'المناسبة الإسلامية القادمة',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.mutedForeground,
                              fontFamily: 'Inter',
                              fontFamilyFallback: const ['NotoSansArabic'],
                            ),
                          ),
                          Text(
                            nextEvent.title,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: colors.foreground,
                              fontFamily: 'Inter',
                              fontFamilyFallback: const ['NotoSansArabic'],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatEventDate(nextEvent.date),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                        fontFamily: 'Inter',
                        fontFamilyFallback: const ['NotoSansArabic'],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        Text(
          'تُحسب المواقيت محليًا وفق $methodLabel. قد تختلف دقائق الحساب عن تقويم الأوقاف المحلي.',
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 12,
            height: 19 / 12,
            color: colors.mutedForeground,
            fontFamily: 'Inter',
            fontFamilyFallback: const ['NotoSansArabic'],
          ),
        ),
      ],
    );
  }

  Widget _prayerRow(
    AppColors colors,
    PrayerEntry item,
    ({PrayerEntry prayer, DateTime time}) next,
    bool isLast,
  ) {
    final isNext = item.key == next.prayer.key &&
        tripoliDateParts(next.time).day == tripoliDateParts(_now).day;
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: colors.border, width: 0.6)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            spacing: 8,
            children: [
              if (isNext)
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isNext ? colors.primary : colors.foreground,
                  fontFamily: 'Inter',
                  fontFamilyFallback: const ['NotoSansArabic'],
                ),
              ),
            ],
          ),
          Text(
            formatPrayerTime(item.time),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isNext ? colors.primary : colors.foreground,
              fontFamily: 'Inter',
              fontFamilyFallback: const ['NotoSansArabic'],
            ),
          ),
        ],
      ),
    );
  }
}
