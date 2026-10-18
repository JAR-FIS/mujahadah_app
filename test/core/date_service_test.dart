import 'package:flutter_test/flutter_test.dart';
import 'package:mujahadah/core/date/date_service.dart';

void main() {
  late DateService dateService;

  setUp(() {
    dateService = DateService();
  });

  group('Locked Business Rules — Operational Boundary Scenarios', () {
    test('2026-10-18 00:00:00 resolves to 2026-10-17', () {
      final dt = DateTime(2026, 10, 18, 0, 0, 0);
      expect(dateService.getMujahadahDayKey(dt), '2026-10-17');
    });

    test('2026-10-18 02:59:59 resolves to 2026-10-17', () {
      final dt = DateTime(2026, 10, 18, 2, 59, 59);
      expect(dateService.getMujahadahDayKey(dt), '2026-10-17');
    });

    test(
        '2026-10-18 02:59:59.999 (millisecond boundary) resolves to 2026-10-17',
        () {
      final dt = DateTime(2026, 10, 18, 2, 59, 59, 999);
      expect(dateService.getMujahadahDayKey(dt), '2026-10-17');
    });

    test('2026-10-18 03:00:00 resolves to 2026-10-18', () {
      final dt = DateTime(2026, 10, 18, 3, 0, 0);
      expect(dateService.getMujahadahDayKey(dt), '2026-10-18');
    });

    test('2026-10-18 22:59:00 resolves to 2026-10-18', () {
      final dt = DateTime(2026, 10, 18, 22, 59, 0);
      expect(dateService.getMujahadahDayKey(dt), '2026-10-18');
    });

    test('2026-10-19 00:30:00 resolves to 2026-10-18', () {
      final dt = DateTime(2026, 10, 19, 0, 30, 0);
      expect(dateService.getMujahadahDayKey(dt), '2026-10-18');
    });

    test('2026-10-19 03:00:00 resolves to 2026-10-19', () {
      final dt = DateTime(2026, 10, 19, 3, 0, 0);
      expect(dateService.getMujahadahDayKey(dt), '2026-10-19');
    });
  });

  group('Calendar Transitions', () {
    test('End of month transition (April 30 to May 1)', () {
      // 02:30 on May 1 belongs to April 30
      final before3am = DateTime(2026, 5, 1, 2, 30, 0);
      expect(dateService.getMujahadahDayKey(before3am), '2026-04-30');

      // 03:00 on May 1 belongs to May 1
      final at3am = DateTime(2026, 5, 1, 3, 0, 0);
      expect(dateService.getMujahadahDayKey(at3am), '2026-05-01');
    });

    test('Year-end transition (Dec 31 to Jan 1)', () {
      // 01:15 on Jan 1 belongs to Dec 31 of previous year
      final janFirstEarly = DateTime(2026, 1, 1, 1, 15, 0);
      expect(dateService.getMujahadahDayKey(janFirstEarly), '2025-12-31');

      // 03:00 on Jan 1 belongs to Jan 1 of new year
      final janFirstDay = DateTime(2026, 1, 1, 3, 0, 0);
      expect(dateService.getMujahadahDayKey(janFirstDay), '2026-01-01');
    });

    test('Leap year transitions (February 2024)', () {
      // 02:00 on Feb 29 belongs to Feb 28
      final feb29Early = DateTime(2024, 2, 29, 2, 0, 0);
      expect(dateService.getMujahadahDayKey(feb29Early), '2024-02-28');

      // 03:00 on Feb 29 belongs to Feb 29
      final feb29Day = DateTime(2024, 2, 29, 3, 0, 0);
      expect(dateService.getMujahadahDayKey(feb29Day), '2024-02-29');

      // 02:30 on March 1 in leap year belongs to Feb 29
      final mar1Early = DateTime(2024, 3, 1, 2, 30, 0);
      expect(dateService.getMujahadahDayKey(mar1Early), '2024-02-29');

      // 03:00 on March 1 belongs to March 1
      final mar1Day = DateTime(2024, 3, 1, 3, 0, 0);
      expect(dateService.getMujahadahDayKey(mar1Day), '2024-03-01');
    });

    test('Non-leap year transitions (February 2026)', () {
      // 02:45 on March 1 in non-leap year belongs to Feb 28
      final mar1Early = DateTime(2026, 3, 1, 2, 45, 0);
      expect(dateService.getMujahadahDayKey(mar1Early), '2026-02-28');

      // 03:00 on March 1 belongs to March 1
      final mar1Day = DateTime(2026, 3, 1, 3, 0, 0);
      expect(dateService.getMujahadahDayKey(mar1Day), '2026-03-01');
    });
  });

  group('Current Time Provider Injection', () {
    test('Injecting time before 03:00 returns previous calendar day', () {
      final customService = DateService(
        nowProvider: () => DateTime(2026, 10, 18, 1, 0, 0),
      );

      expect(customService.getTodayDayKey(), '2026-10-17');
      expect(customService.currentDayKey, '2026-10-17');
      expect(customService.now, DateTime(2026, 10, 18, 1, 0, 0));
    });

    test('Injecting time at or after 03:00 returns current calendar day', () {
      final customService = DateService(
        nowProvider: () => DateTime(2026, 10, 18, 3, 0, 0),
      );

      expect(customService.getTodayDayKey(), '2026-10-18');
      expect(customService.currentDayKey, '2026-10-18');
    });

    test('Dynamically advancing injected time updates operational day', () {
      DateTime simulatedTime = DateTime(2026, 10, 18, 2, 59, 58);
      final customService = DateService(nowProvider: () => simulatedTime);

      expect(customService.getTodayDayKey(), '2026-10-17');

      // Advance by 3 seconds past the 03:00:00 boundary
      simulatedTime = DateTime(2026, 10, 18, 3, 0, 1);
      expect(customService.getTodayDayKey(), '2026-10-18');
    });
  });

  group('Strict Day-Key Validation and Parsing', () {
    test(
        'Valid day keys pass validation independently of operational boundaries',
        () {
      expect(DateService.isValidDayKey('2026-10-18'), isTrue);
      expect(DateService.isValidDayKey('2024-02-29'), isTrue); // Leap year
      expect(DateService.isValidDayKey('2025-12-31'), isTrue);
      expect(DateService.isValidDayKey('2026-01-01'), isTrue);
    });

    test('Invalid formats are rejected', () {
      expect(DateService.isValidDayKey(null), isFalse);
      expect(DateService.isValidDayKey(''), isFalse);
      expect(DateService.isValidDayKey('2026/10/18'), isFalse);
      expect(DateService.isValidDayKey('2026-1-1'), isFalse);
      expect(DateService.isValidDayKey('2026-10-1'), isFalse);
      expect(DateService.isValidDayKey('abcd-ef-gh'), isFalse);
      expect(DateService.isValidDayKey('2026-10-18T00:00:00'), isFalse);
    });

    test('Invalid calendar dates are strictly rejected', () {
      // 2026 is not a leap year, Feb 29 does not exist
      expect(DateService.isValidDayKey('2026-02-29'), isFalse);
      // April has only 30 days
      expect(DateService.isValidDayKey('2026-04-31'), isFalse);
      // June has only 30 days
      expect(DateService.isValidDayKey('2026-06-31'), isFalse);
      // September has only 30 days
      expect(DateService.isValidDayKey('2026-09-31'), isFalse);
      // November has only 30 days
      expect(DateService.isValidDayKey('2026-11-31'), isFalse);
      // Month out of range
      expect(DateService.isValidDayKey('2026-00-15'), isFalse);
      expect(DateService.isValidDayKey('2026-13-01'), isFalse);
      // Day out of range
      expect(DateService.isValidDayKey('2026-10-00'), isFalse);
      expect(DateService.isValidDayKey('2026-10-32'), isFalse);
    });

    test(
        'parseDayKey returns expected UTC DateTime at 00:00:00 UTC for valid day keys',
        () {
      final parsed = DateService.parseDayKey('2026-10-18');
      expect(parsed, DateTime.utc(2026, 10, 18));
      expect(parsed.isUtc, isTrue);
    });

    test('parseDayKey throws FormatException for invalid keys', () {
      expect(
        () => DateService.parseDayKey('invalid'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => DateService.parseDayKey('2026-02-29'),
        throwsA(isA<FormatException>()),
      );
    });

    test('tryParseDayKey returns UTC DateTime for valid and null for invalid',
        () {
      expect(
          DateService.tryParseDayKey('2026-10-18'), DateTime.utc(2026, 10, 18));
      expect(DateService.tryParseDayKey('2026-02-29'), isNull);
      expect(DateService.tryParseDayKey(null), isNull);
    });
  });

  group('Calendar Day Arithmetic (Previous & Next Day Keys)', () {
    test('Standard day transitions', () {
      expect(dateService.getPreviousDayKey('2026-10-18'), '2026-10-17');
      expect(dateService.getNextDayKey('2026-10-18'), '2026-10-19');
    });

    test('Month boundary transitions', () {
      expect(dateService.getPreviousDayKey('2026-05-01'), '2026-04-30');
      expect(dateService.getNextDayKey('2026-04-30'), '2026-05-01');
    });

    test('Year boundary transitions', () {
      expect(dateService.getPreviousDayKey('2026-01-01'), '2025-12-31');
      expect(dateService.getNextDayKey('2025-12-31'), '2026-01-01');
    });

    test('Leap year February transitions', () {
      expect(dateService.getPreviousDayKey('2024-03-01'), '2024-02-29');
      expect(dateService.getNextDayKey('2024-02-28'), '2024-02-29');
      expect(dateService.getNextDayKey('2024-02-29'), '2024-03-01');
    });

    test('Non-leap year February transitions', () {
      expect(dateService.getPreviousDayKey('2026-03-01'), '2026-02-28');
      expect(dateService.getNextDayKey('2026-02-28'), '2026-03-01');
    });
  });

  group('Day-Key Comparison & Difference', () {
    test('compareDayKeys ordering', () {
      expect(
          dateService.compareDayKeys('2026-10-17', '2026-10-18'), isNegative);
      expect(dateService.compareDayKeys('2026-10-18', '2026-10-18'), isZero);
      expect(
          dateService.compareDayKeys('2026-10-19', '2026-10-18'), isPositive);

      expect(dateService.isDayKeyBefore('2026-10-17', '2026-10-18'), isTrue);
      expect(dateService.isDayKeyBefore('2026-10-18', '2026-10-17'), isFalse);

      expect(dateService.isDayKeyAfter('2026-10-19', '2026-10-18'), isTrue);
      expect(dateService.isDayKeyAfter('2026-10-18', '2026-10-19'), isFalse);
    });

    test('compareDayKeys throws on invalid input', () {
      expect(
        () => dateService.compareDayKeys('2026-02-29', '2026-03-01'),
        throwsA(isA<FormatException>()),
      );
    });

    test('differenceInDays calculates exact calendar days', () {
      expect(dateService.differenceInDays('2026-10-18', '2026-10-18'), 0);
      expect(dateService.differenceInDays('2026-10-18', '2026-10-25'), 7);
      expect(dateService.differenceInDays('2026-10-25', '2026-10-18'), -7);

      // Across month boundary
      expect(dateService.differenceInDays('2026-04-29', '2026-05-02'), 3);

      // Across leap year February
      expect(dateService.differenceInDays('2024-02-28', '2024-03-01'), 2);

      // Across non-leap year February
      expect(dateService.differenceInDays('2026-02-28', '2026-03-01'), 1);
    });
  });

  group('Inclusive Date Iteration', () {
    test('Single-day range', () {
      final range =
          dateService.getDayKeyRangeInclusive('2026-10-18', '2026-10-18');
      expect(range, ['2026-10-18']);
    });

    test('Multi-day range across month boundary', () {
      final range =
          dateService.getDayKeyRangeInclusive('2026-10-29', '2026-11-02');
      expect(range, [
        '2026-10-29',
        '2026-10-30',
        '2026-10-31',
        '2026-11-01',
        '2026-11-02',
      ]);
    });

    test('Range across leap year February', () {
      final range =
          dateService.getDayKeyRangeInclusive('2024-02-27', '2024-03-02');
      expect(range, [
        '2024-02-27',
        '2024-02-28',
        '2024-02-29',
        '2024-03-01',
        '2024-03-02',
      ]);
    });

    test('Reversed range returns empty list', () {
      final range =
          dateService.getDayKeyRangeInclusive('2026-10-20', '2026-10-18');
      expect(range, isEmpty);
    });
  });

  group('Operational Boundaries & Membership', () {
    test('getOperationalBoundaryStart returns local 03:00 on the day', () {
      final start = dateService.getOperationalBoundaryStart('2026-10-18');
      expect(start, DateTime(2026, 10, 18, 3, 0, 0));
    });

    test('getOperationalBoundaryEnd returns local 03:00 on following day', () {
      final end = dateService.getOperationalBoundaryEnd('2026-10-18');
      expect(end, DateTime(2026, 10, 19, 3, 0, 0));
    });

    test('isInMujahadahDay evaluates correctly at boundary points', () {
      const dayKey = '2026-10-18';

      // 02:59:59 on Oct 18 is in Oct 17, not Oct 18
      expect(
        dateService.isInMujahadahDay(DateTime(2026, 10, 18, 2, 59, 59), dayKey),
        isFalse,
      );

      // Exactly 03:00:00 on Oct 18 is in Oct 18
      expect(
        dateService.isInMujahadahDay(DateTime(2026, 10, 18, 3, 0, 0), dayKey),
        isTrue,
      );

      // 23:59:59 on Oct 18 is in Oct 18
      expect(
        dateService.isInMujahadahDay(
            DateTime(2026, 10, 18, 23, 59, 59), dayKey),
        isTrue,
      );

      // 02:59:59 on Oct 19 is still in Oct 18
      expect(
        dateService.isInMujahadahDay(DateTime(2026, 10, 19, 2, 59, 59), dayKey),
        isTrue,
      );

      // Exactly 03:00:00 on Oct 19 is in Oct 19, not Oct 18
      expect(
        dateService.isInMujahadahDay(DateTime(2026, 10, 19, 3, 0, 0), dayKey),
        isFalse,
      );
    });

    test('isInMujahadahDay throws FormatException for invalid day key inputs',
        () {
      final sample = DateTime(2026, 10, 18, 12, 0, 0);

      expect(
        () => dateService.isInMujahadahDay(sample, 'invalid-day-key'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => dateService.isInMujahadahDay(sample, '2026-02-29'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => dateService.isInMujahadahDay(sample, '2026/10/18'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('UTC and Local Consistency (Deterministic Fixed Instants)', () {
    test(
        'Fixed-instant near 03:00: local and UTC representations resolve to identical day keys',
        () {
      // 1 second before 03:00:00 local
      final before3amLocal = DateTime(2026, 10, 18, 2, 59, 59);
      final before3amUtc = before3amLocal.toUtc();

      expect(dateService.getMujahadahDayKey(before3amLocal), '2026-10-17');
      expect(dateService.getMujahadahDayKey(before3amUtc), '2026-10-17');

      // Exactly at 03:00:00 local
      final at3amLocal = DateTime(2026, 10, 18, 3, 0, 0);
      final at3amUtc = at3amLocal.toUtc();

      expect(dateService.getMujahadahDayKey(at3amLocal), '2026-10-18');
      expect(dateService.getMujahadahDayKey(at3amUtc), '2026-10-18');
    });

    test(
        'Fixed-instant nowProvider yields deterministic today key in both local and UTC representations',
        () {
      final fixedLocal = DateTime(2026, 10, 18, 14, 0, 0);
      final fixedUtc = fixedLocal.toUtc();

      final serviceLocal = DateService(nowProvider: () => fixedLocal);
      final serviceUtc = DateService(nowProvider: () => fixedUtc);

      expect(serviceLocal.getTodayDayKey(), '2026-10-18');
      expect(serviceUtc.getTodayDayKey(), '2026-10-18');
      expect(serviceLocal.getTodayDayKey(), serviceUtc.getTodayDayKey());
    });

    test(
        'UTC calendar-only DateTimes format without local timezone displacement',
        () {
      // UTC calendar date parsed from day key
      final utcCalendarDate = DateService.parseDayKey('2026-10-18');
      expect(utcCalendarDate.isUtc, isTrue);

      // Formatting must retain the exact 2026-10-18 day key, regardless of local timezone offset
      expect(DateService.formatCalendarDayKey(utcCalendarDate), '2026-10-18');
    });
  });

  group(
      'Historical Calendar Edge Case Determinism (Samoa 2011-12-29 to 2011-12-31)',
      () {
    // Note: This tests the mathematical Gregorian calendar determinism of DateService
    // without claiming native execution within the historical Samoan timezone.
    test('Gregorian calendar continuity across 2011-12-29 to 2011-12-31', () {
      expect(DateService.isValidDayKey('2011-12-29'), isTrue);
      expect(DateService.isValidDayKey('2011-12-30'), isTrue);
      expect(DateService.isValidDayKey('2011-12-31'), isTrue);

      expect(dateService.getNextDayKey('2011-12-29'), '2011-12-30');
      expect(dateService.getNextDayKey('2011-12-30'), '2011-12-31');
      expect(dateService.getPreviousDayKey('2011-12-31'), '2011-12-30');

      final range =
          dateService.getDayKeyRangeInclusive('2011-12-29', '2011-12-31');
      expect(range, ['2011-12-29', '2011-12-30', '2011-12-31']);

      expect(dateService.differenceInDays('2011-12-29', '2011-12-31'), 2);
    });
  });
}
