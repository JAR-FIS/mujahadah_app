/// Centralized DateService responsible for the Mujahadah operational-day boundary
/// and deterministic Gregorian calendar-day operations.
///
/// Business Rules:
/// 1. The Mujahadah operational day begins at 03:00 local device time.
/// 2. It ends immediately before 03:00 the following calendar day.
/// 3. Between 00:00 and 02:59:59, the active Mujahadah day key remains the previous Gregorian calendar date.
/// 4. At exactly 03:00:00, the new Mujahadah day begins.
/// 5. Each operational day has a deterministic YYYY-MM-DD key based on local Gregorian date.
/// 6. Time is injectable for deterministic offline testing.
/// 7. Calendar-day operations (parsing, arithmetic, ranges) are UTC-backed to remain
///    strictly independent of device timezone and Daylight Saving Time (DST) transitions.
class DateService {
  /// The operational boundary hour in local device time (03:00:00).
  static const int operationalBoundaryHour = 3;

  /// Strict regex matching deterministic day key format: YYYY-MM-DD.
  static final RegExp _dayKeyFormat =
      RegExp(r'^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$');

  final DateTime Function() _nowProvider;

  /// Creates a [DateService] with an optional injected current-time provider.
  /// Defaults to [DateTime.now].
  DateService({DateTime Function()? nowProvider})
      : _nowProvider = nowProvider ?? DateTime.now;

  /// Returns the current DateTime from the injected provider.
  DateTime get now => _nowProvider();

  /// Returns the active Mujahadah operational day key (`YYYY-MM-DD`) for the current time.
  String getTodayDayKey() {
    return getMujahadahDayKey(_nowProvider());
  }

  /// Convenience getter for the current operational day key.
  String get currentDayKey => getTodayDayKey();

  /// Calculates the deterministic Mujahadah operational day key (`YYYY-MM-DD`)
  /// for a given [dateTime].
  ///
  /// If [dateTime] is UTC, it is converted to device-local representation first.
  /// If local hour is before 03:00:00 (i.e. 00:00:00 - 02:59:59), the operational
  /// day key is the previous calendar day.
  /// At and after 03:00:00, it is the same calendar day.
  String getMujahadahDayKey(DateTime dateTime) {
    final local = dateTime.isUtc ? dateTime.toLocal() : dateTime;

    if (local.hour < operationalBoundaryHour) {
      final prevDate = DateTime.utc(local.year, local.month, local.day - 1);
      return _formatDate(prevDate.year, prevDate.month, prevDate.day);
    } else {
      return _formatDate(local.year, local.month, local.day);
    }
  }

  /// Formats a [DateTime] into a standard Gregorian calendar day key (`YYYY-MM-DD`)
  /// using its date components directly without timezone shifting.
  ///
  /// This safely handles both local DateTimes and UTC calendar-only DateTimes
  /// without converting UTC calendar dates to local time.
  static String formatCalendarDayKey(DateTime dateTime) {
    return _formatDate(dateTime.year, dateTime.month, dateTime.day);
  }

  /// Helper to format year, month, and day into `YYYY-MM-DD`.
  static String _formatDate(int year, int month, int day) {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Strictly validates whether [dayKey] matches `YYYY-MM-DD` and is a valid calendar date.
  ///
  /// Uses UTC calendar dates to ensure validation is completely independent of
  /// local device timezone, Daylight Saving Time (DST), or historical transitions.
  /// Rejects invalid formats as well as non-existent dates such as 2026-02-29 or 2026-04-31.
  static bool isValidDayKey(String? dayKey) {
    if (dayKey == null || !_dayKeyFormat.hasMatch(dayKey)) {
      return false;
    }

    final parts = dayKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);

    // Construct UTC DateTime to ensure pure calendar validation independent of local DST or timezone transitions.
    final date = DateTime.utc(year, month, day);
    return date.year == year && date.month == month && date.day == day;
  }

  /// Parses a valid [dayKey] (`YYYY-MM-DD`) into a UTC [DateTime] at 00:00:00 UTC.
  ///
  /// Using UTC ensures timezone-independent calendar operations and eliminates
  /// ambiguities caused by daylight-saving time transitions at local midnight.
  /// Throws [FormatException] if [dayKey] is not a strictly valid calendar day key.
  static DateTime parseDayKey(String dayKey) {
    if (!isValidDayKey(dayKey)) {
      throw FormatException(
          'Invalid Mujahadah day key format or date: "$dayKey". Expected YYYY-MM-DD.');
    }
    final parts = dayKey.split('-');
    return DateTime.utc(
        int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  /// Tries to parse [dayKey] into a UTC [DateTime] at 00:00:00 UTC, returning `null` if invalid.
  static DateTime? tryParseDayKey(String? dayKey) {
    if (dayKey == null || !isValidDayKey(dayKey)) {
      return null;
    }
    final parts = dayKey.split('-');
    return DateTime.utc(
        int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  /// Returns the day key of the calendar day immediately preceding [dayKey].
  ///
  /// Arithmetic is evaluated in UTC to ensure deterministic calendar transitions.
  String getPreviousDayKey(String dayKey) {
    final dt = parseDayKey(dayKey);
    final prev = DateTime.utc(dt.year, dt.month, dt.day - 1);
    return formatCalendarDayKey(prev);
  }

  /// Returns the day key of the calendar day immediately following [dayKey].
  ///
  /// Arithmetic is evaluated in UTC to ensure deterministic calendar transitions.
  String getNextDayKey(String dayKey) {
    final dt = parseDayKey(dayKey);
    final next = DateTime.utc(dt.year, dt.month, dt.day + 1);
    return formatCalendarDayKey(next);
  }

  /// Compares two day keys chronologically.
  ///
  /// Returns a negative value if [a] is before [b], zero if [a] == [b],
  /// and a positive value if [a] is after [b].
  /// Throws [FormatException] if either key is invalid.
  int compareDayKeys(String a, String b) {
    if (!isValidDayKey(a)) {
      throw FormatException('Invalid dayKey "a": "$a"');
    }
    if (!isValidDayKey(b)) {
      throw FormatException('Invalid dayKey "b": "$b"');
    }
    return a.compareTo(b);
  }

  /// Returns `true` if [a] is chronologically before [b].
  bool isDayKeyBefore(String a, String b) => compareDayKeys(a, b) < 0;

  /// Returns `true` if [a] is chronologically after [b].
  bool isDayKeyAfter(String a, String b) => compareDayKeys(a, b) > 0;

  /// Returns the signed difference in calendar days between [startDayKey] and [endDayKey].
  ///
  /// For example, difference between 2026-10-18 and 2026-10-19 is 1.
  /// Arithmetic is evaluated in UTC to eliminate DST duration discrepancies.
  /// Throws [FormatException] if either key is invalid.
  int differenceInDays(String startDayKey, String endDayKey) {
    final start = parseDayKey(startDayKey);
    final end = parseDayKey(endDayKey);
    return end.difference(start).inDays;
  }

  /// Returns an inclusive list of day keys between [startDayKey] and [endDayKey].
  ///
  /// If [startDayKey] is after [endDayKey], an empty list is returned.
  /// Iteration uses UTC calendar components to remain independent of fixed 24-hour durations.
  /// Throws [FormatException] if either key is invalid.
  List<String> getDayKeyRangeInclusive(String startDayKey, String endDayKey) {
    final start = parseDayKey(startDayKey);
    final end = parseDayKey(endDayKey);

    if (start.isAfter(end)) {
      return const [];
    }

    final range = <String>[];
    var current = start;
    while (!current.isAfter(end)) {
      range.add(formatCalendarDayKey(current));
      current = DateTime.utc(current.year, current.month, current.day + 1);
    }
    return range;
  }

  /// Returns the local [DateTime] representing the exact operational start boundary
  /// (03:00:00 local device time) for a given [dayKey].
  ///
  /// For example, for day key "2026-10-18", returns 2026-10-18 03:00:00.000 local time.
  ///
  /// Limitation note on historical timezone transitions: In timezones where DST
  /// or policy transitions occur at 03:00, local wall-clock representation may be
  /// shifted by the underlying OS/Dart runtime. The operational boundary rule
  /// remains strictly 03:00 local device time.
  DateTime getOperationalBoundaryStart(String dayKey) {
    final dt = parseDayKey(dayKey);
    return DateTime(dt.year, dt.month, dt.day, operationalBoundaryHour, 0, 0);
  }

  /// Returns the local [DateTime] representing the exact operational end boundary
  /// (03:00:00 local device time of the following calendar day, exclusive) for a given [dayKey].
  ///
  /// For example, for day key "2026-10-18", returns 2026-10-19 03:00:00.000 local time.
  DateTime getOperationalBoundaryEnd(String dayKey) {
    final dt = parseDayKey(dayKey);
    final nextDay = DateTime.utc(dt.year, dt.month, dt.day + 1);
    return DateTime(nextDay.year, nextDay.month, nextDay.day,
        operationalBoundaryHour, 0, 0);
  }

  /// Checks whether a given [dateTime] falls within the Mujahadah operational day [dayKey].
  ///
  /// Throws [FormatException] if [dayKey] is not a strictly valid calendar day key.
  bool isInMujahadahDay(DateTime dateTime, String dayKey) {
    if (!isValidDayKey(dayKey)) {
      throw FormatException(
          'Invalid Mujahadah day key format or date: "$dayKey". Expected YYYY-MM-DD.');
    }
    return getMujahadahDayKey(dateTime) == dayKey;
  }
}
