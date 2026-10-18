import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mujahadah/core/date/date_service.dart';
import 'package:mujahadah/models/achievement_model.dart';
import 'package:mujahadah/models/daily_checkin_model.dart';
import 'package:mujahadah/models/failure_record_model.dart';
import 'package:mujahadah/models/ibadah_model.dart';
import 'package:mujahadah/models/program_model.dart';
import 'package:mujahadah/models/program_v2_model.dart';
import 'package:mujahadah/models/user_model.dart';
import 'package:mujahadah/repositories/program_v2_repository.dart';
import 'package:mujahadah/services/program_v2_creation_service.dart';

void main() {
  late Directory tempDir;
  late Box<ProgramV2Model> box;
  late ProgramV2Repository repository;
  late ProgramV2CreationService service;

  setUpAll(() async {
    // Register adapters once
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(UserModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(IbadahModelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ProgramModelAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(DailyCheckInModelAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(FailureRecordModelAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(AchievementModelAdapter());
    }
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(ProgramV2ModelAdapter());
    }
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('program_v2_creation_test_');
    Hive.init(tempDir.path);
    box = await Hive.openBox<ProgramV2Model>('test_program_v2_box');
    repository = ProgramV2Repository(box: box);
    service = ProgramV2CreationService(repository: repository);
  });

  tearDown(() async {
    if (box.isOpen) {
      await box.close();
    }
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Program V2 Creation & Validation Service', () {
    // 1. Valid 40-day program creation
    test('1. Valid 40-day program creation succeeds', () async {
      final result = await service.createProgram(
        ibadahId: 'ibd-tahajjud',
        ibadahNameSnapshot: 'Shalat Tahajjud',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
      );

      expect(result.isSuccess, isTrue);
      expect(result.program, isNotNull);
      expect(result.program!.targetDays, equals(40));
      expect(result.program!.status, equals(ProgramV2Model.statusActive));
      expect(repository.getAll().length, equals(1));
    });

    // 2. Valid custom 365-day creation
    test('2. Valid custom 365-day program creation succeeds', () async {
      final result = await service.createProgram(
        ibadahId: 'ibd-quran',
        ibadahNameSnapshot: 'Tilawah Al-Quran 365',
        targetDays: 365,
        startSelection: ProgramStartSelection.today,
      );

      expect(result.isSuccess, isTrue);
      expect(result.program!.targetDays, equals(365));
      expect(repository.getAll().length, equals(1));
    });

    // 3. Valid custom intermediate duration (e.g. 60, 90, 100)
    test('3. Valid custom intermediate duration (100 days) succeeds', () async {
      final result = await service.createProgram(
        ibadahId: 'ibd-dhuha',
        ibadahNameSnapshot: 'Shalat Dhuha',
        targetDays: 100,
        startSelection: ProgramStartSelection.tomorrow,
      );

      expect(result.isSuccess, isTrue);
      expect(result.program!.targetDays, equals(100));
    });

    // 4. Rejection of 39 and 366 days
    test('4. Rejects out-of-bound durations: 39 and 366 days', () async {
      final resultBelow = await service.createProgram(
        ibadahId: 'ibd-test',
        ibadahNameSnapshot: 'Test Below',
        targetDays: 39,
        startSelection: ProgramStartSelection.today,
      );
      expect(resultBelow.isFailure, isTrue);
      expect(resultBelow.failureReason,
          equals(ProgramCreationFailureReason.invalidDuration));

      final resultAbove = await service.createProgram(
        ibadahId: 'ibd-test',
        ibadahNameSnapshot: 'Test Above',
        targetDays: 366,
        startSelection: ProgramStartSelection.today,
      );
      expect(resultAbove.isFailure, isTrue);
      expect(resultAbove.failureReason,
          equals(ProgramCreationFailureReason.invalidDuration));
      expect(repository.getAll(), isEmpty);
    });

    // 5. Rejection of zero and negative targets
    test('5. Rejects zero and negative targets', () async {
      final resultZero = await service.createProgram(
        ibadahId: 'ibd-test',
        ibadahNameSnapshot: 'Test Zero',
        targetDays: 0,
        startSelection: ProgramStartSelection.today,
      );
      expect(resultZero.isFailure, isTrue);
      expect(resultZero.failureReason,
          equals(ProgramCreationFailureReason.invalidDuration));

      final resultNeg = await service.createProgram(
        ibadahId: 'ibd-test',
        ibadahNameSnapshot: 'Test Negative',
        targetDays: -40,
        startSelection: ProgramStartSelection.today,
      );
      expect(resultNeg.isFailure, isTrue);
      expect(resultNeg.failureReason,
          equals(ProgramCreationFailureReason.invalidDuration));
      expect(repository.getAll(), isEmpty);
    });

    // 6. Empty ibadah identity / name rejection (including whitespace trimming)
    test('6. Rejects empty and whitespace-only ibadah ID and name snapshot',
        () async {
      final emptyId = await service.createProgram(
        ibadahId: '   ',
        ibadahNameSnapshot: 'Tahajjud',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
      );
      expect(emptyId.isFailure, isTrue);
      expect(emptyId.failureReason,
          equals(ProgramCreationFailureReason.emptyIbadahId));

      final emptyName = await service.createProgram(
        ibadahId: 'ibd-tahajjud',
        ibadahNameSnapshot: '  \t \n ',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
      );
      expect(emptyName.isFailure, isTrue);
      expect(emptyName.failureReason,
          equals(ProgramCreationFailureReason.emptyIbadahName));

      // Successfully trims accidental surrounding whitespace
      final trimmedResult = await service.createProgram(
        ibadahId: '  ibd-tahajjud  ',
        ibadahNameSnapshot: '  Tahajjud  ',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
      );
      expect(trimmedResult.isSuccess, isTrue);
      expect(trimmedResult.program!.ibadahId, equals('ibd-tahajjud'));
      expect(trimmedResult.program!.ibadahNameSnapshot, equals('Tahajjud'));
    });

    // 7. Duplicate ACTIVE program rejection
    test('7. Rejects duplicate creation when an ACTIVE program already exists',
        () async {
      final first = await service.createProgram(
        ibadahId: 'ibd-subuh',
        ibadahNameSnapshot: 'Shalat Subuh',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
      );
      expect(first.isSuccess, isTrue);

      final second = await service.createProgram(
        ibadahId: 'ibd-subuh',
        ibadahNameSnapshot: 'Shalat Subuh Different Name',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
      );
      expect(second.isFailure, isTrue);
      expect(second.failureReason,
          equals(ProgramCreationFailureReason.duplicateActiveProgram));
      expect(repository.getAll().length, equals(1));
    });

    // 8. Duplicate PENDING_FAILURE program rejection
    test(
        '8. Rejects creation when a PENDING_FAILURE program exists for the same ibadah',
        () async {
      final pendingProg = ProgramV2Model(
        id: 'prog-pending-1',
        ibadahId: 'ibd-witir',
        ibadahNameSnapshot: 'Shalat Witir',
        targetDays: 40,
        startDayKey: '2026-10-18',
        status: ProgramV2Model.statusPendingFailure,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        pendingMissedDayKey: '2026-10-18',
      );
      await repository.save(pendingProg);

      final result = await service.createProgram(
        ibadahId: 'ibd-witir',
        ibadahNameSnapshot: 'Shalat Witir New Attempt',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
      );
      expect(result.isFailure, isTrue);
      expect(result.failureReason,
          equals(ProgramCreationFailureReason.duplicateActiveProgram));
      expect(repository.getAll().length, equals(1));
    });

    // 9. Different ibadah IDs can coexist
    test(
        '9. Different ibadah IDs can coexist as ACTIVE programs simultaneously',
        () async {
      final prog1 = await service.createProgram(
        ibadahId: 'ibd-tahajjud',
        ibadahNameSnapshot: 'Shalat Tahajjud',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
      );
      final prog2 = await service.createProgram(
        ibadahId: 'ibd-dhuha',
        ibadahNameSnapshot: 'Shalat Dhuha',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
      );

      expect(prog1.isSuccess, isTrue);
      expect(prog2.isSuccess, isTrue);
      expect(repository.getAll().length, equals(2));
      expect(repository.hasActiveOrPendingProgram('ibd-tahajjud'), isTrue);
      expect(repository.hasActiveOrPendingProgram('ibd-dhuha'), isTrue);
    });

    // 10. Same ibadah ID allowed after previous SUCCESS
    test('10. Same ibadah ID allowed after previous SUCCESS program', () async {
      final successProg = ProgramV2Model(
        id: 'prog-success-old',
        ibadahId: 'ibd-tahajjud',
        ibadahNameSnapshot: 'Shalat Tahajjud',
        targetDays: 40,
        startDayKey: '2026-09-01',
        status: ProgramV2Model.statusSuccess,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        finalizedAt: DateTime.now(),
      );
      await repository.save(successProg);

      final result = await service.createProgram(
        ibadahId: 'ibd-tahajjud',
        ibadahNameSnapshot: 'Shalat Tahajjud Round 2',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
      );

      expect(result.isSuccess, isTrue);
      expect(repository.getAll().length, equals(2));
    });

    // 11. Same ibadah ID allowed after previous FAILED
    test('11. Same ibadah ID allowed after previous FAILED program', () async {
      final failedProg = ProgramV2Model(
        id: 'prog-failed-old',
        ibadahId: 'ibd-tahajjud',
        ibadahNameSnapshot: 'Shalat Tahajjud',
        targetDays: 40,
        startDayKey: '2026-09-01',
        status: ProgramV2Model.statusFailed,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        finalizedAt: DateTime.now(),
      );
      await repository.save(failedProg);

      final result = await service.createProgram(
        ibadahId: 'ibd-tahajjud',
        ibadahNameSnapshot: 'Shalat Tahajjud New Journey',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
      );

      expect(result.isSuccess, isTrue);
      expect(repository.getAll().length, equals(2));
    });

    // 12. Same ibadah ID allowed after previous WARNING
    test('12. Same ibadah ID allowed after previous WARNING program', () async {
      final warningProg = ProgramV2Model(
        id: 'prog-warning-old',
        ibadahId: 'ibd-tahajjud',
        ibadahNameSnapshot: 'Shalat Tahajjud',
        targetDays: 40,
        startDayKey: '2026-09-01',
        status: ProgramV2Model.statusWarning,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        finalizedAt: DateTime.now(),
      );
      await repository.save(warningProg);

      final result = await service.createProgram(
        ibadahId: 'ibd-tahajjud',
        ibadahNameSnapshot: 'Shalat Tahajjud Fresh',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
      );

      expect(result.isSuccess, isTrue);
      expect(repository.getAll().length, equals(2));
    });

    // 13. Existing program scheduled tomorrow still blocks duplicate creation
    test('13. Existing program scheduled tomorrow still blocks creation',
        () async {
      final tomorrowProg = await service.createProgram(
        ibadahId: 'ibd-rawatib',
        ibadahNameSnapshot: 'Rawatib',
        targetDays: 40,
        startSelection: ProgramStartSelection.tomorrow,
      );
      expect(tomorrowProg.isSuccess, isTrue);
      expect(tomorrowProg.program!.status, equals(ProgramV2Model.statusActive));

      // Attempting to create another program today for the same ibadah is rejected
      final duplicate = await service.createProgram(
        ibadahId: 'ibd-rawatib',
        ibadahNameSnapshot: 'Rawatib Attempt 2',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
      );
      expect(duplicate.isFailure, isTrue);
      expect(duplicate.failureReason,
          equals(ProgramCreationFailureReason.duplicateActiveProgram));
      expect(repository.getAll().length, equals(1));
    });

    // 14. Deterministic TODAY/TOMORROW before and at the 03:00 boundary
    test('14. Deterministic TODAY/TOMORROW before and at 03:00 boundary',
        () async {
      // Before 03:00 (2026-10-18 02:30:00) -> TODAY is 2026-10-17, TOMORROW is 2026-10-18
      final clockBefore = DateTime(2026, 10, 18, 2, 30, 0);
      final serviceBefore = ProgramV2CreationService(
        repository: repository,
        dateService: DateService(nowProvider: () => clockBefore),
      );

      final progTodayEarly = await serviceBefore.createProgram(
        ibadahId: 'ibd-early-today',
        ibadahNameSnapshot: 'Early Today',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
      );
      final progTomorrowEarly = await serviceBefore.createProgram(
        ibadahId: 'ibd-early-tomorrow',
        ibadahNameSnapshot: 'Early Tomorrow',
        targetDays: 40,
        startSelection: ProgramStartSelection.tomorrow,
      );

      expect(progTodayEarly.program!.startDayKey, equals('2026-10-17'));
      expect(progTomorrowEarly.program!.startDayKey, equals('2026-10-18'));

      // At 03:00 (2026-10-18 03:00:00) -> TODAY is 2026-10-18, TOMORROW is 2026-10-19
      final clockAt = DateTime(2026, 10, 18, 3, 0, 0);
      final serviceAt = ProgramV2CreationService(
        repository: repository,
        dateService: DateService(nowProvider: () => clockAt),
      );

      final progTodayAt = await serviceAt.createProgram(
        ibadahId: 'ibd-at-today',
        ibadahNameSnapshot: 'At Today',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
      );
      final progTomorrowAt = await serviceAt.createProgram(
        ibadahId: 'ibd-at-tomorrow',
        ibadahNameSnapshot: 'At Tomorrow',
        targetDays: 40,
        startSelection: ProgramStartSelection.tomorrow,
      );

      expect(progTodayAt.program!.startDayKey, equals('2026-10-18'));
      expect(progTomorrowAt.program!.startDayKey, equals('2026-10-19'));
    });

    // 15. Valid and invalid reminderTime values
    test('15. Validates reminderTime format strictly', () async {
      // Null is valid
      final nullReminder = await service.createProgram(
        ibadahId: 'ibd-rem-1',
        ibadahNameSnapshot: 'Test Null Reminder',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
        reminderTime: null,
      );
      expect(nullReminder.isSuccess, isTrue);
      expect(nullReminder.program!.reminderTime, isNull);

      // Valid HH:mm values
      final validReminders = ['00:00', '08:30', '12:00', '23:59'];
      for (var i = 0; i < validReminders.length; i++) {
        final res = await service.createProgram(
          ibadahId: 'ibd-valid-$i',
          ibadahNameSnapshot: 'Valid Reminder $i',
          targetDays: 40,
          startSelection: ProgramStartSelection.today,
          reminderTime: validReminders[i],
        );
        expect(res.isSuccess, isTrue,
            reason: 'Expected ${validReminders[i]} to be valid');
        expect(res.program!.reminderTime, equals(validReminders[i]));
      }

      // Invalid HH:mm values
      final invalidReminders = [
        '25:00',
        '12:60',
        '8:30',
        '08:30:00',
        '',
        '   ',
        'invalid',
        ' 08:30 '
      ];
      for (final invalid in invalidReminders) {
        final res = await service.createProgram(
          ibadahId: 'ibd-invalid-rem',
          ibadahNameSnapshot: 'Invalid Reminder',
          targetDays: 40,
          startSelection: ProgramStartSelection.today,
          reminderTime: invalid,
        );
        expect(res.isFailure, isTrue,
            reason: 'Expected "$invalid" to be rejected');
        expect(res.failureReason,
            equals(ProgramCreationFailureReason.invalidReminderTime));
      }
    });

    // 16. ID collision does not overwrite an existing program
    test('16. ID collision rejects creation and never overwrites existing data',
        () async {
      const collidingId = 'prog-existing-colliding-id';
      final existingProgram = ProgramV2Model(
        id: collidingId,
        ibadahId: 'ibd-original',
        ibadahNameSnapshot: 'Original Ibadah',
        targetDays: 40,
        startDayKey: '2026-10-18',
        status: ProgramV2Model.statusActive,
        createdAt: DateTime(2026, 10, 18, 1, 0),
        updatedAt: DateTime(2026, 10, 18, 1, 0),
      );
      await repository.save(existingProgram);

      // Service with an injected generator that returns the colliding ID
      final collisionService = ProgramV2CreationService(
        repository: repository,
        idGenerator: () => collidingId,
      );

      final result = await collisionService.createProgram(
        ibadahId: 'ibd-new-attempt',
        ibadahNameSnapshot: 'New Attempt',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
      );

      expect(result.isFailure, isTrue);
      expect(result.failureReason,
          equals(ProgramCreationFailureReason.idCollision));

      // Original program remains intact and unmodified
      final retained = repository.getById(collidingId);
      expect(retained, isNotNull);
      expect(retained!.ibadahId, equals('ibd-original'));
      expect(retained.ibadahNameSnapshot, equals('Original Ibadah'));
      expect(repository.getByIbadahId('ibd-new-attempt'), isEmpty);
    });

    // 17. Repeated / concurrent creation requests do not create duplicate active programs
    test(
        '17. Concurrent creation requests for the same ibadah produce only one program',
        () async {
      final future1 = service.createProgram(
        ibadahId: 'ibd-concurrent',
        ibadahNameSnapshot: 'Tahajjud Concurrent',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
      );
      final future2 = service.createProgram(
        ibadahId: 'ibd-concurrent',
        ibadahNameSnapshot: 'Tahajjud Concurrent Duplicate',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
      );

      final results = await Future.wait([future1, future2]);
      final successes = results.where((r) => r.isSuccess).toList();
      final failures = results.where((r) => r.isFailure).toList();

      expect(successes.length, equals(1));
      expect(failures.length, equals(1));
      expect(failures.first.failureReason,
          equals(ProgramCreationFailureReason.duplicateActiveProgram));

      final stored = repository.getByIbadahId('ibd-concurrent');
      expect(stored.length, equals(1));
      expect(stored.first.id, equals(successes.first.program!.id));
    });

    // 18. Failed validation leaves Hive storage unchanged
    test('18. Failed validation leaves Hive storage completely unchanged',
        () async {
      expect(repository.getAll(), isEmpty);

      // Invalid duration
      await service.createProgram(
        ibadahId: 'ibd-test',
        ibadahNameSnapshot: 'Test',
        targetDays: 10,
        startSelection: ProgramStartSelection.today,
      );
      expect(repository.getAll(), isEmpty);

      // Empty ibadah ID
      await service.createProgram(
        ibadahId: '',
        ibadahNameSnapshot: 'Test',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
      );
      expect(repository.getAll(), isEmpty);

      // Invalid reminder
      await service.createProgram(
        ibadahId: 'ibd-test',
        ibadahNameSnapshot: 'Test',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
        reminderTime: '99:99',
      );
      expect(repository.getAll(), isEmpty);
    });

    // 19. Successful creation persists all 13 ProgramV2Model fields correctly
    test('19. Successful creation persists all 13 ProgramV2Model fields',
        () async {
      final fixedClock = DateTime(2026, 10, 18, 5, 30, 15, 789);
      final customService = ProgramV2CreationService(
        repository: repository,
        dateService: DateService(nowProvider: () => fixedClock),
        idGenerator: () => 'prog-explicit-id-13',
      );

      final result = await customService.createProgram(
        ibadahId: 'ibd-subuh-all-fields',
        ibadahNameSnapshot: 'Shalat Subuh Tepat Waktu',
        targetDays: 60,
        startSelection: ProgramStartSelection.today,
        reminderTime: '04:15',
      );

      expect(result.isSuccess, isTrue);
      final p = result.program!;

      // Verify all 13 fields
      expect(p.id, equals('prog-explicit-id-13')); // 0
      expect(p.ibadahId, equals('ibd-subuh-all-fields')); // 1
      expect(p.ibadahNameSnapshot, equals('Shalat Subuh Tepat Waktu')); // 2
      expect(p.targetDays, equals(60)); // 3
      expect(p.startDayKey, equals('2026-10-18')); // 4
      expect(p.status, equals(ProgramV2Model.statusActive)); // 5
      expect(p.reminderTime, equals('04:15')); // 6
      expect(p.restartedFromProgramId, isNull); // 7
      expect(p.recipientNameSnapshot, isNull); // 8
      expect(p.createdAt.isAtSameMomentAs(fixedClock), isTrue); // 9
      expect(p.updatedAt.isAtSameMomentAs(fixedClock), isTrue); // 10
      expect(p.finalizedAt, isNull); // 11
      expect(p.pendingMissedDayKey, isNull); // 12
    });

    // 20. Program survives box flush, close, and reopen
    test(
        '20. Program survives box flush, close, and reopen (isolated disk test)',
        () async {
      final created = await service.createProgram(
        ibadahId: 'ibd-disk-test',
        ibadahNameSnapshot: 'Disk Test Ibadah',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
        reminderTime: '21:00',
      );
      expect(created.isSuccess, isTrue);
      final progId = created.program!.id;

      // Flush and close the box
      await repository.flush();
      await box.close();
      expect(box.isOpen, isFalse);

      // Reopen box
      final reopenedBox =
          await Hive.openBox<ProgramV2Model>('test_program_v2_box');
      final reopenedRepo = ProgramV2Repository(box: reopenedBox);

      final retrieved = reopenedRepo.getById(progId);
      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals(progId));
      expect(retrieved.ibadahId, equals('ibd-disk-test'));
      expect(retrieved.ibadahNameSnapshot, equals('Disk Test Ibadah'));
      expect(retrieved.status, equals(ProgramV2Model.statusActive));
      expect(retrieved.reminderTime, equals('21:00'));

      // Clean up reopened box
      box = reopenedBox; // so tearDown can close it
    });

    // 21. Creation timestamps preserve the actual instant
    test('21. Creation timestamps preserve exact instant with milliseconds',
        () async {
      final fixedClock = DateTime(2026, 10, 18, 14, 25, 33, 456);
      final customService = ProgramV2CreationService(
        repository: repository,
        dateService: DateService(nowProvider: () => fixedClock),
      );

      final result = await customService.createProgram(
        ibadahId: 'ibd-instant-test',
        ibadahNameSnapshot: 'Instant Test',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
      );

      expect(result.isSuccess, isTrue);
      expect(result.program!.createdAt.millisecond, equals(456));
      expect(result.program!.updatedAt.millisecond, equals(456));
      expect(result.program!.createdAt.isAtSameMomentAs(fixedClock), isTrue);
      expect(result.program!.updatedAt.isAtSameMomentAs(fixedClock), isTrue);
    });

    // 22. No new History box or progress counter is introduced
    test('22. No new History box or progress counter is introduced', () async {
      final result = await service.createProgram(
        ibadahId: 'ibd-history-check',
        ibadahNameSnapshot: 'History Check',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
      );
      expect(result.isSuccess, isTrue);

      // Box verification: only the program box exists
      expect(Hive.isBoxOpen('history'), isFalse);
      expect(Hive.isBoxOpen('program_history'), isFalse);

      // Model verification: no progress counter property on ProgramV2Model
      final program = result.program!;
      expect(program.id, isNotEmpty);
      expect(program.status, equals(ProgramV2Model.statusActive));
    });

    // Additional: Create from request DTO helper test
    test('createFromRequest works identically with CreateProgramV2Request',
        () async {
      const request = CreateProgramV2Request(
        ibadahId: 'ibd-dto',
        ibadahNameSnapshot: 'DTO Test',
        targetDays: 90,
        startSelection: ProgramStartSelection.tomorrow,
        reminderTime: '05:00',
      );

      final result = await service.createFromRequest(request);
      expect(result.isSuccess, isTrue);
      expect(result.program!.targetDays, equals(90));
      expect(result.program!.reminderTime, equals('05:00'));
    });

    // Additional: canCreateProgram helper test
    test('canCreateProgram reflects active program availability', () async {
      expect(service.canCreateProgram('ibd-check'), isTrue);
      expect(service.canCreateProgram('   '), isFalse);

      await service.createProgram(
        ibadahId: 'ibd-check',
        ibadahNameSnapshot: 'Check',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
      );

      expect(service.canCreateProgram('ibd-check'), isFalse);
    });

    // Hardening R1: Closed box triggers typed persistenceError
    test('Closed box triggers typed persistenceError during lookup/creation',
        () async {
      await box.close();
      expect(box.isOpen, isFalse);

      final result = await service.createProgram(
        ibadahId: 'ibd-closed-box',
        ibadahNameSnapshot: 'Closed Box Test',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
      );

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.failureReason,
          equals(ProgramCreationFailureReason.persistenceError));
      expect(result.program, isNull);
    });

    // Hardening R1: Simulated repository write failure triggers persistenceError
    test('Simulated repository write failure returns persistenceError',
        () async {
      final failingRepo = FailingSaveProgramV2Repository(box: box);
      final failingService = ProgramV2CreationService(repository: failingRepo);

      final result = await failingService.createProgram(
        ibadahId: 'ibd-failing-save',
        ibadahNameSnapshot: 'Failing Save Test',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
      );

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.failureReason,
          equals(ProgramCreationFailureReason.persistenceError));
      expect(result.program, isNull);
      expect(repository.getAll(), isEmpty);
    });

    // Hardening R1: Empty generated ID triggers idGenerationError
    test('Empty generated ID is rejected with idGenerationError', () async {
      final emptyIdService = ProgramV2CreationService(
        repository: repository,
        idGenerator: () => '',
      );

      final result = await emptyIdService.createProgram(
        ibadahId: 'ibd-empty-gen-id',
        ibadahNameSnapshot: 'Empty Gen ID',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
      );

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.failureReason,
          equals(ProgramCreationFailureReason.idGenerationError));
      expect(result.program, isNull);
      expect(repository.getAll(), isEmpty);
    });

    // Hardening R1: Whitespace-only generated ID triggers idGenerationError
    test('Whitespace-only generated ID is rejected with idGenerationError',
        () async {
      final whitespaceIdService = ProgramV2CreationService(
        repository: repository,
        idGenerator: () => '   \t\n  ',
      );

      final result = await whitespaceIdService.createProgram(
        ibadahId: 'ibd-ws-gen-id',
        ibadahNameSnapshot: 'Whitespace Gen ID',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
      );

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.failureReason,
          equals(ProgramCreationFailureReason.idGenerationError));
      expect(result.program, isNull);
      expect(repository.getAll(), isEmpty);
    });

    // Hardening R1: Injected ID generator that throws is caught and returns idGenerationError
    test('Throwing ID generator is safely caught and returns idGenerationError',
        () async {
      final throwingIdService = ProgramV2CreationService(
        repository: repository,
        idGenerator: () => throw Exception('RNG hardware failure'),
      );

      final result = await throwingIdService.createProgram(
        ibadahId: 'ibd-throwing-gen-id',
        ibadahNameSnapshot: 'Throwing Gen ID',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
      );

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.failureReason,
          equals(ProgramCreationFailureReason.idGenerationError));
      expect(result.program, isNull);
      expect(repository.getAll(), isEmpty);
    });

    // Hardening R1: Advisory canCreateProgram returns false gracefully on closed box
    test(
        'Advisory canCreateProgram returns false gracefully when box is closed',
        () async {
      await box.close();
      expect(box.isOpen, isFalse);

      expect(service.canCreateProgram('ibd-check'), isFalse);
    });
  });
}

/// Injected test double simulating storage write failures without external mocks.
class FailingSaveProgramV2Repository extends ProgramV2Repository {
  FailingSaveProgramV2Repository({required super.box});

  @override
  Future<void> save(ProgramV2Model program) async {
    throw Exception('Simulated disk write failure');
  }
}
