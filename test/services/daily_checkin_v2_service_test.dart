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
import 'package:mujahadah/repositories/daily_checkin_v2_repository.dart';
import 'package:mujahadah/repositories/program_v2_repository.dart';
import 'package:mujahadah/services/daily_checkin_v2_service.dart';

void main() {
  late Directory tempDir;
  late Box<ProgramV2Model> programBox;
  late Box<DailyCheckInModel> checkInBox;
  late ProgramV2Repository programRepo;
  late DailyCheckInV2Repository checkInRepo;
  late DateService dateService;
  late DailyCheckInV2Service service;

  setUpAll(() async {
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
    tempDir = Directory.systemTemp.createTempSync('daily_checkin_v2_test_');
    Hive.init(tempDir.path);
    programBox = await Hive.openBox<ProgramV2Model>('test_programs_box');
    checkInBox = await Hive.openBox<DailyCheckInModel>('test_checkins_box');
    programRepo = ProgramV2Repository(box: programBox);
    checkInRepo = DailyCheckInV2Repository(box: checkInBox);

    // Default fixed clock: 2026-10-18 05:00:00 (dayKey: 2026-10-18)
    dateService = DateService(
      nowProvider: () => DateTime(2026, 10, 18, 5, 0, 0),
    );

    service = DailyCheckInV2Service(
      programRepository: programRepo,
      checkInRepository: checkInRepo,
      dateService: dateService,
    );
  });

  tearDown(() async {
    if (programBox.isOpen) {
      await programBox.close();
    }
    if (checkInBox.isOpen) {
      await checkInBox.close();
    }
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<ProgramV2Model> createProgram({
    String id = 'prog-test-1',
    String ibadahId = 'ibd-tahajjud',
    String ibadahName = 'Shalat Tahajjud',
    int targetDays = 40,
    String startDayKey = '2026-10-18',
    String status = ProgramV2Model.statusActive,
  }) async {
    final prog = ProgramV2Model(
      id: id,
      ibadahId: ibadahId,
      ibadahNameSnapshot: ibadahName,
      targetDays: targetDays,
      startDayKey: startDayKey,
      status: status,
      createdAt: DateTime(2026, 10, 18, 4, 0),
      updatedAt: DateTime(2026, 10, 18, 4, 0),
    );
    await programRepo.save(prog);
    return prog;
  }

  group('Daily Check-in & Progress Calculation Service', () {
    test('1. Valid first-day check-in persists record and reports progress 1',
        () async {
      final prog = await createProgram();

      final result = await service.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );

      expect(result.isSuccess, isTrue);
      expect(result.checkIn, isNotNull);
      expect(result.checkIn!.programId, equals(prog.id));
      expect(result.checkIn!.dayKey, equals('2026-10-18'));
      expect(result.targetReached, isFalse);
      expect(result.progress!.completedDays, equals(1));
      expect(result.progress!.remainingDays, equals(39));
      expect(result.progress!.isCompletedToday, isTrue);

      expect(checkInRepo.getAll().length, equals(1));
    });

    test('2. Check-in without user confirmation fails with no write', () async {
      final prog = await createProgram();

      final result = await service.checkIn(
        programId: prog.id,
        confirmedByUser: false,
      );

      expect(result.isFailure, isTrue);
      expect(result.failureReason,
          equals(DailyCheckInFailureReason.confirmationRequired));
      expect(checkInRepo.getAll(), isEmpty);
    });

    test('3. Rejects blank and unknown program IDs', () async {
      final blankResult = await service.checkIn(
        programId: '   ',
        confirmedByUser: true,
      );
      expect(blankResult.isFailure, isTrue);
      expect(blankResult.failureReason,
          equals(DailyCheckInFailureReason.invalidProgramId));

      final unknownResult = await service.checkIn(
        programId: 'prog-does-not-exist',
        confirmedByUser: true,
      );
      expect(unknownResult.isFailure, isTrue);
      expect(unknownResult.failureReason,
          equals(DailyCheckInFailureReason.programNotFound));

      expect(checkInRepo.getAll(), isEmpty);
    });

    test('4. Program scheduled to start tomorrow cannot check in today',
        () async {
      final prog = await createProgram(startDayKey: '2026-10-19');

      final result = await service.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );

      expect(result.isFailure, isTrue);
      expect(result.failureReason,
          equals(DailyCheckInFailureReason.programNotStarted));
      expect(checkInRepo.getAll(), isEmpty);
    });

    test('5. Program starting tomorrow can check in when that day arrives',
        () async {
      final prog = await createProgram(startDayKey: '2026-10-19');

      final tomorrowService = DailyCheckInV2Service(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(
          nowProvider: () => DateTime(2026, 10, 19, 6, 0, 0),
        ),
      );

      final result = await tomorrowService.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );

      expect(result.isSuccess, isTrue);
      expect(result.checkIn!.dayKey, equals('2026-10-19'));
      expect(result.progress!.completedDays, equals(1));
    });

    test('6. Evaluates operational boundary at 03:00 accurately', () async {
      final prog = await createProgram(startDayKey: '2026-10-17');

      final earlyService = DailyCheckInV2Service(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(
          nowProvider: () => DateTime(2026, 10, 18, 2, 59, 59, 999),
        ),
      );
      final earlyResult = await earlyService.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );
      expect(earlyResult.isSuccess, isTrue);
      expect(earlyResult.checkIn!.dayKey, equals('2026-10-17'));

      final atBoundaryService = DailyCheckInV2Service(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(
          nowProvider: () => DateTime(2026, 10, 18, 3, 0, 0, 0),
        ),
      );
      final atBoundaryResult = await atBoundaryService.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );
      expect(atBoundaryResult.isSuccess, isTrue);
      expect(atBoundaryResult.checkIn!.dayKey, equals('2026-10-18'));

      expect(checkInRepo.getAll().length, equals(2));
    });

    test('7. Repeated tap within the same operational day is rejected',
        () async {
      final prog = await createProgram();

      final first = await service.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );
      expect(first.isSuccess, isTrue);

      final second = await service.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );
      expect(second.isFailure, isTrue);
      expect(second.failureReason,
          equals(DailyCheckInFailureReason.alreadyCheckedIn));

      expect(checkInRepo.getAll().length, equals(1));
    });

    test('8. Two valid check-ins on consecutive operational days accumulate',
        () async {
      final prog = await createProgram(startDayKey: '2026-10-18');

      final day1 = await service.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );
      expect(day1.isSuccess, isTrue);
      expect(day1.progress!.completedDays, equals(1));

      final day2Service = DailyCheckInV2Service(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(
          nowProvider: () => DateTime(2026, 10, 19, 8, 0, 0),
        ),
      );
      final day2 = await day2Service.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );
      expect(day2.isSuccess, isTrue);
      expect(day2.progress!.completedDays, equals(2));
      expect(day2.progress!.remainingDays, equals(38));
      expect(checkInRepo.getAll().length, equals(2));
    });

    test('9. Program with status PENDING_FAILURE cannot check in', () async {
      final prog = await createProgram(
        status: ProgramV2Model.statusPendingFailure,
      );

      final result = await service.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );

      expect(result.isFailure, isTrue);
      expect(result.failureReason,
          equals(DailyCheckInFailureReason.programNotActive));
      expect(checkInRepo.getAll(), isEmpty);
    });

    test('10. Terminal programs (FAILED, WARNING, SUCCESS) cannot check in',
        () async {
      for (final terminalStatus in [
        ProgramV2Model.statusFailed,
        ProgramV2Model.statusWarning,
        ProgramV2Model.statusSuccess,
      ]) {
        final prog = await createProgram(
          id: 'prog-$terminalStatus',
          status: terminalStatus,
        );

        final result = await service.checkIn(
          programId: prog.id,
          confirmedByUser: true,
        );

        expect(result.isFailure, isTrue);
        expect(result.failureReason,
            equals(DailyCheckInFailureReason.programNotActive));
      }
      expect(checkInRepo.getAll(), isEmpty);
    });

    test('11. Missing the first required day blocks check-in on the second day',
        () async {
      final prog = await createProgram(startDayKey: '2026-10-17');

      final result = await service.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );

      expect(result.isFailure, isTrue);
      expect(result.failureReason,
          equals(DailyCheckInFailureReason.requiresMuhasabah));
      expect(checkInRepo.getAll(), isEmpty);
    });

    test('12. Missing a middle operational day blocks subsequent check-in',
        () async {
      final prog = await createProgram(startDayKey: '2026-10-18');
      await service.checkIn(programId: prog.id, confirmedByUser: true);

      final day3Service = DailyCheckInV2Service(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(
          nowProvider: () => DateTime(2026, 10, 20, 5, 0, 0),
        ),
      );

      final result = await day3Service.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );

      expect(result.isFailure, isTrue);
      expect(result.failureReason,
          equals(DailyCheckInFailureReason.requiresMuhasabah));
      expect(checkInRepo.getAll().length, equals(1));
    });

    test('13. Multi-day offline gap blocks check-in with requiresMuhasabah',
        () async {
      final prog = await createProgram(startDayKey: '2026-10-18');
      await service.checkIn(programId: prog.id, confirmedByUser: true);

      final day6Service = DailyCheckInV2Service(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(
          nowProvider: () => DateTime(2026, 10, 23, 5, 0, 0),
        ),
      );

      final result = await day6Service.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );

      expect(result.isFailure, isTrue);
      expect(result.failureReason,
          equals(DailyCheckInFailureReason.requiresMuhasabah));
      expect(checkInRepo.getAll().length, equals(1));
    });

    test('14. Failed eligibility causes zero new writes', () async {
      final prog = await createProgram();

      await service.checkIn(programId: prog.id, confirmedByUser: false);
      expect(checkInRepo.getAll(), isEmpty);

      await service.checkIn(programId: '', confirmedByUser: true);
      expect(checkInRepo.getAll(), isEmpty);
    });

    test('15. Different programs check in on the same day independently',
        () async {
      final prog1 = await createProgram(id: 'prog-1', ibadahId: 'ibd-1');
      final prog2 = await createProgram(id: 'prog-2', ibadahId: 'ibd-2');

      final res1 = await service.checkIn(
        programId: prog1.id,
        confirmedByUser: true,
      );
      final res2 = await service.checkIn(
        programId: prog2.id,
        confirmedByUser: true,
      );

      expect(res1.isSuccess, isTrue);
      expect(res2.isSuccess, isTrue);
      expect(checkInRepo.getAll().length, equals(2));
      expect(checkInRepo.getByProgramId('prog-1').length, equals(1));
      expect(checkInRepo.getByProgramId('prog-2').length, equals(1));
    });

    test('16. Distinct valid day keys determine progress', () async {
      final validProg = await createProgram(
        id: 'prog-valid-start',
        startDayKey: '2026-10-15',
      );
      for (var i = 15; i <= 17; i++) {
        final dayKey = '2026-10-$i';
        await checkInRepo.save(DailyCheckInModel(
          id: '${dayKey}_${validProg.id}',
          programId: validProg.id,
          dayKey: dayKey,
          checkedAt: DateTime(2026, 10, i, 5, 0),
          createdAt: DateTime(2026, 10, i, 5, 0),
        ));
      }

      final validProgress = await service.getProgress(validProg.id);
      expect(validProgress!.completedDays, equals(3));
      expect(validProgress.remainingDays, equals(37));
    });

    test('17. Duplicate stored records do not inflate progress', () async {
      final prog = await createProgram();

      // Canonical record for operational day
      await checkInRepo.save(DailyCheckInModel(
        id: DailyCheckInV2Repository.buildCheckInId('2026-10-18', prog.id),
        programId: prog.id,
        dayKey: '2026-10-18',
        checkedAt: DateTime(2026, 10, 18, 5, 0),
        createdAt: DateTime(2026, 10, 18, 5, 0),
      ));
      // Duplicate record for the same dayKey
      await checkInRepo.save(DailyCheckInModel(
        id: 'legacy-dup-2',
        programId: prog.id,
        dayKey: '2026-10-18',
        checkedAt: DateTime(2026, 10, 18, 5, 30),
        createdAt: DateTime(2026, 10, 18, 5, 30),
      ));

      final progress = await service.getProgress(prog.id);
      expect(progress!.completedDays, equals(1));
    });

    test('18. Check-ins before start or in future do not inflate progress',
        () async {
      final prog = await createProgram(startDayKey: '2026-10-18');

      await checkInRepo.save(DailyCheckInModel(
        id: 'checkin-past',
        programId: prog.id,
        dayKey: '2026-10-17',
        checkedAt: DateTime(2026, 10, 17, 5, 0),
        createdAt: DateTime(2026, 10, 17, 5, 0),
      ));

      await checkInRepo.save(DailyCheckInModel(
        id: 'checkin-future',
        programId: prog.id,
        dayKey: '2026-10-19',
        checkedAt: DateTime(2026, 10, 19, 5, 0),
        createdAt: DateTime(2026, 10, 19, 5, 0),
      ));

      final progress = await service.getProgress(prog.id);
      expect(progress!.completedDays, equals(0));
    });

    test('19. Corrupt/future records cannot authorize target completion',
        () async {
      final prog = await createProgram(targetDays: 2);

      await checkInRepo.save(DailyCheckInModel(
        id: 'checkin-future-1',
        programId: prog.id,
        dayKey: '2026-10-30',
        checkedAt: DateTime(2026, 10, 30, 5, 0),
        createdAt: DateTime(2026, 10, 30, 5, 0),
      ));

      final progress = await service.getProgress(prog.id);
      expect(progress!.isTargetReached, isFalse);
      expect(progress.completedDays, equals(0));
    });

    test('20. CompletedToday accurately shifts across the 03:00 boundary',
        () async {
      final prog = await createProgram(startDayKey: '2026-10-17');

      final earlyService = DailyCheckInV2Service(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(
          nowProvider: () => DateTime(2026, 10, 18, 2, 30, 0),
        ),
      );
      await earlyService.checkIn(programId: prog.id, confirmedByUser: true);

      final preProg = await earlyService.getProgress(prog.id);
      expect(preProg!.isCompletedToday, isTrue);

      final postService = DailyCheckInV2Service(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(
          nowProvider: () => DateTime(2026, 10, 18, 3, 0, 1),
        ),
      );
      final postProg = await postService.getProgress(prog.id);
      expect(postProg!.isCompletedToday, isFalse);
    });

    test(
        '21. Remaining days never become negative with realistic 40-day target',
        () async {
      // 40-day program starting 39 days ago (2026-09-09)
      final prog =
          await createProgram(targetDays: 40, startDayKey: '2026-09-09');

      // Populate 39 consecutive days
      String checkDay = '2026-09-09';
      for (int i = 0; i < 39; i++) {
        final dayKey = checkDay;
        await checkInRepo.save(DailyCheckInModel(
          id: DailyCheckInV2Repository.buildCheckInId(dayKey, prog.id),
          programId: prog.id,
          dayKey: dayKey,
          checkedAt: DateTime(2026, 9, 9, 5, 0).add(Duration(days: i)),
          createdAt: DateTime(2026, 9, 9, 5, 0).add(Duration(days: i)),
        ));
        checkDay = dateService.getNextDayKey(checkDay);
      }

      await service.checkIn(programId: prog.id, confirmedByUser: true);

      final progress = await service.getProgress(prog.id);
      expect(progress!.completedDays, equals(40));
      expect(progress.remainingDays, equals(0));
    });

    test('22. Final target-day check-in returns targetReached true on day 40',
        () async {
      final prog =
          await createProgram(targetDays: 40, startDayKey: '2026-09-09');

      String checkDay = '2026-09-09';
      for (int i = 0; i < 39; i++) {
        final dayKey = checkDay;
        await checkInRepo.save(DailyCheckInModel(
          id: DailyCheckInV2Repository.buildCheckInId(dayKey, prog.id),
          programId: prog.id,
          dayKey: dayKey,
          checkedAt: DateTime(2026, 9, 9, 5, 0).add(Duration(days: i)),
          createdAt: DateTime(2026, 9, 9, 5, 0).add(Duration(days: i)),
        ));
        checkDay = dateService.getNextDayKey(checkDay);
      }

      final result = await service.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );

      expect(result.isSuccess, isTrue);
      expect(result.targetReached, isTrue);
      expect(result.progress!.completedDays, equals(40));
      expect(result.progress!.remainingDays, equals(0));
      expect(result.progress!.isTargetReached, isTrue);
    });

    test(
        '23. Check-in after 40-day target reached is rejected on day 41 with targetAlreadyReached',
        () async {
      final prog =
          await createProgram(targetDays: 40, startDayKey: '2026-09-09');

      String checkDay = '2026-09-09';
      for (int i = 0; i < 39; i++) {
        final dayKey = checkDay;
        await checkInRepo.save(DailyCheckInModel(
          id: DailyCheckInV2Repository.buildCheckInId(dayKey, prog.id),
          programId: prog.id,
          dayKey: dayKey,
          checkedAt: DateTime(2026, 9, 9, 5, 0).add(Duration(days: i)),
          createdAt: DateTime(2026, 9, 9, 5, 0).add(Duration(days: i)),
        ));
        checkDay = dateService.getNextDayKey(checkDay);
      }
      // Check in day 40
      final day40Result =
          await service.checkIn(programId: prog.id, confirmedByUser: true);
      expect(day40Result.isSuccess, isTrue);
      expect(day40Result.targetReached, isTrue);

      // Attempt check-in on day 41 (2026-10-19)
      final nextDayService = DailyCheckInV2Service(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(
          nowProvider: () => DateTime(2026, 10, 19, 5, 0, 0),
        ),
      );

      final result = await nextDayService.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );

      expect(result.isFailure, isTrue);
      expect(result.failureReason,
          equals(DailyCheckInFailureReason.targetAlreadyReached));

      // Program status is still ACTIVE (not mutated in this task)
      final reloadedProg = programRepo.getById(prog.id);
      expect(reloadedProg!.status, equals(ProgramV2Model.statusActive));
      // No 41st check-in record written
      expect(checkInRepo.getAll().length, equals(40));
    });

    test('24. Concurrent check-ins produce exactly one write and one failure',
        () async {
      final prog = await createProgram();

      final future1 = service.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );
      final future2 = service.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );

      final results = await Future.wait([future1, future2]);
      final successes = results.where((r) => r.isSuccess).toList();
      final failures = results.where((r) => r.isFailure).toList();

      expect(successes.length, equals(1));
      expect(failures.length, equals(1));
      expect(failures.first.failureReason,
          equals(DailyCheckInFailureReason.alreadyCheckedIn));
      expect(checkInRepo.getAll().length, equals(1));
    });

    test('25. CheckedAt and createdAt preserve exact instant with milliseconds',
        () async {
      final prog = await createProgram();
      final fixedClock = DateTime(2026, 10, 18, 5, 30, 45, 678);

      final customService = DailyCheckInV2Service(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(nowProvider: () => fixedClock),
      );

      final result = await customService.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );

      expect(result.isSuccess, isTrue);
      expect(result.checkIn!.checkedAt.millisecond, equals(678));
      expect(result.checkIn!.createdAt.millisecond, equals(678));
      expect(result.checkIn!.checkedAt.isAtSameMomentAs(fixedClock), isTrue);
      expect(result.checkIn!.createdAt.isAtSameMomentAs(fixedClock), isTrue);
    });

    test('26. Persisted records survive flush, close, reopen, and reread',
        () async {
      final prog = await createProgram();
      final result = await service.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );
      expect(result.isSuccess, isTrue);
      final checkInId = result.checkIn!.id;

      await checkInRepo.flush();
      await checkInBox.close();
      expect(checkInBox.isOpen, isFalse);

      final reopenedBox =
          await Hive.openBox<DailyCheckInModel>('test_checkins_box');
      final reopenedRepo = DailyCheckInV2Repository(box: reopenedBox);

      final retrieved = reopenedRepo.getById(checkInId);
      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals(checkInId));
      expect(retrieved.programId, equals(prog.id));
      expect(retrieved.dayKey, equals('2026-10-18'));

      checkInBox = reopenedBox;
    });

    test('27. Closed box returns typed persistenceError without uncaught error',
        () async {
      final prog = await createProgram();
      await checkInBox.close();

      final result = await service.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );

      expect(result.isFailure, isTrue);
      expect(result.failureReason,
          equals(DailyCheckInFailureReason.persistenceError));
    });

    test('28. Handled repository write failure returns persistenceError',
        () async {
      final prog = await createProgram();
      final failingRepo = FailingSaveDailyCheckInRepository(box: checkInBox);

      final failingService = DailyCheckInV2Service(
        programRepository: programRepo,
        checkInRepository: failingRepo,
        dateService: dateService,
      );

      final result = await failingService.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );

      expect(result.isFailure, isTrue);
      expect(result.failureReason,
          equals(DailyCheckInFailureReason.persistenceError));
    });

    test('29. Original check-in timestamp is preserved across repeat attempts',
        () async {
      final prog = await createProgram();

      final first = await service.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );
      final originalCheckedAt = first.checkIn!.checkedAt;

      final laterService = DailyCheckInV2Service(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(
          nowProvider: () => DateTime(2026, 10, 18, 10, 0, 0),
        ),
      );
      await laterService.checkIn(programId: prog.id, confirmedByUser: true);

      final current = checkInRepo.getById(first.checkIn!.id);
      expect(current!.checkedAt, equals(originalCheckedAt));
    });

    test('30. Program status and metadata remain untouched by check-in',
        () async {
      final prog = await createProgram();
      final initialUpdatedAt = prog.updatedAt;

      await service.checkIn(programId: prog.id, confirmedByUser: true);

      final retrievedProg = programRepo.getById(prog.id);
      expect(retrievedProg!.status, equals(ProgramV2Model.statusActive));
      expect(retrievedProg.updatedAt, equals(initialUpdatedAt));
      expect(retrievedProg.finalizedAt, isNull);
    });

    test(
        '31. Occupied canonical key containing another record identity rejects with dataIntegrityError',
        () async {
      final prog1 = await createProgram(id: 'prog-1');
      final prog2 = await createProgram(id: 'prog-2');

      final canonicalKeyForProg1 =
          DailyCheckInV2Repository.buildCheckInId('2026-10-18', prog1.id);

      // Pre-occupy prog1 canonical key with prog2 record
      final alienRecord = DailyCheckInModel(
        id: canonicalKeyForProg1,
        programId: prog2.id,
        dayKey: '2026-10-18',
        checkedAt: DateTime(2026, 10, 18, 5, 0),
        createdAt: DateTime(2026, 10, 18, 5, 0),
      );
      await checkInBox.put(canonicalKeyForProg1, alienRecord);

      final result = await service.checkIn(
        programId: prog1.id,
        confirmedByUser: true,
      );

      expect(result.isFailure, isTrue);
      expect(result.failureReason,
          equals(DailyCheckInFailureReason.dataIntegrityError));

      // Assert alien record was not overwritten
      final recordAtKey = checkInRepo.getById(canonicalKeyForProg1);
      expect(recordAtKey!.programId, equals(prog2.id));
    });

    test(
        '32. Record whose internal id conflicts with expected canonical identity rejects with dataIntegrityError',
        () async {
      final prog = await createProgram(id: 'prog-1');
      final canonicalKey =
          DailyCheckInV2Repository.buildCheckInId('2026-10-18', prog.id);

      // Record stored at canonical key has mismatched internal id
      final corruptRecord = DailyCheckInModel(
        id: 'conflicting-internal-id',
        programId: prog.id,
        dayKey: '2026-10-18',
        checkedAt: DateTime(2026, 10, 18, 5, 0),
        createdAt: DateTime(2026, 10, 18, 5, 0),
      );
      await checkInBox.put(canonicalKey, corruptRecord);

      final result = await service.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );

      expect(result.isFailure, isTrue);
      expect(result.failureReason,
          equals(DailyCheckInFailureReason.dataIntegrityError));

      // Assert record was not overwritten
      final stored = checkInRepo.getById(canonicalKey);
      expect(stored!.id, equals('conflicting-internal-id'));
    });

    test(
        '33. Existing anomalous-key record for same program/day rejects with dataIntegrityError and prevents second check-in',
        () async {
      final prog = await createProgram(id: 'prog-1');

      // Stored under legacy/anomalous key
      await checkInBox.put(
        'legacy_anomalous_key',
        DailyCheckInModel(
          id: 'legacy_anomalous_key',
          programId: prog.id,
          dayKey: '2026-10-18',
          checkedAt: DateTime(2026, 10, 18, 5, 0),
          createdAt: DateTime(2026, 10, 18, 5, 0),
        ),
      );

      final result = await service.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );

      expect(result.isFailure, isTrue);
      expect(result.failureReason,
          equals(DailyCheckInFailureReason.dataIntegrityError));
      // No duplicate check-in added
      expect(checkInRepo.getAll().length, equals(1));
    });

    test('34. No overwritten records after integrity rejection', () async {
      final prog = await createProgram(id: 'prog-1');
      final canonicalKey =
          DailyCheckInV2Repository.buildCheckInId('2026-10-18', prog.id);

      final originalRecord = DailyCheckInModel(
        id: 'different-id',
        programId: 'another-prog',
        dayKey: '2026-10-17',
        checkedAt: DateTime(2026, 10, 17, 5, 0),
        createdAt: DateTime(2026, 10, 17, 5, 0),
      );
      await checkInBox.put(canonicalKey, originalRecord);

      final countBefore = checkInRepo.getAll().length;

      final result = await service.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );
      expect(result.isFailure, isTrue);
      expect(result.failureReason,
          equals(DailyCheckInFailureReason.dataIntegrityError));

      expect(checkInRepo.getAll().length, equals(countBefore));
      final preserved = checkInRepo.getById(canonicalKey);
      expect(preserved!.programId, equals('another-prog'));
      expect(preserved.dayKey, equals('2026-10-17'));
    });

    test(
        '35. Correctly formatted but nonconsecutive stored day keys do not authorize target completion',
        () async {
      // 40-day program started 2026-09-09
      final prog =
          await createProgram(targetDays: 40, startDayKey: '2026-09-09');

      // Insert 40 records, but day 20 (2026-09-28) is missing, and an extra day at end is added
      String checkDay = '2026-09-09';
      for (int i = 0; i < 41; i++) {
        final dayKey = checkDay;
        checkDay = dateService.getNextDayKey(checkDay);
        if (i == 19) continue; // Skip day 20
        await checkInRepo.save(DailyCheckInModel(
          id: DailyCheckInV2Repository.buildCheckInId(dayKey, prog.id),
          programId: prog.id,
          dayKey: dayKey,
          checkedAt: DateTime(2026, 9, 9, 5, 0).add(Duration(days: i)),
          createdAt: DateTime(2026, 9, 9, 5, 0).add(Duration(days: i)),
        ));
      }

      final progress = await service.getProgress(prog.id);
      expect(progress, isNotNull);
      // Streak broken at day 20, so only first 19 consecutive days count
      expect(progress!.completedDays, equals(19));
      expect(progress.isTargetReached, isFalse);
    });

    test(
        '36. Mismatched check-in ID or storage key is excluded from progress and cannot authorize target completion',
        () async {
      final prog =
          await createProgram(targetDays: 40, startDayKey: '2026-10-18');

      // Insert record with mismatched ID
      await checkInBox.put(
        'arbitrary_key',
        DailyCheckInModel(
          id: 'wrong_id',
          programId: prog.id,
          dayKey: '2026-10-18',
          checkedAt: DateTime(2026, 10, 18, 5, 0),
          createdAt: DateTime(2026, 10, 18, 5, 0),
        ),
      );

      final progress = await service.getProgress(prog.id);
      expect(progress!.completedDays, equals(0));
      expect(progress.isTargetReached, isFalse);
    });

    test(
        '37. Duplicate records with conflicting identity cannot produce targetReached true',
        () async {
      final prog =
          await createProgram(targetDays: 1, startDayKey: '2026-10-18');

      final canonicalId =
          DailyCheckInV2Repository.buildCheckInId('2026-10-18', prog.id);
      await checkInBox.put(
        canonicalId,
        DailyCheckInModel(
          id: canonicalId,
          programId: prog.id,
          dayKey: '2026-10-18',
          checkedAt: DateTime(2026, 10, 18, 5, 0),
          createdAt: DateTime(2026, 10, 18, 5, 0),
        ),
      );
      // Conflicting duplicate with different timestamp under secondary key
      await checkInBox.put(
        'dup_key',
        DailyCheckInModel(
          id: canonicalId,
          programId: prog.id,
          dayKey: '2026-10-18',
          checkedAt: DateTime(2026, 10, 18, 6, 0),
          createdAt: DateTime(2026, 10, 18, 6, 0),
        ),
      );

      final progress = await service.getProgress(prog.id);
      expect(progress!.isTargetReached, isFalse);
    });

    test('38. Program box closed returns typed error or null without crashing',
        () async {
      final prog = await createProgram();
      await programBox.close();

      final checkInResult = await service.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );
      expect(checkInResult.isFailure, isTrue);
      expect(checkInResult.failureReason,
          equals(DailyCheckInFailureReason.persistenceError));

      final progress = await service.getProgress(prog.id);
      expect(progress, isNull);
    });

    test(
        '39. Check-in box closed during progress retrieval returns null without uncaught exception',
        () async {
      final prog = await createProgram();
      await checkInBox.close();

      final progress = await service.getProgress(prog.id);
      expect(progress, isNull);
    });

    test(
        '40. Injected repository failing during getByProgramId returns null in getProgress',
        () async {
      final prog = await createProgram();
      final failingRepo = FailingGetByProgramIdRepository(box: checkInBox);

      final failingService = DailyCheckInV2Service(
        programRepository: programRepo,
        checkInRepository: failingRepo,
        dateService: dateService,
      );

      final progress = await failingService.getProgress(prog.id);
      expect(progress, isNull);

      final checkInResult = await failingService.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );
      expect(checkInResult.isFailure, isTrue);
      expect(checkInResult.failureReason,
          equals(DailyCheckInFailureReason.persistenceError));
    });

    test(
        '41. After successful write, retry cannot overwrite original check-in and preserves original checkedAt',
        () async {
      final prog = await createProgram();

      final firstResult = await service.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );
      expect(firstResult.isSuccess, isTrue);
      final originalCheckedAt = firstResult.checkIn!.checkedAt;

      // Retry immediately or on same operational day
      final retryResult = await service.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );
      expect(retryResult.isFailure, isTrue);
      expect(retryResult.failureReason,
          equals(DailyCheckInFailureReason.alreadyCheckedIn));

      final stored = checkInRepo.getById(firstResult.checkIn!.id);
      expect(stored!.checkedAt, equals(originalCheckedAt));
      expect(checkInRepo.getAll().length, equals(1));
    });

    test(
        '42. Realistic 40-day program missing one required day does not authorize SUCCESS',
        () async {
      final prog =
          await createProgram(targetDays: 40, startDayKey: '2026-09-09');

      // Populate 38 days, skipping day 20 (2026-09-28)
      String checkDay = '2026-09-09';
      for (int i = 0; i < 39; i++) {
        final dayKey = checkDay;
        checkDay = dateService.getNextDayKey(checkDay);
        if (i == 19) continue; // Skip day 20
        await checkInRepo.save(DailyCheckInModel(
          id: DailyCheckInV2Repository.buildCheckInId(dayKey, prog.id),
          programId: prog.id,
          dayKey: dayKey,
          checkedAt: DateTime(2026, 9, 9, 5, 0).add(Duration(days: i)),
          createdAt: DateTime(2026, 9, 9, 5, 0).add(Duration(days: i)),
        ));
      }

      // Check-in on day 40 is attempted
      final result = await service.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );

      // Must be blocked because day 20 was missed!
      expect(result.isFailure, isTrue);
      expect(result.failureReason,
          equals(DailyCheckInFailureReason.requiresMuhasabah));

      final progress = await service.getProgress(prog.id);
      expect(progress!.completedDays, equals(19));
      expect(progress.isTargetReached, isFalse);
    });

    test(
        '43. Repository save is strictly insert-only and rejects overwrites with StateError',
        () async {
      final prog = await createProgram(id: 'prog-insert-only');
      final canonicalId =
          DailyCheckInV2Repository.buildCheckInId('2026-10-18', prog.id);

      final original = DailyCheckInModel(
        id: canonicalId,
        programId: prog.id,
        dayKey: '2026-10-18',
        checkedAt: DateTime(2026, 10, 18, 5, 0),
        createdAt: DateTime(2026, 10, 18, 5, 0),
      );

      // 1. Initial save to empty key succeeds
      await checkInRepo.save(original);
      expect(checkInRepo.getAll().length, equals(1));

      // 2. Second record with same key but different checkedAt is rejected
      final modifiedTimestamp = DailyCheckInModel(
        id: canonicalId,
        programId: prog.id,
        dayKey: '2026-10-18',
        checkedAt: DateTime(2026, 10, 18, 6, 0),
        createdAt: DateTime(2026, 10, 18, 6, 0),
      );
      expect(
        () => checkInRepo.save(modifiedTimestamp),
        throwsA(isA<StateError>()),
      );

      // 3. Re-saving identical record is rejected
      expect(
        () => checkInRepo.save(original),
        throwsA(isA<StateError>()),
      );

      // 4. Record count and original timestamps remain unchanged
      expect(checkInRepo.getAll().length, equals(1));
      final preserved = checkInRepo.getById(canonicalId);
      expect(preserved!.checkedAt, equals(original.checkedAt));
      expect(preserved.createdAt, equals(original.createdAt));
    });

    test(
        '44. Normal checkIn through service succeeds and repeat attempts are rejected without overwrite',
        () async {
      final prog = await createProgram(id: 'prog-service-flow');

      final firstResult = await service.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );
      expect(firstResult.isSuccess, isTrue);

      final secondResult = await service.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );
      expect(secondResult.isFailure, isTrue);
      expect(secondResult.failureReason,
          equals(DailyCheckInFailureReason.alreadyCheckedIn));

      expect(checkInRepo.getAll().length, equals(1));
    });

    test(
        '45. 40 valid check-ins plus an anomalous record rejects next-day check-in with dataIntegrityError',
        () async {
      final prog =
          await createProgram(targetDays: 40, startDayKey: '2026-09-09');

      // Populate 40 valid consecutive days
      String checkDay = '2026-09-09';
      for (int i = 0; i < 40; i++) {
        final dayKey = checkDay;
        await checkInRepo.save(DailyCheckInModel(
          id: DailyCheckInV2Repository.buildCheckInId(dayKey, prog.id),
          programId: prog.id,
          dayKey: dayKey,
          checkedAt: DateTime(2026, 9, 9, 5, 0).add(Duration(days: i)),
          createdAt: DateTime(2026, 9, 9, 5, 0).add(Duration(days: i)),
        ));
        checkDay = dateService.getNextDayKey(checkDay);
      }

      // Inject an anomalous/corrupted record in storage for the same program
      await checkInBox.put(
        'corrupted_extra_record',
        DailyCheckInModel(
          id: 'corrupted_extra_record',
          programId: prog.id,
          dayKey: '2026-10-25',
          checkedAt: DateTime(2026, 10, 25, 5, 0),
          createdAt: DateTime(2026, 10, 25, 5, 0),
        ),
      );

      // Attempt check-in on day 41 (2026-10-19)
      final nextDayService = DailyCheckInV2Service(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(
          nowProvider: () => DateTime(2026, 10, 19, 5, 0, 0),
        ),
      );

      final result = await nextDayService.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );

      // Must reject with dataIntegrityError because data is anomalous
      expect(result.isFailure, isTrue);
      expect(result.failureReason,
          equals(DailyCheckInFailureReason.dataIntegrityError));
    });

    test(
        '46. 40 valid check-ins without anomalies correctly reports targetAlreadyReached on day 41',
        () async {
      final prog =
          await createProgram(targetDays: 40, startDayKey: '2026-09-09');

      String checkDay = '2026-09-09';
      for (int i = 0; i < 40; i++) {
        final dayKey = checkDay;
        await checkInRepo.save(DailyCheckInModel(
          id: DailyCheckInV2Repository.buildCheckInId(dayKey, prog.id),
          programId: prog.id,
          dayKey: dayKey,
          checkedAt: DateTime(2026, 9, 9, 5, 0).add(Duration(days: i)),
          createdAt: DateTime(2026, 9, 9, 5, 0).add(Duration(days: i)),
        ));
        checkDay = dateService.getNextDayKey(checkDay);
      }

      final nextDayService = DailyCheckInV2Service(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(
          nowProvider: () => DateTime(2026, 10, 19, 5, 0, 0),
        ),
      );

      final result = await nextDayService.checkIn(
        programId: prog.id,
        confirmedByUser: true,
      );

      expect(result.isFailure, isTrue);
      expect(result.failureReason,
          equals(DailyCheckInFailureReason.targetAlreadyReached));
    });
  });
}

class FailingSaveDailyCheckInRepository extends DailyCheckInV2Repository {
  FailingSaveDailyCheckInRepository({required super.box});

  @override
  Future<void> save(DailyCheckInModel checkIn) async {
    throw Exception('Simulated disk write failure on check-in');
  }
}

class FailingGetByProgramIdRepository extends DailyCheckInV2Repository {
  FailingGetByProgramIdRepository({required super.box});

  @override
  List<DailyCheckInModel> getByProgramId(String programId) {
    throw Exception('Simulated Hive error during getByProgramId');
  }
}
