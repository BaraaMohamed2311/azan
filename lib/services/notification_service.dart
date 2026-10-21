import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../logic/prayer.dart';
import '../state/app_settings.dart';

/// Ported from src/lib/notifications.ts — schedules prayer alerts for the
/// next 7 days on Android/iOS. The web target intentionally throws (the
/// original app disabled notifications on web too).

final FlutterLocalNotificationsPlugin _plugin =
    FlutterLocalNotificationsPlugin();

bool _initialized = false;

Future<void> _ensureInit() async {
  if (_initialized) return;
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Africa/Tripoli'));

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();
  await _plugin.initialize(
    settings: const InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    ),
  );
  _initialized = true;
}

Future<bool> requestPermissions() async {
  if (kIsWeb) return false;
  if (defaultTargetPlatform == TargetPlatform.android) {
    final impl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await impl?.requestNotificationsPermission() ?? false;
    return granted;
  }
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    final impl = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final granted =
        await impl?.requestPermissions(alert: true, sound: true, badge: true) ??
            false;
    return granted;
  }
  return false;
}

Future<void> cancelPrayerNotifications() async {
  if (kIsWeb) return;
  await _plugin.cancelAll();
}

Future<int> schedulePrayerNotifications(
  AppPreferences preferences,
  double latitude,
  double longitude,
) async {
  if (kIsWeb) {
    throw Exception(
      'المتصفح لا يضمن تنبيهات مجدولة بعد إغلاق التطبيق؛ فعّل التنبيهات على أندرويد.',
    );
  }

  final soundEnabled = preferences.soundMode == 'system';
  await _ensureInit();

  final granted = await requestPermissions();
  if (!granted) {
    throw Exception('يجب السماح بالإشعارات من إعدادات الجهاز.');
  }

  final channelId = soundEnabled ? 'athan-libya-sound' : 'athan-libya-silent';
  final channelName =
      soundEnabled ? 'مواقيت الصلاة بصوت الجهاز' : 'مواقيت الصلاة بصمت';
  final androidDetails = AndroidNotificationDetails(
    channelId,
    channelName,
    importance: Importance.high,
    priority: Priority.high,
    playSound: soundEnabled,
    vibrationPattern:
        soundEnabled ? Int64List.fromList([0, 250, 180, 250]) : null,
    enableVibration: soundEnabled,
  );
  const iosDetails = DarwinNotificationDetails();
  final details =
      NotificationDetails(android: androidDetails, iOS: iosDetails);

  await _plugin.cancelAll();
  var scheduled = 0;
  final now = DateTime.now();
  final tripoli = tz.getLocation('Africa/Tripoli');
  for (var dayOffset = 0; dayOffset < 7; dayOffset++) {
    final day = now.add(Duration(days: dayOffset));
    final times =
        getPrayerTimes(latitude, longitude, day, preferences.calculationMethod);
    for (final prayer in times) {
      if (!prayer.time.isAfter(now)) continue;
      await _plugin.zonedSchedule(
        id: scheduled,
        title: 'حان وقت صلاة ${prayer.label}',
        body: 'أذان ليبيا — حيّ على الصلاة',
        scheduledDate: tz.TZDateTime.from(prayer.time, tripoli),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      scheduled += 1;
    }
  }
  return scheduled;
}
