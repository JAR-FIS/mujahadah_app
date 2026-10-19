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
import 'package:mujahadah/services/program_v2_success_service.dart';

/// Test repository that can simulate storage failures and mock re-read outcomes for Program.
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
      throw HiveError('Simulated disk I/O write failure on Program');
    }
    await super.save(program);
    if (throwAfterSave) {
      throw HiveError('Simulated crash after Program write completed');
    }
  }

  void resetOverrides() {
    shouldThrowOnSave = false;
    throwAfterSave = false;
    onGetById = null;
    _getByIdCallCounts.clear();
  }
}

/// Test repository that can simulate storage failures and mock re-read outcomes for Achievement.
class FailingAchievementV2Repository extends AchievementV2Repository {
  bool shouldThrowOnSave = false;
  bool throwAfterSave = false;
  AchievementModel? Function(String id, int callCount)? onGetById;
  final Map<String, int> _getByIdCallCounts = {};

  FailingAchievementV2Repository({required super.box});

  @override
  AchievementModel? getById(String id) {
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
  Future<void> save(AchievementModel achievement) async {
    if (shouldThrowOnSave) {
      throw HiveError('Simulated disk I/O write failure on Achievement');
    }
    await super.save(achievement);
    if (throwAfterSave) {
      throw HiveError('Simulated crash after Achievement write completed');
    }
  }

  void resetOverrides() {
    shouldThrowOnSave = false;
    throwAfterSave = false;
    onGetById = null;
    _getByIdCallCounts.clear();
  }
}

/// Test repository that can simulate storage failures for FailureRecord.
class FailingFailureRecordV2Repository extends FailureRecordV2Repository {
  bool shouldThrow = false;

  FailingFailureRecordV2Repository({required super.box});

  @override
  List<FailureRecordModel> getByProgramId(String programId) {
    if (shouldThrow) {
      throw HiveError('Simulated disk I/O read failure on FailureRecord');
    }
    return super.getByProgramId(programId);
  }

  void resetOverrides() {
    shouldThrow = false;
  }
}

class _NoncanonicalKeyAchievementModel extends AchievementModel {
  final dynamic _customKey;

  _NoncanonicalKeyAchievementModel({
    required super.id,
    required super.programId,
    required super.type,
    required super.milestoneDays,
    required super.achievedAt,
    super.recipientNameSnapshot,
    required super.createdAt,
    dynamic customKey,
  }) : _customKey = customKey;

  @override
  dynamic get key => _customKey;
}

class _NoncanonicalKeyCheckInModel extends DailyCheckInModel {
  final dynamic _customKey;

  _NoncanonicalKeyCheckInModel({
    required super.id,
    required super.programId,
    required super.dayKey,
    required super.checkedAt,
    required super.createdAt,
    dynamic customKey,
  }) : _customKey = customKey;

  @override
  dynamic get key => _customKey;
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
  late FailingFailureRecordV2Repository failureRepo;
  late DateService dateService;
  late ProgramV2SuccessService service;

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
    tempDir = Directory.systemTemp.createTempSync('program_v2_success_test_');
    Hive.init(tempDir.path);
    programBox = await Hive.openBox<ProgramV2Model>('test_programs_box');
    checkInBox = await Hive.openBox<DailyCheckInModel>('test_checkins_box');
    achievementBox =
        await Hive.openBox<AchievementModel>('test_achievements_box');
    failureBox = await Hive.openBox<FailureRecordModel>('test_failures_box');

    programRepo = FailingProgramV2Repository(box: programBox);
    checkInRepo = DailyCheckInV2Repository(box: checkInBox);
    achievementRepo = FailingAchievementV2Repository(box: achievementBox);
    failureRepo = FailingFailureRecordV2Repository(box: failureBox);

    // Default clock: 2026-10-25 05:00:00 (operational day: 2026-10-25)
    dateService = DateService(
      nowProvider: () => DateTime(2026, 10, 25, 5, 0, 0),
    );

    service = ProgramV2SuccessService(
      programRepository: programRepo,
      checkInRepository: checkInRepo,
      achievementRepository: achievementRepo,
      failureRecordRepository: failureRepo,
      dateService: dateService,
    );
  });

  tearDown(() async {
    programRepo.resetOverrides();
    achievementRepo.resetOverrides();
    failureRepo.resetOverrides();
    if (programBox.isOpen) {
      await programBox.close();
    }
    if (checkInBox.isOpen) {
      await checkInBox.close();
    }
    if (achievementBox.isOpen) {
      await achievementBox.close();
    }
    if (failureBox.isOpen) {
      await failureBox.close();
    }
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  Future<ProgramV2Model> createProgram({
    required String id,
    int targetDays = 40,
    String startDayKey = '2026-09-01',
    String status = ProgramV2Model.statusActive,
    String ibadahId = 'ibadah-tahajjud',
    String ibadahNameSnapshot = 'Shalat Tahajjud',
    String? recipientNameSnapshot,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? finalizedAt,
    String? pendingMissedDayKey,
  }) async {
    final program = ProgramV2Model(
      id: id,
      ibadahId: ibadahId,
      ibadahNameSnapshot: ibadahNameSnapshot,
      targetDays: targetDays,
      startDayKey: startDayKey,
      status: status,
      recipientNameSnapshot: recipientNameSnapshot,
      createdAt: createdAt ?? DateTime(2026, 8, 31, 20, 0),
      updatedAt: updatedAt ?? DateTime(2026, 8, 31, 20, 0),
      finalizedAt: finalizedAt,
      pendingMissedDayKey: pendingMissedDayKey,
    );
    await programBox.put(id, program);
    return program;
  }

  Future<List<DailyCheckInModel>> populateConsecutiveCheckIns({
    required String programId,
    required String startDayKey,
    required int count,
    DateTime Function(int index, String dayKey)? timestampProvider,
  }) async {
    final startDt = DateService.parseDayKey(startDayKey);
    final records = <DailyCheckInModel>[];

    for (int i = 0; i < count; i++) {
      final currentDt =
          DateTime.utc(startDt.year, startDt.month, startDt.day + i);
      final dayKey = DateService.formatCalendarDayKey(currentDt);
      final id = DailyCheckInV2Repository.buildCheckInId(dayKey, programId);

      // Default timestamp: 05:00:00 local on that day (safely inside operational day)
      final checkedAt = timestampProvider != null
          ? timestampProvider(i, dayKey)
          : DateTime(currentDt.year, currentDt.month, currentDt.day, 5, 0, 0);

      final checkIn = DailyCheckInModel(
        id: id,
        programId: programId,
        dayKey: dayKey,
        checkedAt: checkedAt,
        createdAt: checkedAt,
      );
      await checkInBox.put(id, checkIn);
      records.add(checkIn);
    }
    return records;
  }

  group('Program V2 SUCCESS Finalization & FINAL_SUCCESS Achievement', () {
    // -------------------------------------------------------------------------
    // 1. Authoritative Target Duration Completion (Tests 1–5)
    // -------------------------------------------------------------------------
    test(
        '1. Target 40/40 -> SUCCESS finalization succeeds and creates FINAL_SUCCESS achievement',
        () async {
      await createProgram(
          id: 'prog-40', targetDays: 40, startDayKey: '2026-09-01');
      final checkIns = await populateConsecutiveCheckIns(
        programId: 'prog-40',
        startDayKey: '2026-09-01',
        count: 40,
      );

      final result = await service.finalizeSuccess(
        programId: 'prog-40',
        recipientNameSnapshot: 'Ahmad Fulan',
      );

      expect(result.outcome, ProgramSuccessOutcome.finalizedSuccess);
      expect(result.isSuccess, isTrue);
      expect(result.finalStatus, ProgramV2Model.statusSuccess);
      expect(result.completedDays, 40);

      final persistedProgram = programBox.get('prog-40');
      expect(persistedProgram?.status, ProgramV2Model.statusSuccess);
      expect(persistedProgram?.recipientNameSnapshot, 'Ahmad Fulan');
      expect(persistedProgram?.finalizedAt, isNotNull);

      final expectedAchId =
          AchievementV2Repository.buildFinalSuccessId('prog-40');
      final persistedAch = achievementBox.get(expectedAchId);
      expect(persistedAch, isNotNull);
      expect(persistedAch?.type, AchievementModel.typeFinalSuccess);
      expect(persistedAch?.milestoneDays, 40);
      expect(persistedAch?.recipientNameSnapshot, 'Ahmad Fulan');
      expect(persistedAch?.achievedAt, checkIns.last.checkedAt);
      expect(achievementBox.length, 1);
    });

    test('2. Target 60/60 -> SUCCESS finalization succeeds', () async {
      await createProgram(
          id: 'prog-60', targetDays: 60, startDayKey: '2026-08-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-60',
        startDayKey: '2026-08-01',
        count: 60,
      );

      final result = await service.finalizeSuccess(
        programId: 'prog-60',
        recipientNameSnapshot: 'Budi Santoso',
      );

      expect(result.outcome, ProgramSuccessOutcome.finalizedSuccess);
      expect(result.completedDays, 60);

      final ach = achievementBox
          .get(AchievementV2Repository.buildFinalSuccessId('prog-60'));
      expect(ach?.milestoneDays, 60);
    });

    test('3. Target 90/90 -> SUCCESS finalization succeeds', () async {
      await createProgram(
          id: 'prog-90', targetDays: 90, startDayKey: '2026-07-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-90',
        startDayKey: '2026-07-01',
        count: 90,
      );

      final result = await service.finalizeSuccess(
        programId: 'prog-90',
        recipientNameSnapshot: 'Citra Dewi',
      );

      expect(result.outcome, ProgramSuccessOutcome.finalizedSuccess);
      expect(result.completedDays, 90);
    });

    test('4. Target 100/100 -> SUCCESS finalization succeeds', () async {
      await createProgram(
          id: 'prog-100', targetDays: 100, startDayKey: '2026-06-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-100',
        startDayKey: '2026-06-01',
        count: 100,
      );

      final result = await service.finalizeSuccess(
        programId: 'prog-100',
        recipientNameSnapshot: 'Dimas Pratama',
      );

      expect(result.outcome, ProgramSuccessOutcome.finalizedSuccess);
      expect(result.completedDays, 100);
    });

    test('5. Valid custom target (e.g. 75/75) -> SUCCESS finalization succeeds',
        () async {
      await createProgram(
          id: 'prog-75', targetDays: 75, startDayKey: '2026-08-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-75',
        startDayKey: '2026-08-01',
        count: 75,
      );

      final result = await service.finalizeSuccess(
        programId: 'prog-75',
        recipientNameSnapshot: 'Eka Saputra',
      );

      expect(result.outcome, ProgramSuccessOutcome.finalizedSuccess);
      expect(result.completedDays, 75);
    });

    // -------------------------------------------------------------------------
    // 2. Incompleteness & Ineligibility (Tests 6–8)
    // -------------------------------------------------------------------------
    test('6. 39/40 -> notYetEligible', () async {
      await createProgram(
          id: 'prog-39-40', targetDays: 40, startDayKey: '2026-09-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-39-40',
        startDayKey: '2026-09-01',
        count: 39,
      );

      final result = await service.finalizeSuccess(
        programId: 'prog-39-40',
        recipientNameSnapshot: 'Fulan',
      );

      expect(result.outcome, ProgramSuccessOutcome.notYetEligible);
      expect(result.completedDays, 39);
      expect(result.isNotYetEligible, isTrue);

      final persisted = programBox.get('prog-39-40');
      expect(persisted?.status, ProgramV2Model.statusActive);
      expect(achievementBox.isEmpty, isTrue);
    });

    test('7. 40/60 -> notYetEligible, not WARNING', () async {
      await createProgram(
          id: 'prog-40-60', targetDays: 60, startDayKey: '2026-09-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-40-60',
        startDayKey: '2026-09-01',
        count: 40,
      );

      final result = await service.finalizeSuccess(
        programId: 'prog-40-60',
        recipientNameSnapshot: 'Fulan',
      );

      expect(result.outcome, ProgramSuccessOutcome.notYetEligible);
      expect(result.completedDays, 40);

      final persisted = programBox.get('prog-40-60');
      expect(persisted?.status, ProgramV2Model.statusActive);
    });

    test('8. Gap in required check-ins -> no SUCCESS (dataIntegrityError)',
        () async {
      await createProgram(
          id: 'prog-gap', targetDays: 40, startDayKey: '2026-09-01');
      // Create days 1-10, skip day 11, create days 12-40
      final startDt = DateTime.utc(2026, 9, 1);
      for (int i = 0; i < 40; i++) {
        if (i == 10) continue; // Gap at day index 10
        final cur = DateTime.utc(startDt.year, startDt.month, startDt.day + i);
        final dayKey = DateService.formatCalendarDayKey(cur);
        final id = DailyCheckInV2Repository.buildCheckInId(dayKey, 'prog-gap');
        await checkInBox.put(
          id,
          DailyCheckInModel(
            id: id,
            programId: 'prog-gap',
            dayKey: dayKey,
            checkedAt: DateTime(cur.year, cur.month, cur.day, 5, 0, 0),
            createdAt: DateTime(cur.year, cur.month, cur.day, 5, 0, 0),
          ),
        );
      }

      final result = await service.finalizeSuccess(
        programId: 'prog-gap',
        recipientNameSnapshot: 'Fulan',
      );

      expect(result.outcome, ProgramSuccessOutcome.dataIntegrityError);
      expect(result.errorMessage, contains('gaps or nonconsecutive dates'));
    });

    // -------------------------------------------------------------------------
    // 3. Check-in Integrity & Operational Time Validation (Tests 9–15)
    // -------------------------------------------------------------------------
    test('9. Future check-in -> dataIntegrityError', () async {
      await createProgram(
          id: 'prog-future', targetDays: 40, startDayKey: '2026-09-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-future',
        startDayKey: '2026-09-01',
        count: 39,
      );

      // Insert check-in for tomorrow relative to current date (2026-10-25)
      final futureDay = '2026-10-26';
      final id =
          DailyCheckInV2Repository.buildCheckInId(futureDay, 'prog-future');
      await checkInBox.put(
        id,
        DailyCheckInModel(
          id: id,
          programId: 'prog-future',
          dayKey: futureDay,
          checkedAt: DateTime(2026, 10, 26, 5, 0, 0),
          createdAt: DateTime(2026, 10, 26, 5, 0, 0),
        ),
      );

      final result = await service.finalizeSuccess(
        programId: 'prog-future',
        recipientNameSnapshot: 'Fulan',
      );

      expect(result.outcome, ProgramSuccessOutcome.dataIntegrityError);
      expect(result.errorMessage, contains('future'));
    });

    test('10. Duplicate conflicting check-ins -> dataIntegrityError', () async {
      await createProgram(
          id: 'prog-dup-ci', targetDays: 40, startDayKey: '2026-09-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-dup-ci',
        startDayKey: '2026-09-01',
        count: 40,
      );

      // Put duplicate conflicting record under another key
      await checkInBox.put(
        'dup_ci_key',
        DailyCheckInModel(
          id: 'dup_ci_id',
          programId: 'prog-dup-ci',
          dayKey: '2026-09-10',
          checkedAt: DateTime(2026, 9, 10, 6, 0, 0),
          createdAt: DateTime(2026, 9, 10, 6, 0, 0),
        ),
      );

      final result = await service.finalizeSuccess(
        programId: 'prog-dup-ci',
        recipientNameSnapshot: 'Fulan',
      );

      expect(result.outcome, ProgramSuccessOutcome.dataIntegrityError);
      expect(result.errorMessage, contains('Duplicate'));
    });

    test('11. Noncanonical check-in storage key -> dataIntegrityError',
        () async {
      await createProgram(
          id: 'prog-noncanonical-ci',
          targetDays: 40,
          startDayKey: '2026-09-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-noncanonical-ci',
        startDayKey: '2026-09-01',
        count: 39,
      );

      // 40th check-in stored under noncanonical key
      final expectedId = DailyCheckInV2Repository.buildCheckInId(
          '2026-10-10', 'prog-noncanonical-ci');
      final record = _NoncanonicalKeyCheckInModel(
        id: expectedId,
        programId: 'prog-noncanonical-ci',
        dayKey: '2026-10-10',
        checkedAt: DateTime(2026, 10, 10, 5, 0, 0),
        createdAt: DateTime(2026, 10, 10, 5, 0, 0),
        customKey: 'custom_storage_key_123',
      );
      await checkInBox.put('custom_storage_key_123', record);

      final result = await service.finalizeSuccess(
        programId: 'prog-noncanonical-ci',
        recipientNameSnapshot: 'Fulan',
      );

      expect(result.outcome, ProgramSuccessOutcome.dataIntegrityError);
      expect(result.errorMessage, contains('noncanonical storage key'));
    });

    test(
        '12. checkedAt outside the claimed operational day -> dataIntegrityError',
        () async {
      await createProgram(
          id: 'prog-bad-checked-at', targetDays: 40, startDayKey: '2026-09-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-bad-checked-at',
        startDayKey: '2026-09-01',
        count: 39,
      );

      // 40th check-in claims dayKey 2026-10-10, but checkedAt was 2026-10-10 02:30 (operational day 2026-10-09!)
      final expectedId = DailyCheckInV2Repository.buildCheckInId(
          '2026-10-10', 'prog-bad-checked-at');
      await checkInBox.put(
        expectedId,
        DailyCheckInModel(
          id: expectedId,
          programId: 'prog-bad-checked-at',
          dayKey: '2026-10-10',
          checkedAt: DateTime(
              2026, 10, 10, 2, 30, 0), // Falls in operational day 2026-10-09!
          createdAt: DateTime(2026, 10, 10, 2, 30, 0),
        ),
      );

      final result = await service.finalizeSuccess(
        programId: 'prog-bad-checked-at',
        recipientNameSnapshot: 'Fulan',
      );

      expect(result.outcome, ProgramSuccessOutcome.dataIntegrityError);
      expect(result.errorMessage, contains('falls on operational day'));
    });

    test('13. Final check-in at 02:59 -> correct operational day', () async {
      await createProgram(
          id: 'prog-0259', targetDays: 40, startDayKey: '2026-09-01');
      // Days 1-39 standard
      await populateConsecutiveCheckIns(
        programId: 'prog-0259',
        startDayKey: '2026-09-01',
        count: 39,
      );

      // 40th operational day is 2026-10-10. Checked in on calendar day 2026-10-11 at 02:59:00 local!
      final expectedId =
          DailyCheckInV2Repository.buildCheckInId('2026-10-10', 'prog-0259');
      final checkInTime = DateTime(2026, 10, 11, 2, 59, 0);
      await checkInBox.put(
        expectedId,
        DailyCheckInModel(
          id: expectedId,
          programId: 'prog-0259',
          dayKey: '2026-10-10',
          checkedAt: checkInTime,
          createdAt: checkInTime,
        ),
      );

      final result = await service.finalizeSuccess(
        programId: 'prog-0259',
        recipientNameSnapshot: 'Fulan',
      );

      expect(result.outcome, ProgramSuccessOutcome.finalizedSuccess);
      expect(result.completedDays, 40);
      expect(result.achievement?.achievedAt, checkInTime);
    });

    test('14. Final check-in at 03:00 -> correct next operational day',
        () async {
      await createProgram(
          id: 'prog-0300', targetDays: 40, startDayKey: '2026-09-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-0300',
        startDayKey: '2026-09-01',
        count: 39,
      );

      // 40th operational day 2026-10-10. Checked in on 2026-10-10 at exactly 03:00:00 local!
      final expectedId =
          DailyCheckInV2Repository.buildCheckInId('2026-10-10', 'prog-0300');
      final checkInTime = DateTime(2026, 10, 10, 3, 0, 0);
      await checkInBox.put(
        expectedId,
        DailyCheckInModel(
          id: expectedId,
          programId: 'prog-0300',
          dayKey: '2026-10-10',
          checkedAt: checkInTime,
          createdAt: checkInTime,
        ),
      );

      final result = await service.finalizeSuccess(
        programId: 'prog-0300',
        recipientNameSnapshot: 'Fulan',
      );

      expect(result.outcome, ProgramSuccessOutcome.finalizedSuccess);
      expect(result.completedDays, 40);
      expect(result.achievement?.achievedAt, checkInTime);
    });

    test('15. Delayed finalization after target day -> succeeds', () async {
      await createProgram(
          id: 'prog-delayed', targetDays: 40, startDayKey: '2026-09-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-delayed',
        startDayKey: '2026-09-01',
        count: 40,
      );

      // Current clock is 2026-10-25 (15 days after 40th day was completed on 2026-10-10)
      final result = await service.finalizeSuccess(
        programId: 'prog-delayed',
        recipientNameSnapshot: 'Fulan',
        capturedNow: DateTime(2026, 10, 25, 12, 0, 0),
      );

      expect(result.outcome, ProgramSuccessOutcome.finalizedSuccess);
      expect(result.completedDays, 40);
    });

    // -------------------------------------------------------------------------
    // 4. Lifecycle Ineligibility (Tests 16–17)
    // -------------------------------------------------------------------------
    test('16. PENDING_FAILURE cannot become SUCCESS', () async {
      await createProgram(
        id: 'prog-pending',
        targetDays: 40,
        startDayKey: '2026-09-01',
        status: ProgramV2Model.statusPendingFailure,
        pendingMissedDayKey: '2026-09-15',
      );

      final result = await service.finalizeSuccess(
        programId: 'prog-pending',
        recipientNameSnapshot: 'Fulan',
      );

      expect(result.outcome, ProgramSuccessOutcome.programNotActive);
      expect(result.errorMessage, contains('PENDING_FAILURE'));
    });

    test('17. FAILED and WARNING cannot become SUCCESS', () async {
      await createProgram(
        id: 'prog-failed',
        targetDays: 40,
        startDayKey: '2026-09-01',
        status: ProgramV2Model.statusFailed,
      );
      await createProgram(
        id: 'prog-warning',
        targetDays: 60,
        startDayKey: '2026-09-01',
        status: ProgramV2Model.statusWarning,
      );

      final resultFailed = await service.finalizeSuccess(
        programId: 'prog-failed',
        recipientNameSnapshot: 'Fulan',
      );
      expect(resultFailed.outcome, ProgramSuccessOutcome.programNotActive);
      expect(resultFailed.errorMessage, contains('FAILED'));

      final resultWarning = await service.finalizeSuccess(
        programId: 'prog-warning',
        recipientNameSnapshot: 'Fulan',
      );
      expect(resultWarning.outcome, ProgramSuccessOutcome.programNotActive);
      expect(resultWarning.errorMessage, contains('WARNING'));
    });

    // -------------------------------------------------------------------------
    // 5. Recipient Name & Field Invariants (Tests 18–20)
    // -------------------------------------------------------------------------
    test('18. Empty recipient name rejected before first finalization',
        () async {
      await createProgram(
          id: 'prog-empty-name', targetDays: 40, startDayKey: '2026-09-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-empty-name',
        startDayKey: '2026-09-01',
        count: 40,
      );

      final resultEmpty = await service.finalizeSuccess(
        programId: 'prog-empty-name',
        recipientNameSnapshot: '',
      );
      expect(resultEmpty.outcome, ProgramSuccessOutcome.invalidRecipientName);

      final resultWhitespace = await service.finalizeSuccess(
        programId: 'prog-empty-name',
        recipientNameSnapshot: '   ',
      );
      expect(
          resultWhitespace.outcome, ProgramSuccessOutcome.invalidRecipientName);

      // Verify program not mutated
      final persisted = programBox.get('prog-empty-name');
      expect(persisted?.status, ProgramV2Model.statusActive);
      expect(achievementBox.isEmpty, isTrue);
    });

    test('19. SUCCESS stores the original recipientNameSnapshot', () async {
      await createProgram(
          id: 'prog-trimmed-name', targetDays: 40, startDayKey: '2026-09-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-trimmed-name',
        startDayKey: '2026-09-01',
        count: 40,
      );

      final result = await service.finalizeSuccess(
        programId: 'prog-trimmed-name',
        recipientNameSnapshot: '  Umar bin Khattab  ',
      );

      expect(result.outcome, ProgramSuccessOutcome.finalizedSuccess);
      expect(result.program?.recipientNameSnapshot, 'Umar bin Khattab');
      expect(result.achievement?.recipientNameSnapshot, 'Umar bin Khattab');

      final persistedProgram = programBox.get('prog-trimmed-name');
      expect(persistedProgram?.recipientNameSnapshot, 'Umar bin Khattab');
    });

    test('20. Existing ibadahNameSnapshot is preserved', () async {
      await createProgram(
        id: 'prog-preserve-ibadah',
        targetDays: 40,
        startDayKey: '2026-09-01',
        ibadahId: 'ibadah-khusus',
        ibadahNameSnapshot: 'Tilawah Juz 30 Istiqomah',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-preserve-ibadah',
        startDayKey: '2026-09-01',
        count: 40,
      );

      final result = await service.finalizeSuccess(
        programId: 'prog-preserve-ibadah',
        recipientNameSnapshot: 'Fulan',
      );

      expect(result.outcome, ProgramSuccessOutcome.finalizedSuccess);
      expect(result.program?.ibadahNameSnapshot, 'Tilawah Juz 30 Istiqomah');

      final persisted = programBox.get('prog-preserve-ibadah');
      expect(persisted?.ibadahNameSnapshot, 'Tilawah Juz 30 Istiqomah');
    });

    // -------------------------------------------------------------------------
    // 6. FINAL_SUCCESS Achievement Invariants (Tests 21–26)
    // -------------------------------------------------------------------------
    test('21. FINAL_SUCCESS Achievement created exactly once', () async {
      await createProgram(
          id: 'prog-ach-once', targetDays: 40, startDayKey: '2026-09-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-ach-once',
        startDayKey: '2026-09-01',
        count: 40,
      );

      final result = await service.finalizeSuccess(
        programId: 'prog-ach-once',
        recipientNameSnapshot: 'Fulan',
      );

      expect(result.outcome, ProgramSuccessOutcome.finalizedSuccess);
      expect(achievementBox.length, 1);
      final ach = achievementBox.values.first;
      expect(ach.type, AchievementModel.typeFinalSuccess);
      expect(
          ach.id, AchievementV2Repository.buildFinalSuccessId('prog-ach-once'));
    });

    test('22. Achievement milestoneDays equals target', () async {
      await createProgram(
          id: 'prog-ms-target', targetDays: 40, startDayKey: '2026-09-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-ms-target',
        startDayKey: '2026-09-01',
        count: 40,
      );

      final result = await service.finalizeSuccess(
        programId: 'prog-ms-target',
        recipientNameSnapshot: 'Fulan',
      );

      expect(result.achievement?.milestoneDays, 40);
    });

    test('23. Achievement achievedAt matches final valid check-in', () async {
      await createProgram(
          id: 'prog-ach-at', targetDays: 40, startDayKey: '2026-09-01');
      final checkIns = await populateConsecutiveCheckIns(
        programId: 'prog-ach-at',
        startDayKey: '2026-09-01',
        count: 40,
      );

      final result = await service.finalizeSuccess(
        programId: 'prog-ach-at',
        recipientNameSnapshot: 'Fulan',
      );

      expect(result.achievement?.achievedAt, checkIns.last.checkedAt);
    });

    test('24. No duplicate Achievement on retry', () async {
      await createProgram(
          id: 'prog-no-dup-ach', targetDays: 40, startDayKey: '2026-09-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-no-dup-ach',
        startDayKey: '2026-09-01',
        count: 40,
      );

      final first = await service.finalizeSuccess(
        programId: 'prog-no-dup-ach',
        recipientNameSnapshot: 'Fulan',
      );
      expect(first.outcome, ProgramSuccessOutcome.finalizedSuccess);
      expect(achievementBox.length, 1);

      final retry = await service.finalizeSuccess(
        programId: 'prog-no-dup-ach',
        recipientNameSnapshot: 'Fulan',
      );
      expect(retry.outcome, ProgramSuccessOutcome.alreadyFinalized);
      expect(retry.isAlreadyFinalized, isTrue);
      expect(achievementBox.length, 1);
    });

    test('25. Conflicting Achievement -> dataIntegrityError', () async {
      await createProgram(
          id: 'prog-conflict-ach', targetDays: 40, startDayKey: '2026-09-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-conflict-ach',
        startDayKey: '2026-09-01',
        count: 40,
      );

      // Pre-insert an achievement at the canonical ID with mismatched milestoneDays (e.g. 50 instead of 40)
      final canonicalAchId =
          AchievementV2Repository.buildFinalSuccessId('prog-conflict-ach');
      await achievementBox.put(
        canonicalAchId,
        AchievementModel(
          id: canonicalAchId,
          programId: 'prog-conflict-ach',
          type: AchievementModel.typeFinalSuccess,
          milestoneDays: 50, // Conflict!
          achievedAt: DateTime(2026, 10, 10, 5, 0),
          recipientNameSnapshot: 'Fulan',
          createdAt: DateTime(2026, 10, 10, 5, 0),
        ),
      );

      final result = await service.finalizeSuccess(
        programId: 'prog-conflict-ach',
        recipientNameSnapshot: 'Fulan',
      );

      expect(result.outcome, ProgramSuccessOutcome.dataIntegrityError);
      expect(result.errorMessage,
          contains('Conflicting FINAL_SUCCESS achievement already exists'));
    });

    test('26. Achievement at noncanonical Hive key -> dataIntegrityError',
        () async {
      await createProgram(
        id: 'prog-noncanonical-ach',
        targetDays: 40,
        startDayKey: '2026-09-01',
        status: ProgramV2Model.statusSuccess,
        recipientNameSnapshot: 'Fulan',
        finalizedAt: DateTime(2026, 10, 10, 5, 0),
      );
      final checkIns = await populateConsecutiveCheckIns(
        programId: 'prog-noncanonical-ach',
        startDayKey: '2026-09-01',
        count: 40,
      );

      // Achievement stored under noncanonical key
      final expectedAchId =
          AchievementV2Repository.buildFinalSuccessId('prog-noncanonical-ach');
      await achievementBox.put(
        'custom_ach_key',
        _NoncanonicalKeyAchievementModel(
          id: expectedAchId,
          programId: 'prog-noncanonical-ach',
          type: AchievementModel.typeFinalSuccess,
          milestoneDays: 40,
          achievedAt: checkIns.last.checkedAt,
          recipientNameSnapshot: 'Fulan',
          createdAt: DateTime(2026, 10, 10, 5, 0),
          customKey: 'custom_ach_key',
        ),
      );

      final result = await service.finalizeSuccess(
        programId: 'prog-noncanonical-ach',
        recipientNameSnapshot: 'Fulan',
      );

      expect(result.outcome, ProgramSuccessOutcome.dataIntegrityError);
      expect(result.errorMessage, contains('identity or field mismatch'));
    });

    // -------------------------------------------------------------------------
    // 7. Safe Two-Box Persistence & Recovery (Tests 27–30)
    // -------------------------------------------------------------------------
    test('27. Program save failure before persistence -> no Achievement',
        () async {
      await createProgram(
          id: 'prog-fail-save', targetDays: 40, startDayKey: '2026-09-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-fail-save',
        startDayKey: '2026-09-01',
        count: 40,
      );

      programRepo.shouldThrowOnSave = true;

      final result = await service.finalizeSuccess(
        programId: 'prog-fail-save',
        recipientNameSnapshot: 'Fulan',
      );

      expect(result.outcome, ProgramSuccessOutcome.persistenceError);
      expect(result.isFailure, isTrue);

      // Verify no achievement was written
      expect(achievementBox.isEmpty, isTrue);
      // Program remains ACTIVE
      final persisted = programBox.get('prog-fail-save');
      expect(persisted?.status, ProgramV2Model.statusActive);
    });

    test(
        '28. Program saved SUCCESS, Achievement write fails -> recoverable retry',
        () async {
      await createProgram(
          id: 'prog-ach-fail', targetDays: 40, startDayKey: '2026-09-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-ach-fail',
        startDayKey: '2026-09-01',
        count: 40,
      );

      achievementRepo.shouldThrowOnSave = true;

      final firstResult = await service.finalizeSuccess(
        programId: 'prog-ach-fail',
        recipientNameSnapshot: 'Fulan',
      );

      expect(firstResult.outcome, ProgramSuccessOutcome.persistenceError);
      // Program was saved as SUCCESS in box
      final programInBox = programBox.get('prog-ach-fail');
      expect(programInBox?.status, ProgramV2Model.statusSuccess);
      expect(achievementBox.isEmpty, isTrue);

      // Now retry with achievement storage working
      achievementRepo.resetOverrides();

      final retryResult = await service.finalizeSuccess(
        programId: 'prog-ach-fail',
        recipientNameSnapshot: 'Fulan',
      );

      expect(retryResult.outcome, ProgramSuccessOutcome.recoveredAchievement);
      expect(retryResult.isRecoveredAchievement, isTrue);
      expect(achievementBox.length, 1);
      final ach = achievementBox
          .get(AchievementV2Repository.buildFinalSuccessId('prog-ach-fail'));
      expect(ach, isNotNull);
      expect(ach?.recipientNameSnapshot, 'Fulan');
    });

    test('29. Achievement saved but response lost -> idempotent retry',
        () async {
      await createProgram(
          id: 'prog-response-lost', targetDays: 40, startDayKey: '2026-09-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-response-lost',
        startDayKey: '2026-09-01',
        count: 40,
      );

      final first = await service.finalizeSuccess(
        programId: 'prog-response-lost',
        recipientNameSnapshot: 'Fulan',
      );
      expect(first.outcome, ProgramSuccessOutcome.finalizedSuccess);

      final retry = await service.finalizeSuccess(
        programId: 'prog-response-lost',
        recipientNameSnapshot: 'Fulan',
      );
      expect(retry.outcome, ProgramSuccessOutcome.alreadyFinalized);
      expect(achievementBox.length, 1);
    });

    test('30. SUCCESS with missing Achievement -> safe recovery', () async {
      // Simulate app restart / crash where program is SUCCESS but achievement missing
      await createProgram(
        id: 'prog-missing-ach',
        targetDays: 40,
        startDayKey: '2026-09-01',
        status: ProgramV2Model.statusSuccess,
        recipientNameSnapshot: 'Fulan',
        finalizedAt: DateTime(2026, 10, 10, 5, 0),
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-missing-ach',
        startDayKey: '2026-09-01',
        count: 40,
      );

      expect(achievementBox.isEmpty, isTrue);

      final result = await service.finalizeSuccess(
        programId: 'prog-missing-ach',
        recipientNameSnapshot: 'Fulan',
      );

      expect(result.outcome, ProgramSuccessOutcome.recoveredAchievement);
      expect(result.isSuccess, isTrue);
      expect(achievementBox.length, 1);
    });

    // -------------------------------------------------------------------------
    // 8. Concurrency, Immutability & Persistence (Tests 31–36)
    // -------------------------------------------------------------------------
    test(
        '31. Existing SUCCESS with changed current profile name -> historical snapshot preserved',
        () async {
      await createProgram(
        id: 'prog-change-profile-name',
        targetDays: 40,
        startDayKey: '2026-09-01',
        status: ProgramV2Model.statusSuccess,
        recipientNameSnapshot: 'Original Historical Name',
        finalizedAt: DateTime(2026, 10, 10, 5, 0),
      );
      final checkIns = await populateConsecutiveCheckIns(
        programId: 'prog-change-profile-name',
        startDayKey: '2026-09-01',
        count: 40,
      );

      final expectedAchId = AchievementV2Repository.buildFinalSuccessId(
          'prog-change-profile-name');
      await achievementBox.put(
        expectedAchId,
        AchievementModel(
          id: expectedAchId,
          programId: 'prog-change-profile-name',
          type: AchievementModel.typeFinalSuccess,
          milestoneDays: 40,
          achievedAt: checkIns.last.checkedAt,
          recipientNameSnapshot: 'Original Historical Name',
          createdAt: DateTime(2026, 10, 10, 5, 0),
        ),
      );

      // Caller passes a new/changed user profile name on retry
      final result = await service.finalizeSuccess(
        programId: 'prog-change-profile-name',
        recipientNameSnapshot: 'Brand New User Name',
      );

      expect(result.outcome, ProgramSuccessOutcome.alreadyFinalized);
      expect(result.program?.recipientNameSnapshot, 'Original Historical Name');
      expect(result.achievement?.recipientNameSnapshot,
          'Original Historical Name');

      final persistedProgram = programBox.get('prog-change-profile-name');
      expect(
          persistedProgram?.recipientNameSnapshot, 'Original Historical Name');
    });

    test(
        '32. Concurrent program snapshot modification -> reject stale transition',
        () async {
      await createProgram(
          id: 'prog-concurrent-stale',
          targetDays: 40,
          startDayKey: '2026-09-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-concurrent-stale',
        startDayKey: '2026-09-01',
        count: 40,
      );

      final original = programBox.get('prog-concurrent-stale')!;

      // On re-read in critical section, simulate that another caller changed targetDays to 60
      programRepo.onGetById = (id, count) {
        if (id == 'prog-concurrent-stale' && count >= 2) {
          return ProgramV2Model(
            id: original.id,
            ibadahId: original.ibadahId,
            ibadahNameSnapshot: original.ibadahNameSnapshot,
            targetDays: 60, // Stale snapshot!
            startDayKey: original.startDayKey,
            status: original.status,
            createdAt: original.createdAt,
            updatedAt: original.updatedAt,
          );
        }
        return null;
      };

      final result = await service.finalizeSuccess(
        programId: 'prog-concurrent-stale',
        recipientNameSnapshot: 'Fulan',
      );

      expect(result.outcome, ProgramSuccessOutcome.dataIntegrityError);
      expect(result.errorMessage,
          contains('Program snapshot changed concurrently'));
    });

    test('33. Finalization requests serialized within one service instance',
        () async {
      await createProgram(
          id: 'prog-concurrent-race',
          targetDays: 40,
          startDayKey: '2026-09-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-concurrent-race',
        startDayKey: '2026-09-01',
        count: 40,
      );

      // Fire 5 concurrent finalization calls
      final results = await Future.wait([
        service.finalizeSuccess(
            programId: 'prog-concurrent-race', recipientNameSnapshot: 'Fulan'),
        service.finalizeSuccess(
            programId: 'prog-concurrent-race', recipientNameSnapshot: 'Fulan'),
        service.finalizeSuccess(
            programId: 'prog-concurrent-race', recipientNameSnapshot: 'Fulan'),
        service.finalizeSuccess(
            programId: 'prog-concurrent-race', recipientNameSnapshot: 'Fulan'),
        service.finalizeSuccess(
            programId: 'prog-concurrent-race', recipientNameSnapshot: 'Fulan'),
      ]);

      // Exactly 1 must be finalizedSuccess, the others must be alreadyFinalized
      final finalizedCount = results
          .where((r) => r.outcome == ProgramSuccessOutcome.finalizedSuccess)
          .length;
      final alreadyCount = results
          .where((r) => r.outcome == ProgramSuccessOutcome.alreadyFinalized)
          .length;

      expect(finalizedCount, 1);
      expect(alreadyCount, 4);
      expect(achievementBox.length, 1);
    });

    test(
        '34. Real temporary Hive box flush/close/reopen preserves SUCCESS and FINAL_SUCCESS',
        () async {
      await createProgram(
          id: 'prog-reopen', targetDays: 40, startDayKey: '2026-09-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-reopen',
        startDayKey: '2026-09-01',
        count: 40,
      );

      final result = await service.finalizeSuccess(
        programId: 'prog-reopen',
        recipientNameSnapshot: 'Rizki Pratama',
      );
      expect(result.outcome, ProgramSuccessOutcome.finalizedSuccess);

      // Flush and close all boxes
      await programBox.flush();
      await achievementBox.flush();
      await programBox.close();
      await achievementBox.close();

      // Reopen boxes from disk
      final reopenedProgramBox =
          await Hive.openBox<ProgramV2Model>('test_programs_box');
      final reopenedAchBox =
          await Hive.openBox<AchievementModel>('test_achievements_box');

      final prog = reopenedProgramBox.get('prog-reopen');
      expect(prog?.status, ProgramV2Model.statusSuccess);
      expect(prog?.recipientNameSnapshot, 'Rizki Pratama');
      expect(prog?.finalizedAt, isNotNull);

      final ach = reopenedAchBox
          .get(AchievementV2Repository.buildFinalSuccessId('prog-reopen'));
      expect(ach?.type, AchievementModel.typeFinalSuccess);
      expect(ach?.milestoneDays, 40);
      expect(ach?.recipientNameSnapshot, 'Rizki Pratama');

      // Reassign back to test variables for tearDown
      programBox = reopenedProgramBox;
      achievementBox = reopenedAchBox;
    });

    test('35. Existing milestone records remain unchanged', () async {
      await createProgram(
          id: 'prog-milestone-preserve',
          targetDays: 40,
          startDayKey: '2026-09-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-milestone-preserve',
        startDayKey: '2026-09-01',
        count: 40,
      );

      // Pre-existing milestone achievement (e.g. Day 10 milestone)
      final milestone = AchievementModel(
        id: 'ach_ms_10_prog-milestone-preserve',
        programId: 'prog-milestone-preserve',
        type: AchievementModel.typeMilestone,
        milestoneDays: 10,
        achievedAt: DateTime(2026, 9, 10, 5, 0),
        recipientNameSnapshot: 'Fulan',
        createdAt: DateTime(2026, 9, 10, 5, 0),
      );
      await achievementBox.put(milestone.id, milestone);

      final result = await service.finalizeSuccess(
        programId: 'prog-milestone-preserve',
        recipientNameSnapshot: 'Fulan',
      );

      expect(result.outcome, ProgramSuccessOutcome.finalizedSuccess);
      expect(achievementBox.length, 2);

      // Verify milestone record was not modified or overwritten
      final persistedMs = achievementBox.get(milestone.id);
      expect(persistedMs?.type, AchievementModel.typeMilestone);
      expect(persistedMs?.milestoneDays, 10);
    });

    test('36. No FailureRecord is created during success finalization',
        () async {
      await createProgram(
          id: 'prog-no-fail-rec', targetDays: 40, startDayKey: '2026-09-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-no-fail-rec',
        startDayKey: '2026-09-01',
        count: 40,
      );

      final result = await service.finalizeSuccess(
        programId: 'prog-no-fail-rec',
        recipientNameSnapshot: 'Fulan',
      );

      expect(result.outcome, ProgramSuccessOutcome.finalizedSuccess);
      expect(failureBox.isEmpty, isTrue);
    });

    test('37. Check-in dayKey preceding startDayKey returns dataIntegrityError',
        () async {
      await createProgram(
          id: 'prog-precede-start', targetDays: 40, startDayKey: '2026-09-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-precede-start',
        startDayKey: '2026-09-01',
        count: 39,
      );

      // Add a check-in for 2026-08-31 (preceding startDayKey)
      final earlyDay = '2026-08-31';
      final id = DailyCheckInV2Repository.buildCheckInId(
          earlyDay, 'prog-precede-start');
      await checkInBox.put(
        id,
        DailyCheckInModel(
          id: id,
          programId: 'prog-precede-start',
          dayKey: earlyDay,
          checkedAt: DateTime(2026, 8, 31, 5, 0, 0),
          createdAt: DateTime(2026, 8, 31, 5, 0, 0),
        ),
      );

      final result = await service.finalizeSuccess(
        programId: 'prog-precede-start',
        recipientNameSnapshot: 'Fulan',
      );

      expect(result.outcome, ProgramSuccessOutcome.dataIntegrityError);
      expect(result.errorMessage, contains('precedes program start'));
    });

    test(
        '38. Program containing conflicting FailureRecord history returns dataIntegrityError',
        () async {
      await createProgram(
          id: 'prog-with-failure-rec',
          targetDays: 40,
          startDayKey: '2026-09-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-with-failure-rec',
        startDayKey: '2026-09-01',
        count: 40,
      );

      // Pre-existing FailureRecord for this program
      final failId = FailureRecordV2Repository.buildFailureRecordId(
          '2026-09-20', 'prog-with-failure-rec');
      await failureBox.put(
        failId,
        FailureRecordModel(
          id: failId,
          programId: 'prog-with-failure-rec',
          missedDayKey: '2026-09-20',
          reasonCode: 'SICK',
          reasonLabelSnapshot: 'Sakit',
          createdAt: DateTime(2026, 9, 21, 5, 0),
        ),
      );

      final result = await service.finalizeSuccess(
        programId: 'prog-with-failure-rec',
        recipientNameSnapshot: 'Fulan',
      );

      expect(result.outcome, ProgramSuccessOutcome.dataIntegrityError);
      expect(
          result.errorMessage, contains('conflicting FailureRecord history'));
    });

    test(
        '39. Check-in records extending beyond target final day return dataIntegrityError',
        () async {
      await createProgram(
          id: 'prog-beyond-target', targetDays: 40, startDayKey: '2026-09-01');
      // 40 days: 2026-09-01 to 2026-10-10
      await populateConsecutiveCheckIns(
        programId: 'prog-beyond-target',
        startDayKey: '2026-09-01',
        count: 40,
      );

      // Add a 41st check-in for 2026-10-11
      final extraDay = '2026-10-11';
      final id = DailyCheckInV2Repository.buildCheckInId(
          extraDay, 'prog-beyond-target');
      await checkInBox.put(
        id,
        DailyCheckInModel(
          id: id,
          programId: 'prog-beyond-target',
          dayKey: extraDay,
          checkedAt: DateTime(2026, 10, 11, 5, 0, 0),
          createdAt: DateTime(2026, 10, 11, 5, 0, 0),
        ),
      );

      final result = await service.finalizeSuccess(
        programId: 'prog-beyond-target',
        recipientNameSnapshot: 'Fulan',
      );

      expect(result.outcome, ProgramSuccessOutcome.dataIntegrityError);
      expect(result.errorMessage,
          contains('extends beyond program target final day'));
    });

    test('40. Month, year, and leap-year transitions succeed', () async {
      // Leap year 2028: Feb 2028 has 29 days!
      // Program starts 2028-02-15 with 40 target days.
      // Days: 15 in Feb (15..29), 25 in March (1..25). 40th day is 2028-03-25.
      await createProgram(
          id: 'prog-leap', targetDays: 40, startDayKey: '2028-02-15');
      final checkIns = await populateConsecutiveCheckIns(
        programId: 'prog-leap',
        startDayKey: '2028-02-15',
        count: 40,
      );

      expect(checkIns.last.dayKey, '2028-03-25');

      final result = await service.finalizeSuccess(
        programId: 'prog-leap',
        recipientNameSnapshot: 'Khabib Nurmagomedov',
        capturedNow: DateTime(2028, 3, 26, 10, 0),
      );

      expect(result.outcome, ProgramSuccessOutcome.finalizedSuccess);
      expect(result.completedDays, 40);
      expect(result.achievement?.achievedAt, checkIns.last.checkedAt);
    });

    test('41. Missing program and invalid program ID return typed failures',
        () async {
      final resEmpty = await service.finalizeSuccess(
        programId: '   ',
        recipientNameSnapshot: 'Fulan',
      );
      expect(resEmpty.outcome, ProgramSuccessOutcome.invalidProgramId);

      final resNotFound = await service.finalizeSuccess(
        programId: 'non-existent-program-id',
        recipientNameSnapshot: 'Fulan',
      );
      expect(resNotFound.outcome, ProgramSuccessOutcome.programNotFound);
    });

    // -------------------------------------------------------------------------
    // 12. R1 Targeted Lifecycle & Snapshot Integrity Regressions (Tests 42–50)
    // -------------------------------------------------------------------------
    test(
        '42. Closed FailureRecord Hive box returns persistenceError and does not mutate state',
        () async {
      await createProgram(
          id: 'prog-failbox-err', targetDays: 40, startDayKey: '2026-09-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-failbox-err',
        startDayKey: '2026-09-01',
        count: 40,
      );

      failureRepo.shouldThrow = true;

      final result = await service.finalizeSuccess(
        programId: 'prog-failbox-err',
        recipientNameSnapshot: 'Fulan',
      );

      expect(result.outcome, ProgramSuccessOutcome.persistenceError);
      expect(result.errorMessage, contains('Storage operation failed'));
      expect(programBox.get('prog-failbox-err')!.status,
          ProgramV2Model.statusActive);
      expect(achievementBox.values.isEmpty, isTrue);
    });

    test(
        '43. SUCCESS recovery with conflicting FailureRecord is rejected with dataIntegrityError',
        () async {
      final now = DateTime(2026, 10, 10, 12, 0);
      await createProgram(
        id: 'prog-succ-rec-fail',
        targetDays: 40,
        startDayKey: '2026-09-01',
        status: ProgramV2Model.statusSuccess,
        finalizedAt: now,
        recipientNameSnapshot: 'Original Recipient',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-succ-rec-fail',
        startDayKey: '2026-09-01',
        count: 40,
      );

      // Pre-existing FailureRecord
      final failId = FailureRecordV2Repository.buildFailureRecordId(
          '2026-09-20', 'prog-succ-rec-fail');
      await failureBox.put(
        failId,
        FailureRecordModel(
          id: failId,
          programId: 'prog-succ-rec-fail',
          missedDayKey: '2026-09-20',
          reasonCode: 'SICK',
          reasonLabelSnapshot: 'Sakit',
          createdAt: DateTime(2026, 9, 21, 5, 0),
        ),
      );

      final result = await service.finalizeSuccess(
        programId: 'prog-succ-rec-fail',
        recipientNameSnapshot: 'Original Recipient',
      );

      expect(result.outcome, ProgramSuccessOutcome.dataIntegrityError);
      expect(
          result.errorMessage, contains('conflicting FailureRecord history'));
      expect(achievementBox.values.isEmpty, isTrue);
    });

    test(
        '44. Re-read Program with newly populated pendingMissedDayKey returns dataIntegrityError and aborts write',
        () async {
      await createProgram(
          id: 'prog-reread-pmd', targetDays: 40, startDayKey: '2026-09-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-reread-pmd',
        startDayKey: '2026-09-01',
        count: 40,
      );

      programRepo.onGetById = (id, count) {
        if (id == 'prog-reread-pmd' && count == 2) {
          final original = programBox.get(id)!;
          return ProgramV2Model(
            id: original.id,
            ibadahId: original.ibadahId,
            ibadahNameSnapshot: original.ibadahNameSnapshot,
            targetDays: original.targetDays,
            startDayKey: original.startDayKey,
            status: original.status,
            createdAt: original.createdAt,
            updatedAt: original.updatedAt,
            pendingMissedDayKey: '2026-09-20',
          );
        }
        return null;
      };

      final result = await service.finalizeSuccess(
        programId: 'prog-reread-pmd',
        recipientNameSnapshot: 'Fulan',
      );

      expect(result.outcome, ProgramSuccessOutcome.dataIntegrityError);
      expect(programBox.get('prog-reread-pmd')!.status,
          ProgramV2Model.statusActive);
      expect(achievementBox.values.isEmpty, isTrue);
    });

    test(
        '45. Re-read Program with unexpected finalizedAt returns dataIntegrityError and aborts write',
        () async {
      await createProgram(
          id: 'prog-reread-fin', targetDays: 40, startDayKey: '2026-09-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-reread-fin',
        startDayKey: '2026-09-01',
        count: 40,
      );

      programRepo.onGetById = (id, count) {
        if (id == 'prog-reread-fin' && count == 2) {
          final original = programBox.get(id)!;
          return ProgramV2Model(
            id: original.id,
            ibadahId: original.ibadahId,
            ibadahNameSnapshot: original.ibadahNameSnapshot,
            targetDays: original.targetDays,
            startDayKey: original.startDayKey,
            status: original.status,
            createdAt: original.createdAt,
            updatedAt: original.updatedAt,
            finalizedAt: DateTime(2026, 10, 10),
          );
        }
        return null;
      };

      final result = await service.finalizeSuccess(
        programId: 'prog-reread-fin',
        recipientNameSnapshot: 'Fulan',
      );

      expect(result.outcome, ProgramSuccessOutcome.dataIntegrityError);
      expect(programBox.get('prog-reread-fin')!.status,
          ProgramV2Model.statusActive);
      expect(achievementBox.values.isEmpty, isTrue);
    });

    test(
        '46. Re-read Program with changed recipientNameSnapshot returns dataIntegrityError and aborts write',
        () async {
      await createProgram(
          id: 'prog-reread-rec', targetDays: 40, startDayKey: '2026-09-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-reread-rec',
        startDayKey: '2026-09-01',
        count: 40,
      );

      programRepo.onGetById = (id, count) {
        if (id == 'prog-reread-rec' && count == 2) {
          final original = programBox.get(id)!;
          return ProgramV2Model(
            id: original.id,
            ibadahId: original.ibadahId,
            ibadahNameSnapshot: original.ibadahNameSnapshot,
            targetDays: original.targetDays,
            startDayKey: original.startDayKey,
            status: original.status,
            createdAt: original.createdAt,
            updatedAt: original.updatedAt,
            recipientNameSnapshot: 'Changed Recipient',
          );
        }
        return null;
      };

      final result = await service.finalizeSuccess(
        programId: 'prog-reread-rec',
        recipientNameSnapshot: 'Fulan',
      );

      expect(result.outcome, ProgramSuccessOutcome.dataIntegrityError);
      expect(result.errorMessage, contains('snapshot changed concurrently'));
      expect(programBox.get('prog-reread-rec')!.status,
          ProgramV2Model.statusActive);
      expect(achievementBox.values.isEmpty, isTrue);
    });

    test(
        '47. Re-read Program with changed ibadahNameSnapshot returns dataIntegrityError and aborts write',
        () async {
      await createProgram(
          id: 'prog-reread-ibd', targetDays: 40, startDayKey: '2026-09-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-reread-ibd',
        startDayKey: '2026-09-01',
        count: 40,
      );

      programRepo.onGetById = (id, count) {
        if (id == 'prog-reread-ibd' && count == 2) {
          final original = programBox.get(id)!;
          return ProgramV2Model(
            id: original.id,
            ibadahId: original.ibadahId,
            ibadahNameSnapshot: 'Changed Ibadah Name',
            targetDays: original.targetDays,
            startDayKey: original.startDayKey,
            status: original.status,
            createdAt: original.createdAt,
            updatedAt: original.updatedAt,
          );
        }
        return null;
      };

      final result = await service.finalizeSuccess(
        programId: 'prog-reread-ibd',
        recipientNameSnapshot: 'Fulan',
      );

      expect(result.outcome, ProgramSuccessOutcome.dataIntegrityError);
      expect(result.errorMessage, contains('snapshot changed concurrently'));
      expect(programBox.get('prog-reread-ibd')!.status,
          ProgramV2Model.statusActive);
      expect(achievementBox.values.isEmpty, isTrue);
    });

    test('48. Unchanged valid Program re-read finalization succeeds', () async {
      await createProgram(
          id: 'prog-reread-valid', targetDays: 40, startDayKey: '2026-09-01');
      await populateConsecutiveCheckIns(
        programId: 'prog-reread-valid',
        startDayKey: '2026-09-01',
        count: 40,
      );

      int reReadCount = 0;
      programRepo.onGetById = (id, count) {
        if (count == 2) {
          reReadCount++;
        }
        return null; // Passthrough to box
      };

      final result = await service.finalizeSuccess(
        programId: 'prog-reread-valid',
        recipientNameSnapshot: 'Fulan',
      );

      expect(result.outcome, ProgramSuccessOutcome.finalizedSuccess);
      expect(reReadCount, 1);
      expect(programBox.get('prog-reread-valid')!.status,
          ProgramV2Model.statusSuccess);
      expect(achievementBox.values.length, 1);
    });

    test(
        '49. SUCCESS with pendingMissedDayKey and existing Achievement returns dataIntegrityError',
        () async {
      final now = DateTime(2026, 10, 10, 12, 0);
      await createProgram(
        id: 'prog-succ-pmd-ach',
        targetDays: 40,
        startDayKey: '2026-09-01',
        status: ProgramV2Model.statusSuccess,
        finalizedAt: now,
        recipientNameSnapshot: 'Fulan',
        pendingMissedDayKey: '2026-09-20', // Inconsistent!
      );
      final checkIns = await populateConsecutiveCheckIns(
        programId: 'prog-succ-pmd-ach',
        startDayKey: '2026-09-01',
        count: 40,
      );

      final achId =
          AchievementV2Repository.buildFinalSuccessId('prog-succ-pmd-ach');
      await achievementBox.put(
        achId,
        AchievementModel(
          id: achId,
          programId: 'prog-succ-pmd-ach',
          type: AchievementModel.typeFinalSuccess,
          milestoneDays: 40,
          achievedAt: checkIns.last.checkedAt,
          recipientNameSnapshot: 'Fulan',
          createdAt: now,
        ),
      );

      final result = await service.finalizeSuccess(
        programId: 'prog-succ-pmd-ach',
        recipientNameSnapshot: 'Fulan',
      );

      expect(result.outcome, ProgramSuccessOutcome.dataIntegrityError);
      expect(result.errorMessage, contains('inconsistent pendingMissedDayKey'));
      // Program field not repaired or overwritten
      expect(programBox.get('prog-succ-pmd-ach')!.pendingMissedDayKey,
          '2026-09-20');
    });

    test(
        '50. SUCCESS with pendingMissedDayKey and missing Achievement returns dataIntegrityError without writing Achievement',
        () async {
      final now = DateTime(2026, 10, 10, 12, 0);
      await createProgram(
        id: 'prog-succ-pmd-noach',
        targetDays: 40,
        startDayKey: '2026-09-01',
        status: ProgramV2Model.statusSuccess,
        finalizedAt: now,
        recipientNameSnapshot: 'Fulan',
        pendingMissedDayKey: '2026-09-20', // Inconsistent!
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-succ-pmd-noach',
        startDayKey: '2026-09-01',
        count: 40,
      );

      final result = await service.finalizeSuccess(
        programId: 'prog-succ-pmd-noach',
        recipientNameSnapshot: 'Fulan',
      );

      expect(result.outcome, ProgramSuccessOutcome.dataIntegrityError);
      expect(result.errorMessage, contains('inconsistent pendingMissedDayKey'));
      expect(achievementBox.values.isEmpty,
          isTrue); // No achievement recovered or written
    });
  });
}
