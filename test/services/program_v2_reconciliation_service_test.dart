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
import 'package:mujahadah/services/program_v2_reconciliation_service.dart';

/// Test repository that can simulate storage failures and mock re-read outcomes.
class FailingProgramV2Repository extends ProgramV2Repository {
  bool shouldThrowOnSave = false;
  bool throwAfterSave = false;
  ProgramV2Model? Function(String id, int callCount)? onGetById;
  final Map<String, int> _getByIdCallCounts = {};

  FailingProgramV2Repository({required super.box});

  @override
  ProgramV2Model? getById(String id) {
    final count = (_getByIdCallCounts[id] ?? 0) + 1;
    _getByIdCallCounts[id] = count;
    if (onGetById != null) {
      final override = onGetById!(id, count);
      if (override != null) {
        return override;
      }
    }
    return super.getById(id);
  }

  @override
  Future<void> save(ProgramV2Model program) async {
    if (shouldThrowOnSave) {
      throw HiveError('Simulated disk I/O write failure');
    }
    await super.save(program);
    if (throwAfterSave) {
      throw HiveError('Simulated crash after write completed');
    }
  }

  void resetOverrides() {
    shouldThrowOnSave = false;
    throwAfterSave = false;
    onGetById = null;
    _getByIdCallCounts.clear();
  }
}

void main() {
  late Directory tempDir;
  late Box<ProgramV2Model> programBox;
  late Box<DailyCheckInModel> checkInBox;
  late Box<FailureRecordModel> failureBox;
  late FailingProgramV2Repository programRepo;
  late DailyCheckInV2Repository checkInRepo;
  late DateService dateService;
  late ProgramV2ReconciliationService service;

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
    tempDir =
        Directory.systemTemp.createTempSync('program_v2_reconciliation_test_');
    Hive.init(tempDir.path);
    programBox = await Hive.openBox<ProgramV2Model>('test_programs_box');
    checkInBox = await Hive.openBox<DailyCheckInModel>('test_checkins_box');
    failureBox = await Hive.openBox<FailureRecordModel>('test_failures_box');

    programRepo = FailingProgramV2Repository(box: programBox);
    checkInRepo = DailyCheckInV2Repository(box: checkInBox);

    // Default clock: 2026-10-18 05:00:00 (dayKey: 2026-10-18)
    dateService = DateService(
      nowProvider: () => DateTime(2026, 10, 18, 5, 0, 0),
    );

    service = ProgramV2ReconciliationService(
      programRepository: programRepo,
      checkInRepository: checkInRepo,
      dateService: dateService,
    );
  });

  tearDown(() async {
    programRepo.resetOverrides();
    if (programBox.isOpen) {
      await programBox.close();
    }
    if (checkInBox.isOpen) {
      await checkInBox.close();
    }
    if (failureBox.isOpen) {
      await failureBox.close();
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
    String? reminderTime,
    String? restartedFromProgramId,
    String? recipientNameSnapshot,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? finalizedAt,
    String? pendingMissedDayKey,
  }) async {
    final created = createdAt ?? DateTime(2026, 10, 18, 4, 0);
    final updated = updatedAt ?? DateTime(2026, 10, 18, 4, 0);

    final prog = ProgramV2Model(
      id: id,
      ibadahId: ibadahId,
      ibadahNameSnapshot: ibadahName,
      targetDays: targetDays,
      startDayKey: startDayKey,
      status: status,
      reminderTime: reminderTime,
      restartedFromProgramId: restartedFromProgramId,
      recipientNameSnapshot: recipientNameSnapshot,
      createdAt: created,
      updatedAt: updated,
      finalizedAt: finalizedAt,
      pendingMissedDayKey: pendingMissedDayKey,
    );
    await programRepo.save(prog);
    return prog;
  }

  Future<DailyCheckInModel> createCheckIn({
    required String programId,
    required String dayKey,
    DateTime? checkedAt,
  }) async {
    final id = DailyCheckInV2Repository.buildCheckInId(dayKey, programId);
    final timestamp = checkedAt ?? DateTime(2026, 10, 18, 5, 0);
    final checkIn = DailyCheckInModel(
      id: id,
      programId: programId,
      dayKey: dayKey,
      checkedAt: timestamp,
      createdAt: timestamp,
    );
    await checkInRepo.save(checkIn);
    return checkIn;
  }

  group('Program V2 Missed-Day Reconciliation Service', () {
    test('1. Before program start: no pending transition', () async {
      await createProgram(
        id: 'prog-1',
        startDayKey: '2026-10-20',
      );

      final result = await service.reconcileProgram('prog-1');

      expect(result.outcome, ProgramReconciliationOutcome.notStarted);
      expect(result.isSuccess, isTrue);
      expect(result.hasMissedDay, isFalse);

      final persisted = programRepo.getById('prog-1')!;
      expect(persisted.status, ProgramV2Model.statusActive);
      expect(persisted.pendingMissedDayKey, isNull);
    });

    test('2. On start day without check-in: no pending transition', () async {
      await createProgram(
        id: 'prog-1',
        startDayKey: '2026-10-18',
      );

      final result = await service.reconcileProgram('prog-1');

      expect(result.outcome, ProgramReconciliationOutcome.noMissedDay);
      expect(result.isSuccess, isTrue);
      expect(result.hasMissedDay, isFalse);

      final persisted = programRepo.getById('prog-1')!;
      expect(persisted.status, ProgramV2Model.statusActive);
      expect(persisted.pendingMissedDayKey, isNull);
    });

    test('3. At 02:59:59.999: previous operational day is still open',
        () async {
      await createProgram(
        id: 'prog-1',
        startDayKey: '2026-10-18',
      );

      // 2026-10-19 02:59:59.999 local device time falls in operational day 2026-10-18
      final clockTime = DateTime(2026, 10, 19, 2, 59, 59, 999);
      final customDateService = DateService(nowProvider: () => clockTime);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: customDateService,
      );

      final result = await customService.reconcileProgram('prog-1');

      expect(result.outcome, ProgramReconciliationOutcome.noMissedDay);
      expect(result.isSuccess, isTrue);

      final persisted = programRepo.getById('prog-1')!;
      expect(persisted.status, ProgramV2Model.statusActive);
      expect(persisted.pendingMissedDayKey, isNull);
    });

    test(
        '4. At exactly 03:00:00.000: missed previous day becomes eligible for detection',
        () async {
      await createProgram(
        id: 'prog-1',
        startDayKey: '2026-10-18',
      );

      // At exactly 03:00:00.000, operational day becomes 2026-10-19; 2026-10-18 is closed
      final clockTime = DateTime(2026, 10, 19, 3, 0, 0, 0);
      final customDateService = DateService(nowProvider: () => clockTime);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: customDateService,
      );

      final result = await customService.reconcileProgram('prog-1');

      expect(result.outcome, ProgramReconciliationOutcome.pendingCreated);
      expect(result.isSuccess, isTrue);
      expect(result.isPendingCreated, isTrue);
      expect(result.hasMissedDay, isTrue);
      expect(result.missedDayKey, '2026-10-18');

      final persisted = programRepo.getById('prog-1')!;
      expect(persisted.status, ProgramV2Model.statusPendingFailure);
      expect(persisted.pendingMissedDayKey, '2026-10-18');
      expect(persisted.updatedAt, clockTime);
    });

    test('5. Previous day checked in: remains ACTIVE', () async {
      await createProgram(
        id: 'prog-1',
        startDayKey: '2026-10-18',
      );
      await createCheckIn(programId: 'prog-1', dayKey: '2026-10-18');

      // Next operational day 2026-10-19 at 05:00:00
      final clockTime = DateTime(2026, 10, 19, 5, 0, 0);
      final customDateService = DateService(nowProvider: () => clockTime);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: customDateService,
      );

      final result = await customService.reconcileProgram('prog-1');

      expect(result.outcome, ProgramReconciliationOutcome.noMissedDay);
      expect(result.isSuccess, isTrue);
      expect(result.hasMissedDay, isFalse);

      final persisted = programRepo.getById('prog-1')!;
      expect(persisted.status, ProgramV2Model.statusActive);
      expect(persisted.pendingMissedDayKey, isNull);
    });

    test('6. First required day missing: transition to PENDING_FAILURE',
        () async {
      await createProgram(
        id: 'prog-1',
        startDayKey: '2026-10-18',
      );

      final clockTime = DateTime(2026, 10, 19, 12, 0, 0);
      final customDateService = DateService(nowProvider: () => clockTime);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: customDateService,
      );

      final result = await customService.reconcileProgram('prog-1');

      expect(result.outcome, ProgramReconciliationOutcome.pendingCreated);
      expect(result.missedDayKey, '2026-10-18');

      final persisted = programRepo.getById('prog-1')!;
      expect(persisted.status, ProgramV2Model.statusPendingFailure);
      expect(persisted.pendingMissedDayKey, '2026-10-18');
    });

    test('7. Middle day missing: earliest missed day selected', () async {
      await createProgram(
        id: 'prog-1',
        startDayKey: '2026-10-18',
      );
      // Day 1 (2026-10-18) checked in, Day 2 (2026-10-19) missed
      await createCheckIn(programId: 'prog-1', dayKey: '2026-10-18');

      // Reconciliation on Day 3: 2026-10-20 at 04:00:00
      final clockTime = DateTime(2026, 10, 20, 4, 0, 0);
      final customDateService = DateService(nowProvider: () => clockTime);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: customDateService,
      );

      final result = await customService.reconcileProgram('prog-1');

      expect(result.outcome, ProgramReconciliationOutcome.pendingCreated);
      expect(result.missedDayKey, '2026-10-19');

      final persisted = programRepo.getById('prog-1')!;
      expect(persisted.status, ProgramV2Model.statusPendingFailure);
      expect(persisted.pendingMissedDayKey, '2026-10-19');
    });

    test('8. Multi-day offline gap: earliest missing day selected', () async {
      await createProgram(
        id: 'prog-1',
        startDayKey: '2026-10-18',
      );
      // User offline for 5 days with zero check-ins; reconciliation on 2026-10-23
      final clockTime = DateTime(2026, 10, 23, 5, 0, 0);
      final customDateService = DateService(nowProvider: () => clockTime);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: customDateService,
      );

      final result = await customService.reconcileProgram('prog-1');

      expect(result.outcome, ProgramReconciliationOutcome.pendingCreated);
      expect(result.missedDayKey, '2026-10-18');

      final persisted = programRepo.getById('prog-1')!;
      expect(persisted.status, ProgramV2Model.statusPendingFailure);
      expect(persisted.pendingMissedDayKey, '2026-10-18');
    });

    test('9. Multiple missing days do not create multiple transitions',
        () async {
      await createProgram(
        id: 'prog-1',
        startDayKey: '2026-10-18',
      );
      // 2026-10-18 checked in, 2026-10-19 checked in
      await createCheckIn(programId: 'prog-1', dayKey: '2026-10-18');
      await createCheckIn(programId: 'prog-1', dayKey: '2026-10-19');

      // 2026-10-20 missed, 2026-10-21 missed; reconciliation on 2026-10-22 after 03:00
      final clockTime = DateTime(2026, 10, 22, 6, 0, 0);
      final customDateService = DateService(nowProvider: () => clockTime);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: customDateService,
      );

      final result = await customService.reconcileProgram('prog-1');

      expect(result.outcome, ProgramReconciliationOutcome.pendingCreated);
      expect(result.missedDayKey, '2026-10-20');

      final persisted = programRepo.getById('prog-1')!;
      expect(persisted.pendingMissedDayKey, '2026-10-20');
    });

    test('10. PENDING_FAILURE repeated reconciliation is idempotent', () async {
      await createProgram(
        id: 'prog-1',
        startDayKey: '2026-10-18',
        status: ProgramV2Model.statusPendingFailure,
        pendingMissedDayKey: '2026-10-18',
        updatedAt: DateTime(2026, 10, 19, 3, 0),
      );

      final result = await service.reconcileProgram('prog-1');

      expect(result.outcome, ProgramReconciliationOutcome.alreadyPending);
      expect(result.isSuccess, isTrue);
      expect(result.isAlreadyPending, isTrue);
      expect(result.hasMissedDay, isTrue);
      expect(result.missedDayKey, '2026-10-18');
    });

    test('11. pendingMissedDayKey is retained', () async {
      await createProgram(
        id: 'prog-1',
        startDayKey: '2026-10-18',
        status: ProgramV2Model.statusPendingFailure,
        pendingMissedDayKey: '2026-10-18',
      );

      final result = await service.reconcileProgram('prog-1');

      expect(result.missedDayKey, '2026-10-18');
      final persisted = programRepo.getById('prog-1')!;
      expect(persisted.pendingMissedDayKey, '2026-10-18');
    });

    test('12. updatedAt does not change on repeated no-op', () async {
      final initialUpdatedAt = DateTime(2026, 10, 19, 3, 0, 0);
      await createProgram(
        id: 'prog-1',
        startDayKey: '2026-10-18',
        status: ProgramV2Model.statusPendingFailure,
        pendingMissedDayKey: '2026-10-18',
        updatedAt: initialUpdatedAt,
      );

      // Advance clock
      final clockTime = DateTime(2026, 10, 25, 12, 0, 0);
      final customDateService = DateService(nowProvider: () => clockTime);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: customDateService,
      );

      final result = await customService.reconcileProgram('prog-1');

      expect(result.outcome, ProgramReconciliationOutcome.alreadyPending);
      final persisted = programRepo.getById('prog-1')!;
      expect(persisted.updatedAt, initialUpdatedAt);
    });

    test('13. Persisted PENDING_FAILURE survives Hive flush, close, and reopen',
        () async {
      await createProgram(
        id: 'prog-1',
        startDayKey: '2026-10-18',
      );

      final clockTime = DateTime(2026, 10, 19, 5, 0, 0);
      final customDateService = DateService(nowProvider: () => clockTime);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: customDateService,
      );

      final result = await customService.reconcileProgram('prog-1');
      expect(result.outcome, ProgramReconciliationOutcome.pendingCreated);

      // Flush, close box, re-open from same disk directory
      await programRepo.flush();
      await programBox.close();

      final reopenedBox =
          await Hive.openBox<ProgramV2Model>('test_programs_box');
      final restored = reopenedBox.get('prog-1')!;

      expect(restored.status, ProgramV2Model.statusPendingFailure);
      expect(restored.pendingMissedDayKey, '2026-10-18');
      expect(restored.updatedAt, clockTime);

      await reopenedBox.close();
      // Re-open for tearDown
      programBox = await Hive.openBox<ProgramV2Model>('test_programs_box');
    });

    test('14. All 13 ProgramV2Model fields are preserved correctly', () async {
      final createdAt = DateTime(2026, 10, 15, 10, 30);
      final initialUpdatedAt = DateTime(2026, 10, 15, 10, 30);

      await createProgram(
        id: 'prog-full-13',
        ibadahId: 'ibd-witir',
        ibadahName: 'Shalat Witir',
        targetDays: 45,
        startDayKey: '2026-10-18',
        reminderTime: '21:30',
        restartedFromProgramId: 'prog-prev-99',
        recipientNameSnapshot: 'Ahmad Abdullah',
        createdAt: createdAt,
        updatedAt: initialUpdatedAt,
        finalizedAt: null,
        pendingMissedDayKey: null,
      );

      final transitionInstant = DateTime(2026, 10, 19, 5, 0, 0);
      final customDateService =
          DateService(nowProvider: () => transitionInstant);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: customDateService,
      );

      final result = await customService.reconcileProgram('prog-full-13');
      expect(result.outcome, ProgramReconciliationOutcome.pendingCreated);

      final persisted = programRepo.getById('prog-full-13')!;

      // 10 unmutated fields verified
      expect(persisted.id, 'prog-full-13');
      expect(persisted.ibadahId, 'ibd-witir');
      expect(persisted.ibadahNameSnapshot, 'Shalat Witir');
      expect(persisted.targetDays, 45);
      expect(persisted.startDayKey, '2026-10-18');
      expect(persisted.reminderTime, '21:30');
      expect(persisted.restartedFromProgramId, 'prog-prev-99');
      expect(persisted.recipientNameSnapshot, 'Ahmad Abdullah');
      expect(persisted.createdAt, createdAt);
      expect(persisted.finalizedAt, isNull);

      // 3 mutated fields verified
      expect(persisted.status, ProgramV2Model.statusPendingFailure);
      expect(persisted.pendingMissedDayKey, '2026-10-18');
      expect(persisted.updatedAt, transitionInstant);
    });

    test('15. finalizedAt remains null', () async {
      await createProgram(
        id: 'prog-1',
        startDayKey: '2026-10-18',
      );

      final clockTime = DateTime(2026, 10, 19, 5, 0, 0);
      final customDateService = DateService(nowProvider: () => clockTime);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: customDateService,
      );

      await customService.reconcileProgram('prog-1');

      final persisted = programRepo.getById('prog-1')!;
      expect(persisted.finalizedAt, isNull);
    });

    test('16. No FailureRecord is created', () async {
      await createProgram(
        id: 'prog-1',
        startDayKey: '2026-10-18',
      );

      final clockTime = DateTime(2026, 10, 19, 5, 0, 0);
      final customDateService = DateService(nowProvider: () => clockTime);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: customDateService,
      );

      await customService.reconcileProgram('prog-1');

      expect(failureBox.isEmpty, isTrue);
    });

    test('17. DailyCheckIn history remains unchanged', () async {
      await createProgram(
        id: 'prog-1',
        startDayKey: '2026-10-18',
      );
      await createCheckIn(programId: 'prog-1', dayKey: '2026-10-18');
      expect(checkInBox.length, 1);

      // 2026-10-19 missed, reconciliation on 2026-10-20
      final clockTime = DateTime(2026, 10, 20, 5, 0, 0);
      final customDateService = DateService(nowProvider: () => clockTime);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: customDateService,
      );

      await customService.reconcileProgram('prog-1');

      // DailyCheckIn count and record must remain exactly identical
      expect(checkInBox.length, 1);
      final checkIn = checkInBox.values.first;
      expect(checkIn.programId, 'prog-1');
      expect(checkIn.dayKey, '2026-10-18');
    });

    test('18. Terminal SUCCESS is not modified', () async {
      await createProgram(
        id: 'prog-success',
        startDayKey: '2026-09-01',
        status: ProgramV2Model.statusSuccess,
        finalizedAt: DateTime(2026, 10, 11),
      );

      final result = await service.reconcileProgram('prog-success');

      expect(result.outcome, ProgramReconciliationOutcome.terminalProgram);
      final persisted = programRepo.getById('prog-success')!;
      expect(persisted.status, ProgramV2Model.statusSuccess);
      expect(persisted.pendingMissedDayKey, isNull);
    });

    test('19. Terminal FAILED is not modified', () async {
      await createProgram(
        id: 'prog-failed',
        startDayKey: '2026-09-01',
        status: ProgramV2Model.statusFailed,
        finalizedAt: DateTime(2026, 10, 11),
      );

      final result = await service.reconcileProgram('prog-failed');

      expect(result.outcome, ProgramReconciliationOutcome.terminalProgram);
      final persisted = programRepo.getById('prog-failed')!;
      expect(persisted.status, ProgramV2Model.statusFailed);
      expect(persisted.pendingMissedDayKey, isNull);
    });

    test('20. Terminal WARNING is not modified', () async {
      await createProgram(
        id: 'prog-warning',
        startDayKey: '2026-09-01',
        status: ProgramV2Model.statusWarning,
        finalizedAt: DateTime(2026, 10, 11),
      );

      final result = await service.reconcileProgram('prog-warning');

      expect(result.outcome, ProgramReconciliationOutcome.terminalProgram);
      final persisted = programRepo.getById('prog-warning')!;
      expect(persisted.status, ProgramV2Model.statusWarning);
      expect(persisted.pendingMissedDayKey, isNull);
    });

    test(
        '21. A clean 40/40 ACTIVE program awaiting SUCCESS finalization is never marked PENDING_FAILURE',
        () async {
      // 40-day target starting 2026-09-09
      await createProgram(
        id: 'prog-40',
        targetDays: 40,
        startDayKey: '2026-09-09',
      );

      // Populate 40 valid consecutive check-ins from 2026-09-09 through 2026-10-18
      var cur = DateTime.utc(2026, 9, 9);
      for (int i = 0; i < 40; i++) {
        final dayKey = DateService.formatCalendarDayKey(cur);
        await createCheckIn(
          programId: 'prog-40',
          dayKey: dayKey,
          checkedAt: DateTime(cur.year, cur.month, cur.day, 5, 0),
        );
        cur = DateTime.utc(cur.year, cur.month, cur.day + 1);
      }
      expect(checkInBox.length, 40);

      // Day 41: 2026-10-19 at 05:00:00 (after 03:00 boundary)
      final clockDay41 = DateTime(2026, 10, 19, 5, 0, 0);
      final serviceDay41 = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(nowProvider: () => clockDay41),
      );

      final result41 = await serviceDay41.reconcileProgram('prog-40');

      expect(result41.outcome,
          ProgramReconciliationOutcome.requiresSuccessFinalization);
      expect(result41.hasMissedDay, isFalse);

      final prog41 = programRepo.getById('prog-40')!;
      expect(prog41.status, ProgramV2Model.statusActive);
      expect(prog41.pendingMissedDayKey, isNull);

      // Day 45: 2026-10-23 at 08:00:00 (multiple days later)
      final clockDay45 = DateTime(2026, 10, 23, 8, 0, 0);
      final serviceDay45 = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(nowProvider: () => clockDay45),
      );

      final result45 = await serviceDay45.reconcileProgram('prog-40');

      expect(result45.outcome,
          ProgramReconciliationOutcome.requiresSuccessFinalization);
      expect(result45.hasMissedDay, isFalse);

      final prog45 = programRepo.getById('prog-40')!;
      expect(prog45.status, ProgramV2Model.statusActive);
      expect(prog45.pendingMissedDayKey, isNull);
    });

    test('22. A completed custom-target program is also protected', () async {
      await createProgram(
        id: 'prog-50',
        targetDays: 50,
        startDayKey: '2026-08-01',
      );

      var cur = DateTime.utc(2026, 8, 1);
      for (int i = 0; i < 50; i++) {
        final dayKey = DateService.formatCalendarDayKey(cur);
        await createCheckIn(
          programId: 'prog-50',
          dayKey: dayKey,
          checkedAt: DateTime(cur.year, cur.month, cur.day, 5, 0),
        );
        cur = DateTime.utc(cur.year, cur.month, cur.day + 1);
      }
      expect(checkInBox.length, 50);

      // Advance clock past target completion
      final clockTime = DateTime(2026, 10, 19, 5, 0, 0);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(nowProvider: () => clockTime),
      );

      final result = await customService.reconcileProgram('prog-50');

      expect(result.outcome,
          ProgramReconciliationOutcome.requiresSuccessFinalization);
      final persisted = programRepo.getById('prog-50')!;
      expect(persisted.status, ProgramV2Model.statusActive);
      expect(persisted.pendingMissedDayKey, isNull);
    });

    test(
        '23. Corrupt canonical ID cannot be treated as a legitimate completed day',
        () async {
      await createProgram(
        id: 'prog-1',
        startDayKey: '2026-10-18',
      );

      // Store a check-in with a corrupt ID under the canonical key
      final corruptCheckIn = DailyCheckInModel(
        id: 'corrupt_id_format',
        programId: 'prog-1',
        dayKey: '2026-10-18',
        checkedAt: DateTime(2026, 10, 18, 5, 0),
        createdAt: DateTime(2026, 10, 18, 5, 0),
      );
      await checkInBox.put('corrupt_id_format', corruptCheckIn);

      final clockTime = DateTime(2026, 10, 19, 5, 0, 0);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(nowProvider: () => clockTime),
      );

      final result = await customService.reconcileProgram('prog-1');

      expect(result.outcome, ProgramReconciliationOutcome.dataIntegrityError);
      expect(result.isFailure, isTrue);

      final persisted = programRepo.getById('prog-1')!;
      expect(persisted.status, ProgramV2Model.statusActive);
      expect(persisted.pendingMissedDayKey, isNull);
    });

    test(
        '24. Occupied canonical key with mismatched identity produces dataIntegrityError',
        () async {
      await createProgram(
        id: 'prog-1',
        startDayKey: '2026-10-18',
      );

      // Occupy canonical key 2026-10-18_prog-1 with a conflicting record belonging to other_prog
      final conflictingCheckIn = DailyCheckInModel(
        id: '2026-10-18_other_prog',
        programId: 'other_prog',
        dayKey: '2026-10-18',
        checkedAt: DateTime(2026, 10, 18, 5, 0),
        createdAt: DateTime(2026, 10, 18, 5, 0),
      );
      await checkInBox.put('2026-10-18_prog-1', conflictingCheckIn);

      final clockTime = DateTime(2026, 10, 19, 5, 0, 0);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(nowProvider: () => clockTime),
      );

      final result = await customService.reconcileProgram('prog-1');

      expect(result.outcome, ProgramReconciliationOutcome.dataIntegrityError);
      expect(result.isFailure, isTrue);

      final persisted = programRepo.getById('prog-1')!;
      expect(persisted.status, ProgramV2Model.statusActive);
      expect(persisted.pendingMissedDayKey, isNull);
    });

    test('25. A closed Program Hive box produces a typed persistence error',
        () async {
      await createProgram(id: 'prog-1');
      await programBox.close();

      final result = await service.reconcileProgram('prog-1');

      expect(result.outcome, ProgramReconciliationOutcome.persistenceError);
      expect(result.isFailure, isTrue);

      // Reopen for tearDown
      programBox = await Hive.openBox<ProgramV2Model>('test_programs_box');
    });

    test(
        '26. A closed DailyCheckIn Hive box produces a typed persistence error',
        () async {
      await createProgram(id: 'prog-1');
      await checkInBox.close();

      final result = await service.reconcileProgram('prog-1');

      expect(result.outcome, ProgramReconciliationOutcome.persistenceError);
      expect(result.isFailure, isTrue);

      // Reopen for tearDown
      checkInBox = await Hive.openBox<DailyCheckInModel>('test_checkins_box');
    });

    test('27. A simulated failed Program write is handled safely', () async {
      await createProgram(
        id: 'prog-1',
        startDayKey: '2026-10-18',
      );

      final clockTime = DateTime(2026, 10, 19, 5, 0, 0);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(nowProvider: () => clockTime),
      );

      // Enable simulated write failure
      programRepo.shouldThrowOnSave = true;

      final result = await customService.reconcileProgram('prog-1');

      expect(result.outcome, ProgramReconciliationOutcome.persistenceError);
      expect(result.isFailure, isTrue);
      expect(result.errorMessage, contains('Storage operation failed'));

      programRepo.shouldThrowOnSave = false;
    });

    test(
        '28. Retried reconciliation after an uncertain write re-reads the persisted status',
        () async {
      await createProgram(
        id: 'prog-1',
        startDayKey: '2026-10-18',
      );

      final clockTime = DateTime(2026, 10, 19, 5, 0, 0);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(nowProvider: () => clockTime),
      );

      // First run succeeds in persisting PENDING_FAILURE
      final result1 = await customService.reconcileProgram('prog-1');
      expect(result1.outcome, ProgramReconciliationOutcome.pendingCreated);

      // Subsequent retry re-reads the actual persisted status from storage
      final result2 = await customService.reconcileProgram('prog-1');
      expect(result2.outcome, ProgramReconciliationOutcome.alreadyPending);
      expect(result2.missedDayKey, '2026-10-18');
    });

    test(
        '29. Concurrent reconciliation calls through one service instance cause one effective transition',
        () async {
      await createProgram(
        id: 'prog-1',
        startDayKey: '2026-10-18',
      );

      final clockTime = DateTime(2026, 10, 19, 5, 0, 0);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(nowProvider: () => clockTime),
      );

      // Launch 5 concurrent calls
      final futures = List.generate(
        5,
        (_) => customService.reconcileProgram('prog-1'),
      );
      final results = await Future.wait(futures);

      final pendingCreated = results
          .where(
              (r) => r.outcome == ProgramReconciliationOutcome.pendingCreated)
          .length;
      final alreadyPending = results
          .where(
              (r) => r.outcome == ProgramReconciliationOutcome.alreadyPending)
          .length;

      expect(pendingCreated, 1);
      expect(alreadyPending, 4);

      final persisted = programRepo.getById('prog-1')!;
      expect(persisted.status, ProgramV2Model.statusPendingFailure);
      expect(persisted.pendingMissedDayKey, '2026-10-18');
    });

    test('30. Batch reconciliation handles multiple programs independently',
        () async {
      // Program A: Missed Day 1 -> transitions to PENDING_FAILURE
      await createProgram(
        id: 'prog-a',
        startDayKey: '2026-10-18',
      );

      // Program B: Checked in on Day 1 -> remains ACTIVE (noMissedDay)
      await createProgram(
        id: 'prog-b',
        startDayKey: '2026-10-18',
      );
      await createCheckIn(programId: 'prog-b', dayKey: '2026-10-18');

      // Program C: Already PENDING_FAILURE -> alreadyPending
      await createProgram(
        id: 'prog-c',
        startDayKey: '2026-10-18',
        status: ProgramV2Model.statusPendingFailure,
        pendingMissedDayKey: '2026-10-18',
      );

      // Program D: Not started yet -> notStarted
      await createProgram(
        id: 'prog-d',
        startDayKey: '2026-10-25',
      );

      // Program E: Terminal SUCCESS -> ignored/skipped from active batch
      await createProgram(
        id: 'prog-e',
        startDayKey: '2026-09-01',
        status: ProgramV2Model.statusSuccess,
      );

      final clockTime = DateTime(2026, 10, 19, 5, 0, 0);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(nowProvider: () => clockTime),
      );

      final batchResult = await customService.reconcileActivePrograms();

      expect(batchResult.totalInspected, 4);
      expect(batchResult.pendingCreatedCount, 1);
      expect(batchResult.alreadyPendingCount, 1);
      expect(batchResult.noMissedDayCount, 1);
      expect(batchResult.errorCount, 0);

      expect(batchResult.pendingMuhasabahResults.length, 2);
      final pendingIds =
          batchResult.pendingMuhasabahResults.map((r) => r.programId).toList();
      expect(pendingIds, containsAll(['prog-a', 'prog-c']));
    });

    test('31. Unknown and blank program IDs return typed failures', () async {
      final blankResult = await service.reconcileProgram('   ');
      expect(
          blankResult.outcome, ProgramReconciliationOutcome.invalidProgramId);
      expect(blankResult.isFailure, isTrue);

      final unknownResult =
          await service.reconcileProgram('prog-does-not-exist');
      expect(
          unknownResult.outcome, ProgramReconciliationOutcome.programNotFound);
      expect(unknownResult.isFailure, isTrue);
    });

    test(
        '32. Boundary cases across month/year transitions use DateService correctly',
        () async {
      await createProgram(
        id: 'prog-nye',
        startDayKey: '2026-12-31',
      );

      // 2027-01-01 02:59:59.999 is still within operational day 2026-12-31
      final preCutoff = DateTime(2027, 1, 1, 2, 59, 59, 999);
      final preService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(nowProvider: () => preCutoff),
      );
      final preResult = await preService.reconcileProgram('prog-nye');
      expect(preResult.outcome, ProgramReconciliationOutcome.noMissedDay);

      // 2027-01-01 03:00:00.000 crosses the boundary to operational day 2027-01-01
      final postCutoff = DateTime(2027, 1, 1, 3, 0, 0, 0);
      final postService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(nowProvider: () => postCutoff),
      );
      final postResult = await postService.reconcileProgram('prog-nye');

      expect(postResult.outcome, ProgramReconciliationOutcome.pendingCreated);
      expect(postResult.missedDayKey, '2026-12-31');

      final persisted = programRepo.getById('prog-nye')!;
      expect(persisted.status, ProgramV2Model.statusPendingFailure);
      expect(persisted.pendingMissedDayKey, '2026-12-31');
    });

    test(
        '33. Nonconsecutive check-ins claiming target completion return dataIntegrityError',
        () async {
      await createProgram(
        id: 'prog-nonconsec',
        targetDays: 40,
        startDayKey: '2026-09-09',
      );

      // Populate 40 check-ins with a gap: day 20 is skipped, day 41 is inserted
      var cur = DateTime.utc(2026, 9, 9);
      for (int i = 0; i < 41; i++) {
        if (i == 20) {
          // Skip day 20
          cur = DateTime.utc(cur.year, cur.month, cur.day + 1);
          continue;
        }
        final dayKey = DateService.formatCalendarDayKey(cur);
        await createCheckIn(
          programId: 'prog-nonconsec',
          dayKey: dayKey,
          checkedAt: DateTime(cur.year, cur.month, cur.day, 5, 0),
        );
        cur = DateTime.utc(cur.year, cur.month, cur.day + 1);
      }
      expect(checkInBox.length, 40);

      final clockTime = DateTime(2026, 10, 25, 5, 0, 0);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(nowProvider: () => clockTime),
      );

      final result = await customService.reconcileProgram('prog-nonconsec');

      expect(result.outcome, ProgramReconciliationOutcome.dataIntegrityError);
      expect(result.isFailure, isTrue);

      final persisted = programRepo.getById('prog-nonconsec')!;
      expect(persisted.status, ProgramV2Model.statusActive);
    });

    test('34. Future-dated check-in produces dataIntegrityError', () async {
      await createProgram(
        id: 'prog-future',
        startDayKey: '2026-10-18',
      );

      // Store a check-in dated tomorrow (2026-10-19) relative to current clock (2026-10-18)
      await createCheckIn(
        programId: 'prog-future',
        dayKey: '2026-10-19',
        checkedAt: DateTime(2026, 10, 19, 5, 0),
      );

      final result = await service.reconcileProgram('prog-future');

      expect(result.outcome, ProgramReconciliationOutcome.dataIntegrityError);
      expect(result.isFailure, isTrue);

      final persisted = programRepo.getById('prog-future')!;
      expect(persisted.status, ProgramV2Model.statusActive);
    });

    test(
        '35. PENDING_FAILURE with null or invalid pendingMissedDayKey produces dataIntegrityError',
        () async {
      await createProgram(
        id: 'prog-corrupt-pending',
        startDayKey: '2026-10-18',
        status: ProgramV2Model.statusPendingFailure,
        pendingMissedDayKey: null, // missing required field for pending state
      );

      final result = await service.reconcileProgram('prog-corrupt-pending');

      expect(result.outcome, ProgramReconciliationOutcome.dataIntegrityError);
      expect(result.isFailure, isTrue);
    });

    // --- R1 Hardening Tests ---

    test(
        '36. ProgramV2Model stored under a mismatched Hive key is rejected with dataIntegrityError',
        () async {
      final mismatched = ProgramV2Model(
        id: 'actual-underlying-id',
        ibadahId: 'ibd-tahajjud',
        ibadahNameSnapshot: 'Shalat Tahajjud',
        targetDays: 40,
        startDayKey: '2026-10-18',
        status: ProgramV2Model.statusActive,
        createdAt: DateTime(2026, 10, 18, 4, 0),
        updatedAt: DateTime(2026, 10, 18, 4, 0),
      );
      // Put under a conflicting storage key
      await programBox.put('requested-key-1', mismatched);

      final result = await service.reconcileProgram('requested-key-1');

      expect(result.outcome, ProgramReconciliationOutcome.dataIntegrityError);
      expect(result.isFailure, isTrue);
      expect(result.errorMessage, contains('storage key identity mismatch'));

      // Ensure no new key was created and original record was not overwritten
      expect(programBox.length, 1);
      expect(programBox.containsKey('requested-key-1'), isTrue);
      expect(programBox.containsKey('actual-underlying-id'), isFalse);
      expect(programBox.get('requested-key-1')!.id, 'actual-underlying-id');
    });

    test(
        '37. Mismatch introduced during re-read before write is rejected with dataIntegrityError',
        () async {
      await createProgram(
        id: 'prog-reread-mismatch',
        startDayKey: '2026-10-18',
      );

      final clockTime = DateTime(2026, 10, 19, 5, 0, 0);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(nowProvider: () => clockTime),
      );

      // Simulate concurrent swap/tampering during re-read
      programRepo.onGetById = (id, count) {
        if (count >= 2) {
          return ProgramV2Model(
            id: 'tampered-other-id',
            ibadahId: 'ibd-tahajjud',
            ibadahNameSnapshot: 'Shalat Tahajjud',
            targetDays: 40,
            startDayKey: '2026-10-18',
            status: ProgramV2Model.statusActive,
            createdAt: DateTime(2026, 10, 18),
            updatedAt: DateTime(2026, 10, 18),
          );
        }
        return null;
      };

      final result =
          await customService.reconcileProgram('prog-reread-mismatch');

      expect(result.outcome, ProgramReconciliationOutcome.dataIntegrityError);
      expect(result.isFailure, isTrue);
      expect(result.errorMessage, contains('storage key identity mismatch'));

      // Original program remains ACTIVE
      programRepo.resetOverrides();
      final persisted = programRepo.getById('prog-reread-mismatch')!;
      expect(persisted.status, ProgramV2Model.statusActive);
    });

    test(
        '38. Re-read status changed to PENDING_FAILURE with null missedDayKey returns dataIntegrityError',
        () async {
      await createProgram(
        id: 'prog-reread-null-missed',
        startDayKey: '2026-10-18',
      );

      final clockTime = DateTime(2026, 10, 19, 5, 0, 0);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(nowProvider: () => clockTime),
      );

      programRepo.onGetById = (id, count) {
        if (count >= 2) {
          return ProgramV2Model(
            id: 'prog-reread-null-missed',
            ibadahId: 'ibd-tahajjud',
            ibadahNameSnapshot: 'Shalat Tahajjud',
            targetDays: 40,
            startDayKey: '2026-10-18',
            status: ProgramV2Model.statusPendingFailure,
            pendingMissedDayKey: null, // missing required key on pending
            createdAt: DateTime(2026, 10, 18),
            updatedAt: DateTime(2026, 10, 18),
          );
        }
        return null;
      };

      final result =
          await customService.reconcileProgram('prog-reread-null-missed');

      expect(result.outcome, ProgramReconciliationOutcome.dataIntegrityError);
      expect(result.isFailure, isTrue);
    });

    test(
        '39. Re-read status changed to PENDING_FAILURE with malformed missedDayKey returns dataIntegrityError',
        () async {
      await createProgram(
        id: 'prog-reread-bad-missed',
        startDayKey: '2026-10-18',
      );

      final clockTime = DateTime(2026, 10, 19, 5, 0, 0);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(nowProvider: () => clockTime),
      );

      programRepo.onGetById = (id, count) {
        if (count >= 2) {
          return ProgramV2Model(
            id: 'prog-reread-bad-missed',
            ibadahId: 'ibd-tahajjud',
            ibadahNameSnapshot: 'Shalat Tahajjud',
            targetDays: 40,
            startDayKey: '2026-10-18',
            status: ProgramV2Model.statusPendingFailure,
            pendingMissedDayKey: '2026-99-99', // invalid date
            createdAt: DateTime(2026, 10, 18),
            updatedAt: DateTime(2026, 10, 18),
          );
        }
        return null;
      };

      final result =
          await customService.reconcileProgram('prog-reread-bad-missed');

      expect(result.outcome, ProgramReconciliationOutcome.dataIntegrityError);
      expect(result.isFailure, isTrue);
    });

    test(
        '40. Re-read status changed to PENDING_FAILURE with valid existing missedDayKey returns alreadyPending without fallback',
        () async {
      await createProgram(
        id: 'prog-reread-valid-pending',
        startDayKey: '2026-10-18',
      );

      final clockTime = DateTime(2026, 10, 19, 5, 0, 0);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(nowProvider: () => clockTime),
      );

      programRepo.onGetById = (id, count) {
        if (count >= 2) {
          return ProgramV2Model(
            id: 'prog-reread-valid-pending',
            ibadahId: 'ibd-tahajjud',
            ibadahNameSnapshot: 'Shalat Tahajjud',
            targetDays: 40,
            startDayKey: '2026-10-18',
            status: ProgramV2Model.statusPendingFailure,
            pendingMissedDayKey: '2026-10-18',
            createdAt: DateTime(2026, 10, 18),
            updatedAt: DateTime(2026, 10, 19, 3, 0),
          );
        }
        return null;
      };

      final result =
          await customService.reconcileProgram('prog-reread-valid-pending');

      expect(result.outcome, ProgramReconciliationOutcome.alreadyPending);
      expect(result.missedDayKey, '2026-10-18');
    });

    test(
        '41. Re-read status changed to unknown status returns dataIntegrityError',
        () async {
      await createProgram(
        id: 'prog-reread-unknown',
        startDayKey: '2026-10-18',
      );

      final clockTime = DateTime(2026, 10, 19, 5, 0, 0);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(nowProvider: () => clockTime),
      );

      programRepo.onGetById = (id, count) {
        if (count >= 2) {
          return ProgramV2Model(
            id: 'prog-reread-unknown',
            ibadahId: 'ibd-tahajjud',
            ibadahNameSnapshot: 'Shalat Tahajjud',
            targetDays: 40,
            startDayKey: '2026-10-18',
            status: 'SOME_CORRUPTED_STATUS',
            createdAt: DateTime(2026, 10, 18),
            updatedAt: DateTime(2026, 10, 18),
          );
        }
        return null;
      };

      final result =
          await customService.reconcileProgram('prog-reread-unknown');

      expect(result.outcome, ProgramReconciliationOutcome.dataIntegrityError);
      expect(result.isFailure, isTrue);
    });

    test(
        '42. Re-read status changed to terminal status returns terminalProgram without writing',
        () async {
      await createProgram(
        id: 'prog-reread-terminal',
        startDayKey: '2026-10-18',
      );

      final clockTime = DateTime(2026, 10, 19, 5, 0, 0);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(nowProvider: () => clockTime),
      );

      programRepo.onGetById = (id, count) {
        if (count >= 2) {
          return ProgramV2Model(
            id: 'prog-reread-terminal',
            ibadahId: 'ibd-tahajjud',
            ibadahNameSnapshot: 'Shalat Tahajjud',
            targetDays: 40,
            startDayKey: '2026-10-18',
            status: ProgramV2Model.statusSuccess,
            createdAt: DateTime(2026, 10, 18),
            updatedAt: DateTime(2026, 10, 18),
            finalizedAt: DateTime(2026, 10, 19),
          );
        }
        return null;
      };

      final result =
          await customService.reconcileProgram('prog-reread-terminal');

      expect(result.outcome, ProgramReconciliationOutcome.terminalProgram);
      expect(result.isSuccess, isTrue);
    });

    test(
        '43. Persisted program with invalid startDayKey returns dataIntegrityError without uncaught exception',
        () async {
      final corrupt = ProgramV2Model(
        id: 'prog-corrupt-start',
        ibadahId: 'ibd-tahajjud',
        ibadahNameSnapshot: 'Shalat Tahajjud',
        targetDays: 40,
        startDayKey: '2026-02-30', // invalid Gregorian calendar date
        status: ProgramV2Model.statusActive,
        createdAt: DateTime(2026, 10, 18),
        updatedAt: DateTime(2026, 10, 18),
      );
      await programBox.put('prog-corrupt-start', corrupt);

      final result = await service.reconcileProgram('prog-corrupt-start');

      expect(result.outcome, ProgramReconciliationOutcome.dataIntegrityError);
      expect(result.isFailure, isTrue);
      expect(result.errorMessage, contains('Invalid program startDayKey'));
    });

    test(
        '44. Persisted program with invalid targetDays returns dataIntegrityError',
        () async {
      // Below min duration (< 40)
      final corruptLow = ProgramV2Model(
        id: 'prog-corrupt-low',
        ibadahId: 'ibd-tahajjud',
        ibadahNameSnapshot: 'Shalat Tahajjud',
        targetDays: 39,
        startDayKey: '2026-10-18',
        status: ProgramV2Model.statusActive,
        createdAt: DateTime(2026, 10, 18),
        updatedAt: DateTime(2026, 10, 18),
      );
      await programBox.put('prog-corrupt-low', corruptLow);

      final resultLow = await service.reconcileProgram('prog-corrupt-low');
      expect(
          resultLow.outcome, ProgramReconciliationOutcome.dataIntegrityError);

      // Above max duration (> 365)
      final corruptHigh = ProgramV2Model(
        id: 'prog-corrupt-high',
        ibadahId: 'ibd-tahajjud',
        ibadahNameSnapshot: 'Shalat Tahajjud',
        targetDays: 366,
        startDayKey: '2026-10-18',
        status: ProgramV2Model.statusActive,
        createdAt: DateTime(2026, 10, 18),
        updatedAt: DateTime(2026, 10, 18),
      );
      await programBox.put('prog-corrupt-high', corruptHigh);

      final resultHigh = await service.reconcileProgram('prog-corrupt-high');
      expect(
          resultHigh.outcome, ProgramReconciliationOutcome.dataIntegrityError);
    });

    test(
        '45. Persisted program with pendingMissedDayKey preceding startDayKey returns dataIntegrityError',
        () async {
      final corruptPreceding = ProgramV2Model(
        id: 'prog-corrupt-preceding',
        ibadahId: 'ibd-tahajjud',
        ibadahNameSnapshot: 'Shalat Tahajjud',
        targetDays: 40,
        startDayKey: '2026-10-18',
        status: ProgramV2Model.statusPendingFailure,
        pendingMissedDayKey: '2026-10-15', // precedes startDayKey
        createdAt: DateTime(2026, 10, 18),
        updatedAt: DateTime(2026, 10, 18),
      );
      await programBox.put('prog-corrupt-preceding', corruptPreceding);

      final result = await service.reconcileProgram('prog-corrupt-preceding');

      expect(result.outcome, ProgramReconciliationOutcome.dataIntegrityError);
      expect(result.isFailure, isTrue);
      expect(result.errorMessage, contains('cannot precede startDayKey'));
    });

    test(
        '46. Batch reconciliation classifies corrupted program records as dataIntegrityError, not persistenceError',
        () async {
      final corrupt = ProgramV2Model(
        id: 'prog-batch-corrupt',
        ibadahId: 'ibd-tahajjud',
        ibadahNameSnapshot: 'Shalat Tahajjud',
        targetDays: 0, // corrupted duration
        startDayKey: '2026-10-18',
        status: ProgramV2Model.statusActive,
        createdAt: DateTime(2026, 10, 18),
        updatedAt: DateTime(2026, 10, 18),
      );
      await programBox.put('prog-batch-corrupt', corrupt);

      final batchResult = await service.reconcileActivePrograms();

      expect(batchResult.totalInspected, 1);
      expect(batchResult.results.first.outcome,
          ProgramReconciliationOutcome.dataIntegrityError);
      expect(batchResult.errorCount, 1);
    });

    test(
        '47. Cloned DailyCheckIn record stored at anomalous key is rejected and cannot authorize target completion',
        () async {
      await createProgram(
        id: 'prog-clone-tampered',
        targetDays: 40,
        startDayKey: '2026-09-09',
      );

      // Populate 40 valid consecutive check-ins
      var cur = DateTime.utc(2026, 9, 9);
      for (int i = 0; i < 40; i++) {
        final dayKey = DateService.formatCalendarDayKey(cur);
        await createCheckIn(
          programId: 'prog-clone-tampered',
          dayKey: dayKey,
          checkedAt: DateTime(cur.year, cur.month, cur.day, 5, 0),
        );
        cur = DateTime.utc(cur.year, cur.month, cur.day + 1);
      }
      expect(checkInBox.length, 40);

      // Store a duplicate/cloned check-in under an anomalous noncanonical key
      final clonedRecord = DailyCheckInModel(
        id: '2026-10-18_prog-clone-tampered',
        programId: 'prog-clone-tampered',
        dayKey: '2026-10-18',
        checkedAt: DateTime(2026, 10, 18, 5, 0),
        createdAt: DateTime(2026, 10, 18, 5, 0),
      );
      await checkInBox.put('anomalous_clone_key', clonedRecord);
      expect(checkInBox.length, 41);

      // Reconciliation on Day 41
      final clockTime = DateTime(2026, 10, 19, 5, 0, 0);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(nowProvider: () => clockTime),
      );

      final result =
          await customService.reconcileProgram('prog-clone-tampered');

      expect(result.outcome, ProgramReconciliationOutcome.dataIntegrityError);
      expect(result.isFailure, isTrue);
      expect(result.errorMessage, contains('noncanonical storage key'));

      // Program remains ACTIVE, not authorized for clean success
      final persisted = programRepo.getById('prog-clone-tampered')!;
      expect(persisted.status, ProgramV2Model.statusActive);
    });

    test(
        '48. Uncertain write failure: first call returns persistenceError, retry returns alreadyPending with original key',
        () async {
      await createProgram(
        id: 'prog-uncertain-write',
        startDayKey: '2026-10-18',
      );

      final clockTime = DateTime(2026, 10, 19, 5, 0, 0);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(nowProvider: () => clockTime),
      );

      // Simulate crash immediately after Hive write succeeded
      programRepo.throwAfterSave = true;

      final result1 =
          await customService.reconcileProgram('prog-uncertain-write');

      expect(result1.outcome, ProgramReconciliationOutcome.persistenceError);
      expect(result1.isFailure, isTrue);

      // Disable simulation for the retry attempt
      programRepo.throwAfterSave = false;

      // On retry, service reloads persisted state and discovers PENDING_FAILURE was saved
      final result2 =
          await customService.reconcileProgram('prog-uncertain-write');

      expect(result2.outcome, ProgramReconciliationOutcome.alreadyPending);
      expect(result2.missedDayKey, '2026-10-18');

      final persisted = programRepo.getById('prog-uncertain-write')!;
      expect(persisted.status, ProgramV2Model.statusPendingFailure);
      expect(persisted.pendingMissedDayKey, '2026-10-18');
    });

    // --- R2 Safety Hardening Tests ---

    test(
        '49. Re-read snapshot consistency: startDayKey changed concurrently returns dataIntegrityError without write',
        () async {
      await createProgram(
        id: 'prog-snapshot-startday',
        startDayKey: '2026-10-18',
      );

      final clockTime = DateTime(2026, 10, 19, 5, 0, 0);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(nowProvider: () => clockTime),
      );

      // Simulate concurrent change to startDayKey on re-read before write
      programRepo.onGetById = (id, count) {
        if (count >= 2) {
          return ProgramV2Model(
            id: 'prog-snapshot-startday',
            ibadahId: 'ibd-tahajjud',
            ibadahNameSnapshot: 'Shalat Tahajjud',
            targetDays: 40,
            startDayKey: '2026-10-19', // changed startDayKey
            status: ProgramV2Model.statusActive,
            createdAt: DateTime(2026, 10, 18),
            updatedAt: DateTime(2026, 10, 18),
          );
        }
        return null;
      };

      final result =
          await customService.reconcileProgram('prog-snapshot-startday');

      expect(result.outcome, ProgramReconciliationOutcome.dataIntegrityError);
      expect(result.isFailure, isTrue);
      expect(result.errorMessage,
          contains('Program snapshot changed concurrently'));

      // Ensure no PENDING_FAILURE transition was written
      programRepo.resetOverrides();
      final persisted = programRepo.getById('prog-snapshot-startday')!;
      expect(persisted.status, ProgramV2Model.statusActive);
      expect(persisted.pendingMissedDayKey, isNull);
    });

    test(
        '50. Re-read snapshot consistency: targetDays changed concurrently returns dataIntegrityError without write',
        () async {
      await createProgram(
        id: 'prog-snapshot-targetdays',
        startDayKey: '2026-10-18',
        targetDays: 40,
      );

      final clockTime = DateTime(2026, 10, 19, 5, 0, 0);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(nowProvider: () => clockTime),
      );

      // Simulate concurrent change to targetDays on re-read
      programRepo.onGetById = (id, count) {
        if (count >= 2) {
          return ProgramV2Model(
            id: 'prog-snapshot-targetdays',
            ibadahId: 'ibd-tahajjud',
            ibadahNameSnapshot: 'Shalat Tahajjud',
            targetDays: 60, // changed targetDays
            startDayKey: '2026-10-18',
            status: ProgramV2Model.statusActive,
            createdAt: DateTime(2026, 10, 18),
            updatedAt: DateTime(2026, 10, 18),
          );
        }
        return null;
      };

      final result =
          await customService.reconcileProgram('prog-snapshot-targetdays');

      expect(result.outcome, ProgramReconciliationOutcome.dataIntegrityError);
      expect(result.isFailure, isTrue);
      expect(result.errorMessage,
          contains('Program snapshot changed concurrently'));

      programRepo.resetOverrides();
      final persisted = programRepo.getById('prog-snapshot-targetdays')!;
      expect(persisted.status, ProgramV2Model.statusActive);
      expect(persisted.targetDays, 40);
      expect(persisted.pendingMissedDayKey, isNull);
    });

    test(
        '51. Re-read snapshot consistency: ibadahId changed concurrently returns dataIntegrityError without write',
        () async {
      await createProgram(
        id: 'prog-snapshot-ibadah',
        ibadahId: 'ibd-tahajjud',
        startDayKey: '2026-10-18',
      );

      final clockTime = DateTime(2026, 10, 19, 5, 0, 0);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(nowProvider: () => clockTime),
      );

      // Simulate concurrent change to ibadahId on re-read
      programRepo.onGetById = (id, count) {
        if (count >= 2) {
          return ProgramV2Model(
            id: 'prog-snapshot-ibadah',
            ibadahId: 'ibd-dhuha', // changed ibadahId
            ibadahNameSnapshot: 'Shalat Dhuha',
            targetDays: 40,
            startDayKey: '2026-10-18',
            status: ProgramV2Model.statusActive,
            createdAt: DateTime(2026, 10, 18),
            updatedAt: DateTime(2026, 10, 18),
          );
        }
        return null;
      };

      final result =
          await customService.reconcileProgram('prog-snapshot-ibadah');

      expect(result.outcome, ProgramReconciliationOutcome.dataIntegrityError);
      expect(result.isFailure, isTrue);
      expect(result.errorMessage,
          contains('Program snapshot changed concurrently'));

      programRepo.resetOverrides();
      final persisted = programRepo.getById('prog-snapshot-ibadah')!;
      expect(persisted.status, ProgramV2Model.statusActive);
      expect(persisted.ibadahId, 'ibd-tahajjud');
      expect(persisted.pendingMissedDayKey, isNull);
    });

    test(
        '52. Re-read snapshot consistency: identical ACTIVE snapshot transitions to PENDING_FAILURE normally',
        () async {
      await createProgram(
        id: 'prog-snapshot-consistent',
        startDayKey: '2026-10-18',
      );

      final clockTime = DateTime(2026, 10, 19, 5, 0, 0);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(nowProvider: () => clockTime),
      );

      final result =
          await customService.reconcileProgram('prog-snapshot-consistent');

      expect(result.outcome, ProgramReconciliationOutcome.pendingCreated);
      expect(result.missedDayKey, '2026-10-18');
      expect(result.isSuccess, isTrue);

      final persisted = programRepo.getById('prog-snapshot-consistent')!;
      expect(persisted.status, ProgramV2Model.statusPendingFailure);
      expect(persisted.pendingMissedDayKey, '2026-10-18');
    });

    test(
        '53. Batch storage identity: ACTIVE program stored at wrong key is classified as dataIntegrityError, not programNotFound',
        () async {
      // 1. Valid program stored at its canonical key
      final validProg = ProgramV2Model(
        id: 'prog-valid-batch',
        ibadahId: 'ibd-tahajjud',
        ibadahNameSnapshot: 'Shalat Tahajjud',
        targetDays: 40,
        startDayKey: '2026-10-18',
        status: ProgramV2Model.statusActive,
        createdAt: DateTime(2026, 10, 18),
        updatedAt: DateTime(2026, 10, 18),
      );
      await programBox.put('prog-valid-batch', validProg);

      // 2. Existing program occupying key 'existing-occupied-key'
      final existingProg = ProgramV2Model(
        id: 'existing-occupied-key',
        ibadahId: 'ibd-witir',
        ibadahNameSnapshot: 'Shalat Witir',
        targetDays: 40,
        startDayKey: '2026-10-18',
        status: ProgramV2Model.statusActive,
        createdAt: DateTime(2026, 10, 18),
        updatedAt: DateTime(2026, 10, 18),
      );
      await programBox.put('existing-occupied-key', existingProg);

      // 3. Corrupted program with id 'prog-mismatched' stored under 'wrong-storage-key'
      final corruptProg = ProgramV2Model(
        id: 'prog-mismatched',
        ibadahId: 'ibd-dhuha',
        ibadahNameSnapshot: 'Shalat Dhuha',
        targetDays: 40,
        startDayKey: '2026-10-18',
        status: ProgramV2Model.statusActive,
        createdAt: DateTime(2026, 10, 18),
        updatedAt: DateTime(2026, 10, 18),
      );
      await programBox.put('wrong-storage-key', corruptProg);

      final initialKeys = programBox.keys.toSet();
      expect(initialKeys,
          {'prog-valid-batch', 'existing-occupied-key', 'wrong-storage-key'});

      final clockTime = DateTime(2026, 10, 19, 5, 0, 0);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(nowProvider: () => clockTime),
      );

      final batchResult = await customService.reconcileActivePrograms();

      expect(batchResult.totalInspected, 3);

      // The mismatched program is classified as dataIntegrityError, NOT programNotFound
      final corruptResult = batchResult.results
          .firstWhere((r) => r.programId == 'prog-mismatched');
      expect(corruptResult.outcome,
          ProgramReconciliationOutcome.dataIntegrityError);
      expect(corruptResult.isFailure, isTrue);
      expect(corruptResult.errorMessage,
          contains('Program storage key identity mismatch'));

      // Valid program in the same batch is still reconciled successfully
      final validResult = batchResult.results
          .firstWhere((r) => r.programId == 'prog-valid-batch');
      expect(validResult.outcome, ProgramReconciliationOutcome.pendingCreated);
      expect(validResult.isSuccess, isTrue);

      // Existing program at 'existing-occupied-key' was processed normally
      final existingResult = batchResult.results
          .firstWhere((r) => r.programId == 'existing-occupied-key');
      expect(
          existingResult.outcome, ProgramReconciliationOutcome.pendingCreated);

      // No additional keys or duplicate records are written; no existing program is overwritten
      expect(programBox.keys.toSet(), initialKeys);

      // Corrupt record was not modified in storage
      final preservedCorrupt = programBox.get('wrong-storage-key')!;
      expect(preservedCorrupt.id, 'prog-mismatched');
      expect(preservedCorrupt.status, ProgramV2Model.statusActive);
      expect(preservedCorrupt.pendingMissedDayKey, isNull);
    });

    test(
        '54. Safe batch error handling: sensitive paths and internal exception details are not exposed in errorMessage',
        () async {
      await createProgram(
        id: 'prog-sensitive-error',
        startDayKey: '2026-10-18',
      );

      final clockTime = DateTime(2026, 10, 19, 5, 0, 0);
      final customService = ProgramV2ReconciliationService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: DateService(nowProvider: () => clockTime),
      );

      const sensitivePath =
          '/data/user/0/com.majelis.mujahadah/app_flutter/hive/secret_storage.hive';
      const sensitiveReason =
          'simulated internal disk corruption: permission denied';

      // Override getById on re-read to simulate an unexpected internal error with sensitive paths
      programRepo.onGetById = (id, count) {
        if (count >= 2) {
          throw StateError('Fatal crash at $sensitivePath: $sensitiveReason');
        }
        return null;
      };

      final batchResult = await customService.reconcileActivePrograms();

      expect(batchResult.totalInspected, 1);
      final failureResult = batchResult.results.first;

      expect(failureResult.isFailure, isTrue);
      // Classified as unexpectedError, not blindly dataIntegrityError
      expect(
          failureResult.outcome, ProgramReconciliationOutcome.unexpectedError);

      // The errorMessage must be user-safe and must NOT leak sensitive paths or internal stack details
      expect(failureResult.errorMessage, isNotNull);
      expect(failureResult.errorMessage, isNot(contains(sensitivePath)));
      expect(failureResult.errorMessage, isNot(contains('secret_storage')));
      expect(failureResult.errorMessage, isNot(contains(sensitiveReason)));
      expect(failureResult.errorMessage, isNot(contains('Exception')));
      expect(
        failureResult.errorMessage,
        'An unexpected error occurred during reconciliation of program "prog-sensitive-error".',
      );
    });

    test(
        '55. Safe batch error handling: Hive read failure in getAll does not leak raw paths',
        () async {
      await createProgram(
        id: 'prog-safe-batch',
        startDayKey: '2026-10-18',
      );

      // Close the box to trigger HiveError on getAll()
      await programBox.close();

      final batchResult = await service.reconcileActivePrograms();

      expect(batchResult.results.length, 1);
      final failureResult = batchResult.results.first;
      expect(
          failureResult.outcome, ProgramReconciliationOutcome.persistenceError);
      expect(
        failureResult.errorMessage,
        'Storage operation failed while retrieving programs for batch reconciliation.',
      );
      expect(failureResult.errorMessage, isNot(contains('HiveError')));
      expect(failureResult.errorMessage,
          isNot(contains('Box has already been closed')));
    });
  });
}
