/// Arabic formatting helpers ported from the original app's lib files.
const String _arabicDigits = '٠١٢٣٤٥٦٧٨٩';

String toArabicDigits(num value) {
  return value
      .toString()
      .replaceAllMapped(RegExp(r'\d'), (m) => _arabicDigits[int.parse(m[0]!)]);
}

String _pad2(int value) => value.toString().padLeft(2, '0');

/// Africa/Tripoli is fixed UTC+02:00 in the current era (DST abolished in 2013).
const Duration tripoliOffset = Duration(hours: 2);

/// Returns the UTC+02 wall-clock view of an instant (mirrors Intl timeZone:
/// 'Africa/Tripoli' behavior used throughout the original app).
DateTime tripoliWallClock(DateTime instant) {
  return instant.toUtc().add(tripoliOffset);
}

/// Tripoli calendar date parts (year/month/day) of an instant.
({int year, int month, int day}) tripoliDateParts(DateTime instant) {
  final wall = tripoliWallClock(instant);
  return (year: wall.year, month: wall.month, day: wall.day);
}

/// Unix day number (days since 1970-01-01) counted on Africa/Tripoli calendar days.
int tripoliUnixDay(DateTime instant) {
  final ms = instant.toUtc().millisecondsSinceEpoch +
      tripoliOffset.inMilliseconds;
  return ms ~/ 86400000;
}

/// Instant of Tripoli wall-clock day number at 12:00 local noon.
DateTime noonOfDay(int unixDay) {
  return DateTime.fromMillisecondsSinceEpoch(
    unixDay * 86400000,
    isUtc: true,
  );
}

const gregorianMonthsAr = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

const weekdaysAr = [
  'الأحد',
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
];

const weekdaysShortAr = ['أحد', 'اثن', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت'];

/// Mirrors Intl 'ar-LY' {hour: 2-digit, minute: 2-digit, hour12: false}.
/// Emits Latin digits, e.g. "05:12".
String formatPrayerTime(DateTime utcWithTripoliWallClock) {
  final wall = tripoliWallClock(utcWithTripoliWallClock);
  return '${_pad2(wall.hour)}:${_pad2(wall.minute)}';
}

/// Mirrors Intl 'ar-LY' {day: numeric, month: long, weekday: long}, e.g.
/// "الأربعاء، 21 أكتوبر".
String formatGregorianDate(DateTime instant) {
  final wall = tripoliWallClock(instant);
  final weekday = weekdaysAr[wall.weekday % 7];
  return '$weekday، ${wall.day} ${gregorianMonthsAr[wall.month - 1]}';
}

/// Mirrors Intl 'ar-LY' {day: numeric, month: short}, e.g. "21 أكتوبر".
String formatEventDate(DateTime instant) {
  final wall = tripoliWallClock(instant);
  return '${wall.day} ${gregorianMonthsAr[wall.month - 1]}';
}

/// "HH:MM:SS" countdown with Arabic-Indic digits.
String formatCountdown(Duration remaining) {
  final totalSeconds = remaining.inSeconds < 0 ? 0 : remaining.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final latin = '${_pad2(hours)}:${_pad2(minutes)}:${_pad2(seconds)}';
  return latin.replaceAllMapped(
      RegExp(r'\d'), (m) => _arabicDigits[int.parse(m[0]!)]);
}
