import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_ui.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../logic/hijri.dart';
import '../state/app_settings.dart';

/// Ported from app/calendar.tsx — Hijri month grid with events.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  int _monthOffset = 0;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final prefs = context.watch<AppSettings>().preferences;
    final anchor =
        DateTime.now().add(Duration(days: _monthOffset * 30));
    final month = getHijriDate(anchor, prefs.hijriOffset);
    final days = getHijriMonthDays(anchor, prefs.hijriOffset);
    final events = getUpcomingIslamicEvents(DateTime.now(), prefs.hijriOffset);
    final monthEvents = events.where((event) {
      final parts = getHijriDate(event.date, prefs.hijriOffset);
      return parts.month == month.month && parts.year == month.year;
    }).toList();
    // Weekday of the Tripoli calendar day (cell dates are day-start instants
    // expressed at 22:00 UTC of the previous civil day).
    final firstWeekday = days.isEmpty
        ? 0
        : tripoliWallClock(days.first.date).weekday % 7;
    final today = getHijriDate(DateTime.now(), prefs.hijriOffset);
    final gregorianAnchor = formatGregorianDate(anchor);

    return Screen(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_forward),
              color: colors.foreground,
            ),
            Expanded(
              child: PageTitle(
                title: 'التقويم الهجري',
                subtitle: 'تقويم حسابي للاسترشاد؛ قد تختلف المناسبات بعد تحرّي الهلال',
              ),
            ),
          ],
        ),
        CardX(
          child: Column(
            spacing: 17,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() => _monthOffset += 1),
                    icon: Icon(Icons.chevron_right,
                        size: 19, color: colors.primary),
                    tooltip: 'الشهر التالي',
                  ),
                  Expanded(
                    child: Column(
                      spacing: 3,
                      children: [
                        Text(
                          '${month.monthName} ${toArabicDigits(month.year)} هـ',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: colors.foreground,
                            fontFamily: 'Inter',
                            fontFamilyFallback: const ['NotoSansArabic'],
                          ),
                        ),
                        Text(
                          gregorianAnchor,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.mutedForeground,
                            fontFamily: 'Inter',
                            fontFamilyFallback: const ['NotoSansArabic'],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _monthOffset -= 1),
                    icon: Icon(Icons.chevron_left,
                        size: 19, color: colors.primary),
                    tooltip: 'الشهر السابق',
                  ),
                ],
              ),
              Row(
                children: [
                  for (final weekday in weekdaysShortAr)
                    Expanded(
                      child: Text(
                        weekday,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colors.mutedForeground,
                          fontFamily: 'Inter',
                          fontFamilyFallback: const ['NotoSansArabic'],
                        ),
                      ),
                    ),
                ],
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cellWidth = constraints.maxWidth / 7;
                  return Wrap(
                    children: [
                      for (var i = 0; i < firstWeekday; i++)
                        SizedBox(width: cellWidth, height: 51),
                      for (final cell in days)
                        _dayCell(colors, cell, cellWidth, month, today),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        Text(
          'مناسبات هذا الشهر',
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colors.foreground,
            fontFamily: 'Inter',
            fontFamilyFallback: const ['NotoSansArabic'],
          ),
        ),
        if (monthEvents.isNotEmpty)
          CardX(
            padding:
                const EdgeInsets.symmetric(vertical: 4, horizontal: 17),
            child: Column(
              children: [
                for (final event in monthEvents)
                  Container(
                    constraints: const BoxConstraints(minHeight: 42),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      spacing: 10,
                      children: [
                        Text(
                          event.title,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colors.foreground,
                            fontFamily: 'Inter',
                            fontFamilyFallback: const ['NotoSansArabic'],
                          ),
                        ),
                        Text(
                          event.hijriLabel,
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.primary,
                            fontFamily: 'Inter',
                            fontFamilyFallback: const ['NotoSansArabic'],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          )
        else
          CardX(
            child: Text(
              'لا توجد مناسبة رئيسية مسجلة لهذا الشهر.',
              textAlign: TextAlign.center,
              style: appText(context, fontSize: 13, color: colors.mutedForeground),
            ),
          ),
      ],
    );
  }

  Widget _dayCell(
    AppColors colors,
    HijriDayCell cell,
    double width,
    HijriDateParts month,
    HijriDateParts today,
  ) {
    final isToday = today.day == cell.hijriDay &&
        today.month == month.month &&
        today.year == month.year;
    final gregorianDay = tripoliDateParts(cell.date).day;
    return SizedBox(
      width: width,
      height: 51,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 1,
        children: [
          Container(
            width: 31,
            height: 31,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isToday ? colors.primary : Colors.transparent,
              shape: BoxShape.circle,
              border: isToday
                  ? Border.all(color: colors.primary)
                  : null,
            ),
            child: Text(
              toArabicDigits(cell.hijriDay),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isToday ? colors.primaryForeground : colors.foreground,
                fontFamily: 'Inter',
                fontFamilyFallback: const ['NotoSansArabic'],
              ),
            ),
          ),
          Text(
            '$gregorianDay',
            style: TextStyle(
              fontSize: 9,
              color: colors.mutedForeground,
              fontFamily: 'Inter',
              fontFamilyFallback: const ['NotoSansArabic'],
            ),
          ),
        ],
      ),
    );
  }
}
