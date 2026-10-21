import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_ui.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../logic/hijri.dart';
import '../state/app_settings.dart';
import 'calendar_screen.dart';
import 'settings_screen.dart';

/// Ported from app/(tabs)/more.tsx — events, calendar & settings hub.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final prefs = context.watch<AppSettings>().preferences;
    final now = DateTime.now();
    final hijri = getHijriDate(now, prefs.hijriOffset);
    final nextEvents = getUpcomingIslamicEvents(now, prefs.hijriOffset);

    return Screen(
      children: [
        PageTitle(
          title: 'المزيد',
          subtitle: 'التقويم والإعدادات ومعلومات التطبيق',
        ),

        // Hijri today hero card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(colors.radius + 10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 7,
            children: [
              Text(
                'تاريخ اليوم',
                style: TextStyle(
                  fontSize: 13,
                  color: colors.primaryForeground.withValues(alpha: 0.78),
                  fontFamily: 'Inter',
                  fontFamilyFallback: const ['NotoSansArabic'],
                ),
              ),
              Text(
                hijri.fullLabel,
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  color: colors.primaryForeground,
                  fontFamily: 'Inter',
                  fontFamilyFallback: const ['NotoSansArabic'],
                ),
              ),
              Text(
                formatGregorianDate(now),
                style: TextStyle(
                  fontSize: 13,
                  color: colors.primaryForeground.withValues(alpha: 0.8),
                  fontFamily: 'Inter',
                  fontFamilyFallback: const ['NotoSansArabic'],
                ),
              ),
              const SizedBox(height: 1),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Material(
                  color: colors.primaryForeground,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const CalendarScreen()),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 7,
                        children: [
                          Text(
                            'فتح التقويم الهجري',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: colors.primary,
                              fontFamily: 'Inter',
                              fontFamilyFallback: const ['NotoSansArabic'],
                            ),
                          ),
                          Icon(Icons.arrow_back,
                              size: 17, color: colors.primary),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        Text(
          'المناسبات القادمة',
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colors.foreground,
            fontFamily: 'Inter',
            fontFamilyFallback: const ['NotoSansArabic'],
          ),
        ),

        CardX(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < nextEvents.length && i < 3; i++)
                _eventRow(colors, nextEvents[i], i < 3 - 1 && i < nextEvents.length - 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 17, vertical: 9),
                child: Text(
                  'التواريخ المحسوبة تقريبية وقد تختلف حسب ثبوت الهلال في ليبيا.',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    height: 18 / 11,
                    color: colors.mutedForeground,
                    fontFamily: 'Inter',
                    fontFamilyFallback: const ['NotoSansArabic'],
                  ),
                ),
              ),
            ],
          ),
        ),

        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(colors.radius + 10),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            child: CardX(
              child: Row(
                spacing: 12,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colors.secondary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.settings_outlined,
                        size: 20, color: colors.primary),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 4,
                      children: [
                        Text(
                          'الإعدادات',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colors.foreground,
                            fontFamily: 'Inter',
                            fontFamilyFallback: const ['NotoSansArabic'],
                          ),
                        ),
                        Text(
                          'البلدية، طريقة الحساب، التنبيهات وحجم الخط',
                          style: TextStyle(
                            fontSize: 11,
                            height: 17 / 11,
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
        ),

        CardX(
          child: Column(
            spacing: 13,
            children: [
              Row(
                spacing: 11,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colors.accent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.dark_mode_outlined,
                        size: 21, color: colors.accentForeground),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 4,
                      children: [
                        Text(
                          'أذان ليبيا',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colors.foreground,
                            fontFamily: 'Inter',
                            fontFamilyFallback: const ['NotoSansArabic'],
                          ),
                        ),
                        Text(
                          'إصدار ١.٠ · صاحب التصميم: علي الليبي',
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
                ],
              ),
              Text(
                'مواقيت محلية، قبلة، قرآن قالون، أذكار وتقويم هجري. بيانات البلديات من مشروع البيانات الإدارية المفتوحة، ونص القرآن من مصدر موثّق من مجمع الملك فهد.',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 11,
                  height: 19 / 11,
                  color: colors.mutedForeground,
                  fontFamily: 'Inter',
                  fontFamilyFallback: const ['NotoSansArabic'],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _eventRow(AppColors colors, IslamicEvent event, bool showDivider) {
    return Container(
      constraints: const BoxConstraints(minHeight: 59),
      padding: const EdgeInsets.symmetric(horizontal: 17),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: colors.border, width: 0.6))
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        spacing: 10,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 4,
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
                  textAlign: TextAlign.right,
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
          Text(
            formatEventDate(event.date),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.primary,
              fontFamily: 'Inter',
              fontFamilyFallback: const ['NotoSansArabic'],
            ),
          ),
        ],
      ),
    );
  }
}
