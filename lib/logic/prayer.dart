import 'dart:math' as math;

import 'package:adhan/adhan.dart';

import '../core/format.dart';

/// Ported from src/lib/prayer.ts using the Dart port of the same `adhan`
/// library the original app used.

enum CalculationMethodKey { egyptian, mwl, karachi }

enum PrayerKey { fajr, dhuhr, asr, maghrib, isha }

class PrayerEntry {
  final PrayerKey key;
  final String label;
  final DateTime time;

  const PrayerEntry(this.key, this.label, this.time);
}

const calculationMethods =
    <({CalculationMethodKey key, String label, String detail})>[
  (
    key: CalculationMethodKey.egyptian,
    label: 'المصري',
    detail: '19.5° للفجر، 17.5° للعشاء'
  ),
  (
    key: CalculationMethodKey.mwl,
    label: 'رابطة العالم الإسلامي',
    detail: '18° للفجر والعشاء'
  ),
  (
    key: CalculationMethodKey.karachi,
    label: 'كراتشي',
    detail: '18° للفجر، 18° للعشاء'
  ),
];

const prayerLabels = <PrayerKey, String>{
  PrayerKey.fajr: 'الفجر',
  PrayerKey.dhuhr: 'الظهر',
  PrayerKey.asr: 'العصر',
  PrayerKey.maghrib: 'المغرب',
  PrayerKey.isha: 'العشاء',
};

CalculationParameters _parameters(CalculationMethodKey method) {
  final params = switch (method) {
    CalculationMethodKey.mwl =>
      CalculationMethod.muslim_world_league.getParameters(),
    CalculationMethodKey.karachi => CalculationMethod.karachi.getParameters(),
    CalculationMethodKey.egyptian => CalculationMethod.egyptian.getParameters(),
  };
  params.madhab = Madhab.shafi;
  return params;
}

List<PrayerEntry> getPrayerTimes(
  double latitude,
  double longitude,
  DateTime now,
  CalculationMethodKey method,
) {
  final parts = tripoliDateParts(now);
  // Note: the adhan package's utcOffset param bakes the offset into the
  // DateTime's wall clock; we keep plain instants instead and format them
  // through tripoliWallClock() (single +02:00 application).
  final prayerTimes = PrayerTimes(
    Coordinates(latitude, longitude),
    DateComponents(parts.year, parts.month, parts.day),
    _parameters(method),
  );
  return [
    PrayerEntry(PrayerKey.fajr, prayerLabels[PrayerKey.fajr]!, prayerTimes.fajr),
    PrayerEntry(
        PrayerKey.dhuhr, prayerLabels[PrayerKey.dhuhr]!, prayerTimes.dhuhr),
    PrayerEntry(PrayerKey.asr, prayerLabels[PrayerKey.asr]!, prayerTimes.asr),
    PrayerEntry(
        PrayerKey.maghrib, prayerLabels[PrayerKey.maghrib]!, prayerTimes.maghrib),
    PrayerEntry(PrayerKey.isha, prayerLabels[PrayerKey.isha]!, prayerTimes.isha),
  ];
}

({PrayerEntry prayer, DateTime time}) getNextPrayer(
  List<PrayerEntry> times,
  DateTime now,
  double latitude,
  double longitude,
  CalculationMethodKey method,
) {
  for (final item in times) {
    if (item.time.isAfter(now)) {
      return (prayer: item, time: item.time);
    }
  }
  final today = tripoliDateParts(now);
  final tomorrow = DateTime.utc(today.year, today.month, today.day + 1);
  final nextDayTimes = getPrayerTimes(latitude, longitude, tomorrow, method);
  return (prayer: nextDayTimes.first, time: nextDayTimes.first.time);
}

/// Qibla bearing from true north, clockwise degrees.
double qiblaBearing(double latitude, double longitude) {
  const kaabaLat = 21.4225;
  const kaabaLng = 39.8262;
  double toRadians(double degrees) => degrees * math.pi / 180.0;
  double toDegrees(double radians) => radians * 180.0 / math.pi;
  final lat1 = toRadians(latitude);
  final lat2 = toRadians(kaabaLat);
  final deltaLng = toRadians(kaabaLng - longitude);
  final y = math.sin(deltaLng) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(deltaLng);
  return (toDegrees(math.atan2(y, x)) + 360) % 360;
}
