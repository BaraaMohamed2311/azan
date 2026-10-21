import '../core/format.dart';
import '../data/hijri_umalqura_data.dart';

/// Ported from src/lib/hijri.ts.
///
/// Primary conversion uses the Umm al-Qura month table generated from ICU
/// (identical to the original app's Intl 'islamic-umalqura' calendar), with
/// the same tabular fallback for dates outside the 1300-1600 AH range.

class HijriDateParts {
  final int day;
  final int month;
  final int year;
  final String monthName;
  final String fullLabel;

  HijriDateParts(this.day, this.month, this.year, this.monthName)
      : fullLabel =
            '${toArabicDigits(day)} $monthName ${toArabicDigits(year)} هـ';
}

const hijriMonths = [
  'محرّم',
  'صفر',
  'ربيع الأول',
  'ربيع الآخر',
  'جمادى الأولى',
  'جمادى الآخرة',
  'رجب',
  'شعبان',
  'رمضان',
  'شوّال',
  'ذو القعدة',
  'ذو الحجة',
];

int _monthStartIndex(int year, int month) =>
    (year - kUmalquraFirstYear) * 12 + (month - 1);

bool _inTable(int year, int month) {
  return year >= kUmalquraFirstYear &&
      year <= kUmalquraLastYear &&
      month >= 1 &&
      month <= 12;
}

/// Umm al-Qura: Gregorian instant -> Hijri parts (Tripoli calendar day).
HijriDateParts? _umalquraFromUnixDay(int unixDay) {
  final starts = kUmalquraMonthStarts;
  if (unixDay < starts.first || unixDay >= starts.last) return null;
  var lo = 0;
  var hi = starts.length - 1;
  while (lo < hi) {
    final mid = (lo + hi + 1) ~/ 2;
    if (starts[mid] <= unixDay) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  final year = kUmalquraFirstYear + lo ~/ 12;
  final month = lo % 12 + 1;
  final day = unixDay - starts[lo] + 1;
  return HijriDateParts(day, month, year, hijriMonths[month - 1]);
}

/// Umm al-Qura: (hijri y, m, d) -> Tripoli unix day, or null outside table.
int? _unixDayFromUmalqura(int year, int month, int day) {
  if (!_inTable(year, month) || day < 1 || day > 30) return null;
  final index = _monthStartIndex(year, month);
  if (index + 1 >= kUmalquraMonthStarts.length) return null;
  final length =
      kUmalquraMonthStarts[index + 1] - kUmalquraMonthStarts[index];
  if (day > length) return null;
  return kUmalquraMonthStarts[index] + day - 1;
}

HijriDateParts _tabularHijri(DateTime instant) {
  final dayNumber = tripoliUnixDay(instant);
  final jd = dayNumber + 2440588;
  final year = (30 * (jd - 1948439) + 10646) ~/ 10631;
  var month = ((jd - (29 + _hijriToJulianDay(year, 1, 1))) / 29.5).ceil() + 1;
  month = month.clamp(1, 12);
  final day = jd - _hijriToJulianDay(year, month, 1) + 1;
  return HijriDateParts(day, month, year, hijriMonths[month - 1]);
}

int _hijriToJulianDay(int year, int month, int day) {
  return day +
      (29.5 * (month - 1)).ceil() +
      (year - 1) * 354 +
      (3 + 11 * year) ~/ 30 +
      1948439 -
      1;
}

HijriDateParts getHijriDate(DateTime instant, [int offset = 0]) {
  final adjusted = instant.add(Duration(days: offset));
  final unixDay = tripoliUnixDay(adjusted);
  return _umalquraFromUnixDay(unixDay) ?? _tabularHijri(adjusted);
}

/// Gregorian instant for the given Hijri date (start of that Tripoli day),
/// or null when outside the supported range.
DateTime? hijriToGregorian(int year, int month, int day) {
  final unixDay = _unixDayFromUmalqura(year, month, day);
  if (unixDay == null) return null;
  // Tripoli day boundary is 22:00 UTC of the previous day (UTC+02).
  return DateTime.fromMillisecondsSinceEpoch(
    unixDay * 86400000 - tripoliOffset.inMilliseconds,
    isUtc: true,
  );
}

const eventDefinitions = <({int month, int day, String title})>[
  (month: 1, day: 1, title: 'رأس السنة الهجرية'),
  (month: 1, day: 10, title: 'يوم عاشوراء'),
  (month: 3, day: 12, title: 'المولد النبوي الشريف'),
  (month: 9, day: 1, title: 'بداية شهر رمضان'),
  (month: 10, day: 1, title: 'عيد الفطر'),
  (month: 12, day: 10, title: 'عيد الأضحى'),
];

class IslamicEvent {
  final String title;
  final DateTime date;
  final String hijriLabel;
  const IslamicEvent(this.title, this.date, this.hijriLabel);
}

List<IslamicEvent> getUpcomingIslamicEvents(DateTime from, [int offset = 0]) {
  final found = <String, IslamicEvent>{};
  for (var day = 0; day <= 390 && found.length < eventDefinitions.length; day++) {
    final date = from.add(Duration(days: day));
    final hijri = getHijriDate(date, offset);
    for (final event in eventDefinitions) {
      final key = '${event.month}-${event.day}';
      final isMatch = hijri.month == event.month && hijri.day == event.day;
      if (!found.containsKey(key) && isMatch) {
        found[key] = IslamicEvent(event.title, date, hijri.fullLabel);
      }
    }
  }
  final events = found.values.toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  return events;
}

class HijriDayCell {
  final DateTime date;
  final int hijriDay;
  const HijriDayCell(this.date, this.hijriDay);
}

List<HijriDayCell> getHijriMonthDays(DateTime anchor, [int offset = 0]) {
  final target = getHijriDate(anchor, offset);
  var firstDay = hijriToGregorian(target.year, target.month, 1);
  firstDay ??= anchor.subtract(Duration(days: target.day - 1));

  final result = <HijriDayCell>[];
  for (var index = 0; index < 30; index++) {
    final date = firstDay.add(Duration(days: index));
    final parts = getHijriDate(date, offset);
    if (parts.month != target.month || parts.year != target.year) break;
    result.add(HijriDayCell(date, parts.day));
  }
  return result;
}
