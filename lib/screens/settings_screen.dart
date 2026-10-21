import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_ui.dart';
import '../core/format.dart' show toArabicDigits;
import '../core/theme.dart';
import '../data/municipalities.dart';
import '../logic/prayer.dart' show calculationMethods, CalculationMethodKey;
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../state/app_settings.dart';

/// Ported from app/settings.tsx — municipality picker, GPS, calculation
/// method, notifications, hijri offset and Quran font scale.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _search = '';
  bool _gpsBusy = false;
  String? _alertMessage;

  bool get _isWeb => kIsWeb;

  List<Municipality> _filtered() {
    final query = _search.trim().toLowerCase();
    final all = MunicipalityData.municipalities;
    if (query.isEmpty) return all;
    return all
        .where((m) =>
            m.name.contains(_search.trim()) ||
            m.district.contains(_search.trim()) ||
            m.region.contains(_search.trim()) ||
            m.englishName.toLowerCase().contains(query))
        .toList();
  }

  Future<void> _updateNotifications(bool enabled) async {
    setState(() => _alertMessage = null);
    final settings = context.read<AppSettings>();
    if (!enabled) {
      await cancelPrayerNotifications();
      settings.updatePreferences(
          (p) => p.copyWith(notificationsEnabled: false));
      return;
    }
    settings
        .updatePreferences((p) => p.copyWith(notificationsEnabled: true));
    setState(() => _alertMessage = 'جارٍ إعداد تنبيهات الصلاة…');
    try {
      final place = settings.place;
      final scheduled = await schedulePrayerNotifications(
        settings.preferences,
        place.latitude,
        place.longitude,
      );
      if (mounted) {
        setState(() => _alertMessage =
            'تمت جدولة ${toArabicDigits(scheduled)} تنبيهًا للأيام السبعة القادمة.');
      }
    } catch (error) {
      settings.updatePreferences(
          (p) => p.copyWith(notificationsEnabled: false));
      if (mounted) {
        setState(() => _alertMessage =
            error is Exception ? '$error'.replaceAll('Exception: ', '') : 'تعذّر إعداد التنبيهات.');
      }
    }
  }

  Future<void> _locate() async {
    setState(() {
      _gpsBusy = true;
      _alertMessage = null;
    });
    final settings = context.read<AppSettings>();
    try {
      final position = await LocationService.getCurrentPosition();
      settings.useGpsPlace(position.latitude, position.longitude);
      if (mounted) {
        setState(() => _alertMessage = 'تم تحديث المواقيت حسب موقعك الحالي.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _alertMessage =
            'لم يُسمح بالوصول إلى الموقع أو تعذّر تحديده. اختر بلديتك يدويًا أدناه.');
      }
    } finally {
      if (mounted) setState(() => _gpsBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final settings = context.watch<AppSettings>();
    final prefs = settings.preferences;
    final place = settings.place;
    final filtered = _filtered();

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
                title: 'الإعدادات',
                subtitle: 'إعدادات تحفظ تلقائيًا على هذا الجهاز',
              ),
            ),
          ],
        ),

        _sectionTitle(colors, 'الموقع والبلدية'),
        CardX(
          child: Column(
            spacing: 12,
            children: [
              Row(
                spacing: 10,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 4,
                      children: [
                        Text(
                          place.name,
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
                          prefs.gpsPlace != null
                              ? 'موقع الجهاز الحالي'
                              : 'البلدية المختارة',
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
                  Material(
                    color: colors.secondary,
                    borderRadius: BorderRadius.circular(13),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(13),
                      onTap: _gpsBusy ? null : _locate,
                      child: Container(
                        constraints:
                            const BoxConstraints(minHeight: 39),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 11),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 5,
                          children: [
                            Icon(Icons.near_me_outlined,
                                size: 17, color: colors.primary),
                            Text(
                              _gpsBusy ? 'جارٍ التحديد' : 'موقعي',
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
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                constraints: const BoxConstraints(minHeight: 45),
                padding: const EdgeInsets.symmetric(horizontal: 11),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  spacing: 8,
                  children: [
                    Icon(Icons.search,
                        size: 18, color: colors.mutedForeground),
                    Expanded(
                      child: TextField(
                        onChanged: (value) => setState(() => _search = value),
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          hintText: 'ابحث بين ١٠٤ بلديات',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: colors.mutedForeground,
                            fontFamily: 'Inter',
                            fontFamilyFallback: const ['NotoSansArabic'],
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.foreground,
                          fontFamily: 'Inter',
                          fontFamilyFallback: const ['NotoSansArabic'],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 345),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final municipality
                          in filtered.take(35))
                        _municipalityRow(colors, settings, municipality),
                      if (filtered.length > 35)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            'اكتب مزيدًا من الحروف لتصفية بقية البلديات.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.mutedForeground,
                              fontFamily: 'Inter',
                              fontFamilyFallback: const ['NotoSansArabic'],
                            ),
                          ),
                        ),
                      if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            'لا توجد بلدية مطابقة.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.mutedForeground,
                              fontFamily: 'Inter',
                              fontFamilyFallback: const ['NotoSansArabic'],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        _sectionTitle(colors, 'طريقة حساب المواقيت'),
        CardX(
          child: Column(
            spacing: 10,
            children: [
              Text(
                'تختلف الحسابات الفلكية عن الجداول المحلية. اختر الإعداد المعتمد لديك.',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  height: 19 / 12,
                  color: colors.mutedForeground,
                  fontFamily: 'Inter',
                  fontFamilyFallback: const ['NotoSansArabic'],
                ),
              ),
              for (final method in calculationMethods)
                _methodRow(colors, settings, method),
            ],
          ),
        ),

        _sectionTitle(colors, 'تنبيهات الصلاة'),
        CardX(
          child: Column(
            spacing: 10,
            children: [
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 4,
                      children: [
                        Text(
                          'تنبيهات المواقيت',
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
                          'جدولة محلية للأيام السبعة القادمة',
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
                  Switch(
                    value: prefs.notificationsEnabled,
                    onChanged: (value) => _updateNotifications(value),
                    activeThumbColor: colors.primary,
                  ),
                ],
              ),
              if (_isWeb || defaultTargetPlatform != TargetPlatform.android)
                Text(
                  'إشعارات الويب بعد إغلاق المتصفح غير مضمونة؛ استخدم أندرويد للتنبيهات المجدولة.',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    height: 19 / 12,
                    color: colors.mutedForeground,
                    fontFamily: 'Inter',
                    fontFamilyFallback: const ['NotoSansArabic'],
                  ),
                )
              else
                Row(
                  spacing: 8,
                  children: [
                    Pill(
                      label: 'نغمة الجهاز',
                      active: prefs.soundMode == 'system',
                      onPress: () => settings.updatePreferences(
                          (p) => p.copyWith(soundMode: 'system')),
                    ),
                    Pill(
                      label: 'صامت',
                      active: prefs.soundMode == 'silent',
                      onPress: () => settings.updatePreferences(
                          (p) => p.copyWith(soundMode: 'silent')),
                    ),
                  ],
                ),
              if (_alertMessage != null)
                Text(
                  _alertMessage!,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    height: 19 / 12,
                    color: colors.primary,
                    fontFamily: 'Inter',
                    fontFamilyFallback: const ['NotoSansArabic'],
                  ),
                ),
            ],
          ),
        ),

        _sectionTitle(colors, 'التقويم والقراءة'),
        CardX(
          child: Column(
            children: [
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 4,
                      children: [
                        Text(
                          'تعديل التاريخ الهجري',
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
                          prefs.hijriOffset > 0
                              ? 'تقديم يوم'
                              : prefs.hijriOffset < 0
                                  ? 'تأخير يوم'
                                  : 'دون تعديل',
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
                  _offsetButton(
                    colors,
                    Icons.add,
                    tooltip: 'تقديم التاريخ الهجري يومًا',
                    enabled: prefs.hijriOffset < 1,
                    onTap: () => settings.updatePreferences((p) =>
                        p.copyWith(
                            hijriOffset: (p.hijriOffset + 1).clamp(-1, 1))),
                  ),
                  _offsetButton(
                    colors,
                    Icons.remove,
                    tooltip: 'تأخير التاريخ الهجري يومًا',
                    enabled: prefs.hijriOffset > -1,
                    onTap: () => settings.updatePreferences((p) =>
                        p.copyWith(
                            hijriOffset: (p.hijriOffset - 1).clamp(-1, 1))),
                  ),
                ],
              ),
              Container(
                margin: const EdgeInsets.only(top: 13),
                padding: const EdgeInsets.only(top: 13),
                decoration: BoxDecoration(
                  border: Border(
                      top: BorderSide(color: colors.border, width: 0.6)),
                ),
                child: Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 4,
                        children: [
                          Text(
                            'حجم خط القرآن',
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
                            prefs.quranFontScale == 0
                                ? 'افتراضي'
                                : 'تغيير ${prefs.quranFontScale > 0 ? '+' : ''}${toArabicDigits(prefs.quranFontScale)}',
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
                    _offsetButton(
                      colors,
                      Icons.add,
                      tooltip: 'تكبير خط القرآن',
                      enabled: prefs.quranFontScale < 3,
                      onTap: () => settings.updatePreferences((p) =>
                          p.copyWith(
                              quranFontScale:
                                  (p.quranFontScale + 1).clamp(-2, 3))),
                    ),
                    _offsetButton(
                      colors,
                      Icons.remove,
                      tooltip: 'تصغير خط القرآن',
                      enabled: prefs.quranFontScale > -2,
                      onTap: () => settings.updatePreferences((p) =>
                          p.copyWith(
                              quranFontScale:
                                  (p.quranFontScale - 1).clamp(-2, 3))),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Text(
          'أذان ليبيا · صاحب التصميم: علي الليبي · يتم حفظ الاختيارات على جهازك.',
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

  Widget _sectionTitle(AppColors colors, String title) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: colors.foreground,
          fontFamily: 'Inter',
          fontFamilyFallback: const ['NotoSansArabic'],
        ),
      ),
    );
  }

  Widget _municipalityRow(
      AppColors colors, AppSettings settings, Municipality municipality) {
    final active = settings.preferences.gpsPlace == null &&
        municipality.id == settings.preferences.municipalityId;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          settings.chooseMunicipality(municipality.id);
          setState(
              () => _alertMessage = 'تم اختيار بلدية ${municipality.name}.');
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 51),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(color: colors.border, width: 0.6)),
          ),
          child: Row(
            spacing: 9,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 3,
                  children: [
                    Text(
                      municipality.name,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: active ? colors.primary : colors.foreground,
                        fontFamily: 'Inter',
                        fontFamilyFallback: const ['NotoSansArabic'],
                      ),
                    ),
                    Text(
                      '${municipality.region} · ${municipality.district}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.mutedForeground,
                        fontFamily: 'Inter',
                        fontFamilyFallback: const ['NotoSansArabic'],
                      ),
                    ),
                  ],
                ),
              ),
              if (active)
                Icon(Icons.check_circle, size: 19, color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _methodRow(
    AppColors colors,
    AppSettings settings,
    ({CalculationMethodKey key, String label, String detail}) method,
  ) {
    final active = settings.preferences.calculationMethod == method.key;
    return InkWell(
      onTap: () => settings
          .updatePreferences((p) => p.copyWith(calculationMethod: method.key)),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: colors.border, width: 0.6)),
        ),
        child: Row(
          spacing: 10,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 4,
                children: [
                  Text(
                    method.label,
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
                    method.detail,
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
            Icon(
              active
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              size: 20,
              color: active ? colors.primary : colors.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }

  Widget _offsetButton(
    AppColors colors,
    IconData icon, {
    required String tooltip,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: colors.secondary,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Opacity(
              opacity: enabled ? 1 : 0.4,
              child: Icon(icon, size: 18, color: colors.primary),
            ),
          ),
        ),
      ),
    );
  }
}
