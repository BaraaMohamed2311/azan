import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../logic/prayer.dart';
import '../state/app_settings.dart';
import 'azan_web_stub.dart' if (dart.library.js_interop) 'azan_web.dart'
    as azan_web;

/// Prayer-call alerts.
///
/// Android: alarms are handed to native code (AlarmManager -> AzanService), so
/// the azan plays at prayer time with the heads-up notification, a stop button
/// and volume-button stop — even if the app is closed or the phone rebooted.
///
/// Web: scheduled in the browser by web/azan_web.js (audio + notification with
/// a stop action). Browsers cannot wake a closed page, so it works while the
/// site / installed PWA is open (foreground or background).

const MethodChannel _channel = MethodChannel('ly.aliliby.athan_libya/azan');

/// Days of alerts handed to the OS. Re-scheduled on every app launch.
const int _daysAhead = 30;

/// Thrown when the user has not allowed notifications.
class AzanPermissionException implements Exception {
  final String message;
  const AzanPermissionException(this.message);
  @override
  String toString() => message;
}

bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

final FlutterLocalNotificationsPlugin _plugin =
    FlutterLocalNotificationsPlugin();
bool _pluginReady = false;

Future<bool> requestPermissions() async {
  if (kIsWeb) {
    return await azan_web.requestPermission() == 'granted';
  }
  if (_isAndroid) {
    if (!_pluginReady) {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _pluginReady = true;
    }
    final impl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await impl?.requestNotificationsPermission() ?? false;
  }
  return false;
}

Future<void> cancelPrayerNotifications() async {
  if (kIsWeb) {
    azan_web.cancel();
  } else if (_isAndroid) {
    await _channel.invokeMethod<void>('cancel');
  }
}

/// Stops the azan if it is currently playing.
Future<void> stopAzan() async {
  if (kIsWeb) {
    azan_web.stop();
  } else if (_isAndroid) {
    await _channel.invokeMethod<void>('stop');
  }
}

List<Map<String, Object>> _buildItems(
  AppPreferences preferences,
  double latitude,
  double longitude,
) {
  final sound = preferences.soundMode == 'system';
  final now = DateTime.now();
  final items = <Map<String, Object>>[];
  var id = 0;
  for (var dayOffset = 0; dayOffset < _daysAhead; dayOffset++) {
    final day = now.add(Duration(days: dayOffset));
    final times =
        getPrayerTimes(latitude, longitude, day, preferences.calculationMethod);
    for (final prayer in times) {
      if (!prayer.time.isAfter(now)) continue;
      items.add({
        'id': id++,
        'time': prayer.time.millisecondsSinceEpoch,
        'title': 'حان وقت صلاة ${prayer.label}',
        'body': 'أذان ليبيا — حيّ على الصلاة',
        'sound': sound,
      });
    }
  }
  return items;
}

Future<void> _ensureAllowed() async {
  if (!kIsWeb && !_isAndroid) {
    throw Exception('التنبيهات المجدولة متاحة على أندرويد والويب فقط.');
  }
  if (kIsWeb && azan_web.permissionStatus() == 'unsupported') {
    throw Exception(
        'هذا المتصفح لا يدعم الإشعارات. جرّب Chrome أو ثبّت التطبيق على الشاشة الرئيسية.');
  }
  final granted = await requestPermissions();
  if (!granted) {
    throw AzanPermissionException(kIsWeb
        ? 'يجب السماح بالإشعارات من إعدادات المتصفح.'
        : 'يجب السماح بالإشعارات من إعدادات الجهاز.');
  }
}

/// Schedules the next [_daysAhead] days of prayer calls. Returns the count.
Future<int> schedulePrayerNotifications(
  AppPreferences preferences,
  double latitude,
  double longitude,
) async {
  await _ensureAllowed();
  final items = _buildItems(preferences, latitude, longitude);
  if (kIsWeb) {
    return azan_web.schedule(jsonEncode(items));
  }
  final count =
      await _channel.invokeMethod<int>('schedule', {'items': items});
  return count ?? items.length;
}

/// Fires an immediate test call (uses the current sound setting).
Future<void> testAzan(AppPreferences preferences) async {
  await _ensureAllowed();
  final sound = preferences.soundMode == 'system';
  const title = 'تجربة الأذان';
  const body = 'أذان ليبيا — حيّ على الصلاة';
  if (kIsWeb) {
    azan_web.test(jsonEncode(
        {'id': -1, 'title': title, 'body': body, 'sound': sound}));
  } else {
    await _channel.invokeMethod<void>(
        'test', {'title': title, 'body': body, 'sound': sound});
  }
}

/// Keeps the OS schedule in sync with the app: re-schedules at launch (so the
/// 30-day window keeps rolling forward) and whenever place / method / sound
/// change. Nothing here needs the app to stay open afterwards.
class AzanSync {
  static String? _signature;
  static Timer? _debounce;

  static String _sig(AppSettings s) {
    final p = s.preferences;
    final place = s.place;
    return '${p.soundMode}|${p.calculationMethod.name}|'
        '${place.latitude}|${place.longitude}';
  }

  static void attach(AppSettings settings) {
    _signature = _sig(settings);
    settings.addListener(() {
      final next = _sig(settings);
      if (next == _signature) return;
      _signature = next;
      _debounce?.cancel();
      _debounce = Timer(
          const Duration(milliseconds: 800), () => unawaited(_sync(settings)));
    });
    unawaited(_sync(settings));
  }

  static Future<void> _sync(AppSettings settings) async {
    final prefs = settings.preferences;
    if (!prefs.notificationsEnabled) return;
    try {
      // Browsers only allow the permission prompt from a click, so on web we
      // only re-schedule when permission was already granted.
      if (kIsWeb && azan_web.permissionStatus() != 'granted') return;
      final place = settings.place;
      await schedulePrayerNotifications(
          prefs, place.latitude, place.longitude);
    } on AzanPermissionException {
      settings.updatePreferences((p) => p.copyWith(notificationsEnabled: false));
    } catch (_) {
      // Keep the toggle as is; the next launch retries.
    }
  }
}
