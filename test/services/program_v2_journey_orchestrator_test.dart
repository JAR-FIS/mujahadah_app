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
import 'package:mujahadah/repositories/achievement_v2_repository.dart';
import 'package:mujahadah/repositories/daily_checkin_v2_repository.dart';
import 'package:mujahadah/repositories/failure_record_v2_repository.dart';
import 'package:mujahadah/repositories/program_v2_repository.dart';
import 'package:mujahadah/services/daily_checkin_v2_service.dart';
import 'package:mujahadah/services/program_v2_journey_orchestrator.dart';
import 'package:mujahadah/services/program_v2_muhasabah_service.dart';
import 'package:mujahadah/services/program_v2_reconciliation_service.dart';
import 'package:mujahadah/services/program_v2_success_service.dart';

class FailingProgramV2Repository extends ProgramV2Repository {
  bool shouldThrowOnGet = false;
  bool shouldThrowOnSave = false;
  String customErrorMessage = 'Simulated storage error on program lookup';

  FailingProgramV2Repository({required super.box});

  @override
  ProgramV2Model? getById(String id) {
    if (shouldThrowOnGet) {
      throw HiveError(customErrorMessage);
    }
    return super.getById(id);
  }

  @override
  Future<void> save(ProgramV2Model program) async {
    if (shouldThrowOnSave) {
      throw HiveError('Simulated storage error on program save');
    }
    await super.save(program);
  }
}

class MockBoundaryReconciliationService extends ProgramV2ReconciliationService {
  int reconcileProgramCallCount = 0;
  bool throwHiveOnFirstCall = false;
  bool throwHiveOnSecondCall = false;
  bool throwUnexpectedOnSecondCall = false;
  String customErrorMessage = 'Simulated internal error';

  MockBoundaryReconciliationService({
    required super.programRepository,
    required super.checkInRepository,
    super.dateService,
  });

  @override
  Future<ProgramReconciliationResult> reconcileProgram(
    String programId, {
    DateTime? capturedNow,
  }) async {
    reconcileProgramCallCount++;
    if (reconcileProgramCallCount == 1 && throwHiveOnFirstCall) {
      throw HiveError(customErrorMessage);
    }
    if (reconcileProgramCallCount == 2) {
      if (throwHiveOnSecondCall) {
        throw HiveError(
            'Internal storage fault: /data/user/0/app/cache/hive.lock');
      }
      if (throwUnexpectedOnSecondCall) {
        throw FormatException(
            'Internal unexpected parser crash at NativeEngine.cpp:128');
      }
    }
    return super.reconcileProgram(programId, capturedNow: capturedNow);
  }
}

class FailingAchievementV2Repository extends AchievementV2Repository {
  bool shouldThrowOnSave = false;

  FailingAchievementV2Repository({required super.box});

  @override
  Future<void> save(AchievementModel achievement) async {
    if (shouldThrowOnSave) {
      throw HiveError('Simulated storage error on achievement save');
    }
    await super.save(achievement);
  }
}

void main() {
  late Directory tempDir;
  late Box<ProgramV2Model> programBox;
  late Box<DailyCheckInModel> checkInBox;
  late Box<AchievementModel> achievementBox;
  late Box<FailureRecordModel> failureBox;

  late FailingProgramV2Repository programRepo;
  late DailyCheckInV2Repository checkInRepo;
  late FailingAchievementV2Repository achievementRepo;
  late FailureRecordV2Repository failureRepo;

  late DateTime currentClock;
  late DateService dateService;

  late DailyCheckInV2Service dailyCheckInService;
  late ProgramV2ReconciliationService reconciliationService;
  late ProgramV2MuhasabahService muhasabahService;
  late ProgramV2SuccessService successService;
  late ProgramV2JourneyOrchestrator orchestrator;

  String getOffsetDayKey(DateTime start, int offset) {
    final d = DateTime.utc(start.year, start.month, start.day + offset);
    return DateService.formatCalendarDayKey(d);
  }

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
    tempDir = Directory.systemTemp.createTempSync('journey_orchestrator_test_');
    Hive.init(tempDir.path);

    programBox = await Hive.openBox<ProgramV2Model>('test_programs_box');
    checkInBox = await Hive.openBox<DailyCheckInModel>('test_checkins_box');
    achievementBox =
        await Hive.openBox<AchievementModel>('test_achievements_box');
    failureBox = await Hive.openBox<FailureRecordModel>('test_failures_box');

    programRepo = FailingProgramV2Repository(box: programBox);
    checkInRepo = DailyCheckInV2Repository(box: checkInBox);
    achievementRepo = FailingAchievementV2Repository(box: achievementBox);
    failureRepo = FailureRecordV2Repository(box: failureBox);

    currentClock = DateTime(2026, 10, 18, 5, 0, 0);
    dateService = DateService(nowProvider: () => currentClock);

    dailyCheckInService = DailyCheckInV2Service(
      programRepository: programRepo,
      checkInRepository: checkInRepo,
      dateService: dateService,
    );

    reconciliationService = ProgramV2ReconciliationService(
      programRepository: programRepo,
      checkInRepository: checkInRepo,
      dateService: dateService,
    );

    muhasabahService = ProgramV2MuhasabahService(
      programRepository: programRepo,
      checkInRepository: checkInRepo,
      failureRecordRepository: failureRepo,
      dateService: dateService,
    );

    successService = ProgramV2SuccessService(
      programRepository: programRepo,
      checkInRepository: checkInRepo,
      achievementRepository: achievementRepo,
      failureRecordRepository: failureRepo,
      dateService: dateService,
    );

    orchestrator = ProgramV2JourneyOrchestrator(
      programRepository: programRepo,
      dailyCheckInService: dailyCheckInService,
      reconciliationService: reconciliationService,
      muhasabahService: muhasabahService,
      successService: successService,
      dateService: dateService,
    );
  });

  tearDown(() async {
    await programBox.close();
    await checkInBox.close();
    await achievementBox.close();
    await failureBox.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<ProgramV2Model> createProgram({
    required String id,
    int targetDays = 40,
    String startDayKey = '2026-10-18',
    String status = ProgramV2Model.statusActive,
    String? recipientNameSnapshot,
    String? pendingMissedDayKey,
    DateTime? finalizedAt,
  }) async {
    final prog = ProgramV2Model(
      id: id,
      ibadahId: 'ibadah_1',
      ibadahNameSnapshot: 'Tahajjud',
      targetDays: targetDays,
      startDayKey: startDayKey,
      status: status,
      recipientNameSnapshot: recipientNameSnapshot,
      pendingMissedDayKey: pendingMissedDayKey,
      finalizedAt: finalizedAt,
      createdAt: DateTime(2026, 10, 18, 0, 0, 0),
      updatedAt: DateTime(2026, 10, 18, 0, 0, 0),
    );
    await programRepo.save(prog);
    return prog;
  }

  Future<void> seedCheckIns({
    required String programId,
    required List<String> dayKeys,
  }) async {
    for (final dayKey in dayKeys) {
      final id = DailyCheckInV2Repository.buildCheckInId(dayKey, programId);
      final dayDate = DateService.parseDayKey(dayKey);
      final instant =
          DateTime(dayDate.year, dayDate.month, dayDate.day, 5, 0, 0);
      final checkIn = DailyCheckInModel(
        id: id,
        programId: programId,
        dayKey: dayKey,
        checkedAt: instant,
        createdAt: instant,
      );
      await checkInRepo.save(checkIn);
    }
  }

  group('Program V2 Core Journey Orchestrator Tests', () {
    test('1. First confirmed check-in succeeds', () async {
      await createProgram(
          id: 'prog_1', startDayKey: '2026-10-18', targetDays: 40);

      final result = await orchestrator.checkIn(
        programId: 'prog_1',
        confirmedByUser: true,
      );

      expect(result.isSuccess, isTrue);
      expect(result.outcome, OrchestratedCheckInOutcome.checkInCompleted);
      expect(result.checkIn, isNotNull);
      expect(result.checkIn!.dayKey, '2026-10-18');
      expect(result.progress, isNotNull);
      expect(result.progress!.completedDays, 1);
      expect(result.progress!.remainingDays, 39);
      expect(checkInRepo.hasCheckIn('prog_1', '2026-10-18'), isTrue);
    });

    test('2. Repeated same-day tap returns alreadyCheckedIn', () async {
      await createProgram(
          id: 'prog_1', startDayKey: '2026-10-18', targetDays: 40);

      final res1 = await orchestrator.checkIn(
          programId: 'prog_1', confirmedByUser: true);
      expect(res1.isSuccess, isTrue);

      final res2 = await orchestrator.checkIn(
          programId: 'prog_1', confirmedByUser: true);
      expect(res2.isSuccess, isFalse);
      expect(res2.isAlreadyCheckedIn, isTrue);
      expect(res2.outcome, OrchestratedCheckInOutcome.alreadyCheckedIn);
      expect(checkInRepo.getByProgramId('prog_1').length, 1);
    });

    test('3. Cancelled confirmation makes no writes', () async {
      await createProgram(
          id: 'prog_1', startDayKey: '2026-10-18', targetDays: 40);

      final result = await orchestrator.checkIn(
        programId: 'prog_1',
        confirmedByUser: false,
      );

      expect(result.isSuccess, isFalse);
      expect(result.outcome, OrchestratedCheckInOutcome.confirmationRequired);
      expect(checkInRepo.getAll(), isEmpty);
    });

    test('4. Future start date blocks check-in', () async {
      await createProgram(
          id: 'prog_1', startDayKey: '2026-10-25', targetDays: 40);

      final result = await orchestrator.checkIn(
        programId: 'prog_1',
        confirmedByUser: true,
      );

      expect(result.isSuccess, isFalse);
      expect(result.outcome, OrchestratedCheckInOutcome.programNotStarted);
      expect(checkInRepo.getAll(), isEmpty);
    });

    test('5. Normal intermediate progress remains ACTIVE', () async {
      final days = List.generate(
        9,
        (i) => '2026-10-${(1 + i).toString().padLeft(2, '0')}',
      );
      await createProgram(
          id: 'prog_1', startDayKey: '2026-10-01', targetDays: 40);
      await seedCheckIns(programId: 'prog_1', dayKeys: days);

      currentClock = DateTime(2026, 10, 10, 5, 0, 0); // Day 10

      final result = await orchestrator.checkIn(
        programId: 'prog_1',
        confirmedByUser: true,
      );

      expect(result.isSuccess, isTrue);
      expect(result.outcome, OrchestratedCheckInOutcome.checkInCompleted);
      expect(result.progress!.completedDays, 10);
      expect(result.progress!.remainingDays, 30);

      final prog = programRepo.getById('prog_1');
      expect(prog!.status, ProgramV2Model.statusActive);
    });

    test('6. Final check-in triggers SUCCESS', () async {
      final start = DateService.parseDayKey('2026-09-01');
      final days = List.generate(39, (i) => getOffsetDayKey(start, i));
      await createProgram(
          id: 'prog_1', startDayKey: '2026-09-01', targetDays: 40);
      await seedCheckIns(programId: 'prog_1', dayKeys: days);

      final day40Key = getOffsetDayKey(start, 39);
      final day40Date = DateService.parseDayKey(day40Key);
      currentClock =
          DateTime(day40Date.year, day40Date.month, day40Date.day, 5, 0, 0);

      final result = await orchestrator.checkIn(
        programId: 'prog_1',
        confirmedByUser: true,
        recipientNameSnapshot: 'Ahmad Mujahid',
      );

      expect(result.isSuccess, isTrue);
      expect(result.isSuccessFinalized, isTrue);
      expect(result.outcome, OrchestratedCheckInOutcome.successFinalized);
      expect(result.program!.status, ProgramV2Model.statusSuccess);
      expect(result.achievement, isNotNull);
      expect(result.achievement!.type, AchievementModel.typeFinalSuccess);
      expect(result.achievement!.milestoneDays, 40);
      expect(result.achievement!.recipientNameSnapshot, 'Ahmad Mujahid');

      final storedProg = programRepo.getById('prog_1');
      expect(storedProg!.status, ProgramV2Model.statusSuccess);
    });

    test('7. Target achievement persists exactly once', () async {
      final start = DateService.parseDayKey('2026-09-01');
      final day40Key = getOffsetDayKey(start, 39);
      final day40Date = DateService.parseDayKey(day40Key);
      currentClock =
          DateTime(day40Date.year, day40Date.month, day40Date.day, 5, 0, 0);

      final days = List.generate(39, (i) => getOffsetDayKey(start, i));
      await createProgram(
          id: 'prog_1', startDayKey: '2026-09-01', targetDays: 40);
      await seedCheckIns(programId: 'prog_1', dayKeys: days);

      final res1 = await orchestrator.checkIn(
        programId: 'prog_1',
        confirmedByUser: true,
        recipientNameSnapshot: 'Ahmad Mujahid',
      );
      expect(res1.isSuccessFinalized, isTrue);

      final res2 = await orchestrator.checkIn(
        programId: 'prog_1',
        confirmedByUser: true,
        recipientNameSnapshot: 'Ahmad Mujahid',
      );

      expect(achievementRepo.getByProgramId('prog_1').length, 1);
      expect(res2.outcome, OrchestratedCheckInOutcome.successFinalized);
    });

    test('8. Preflight detects and persists PENDING_FAILURE', () async {
      // Program starts 2026-10-01, current time is 2026-10-03 (day 2026-10-01 closed)
      await createProgram(
          id: 'prog_1', startDayKey: '2026-10-01', targetDays: 40);
      currentClock = DateTime(2026, 10, 3, 5, 0, 0);

      final result = await orchestrator.checkIn(
        programId: 'prog_1',
        confirmedByUser: true,
      );

      expect(result.isSuccess, isFalse);
      expect(result.isMuhasabahRequired, isTrue);
      expect(result.outcome, OrchestratedCheckInOutcome.muhasabahRequired);
      expect(result.missedDayKey, '2026-10-01');

      final prog = programRepo.getById('prog_1');
      expect(prog!.status, ProgramV2Model.statusPendingFailure);
      expect(prog.pendingMissedDayKey, '2026-10-01');
      expect(checkInRepo.getAll(), isEmpty);
    });

    test('9. Pending program cannot check in', () async {
      await createProgram(
        id: 'prog_1',
        startDayKey: '2026-10-01',
        status: ProgramV2Model.statusPendingFailure,
        pendingMissedDayKey: '2026-10-01',
      );
      currentClock = DateTime(2026, 10, 3, 5, 0, 0);

      final result = await orchestrator.checkIn(
        programId: 'prog_1',
        confirmedByUser: true,
      );

      expect(result.isMuhasabahRequired, isTrue);
      expect(result.outcome, OrchestratedCheckInOutcome.muhasabahRequired);
      expect(checkInRepo.getAll(), isEmpty);
    });

    test('10. Missing Muhasabah reason never finalizes failure', () async {
      await createProgram(
        id: 'prog_1',
        status: ProgramV2Model.statusPendingFailure,
        pendingMissedDayKey: '2026-10-01',
      );

      final result = await orchestrator.submitMuhasabah(
        programId: 'prog_1',
        reasonCode: '   ',
        reasonLabelSnapshot: '',
      );

      expect(result.isSuccess, isFalse);
      expect(result.outcome, OrchestratedMuhasabahOutcome.invalidReason);
      expect(failureRepo.getAll(), isEmpty);
      expect(programRepo.getById('prog_1')!.status,
          ProgramV2Model.statusPendingFailure);
    });

    test('11. Muhasabah with progress 39 -> FAILED', () async {
      final start = DateService.parseDayKey('2026-09-01');
      final days = List.generate(39, (i) => getOffsetDayKey(start, i));
      final missedDay = getOffsetDayKey(start, 39);

      await createProgram(
        id: 'prog_1',
        startDayKey: '2026-09-01',
        targetDays: 40,
        status: ProgramV2Model.statusPendingFailure,
        pendingMissedDayKey: missedDay,
      );
      await seedCheckIns(programId: 'prog_1', dayKeys: days);

      final result = await orchestrator.submitMuhasabah(
        programId: 'prog_1',
        reasonCode: 'SAKIT',
        reasonLabelSnapshot: 'Sakit Berat',
        note: 'Opname di RS',
      );

      expect(result.isSuccess, isTrue);
      expect(result.isFailedCreated, isTrue);
      expect(result.finalStatus, ProgramV2Model.statusFailed);
      expect(result.completedDays, 39);
      expect(result.failureRecord, isNotNull);
      expect(result.failureRecord!.reasonCode, 'SAKIT');
      expect(result.failureRecord!.note, 'Opname di RS');

      final prog = programRepo.getById('prog_1');
      expect(prog!.status, ProgramV2Model.statusFailed);
    });

    test('12. Muhasabah with progress 40 before target -> WARNING', () async {
      final start = DateService.parseDayKey('2026-09-01');
      final days = List.generate(40, (i) => getOffsetDayKey(start, i));
      final missedDay = getOffsetDayKey(start, 40);

      await createProgram(
        id: 'prog_1',
        startDayKey: '2026-09-01',
        targetDays: 50,
        status: ProgramV2Model.statusPendingFailure,
        pendingMissedDayKey: missedDay,
      );
      await seedCheckIns(programId: 'prog_1', dayKeys: days);

      final result = await orchestrator.submitMuhasabah(
        programId: 'prog_1',
        reasonCode: 'SAFAR',
        reasonLabelSnapshot: 'Perjalanan Jauh',
      );

      expect(result.isSuccess, isTrue);
      expect(result.isWarningCreated, isTrue);
      expect(result.finalStatus, ProgramV2Model.statusWarning);
      expect(result.completedDays, 40);

      final prog = programRepo.getById('prog_1');
      expect(prog!.status, ProgramV2Model.statusWarning);
    });

    test('13. Previously completed target is not classified as missed-day',
        () async {
      final start = DateService.parseDayKey('2026-09-01');
      final days = List.generate(40, (i) => getOffsetDayKey(start, i));
      await createProgram(
          id: 'prog_1', startDayKey: '2026-09-01', targetDays: 40);
      await seedCheckIns(programId: 'prog_1', dayKeys: days);

      // Current time is 3 days after completion
      final day43Key = getOffsetDayKey(start, 43);
      final day43Date = DateService.parseDayKey(day43Key);
      currentClock =
          DateTime(day43Date.year, day43Date.month, day43Date.day, 5, 0, 0);

      final result = await orchestrator.checkIn(
        programId: 'prog_1',
        confirmedByUser: true,
        recipientNameSnapshot: 'Ahmad Mujahid',
      );

      expect(result.isSuccessFinalized, isTrue);
      expect(result.outcome, OrchestratedCheckInOutcome.successFinalized);
      expect(
          programRepo.getById('prog_1')!.status, ProgramV2Model.statusSuccess);
    });

    test('14. SUCCESS partial-write recovery completes its Achievement',
        () async {
      final start = DateService.parseDayKey('2026-09-01');
      final days = List.generate(40, (i) => getOffsetDayKey(start, i));
      await createProgram(
        id: 'prog_1',
        startDayKey: '2026-09-01',
        targetDays: 40,
        status: ProgramV2Model.statusSuccess,
        recipientNameSnapshot: 'Ahmad Mujahid',
        finalizedAt: DateTime(2026, 10, 11, 5, 0, 0),
      );
      await seedCheckIns(programId: 'prog_1', dayKeys: days);

      expect(achievementRepo.getByProgramId('prog_1'), isEmpty);

      final result = await orchestrator.finalizeSuccess(
        programId: 'prog_1',
        recipientNameSnapshot: 'Ahmad Mujahid',
      );

      expect(result.isSuccess, isTrue);
      expect(result.isAchievementRecovered, isTrue);
      expect(result.outcome, OrchestratedSuccessOutcome.achievementRecovered);
      expect(achievementRepo.getByProgramId('prog_1').length, 1);
    });

    test('15. FailureRecord partial-write retry completes terminal failure',
        () async {
      final start = DateService.parseDayKey('2026-09-01');
      final days = List.generate(39, (i) => getOffsetDayKey(start, i));
      final missedDay = getOffsetDayKey(start, 39);

      await createProgram(
        id: 'prog_1',
        startDayKey: '2026-09-01',
        targetDays: 40,
        status: ProgramV2Model.statusPendingFailure,
        pendingMissedDayKey: missedDay,
      );
      await seedCheckIns(programId: 'prog_1', dayKeys: days);

      final res1 = await orchestrator.submitMuhasabah(
        programId: 'prog_1',
        reasonCode: 'SAKIT',
        reasonLabelSnapshot: 'Sakit Berat',
      );
      expect(res1.isFailedCreated, isTrue);

      final res2 = await orchestrator.submitMuhasabah(
        programId: 'prog_1',
        reasonCode: 'SAKIT',
        reasonLabelSnapshot: 'Sakit Berat',
      );
      expect(res2.isAlreadyFinalized, isTrue);
      expect(failureRepo.getByProgramId('prog_1').length, 1);
    });

    test('16. Missing recipient name does not discard completed check-ins',
        () async {
      final start = DateService.parseDayKey('2026-09-01');
      final days = List.generate(39, (i) => getOffsetDayKey(start, i));
      await createProgram(
          id: 'prog_1', startDayKey: '2026-09-01', targetDays: 40);
      await seedCheckIns(programId: 'prog_1', dayKeys: days);

      final day40Key = getOffsetDayKey(start, 39);
      final day40Date = DateService.parseDayKey(day40Key);
      currentClock =
          DateTime(day40Date.year, day40Date.month, day40Date.day, 5, 0, 0);

      final result = await orchestrator.checkIn(
        programId: 'prog_1',
        confirmedByUser: true,
        recipientNameSnapshot: null,
      );

      expect(result.isSuccess, isTrue);
      expect(result.isNeedsRecipientName, isTrue);
      expect(result.outcome, OrchestratedCheckInOutcome.needsRecipientName);
      expect(checkInRepo.hasCheckIn('prog_1', day40Key), isTrue);
      expect(checkInRepo.getByProgramId('prog_1').length, 40);
      expect(
          programRepo.getById('prog_1')!.status, ProgramV2Model.statusActive);
    });

    test(
        '17. Pending SUCCESS can complete after recipient name becomes available',
        () async {
      final start = DateService.parseDayKey('2026-09-01');
      final days = List.generate(40, (i) => getOffsetDayKey(start, i));
      await createProgram(
          id: 'prog_1', startDayKey: '2026-09-01', targetDays: 40);
      await seedCheckIns(programId: 'prog_1', dayKeys: days);

      final result = await orchestrator.finalizeSuccess(
        programId: 'prog_1',
        recipientNameSnapshot: 'Ust. Fulan',
      );

      expect(result.isSuccess, isTrue);
      expect(result.isSuccessFinalized, isTrue);
      expect(
          programRepo.getById('prog_1')!.status, ProgramV2Model.statusSuccess);
      expect(achievementRepo.getByProgramId('prog_1').length, 1);
    });

    test(
        '18. Clock advances across the 03:00 boundary during check-in orchestration',
        () async {
      // Program starts 2026-10-18
      await createProgram(
          id: 'prog_1', startDayKey: '2026-10-18', targetDays: 40);

      // Preflight clock: 2026-10-19 02:59:59 (operational day 2026-10-18 is still open)
      currentClock = DateTime(2026, 10, 19, 2, 59, 59);

      // Re-initialize dailyCheckInService to advance clock immediately when checkIn starts
      var calls = 0;
      final dynamicDateService = DateService(nowProvider: () {
        calls++;
        if (calls > 1) {
          // Cross boundary to 03:00:00!
          return DateTime(2026, 10, 19, 3, 0, 0);
        }
        return DateTime(2026, 10, 19, 2, 59, 59);
      });

      final raceDailyCheckInService = DailyCheckInV2Service(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: dynamicDateService,
      );

      final raceReconService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: dynamicDateService,
      );

      final raceOrchestrator = ProgramV2JourneyOrchestrator(
        programRepository: programRepo,
        dailyCheckInService: raceDailyCheckInService,
        reconciliationService: raceReconService,
        muhasabahService: muhasabahService,
        successService: successService,
        dateService: dynamicDateService,
      );

      final result = await raceOrchestrator.checkIn(
        programId: 'prog_1',
        confirmedByUser: true,
      );

      expect(result.isSuccess, isFalse);
      expect(result.isMuhasabahRequired, isTrue);
      expect(result.outcome, OrchestratedCheckInOutcome.muhasabahRequired);
      expect(result.missedDayKey, '2026-10-18');
      expect(programRepo.getById('prog_1')!.status,
          ProgramV2Model.statusPendingFailure);
    });

    test('19. No check-in is written after a missed-day is detected', () async {
      await createProgram(
          id: 'prog_1', startDayKey: '2026-10-18', targetDays: 40);
      currentClock =
          DateTime(2026, 10, 20, 5, 0, 0); // missed 2026-10-18 and 2026-10-19

      final result = await orchestrator.checkIn(
        programId: 'prog_1',
        confirmedByUser: true,
      );

      expect(result.isMuhasabahRequired, isTrue);
      expect(checkInRepo.getAll(), isEmpty);
    });

    test('20. Preflight Hive storage error blocks check-in', () async {
      await createProgram(
          id: 'prog_1', startDayKey: '2026-10-18', targetDays: 40);
      programRepo.shouldThrowOnGet = true;

      final result = await orchestrator.checkIn(
        programId: 'prog_1',
        confirmedByUser: true,
      );

      expect(result.isSuccess, isFalse);
      expect(result.outcome, OrchestratedCheckInOutcome.persistenceError);
      expect(checkInRepo.getAll(), isEmpty);
    });

    test('21. Data integrity error blocks mutation', () async {
      // Program with invalid targetDays (30 < 40)
      final corruptProg = ProgramV2Model(
        id: 'corrupt_1',
        ibadahId: 'ibadah_1',
        ibadahNameSnapshot: 'Tahajjud',
        targetDays: 30, // Corrupt
        startDayKey: '2026-10-18',
        status: ProgramV2Model.statusActive,
        createdAt: DateTime(2026, 10, 18, 0, 0, 0),
        updatedAt: DateTime(2026, 10, 18, 0, 0, 0),
      );
      await programRepo.save(corruptProg);

      final result = await orchestrator.checkIn(
        programId: 'corrupt_1',
        confirmedByUser: true,
      );

      expect(result.isSuccess, isFalse);
      expect(result.outcome, OrchestratedCheckInOutcome.dataIntegrityError);
      expect(checkInRepo.getAll(), isEmpty);
    });

    test('22. Batch bootstrap-style reconciliation handles several programs',
        () async {
      // Program 1: on track
      await createProgram(id: 'prog_on_track', startDayKey: '2026-10-18');
      // Program 2: missed day
      await createProgram(id: 'prog_missed', startDayKey: '2026-10-10');
      // Program 3: completed target duration
      final start = DateService.parseDayKey('2026-09-01');
      final days = List.generate(40, (i) => getOffsetDayKey(start, i));
      await createProgram(
          id: 'prog_completed', startDayKey: '2026-09-01', targetDays: 40);
      await seedCheckIns(programId: 'prog_completed', dayKeys: days);

      final bootstrap = await orchestrator.processAppResume(
        capturedNow: DateTime(2026, 10, 18, 5, 0, 0),
        recipientNameByProgramId: {'prog_completed': 'Haji Fulan'},
      );

      expect(bootstrap.totalInspected, 3);
      expect(bootstrap.programsNeedingMuhasabah.length, 1);
      expect(bootstrap.programsNeedingMuhasabah.first.programId, 'prog_missed');
      expect(bootstrap.programsFinalizedSuccess.length, 1);
      expect(
          bootstrap.programsFinalizedSuccess.first.programId, 'prog_completed');
      expect(programRepo.getById('prog_completed')!.status,
          ProgramV2Model.statusSuccess);
    });

    test('23. One invalid program does not block unrelated valid programs',
        () async {
      final corruptProg = ProgramV2Model(
        id: 'prog_bad',
        ibadahId: 'ibadah_1',
        ibadahNameSnapshot: 'Tahajjud',
        targetDays: 20, // Invalid
        startDayKey: '2026-10-18',
        status: ProgramV2Model.statusActive,
        createdAt: DateTime(2026, 10, 18, 0, 0, 0),
        updatedAt: DateTime(2026, 10, 18, 0, 0, 0),
      );
      await programRepo.save(corruptProg);
      await createProgram(id: 'prog_good', startDayKey: '2026-10-18');

      final bootstrap = await orchestrator.processAppResume();

      expect(bootstrap.items.length, 2);
      final badItem =
          bootstrap.items.firstWhere((i) => i.programId == 'prog_bad');
      final goodItem =
          bootstrap.items.firstWhere((i) => i.programId == 'prog_good');

      expect(badItem.isError, isTrue);
      expect(goodItem.action, ProgramResumeAction.onTrack);
    });

    test('24. Repeated batch runs remain idempotent', () async {
      await createProgram(id: 'prog_1', startDayKey: '2026-10-18');
      await createProgram(id: 'prog_missed', startDayKey: '2026-10-10');

      final run1 = await orchestrator.processAppResume();
      expect(run1.programsNeedingMuhasabah.length, 1);

      final run2 = await orchestrator.processAppResume();
      expect(run2.programsNeedingMuhasabah.length, 1);
      expect(failureRepo.getAll(), isEmpty);
    });

    test(
        '25. Concurrent orchestrator check-in requests do not duplicate records',
        () async {
      await createProgram(
          id: 'prog_1', startDayKey: '2026-10-18', targetDays: 40);

      final futures = List.generate(
        5,
        (_) => orchestrator.checkIn(programId: 'prog_1', confirmedByUser: true),
      );

      final results = await Future.wait(futures);

      final successes = results.where((r) => r.isSuccess).toList();
      final alreadyChecked =
          results.where((r) => r.isAlreadyCheckedIn).toList();

      expect(successes.length, 1);
      expect(alreadyChecked.length, 4);
      expect(checkInRepo.getByProgramId('prog_1').length, 1);
    });

    test('26. Real temporary Hive boxes survive flush/close/reopen', () async {
      await createProgram(
          id: 'prog_1', startDayKey: '2026-10-18', targetDays: 40);

      final checkInRes = await orchestrator.checkIn(
        programId: 'prog_1',
        confirmedByUser: true,
      );
      expect(checkInRes.isSuccess, isTrue);

      await programBox.flush();
      await checkInBox.flush();
      await achievementBox.flush();
      await failureBox.flush();

      await programBox.close();
      await checkInBox.close();
      await achievementBox.close();
      await failureBox.close();

      final reProgramBox =
          await Hive.openBox<ProgramV2Model>('test_programs_box');
      final reCheckInBox =
          await Hive.openBox<DailyCheckInModel>('test_checkins_box');

      expect(reProgramBox.containsKey('prog_1'), isTrue);
      final checkInId =
          DailyCheckInV2Repository.buildCheckInId('2026-10-18', 'prog_1');
      expect(reCheckInBox.containsKey(checkInId), isTrue);

      await reProgramBox.close();
      await reCheckInBox.close();
    });

    test(
        '27. Post-boundary second reconciliation throwing HiveError returns persistenceError',
        () async {
      await createProgram(
          id: 'prog_1', startDayKey: '2026-10-18', targetDays: 40);

      var calls = 0;
      final dynamicDateService = DateService(nowProvider: () {
        calls++;
        if (calls > 1) {
          return DateTime(2026, 10, 19, 3, 0, 0);
        }
        return DateTime(2026, 10, 19, 2, 59, 59);
      });

      final raceDailyCheckInService = DailyCheckInV2Service(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: dynamicDateService,
      );

      final mockReconService = MockBoundaryReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: dynamicDateService,
      );
      mockReconService.throwHiveOnSecondCall = true;

      final raceOrchestrator = ProgramV2JourneyOrchestrator(
        programRepository: programRepo,
        dailyCheckInService: raceDailyCheckInService,
        reconciliationService: mockReconService,
        muhasabahService: muhasabahService,
        successService: successService,
        dateService: dynamicDateService,
      );

      final result = await raceOrchestrator.checkIn(
        programId: 'prog_1',
        confirmedByUser: true,
      );

      expect(result.isSuccess, isFalse);
      expect(result.outcome, OrchestratedCheckInOutcome.persistenceError);
      expect(result.errorMessage,
          'Storage operation failed during boundary reconciliation.');
      expect(result.errorMessage,
          isNot(contains('/data/user/0/app/cache/hive.lock')));
      expect(checkInRepo.getAll(), isEmpty);
      expect(
          programRepo.getById('prog_1')!.status, ProgramV2Model.statusActive);
    });

    test(
        '28. Post-boundary second reconciliation throwing unexpected error returns unexpectedError',
        () async {
      await createProgram(
          id: 'prog_1', startDayKey: '2026-10-18', targetDays: 40);

      var calls = 0;
      final dynamicDateService = DateService(nowProvider: () {
        calls++;
        if (calls > 1) {
          return DateTime(2026, 10, 19, 3, 0, 0);
        }
        return DateTime(2026, 10, 19, 2, 59, 59);
      });

      final raceDailyCheckInService = DailyCheckInV2Service(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: dynamicDateService,
      );

      final mockReconService = MockBoundaryReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: dynamicDateService,
      );
      mockReconService.throwUnexpectedOnSecondCall = true;

      final raceOrchestrator = ProgramV2JourneyOrchestrator(
        programRepository: programRepo,
        dailyCheckInService: raceDailyCheckInService,
        reconciliationService: mockReconService,
        muhasabahService: muhasabahService,
        successService: successService,
        dateService: dynamicDateService,
      );

      final result = await raceOrchestrator.checkIn(
        programId: 'prog_1',
        confirmedByUser: true,
      );

      expect(result.isSuccess, isFalse);
      expect(result.outcome, OrchestratedCheckInOutcome.unexpectedError);
      expect(result.errorMessage,
          'Unexpected error occurred during boundary reconciliation.');
      expect(result.errorMessage, isNot(contains('NativeEngine.cpp:128')));
      expect(checkInRepo.getAll(), isEmpty);
      expect(
          programRepo.getById('prog_1')!.status, ProgramV2Model.statusActive);
    });

    test(
        '29. Public error messages are sanitized and do not leak raw exception details or paths',
        () async {
      await createProgram(
          id: 'prog_1', startDayKey: '2026-10-18', targetDays: 40);

      // 1. Preflight check-in exception sanitization
      final mockSanitizeRecon = MockBoundaryReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: dateService,
      );
      mockSanitizeRecon.throwHiveOnFirstCall = true;
      mockSanitizeRecon.customErrorMessage =
          'Disk corruption at /var/lib/secure/vault.hive';

      final mockOrchestrator = ProgramV2JourneyOrchestrator(
        programRepository: programRepo,
        dailyCheckInService: dailyCheckInService,
        reconciliationService: mockSanitizeRecon,
        muhasabahService: muhasabahService,
        successService: successService,
        dateService: dateService,
      );

      final checkInResult = await mockOrchestrator.checkIn(
        programId: 'prog_1',
        confirmedByUser: true,
      );

      expect(checkInResult.isSuccess, isFalse);
      expect(
          checkInResult.outcome, OrchestratedCheckInOutcome.persistenceError);
      expect(checkInResult.errorMessage,
          'Storage operation failed during reconciliation.');
      expect(checkInResult.errorMessage,
          isNot(contains('/var/lib/secure/vault.hive')));

      // 2. Finalize success exception sanitization
      achievementRepo.shouldThrowOnSave = true;
      final start = DateService.parseDayKey('2026-09-01');
      final days = List.generate(40, (i) => getOffsetDayKey(start, i));
      await createProgram(
          id: 'prog_success_test', startDayKey: '2026-09-01', targetDays: 40);
      await seedCheckIns(programId: 'prog_success_test', dayKeys: days);

      final successResult = await orchestrator.finalizeSuccess(
        programId: 'prog_success_test',
        recipientNameSnapshot: 'Haji Ahmad',
      );

      expect(successResult.isSuccess, isFalse);
      expect(successResult.errorMessage, isNotNull);
      expect(successResult.errorMessage, isNot(contains('/var/lib')));

      achievementRepo.shouldThrowOnSave = false;

      // 3. Submit Muhasabah exception sanitization
      await createProgram(
        id: 'prog_muhasabah_test',
        startDayKey: '2026-10-01',
        status: ProgramV2Model.statusPendingFailure,
        pendingMissedDayKey: '2026-10-01',
      );
      programRepo.shouldThrowOnSave = true;

      final muhasabahResult = await orchestrator.submitMuhasabah(
        programId: 'prog_muhasabah_test',
        reasonCode: 'UZUR',
        reasonLabelSnapshot: 'Uzur Syar i',
      );

      expect(muhasabahResult.isSuccess, isFalse);
      expect(muhasabahResult.outcome,
          OrchestratedMuhasabahOutcome.persistenceError);
      expect(muhasabahResult.errorMessage,
          'Storage operation failed while persisting program finalization status.');
      expect(muhasabahResult.errorMessage,
          isNot(contains('Simulated storage error')));

      programRepo.shouldThrowOnSave = false;

      // 4. Batch resume exception sanitization
      final failingBatchRepo = FailingProgramV2Repository(box: programBox);
      failingBatchRepo.shouldThrowOnGet = true;
      failingBatchRepo.customErrorMessage =
          'Severe I/O crash at C:\\System32\\hive.sys';

      final failingReconService = ProgramV2ReconciliationService(
        programRepository: failingBatchRepo,
        checkInRepository: checkInRepo,
        dateService: dateService,
      );

      final failingBatchOrchestrator = ProgramV2JourneyOrchestrator(
        programRepository: failingBatchRepo,
        dailyCheckInService: dailyCheckInService,
        reconciliationService: failingReconService,
        muhasabahService: muhasabahService,
        successService: successService,
        dateService: dateService,
      );

      final batchResult = await failingBatchOrchestrator.processAppResume();
      expect(batchResult.hasErrors, isTrue);
      expect(batchResult.errors.first.errorMessage,
          'Storage operation failed during program lookup.');
      expect(batchResult.errors.first.errorMessage,
          isNot(contains('C:\\System32\\hive.sys')));
    });
  });
}
