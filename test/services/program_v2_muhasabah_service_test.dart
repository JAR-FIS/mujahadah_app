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
import 'package:mujahadah/repositories/failure_record_v2_repository.dart';
import 'package:mujahadah/repositories/program_v2_repository.dart';
import 'package:mujahadah/services/program_v2_muhasabah_service.dart';

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

class _NoncanonicalKeyFailureRecordModel extends FailureRecordModel {
  final dynamic _customKey;

  _NoncanonicalKeyFailureRecordModel({
    required super.id,
    required super.programId,
    required super.missedDayKey,
    required super.reasonCode,
    required super.reasonLabelSnapshot,
    required super.createdAt,
    dynamic customKey,
  }) : _customKey = customKey;

  @override
  dynamic get key => _customKey;
}

/// Test repository that can simulate storage failures on FailureRecord operations.
class FailingFailureRecordV2Repository extends FailureRecordV2Repository {
  bool shouldThrowOnSave = false;
  bool throwAfterSave = false;
  FailureRecordModel? Function(String id, int callCount)? onGetById;
  List<FailureRecordModel>? Function(String programId, String missedDayKey)?
      onGetRecordsForInterruption;
  List<FailureRecordModel>? Function(String programId)? onGetByProgramId;
  bool returnNullOnGetById = false;
  final Map<String, int> _getByIdCallCounts = {};

  FailingFailureRecordV2Repository({required super.box});

  @override
  FailureRecordModel? getById(String id) {
    final count = (_getByIdCallCounts[id] ?? 0) + 1;
    _getByIdCallCounts[id] = count;
    if (returnNullOnGetById) {
      return null;
    }
    if (onGetById != null) {
      final override = onGetById!(id, count);
      if (override != null) {
        return override;
      }
    }
    return super.getById(id);
  }

  @override
  List<FailureRecordModel> getRecordsForInterruption(
    String programId,
    String missedDayKey,
  ) {
    if (onGetRecordsForInterruption != null) {
      final override = onGetRecordsForInterruption!(programId, missedDayKey);
      if (override != null) {
        return override;
      }
    }
    return super.getRecordsForInterruption(programId, missedDayKey);
  }

  @override
  List<FailureRecordModel> getByProgramId(String programId) {
    if (onGetByProgramId != null) {
      final override = onGetByProgramId!(programId);
      if (override != null) {
        return override;
      }
    }
    return super.getByProgramId(programId);
  }

  @override
  Future<void> save(FailureRecordModel failureRecord) async {
    if (shouldThrowOnSave) {
      throw HiveError('Simulated disk I/O write failure on FailureRecord');
    }
    await super.save(failureRecord);
    if (throwAfterSave) {
      throw HiveError('Simulated crash after FailureRecord write completed');
    }
  }

  void resetOverrides() {
    shouldThrowOnSave = false;
    throwAfterSave = false;
    onGetById = null;
    onGetRecordsForInterruption = null;
    onGetByProgramId = null;
    returnNullOnGetById = false;
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
  late FailingFailureRecordV2Repository failureRepo;
  late DateService dateService;
  late ProgramV2MuhasabahService service;

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
    tempDir = Directory.systemTemp.createTempSync('program_v2_muhasabah_test_');
    Hive.init(tempDir.path);
    programBox = await Hive.openBox<ProgramV2Model>('test_programs_box');
    checkInBox = await Hive.openBox<DailyCheckInModel>('test_checkins_box');
    failureBox = await Hive.openBox<FailureRecordModel>('test_failures_box');

    programRepo = FailingProgramV2Repository(box: programBox);
    checkInRepo = DailyCheckInV2Repository(box: checkInBox);
    failureRepo = FailingFailureRecordV2Repository(box: failureBox);

    // Default clock: 2026-10-25 05:00:00 (operational day: 2026-10-25)
    dateService = DateService(
      nowProvider: () => DateTime(2026, 10, 25, 5, 0, 0),
    );

    service = ProgramV2MuhasabahService(
      programRepository: programRepo,
      checkInRepository: checkInRepo,
      failureRecordRepository: failureRepo,
      dateService: dateService,
    );
  });

  tearDown(() async {
    programRepo.resetOverrides();
    failureRepo.resetOverrides();
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
    String startDayKey = '2026-09-01',
    String status = ProgramV2Model.statusPendingFailure,
    String? reminderTime,
    String? restartedFromProgramId,
    String? recipientNameSnapshot,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? finalizedAt,
    String? pendingMissedDayKey = '2026-09-10',
  }) async {
    final created = createdAt ?? DateTime(2026, 9, 1, 4, 0);
    final updated = updatedAt ?? DateTime(2026, 9, 11, 4, 0);

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
    final timestamp = checkedAt ?? DateTime(2026, 9, 1, 5, 0);
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

  /// Helper to populate consecutive valid check-ins starting from [startDayKey]
  Future<void> populateConsecutiveCheckIns({
    required String programId,
    required String startDayKey,
    required int count,
  }) async {
    var cur = DateTime.parse(startDayKey);
    for (int i = 0; i < count; i++) {
      final dayKey = DateService.formatCalendarDayKey(cur);
      await createCheckIn(
        programId: programId,
        dayKey: dayKey,
        checkedAt: DateTime(cur.year, cur.month, cur.day, 5, 0),
      );
      cur = cur.add(const Duration(days: 1));
    }
  }

  group('Program V2 Muhasabah & Failure Finalization Service', () {
    test('1. PENDING_FAILURE with valid reason (<40 days completed) -> FAILED',
        () async {
      await createProgram(
        id: 'prog-fail-1',
        targetDays: 40,
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-10', // missed day 10
      );
      // 9 consecutive check-ins (days 1..9)
      await populateConsecutiveCheckIns(
        programId: 'prog-fail-1',
        startDayKey: '2026-09-01',
        count: 9,
      );

      final result = await service.finalizeFailure(
        programId: 'prog-fail-1',
        reasonCode: 'OVERTIRED',
        reasonLabelSnapshot: 'Terlalu lelah / tertidur',
        note: 'Lembur pekerjaan',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.failedCreated);
      expect(result.isSuccess, isTrue);
      expect(result.isFailedCreated, isTrue);
      expect(result.finalStatus, ProgramV2Model.statusFailed);
      expect(result.completedDays, 9);
      expect(result.failureRecord, isNotNull);
      expect(result.failureRecord!.reasonCode, 'OVERTIRED');
      expect(result.failureRecord!.note, 'Lembur pekerjaan');

      // Verify persisted state
      final persistedProg = programRepo.getById('prog-fail-1')!;
      expect(persistedProg.status, ProgramV2Model.statusFailed);
      expect(persistedProg.finalizedAt, isNotNull);
      expect(persistedProg.pendingMissedDayKey, '2026-09-10');

      final expectedFailId = FailureRecordV2Repository.buildFailureRecordId(
          '2026-09-10', 'prog-fail-1');
      final persistedFail = failureRepo.getById(expectedFailId)!;
      expect(persistedFail.id, expectedFailId);
      expect(persistedFail.programId, 'prog-fail-1');
      expect(persistedFail.missedDayKey, '2026-09-10');
      expect(persistedFail.reasonCode, 'OVERTIRED');
    });

    test(
        '2. PENDING_FAILURE with valid reason (>=40 days before target) -> WARNING',
        () async {
      await createProgram(
        id: 'prog-warn-1',
        targetDays: 60,
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-10-15', // Day 45
      );
      // 44 consecutive check-ins
      await populateConsecutiveCheckIns(
        programId: 'prog-warn-1',
        startDayKey: '2026-09-01',
        count: 44,
      );

      final result = await service.finalizeFailure(
        programId: 'prog-warn-1',
        reasonCode: 'TRAVELING',
        reasonLabelSnapshot: 'Sedang dalam perjalanan (Safar)',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.warningCreated);
      expect(result.isSuccess, isTrue);
      expect(result.isWarningCreated, isTrue);
      expect(result.finalStatus, ProgramV2Model.statusWarning);
      expect(result.completedDays, 44);

      final persistedProg = programRepo.getById('prog-warn-1')!;
      expect(persistedProg.status, ProgramV2Model.statusWarning);
    });

    test('3. Exact 39-day threshold -> FAILED', () async {
      await createProgram(
        id: 'prog-thresh-39',
        targetDays: 60,
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-10-10', // Day 40
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-thresh-39',
        startDayKey: '2026-09-01',
        count: 39,
      );

      final result = await service.finalizeFailure(
        programId: 'prog-thresh-39',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.failedCreated);
      expect(result.finalStatus, ProgramV2Model.statusFailed);
      expect(result.completedDays, 39);
    });

    test('4. Exact 40-day threshold before a later target -> WARNING',
        () async {
      await createProgram(
        id: 'prog-thresh-40',
        targetDays: 60,
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-10-11', // Day 41
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-thresh-40',
        startDayKey: '2026-09-01',
        count: 40,
      );

      final result = await service.finalizeFailure(
        programId: 'prog-thresh-40',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.warningCreated);
      expect(result.finalStatus, ProgramV2Model.statusWarning);
      expect(result.completedDays, 40);
    });

    test('5. Completed target 40/40 never becomes FAILED or WARNING', () async {
      await createProgram(
        id: 'prog-completed-40',
        targetDays: 40,
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-10-11', // claims day 41 missed
      );
      // All 40 target days completed
      await populateConsecutiveCheckIns(
        programId: 'prog-completed-40',
        startDayKey: '2026-09-01',
        count: 40,
      );

      final result = await service.finalizeFailure(
        programId: 'prog-completed-40',
        reasonCode: 'FORGOT',
        reasonLabelSnapshot: 'Lupa',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.dataIntegrityError);
      expect(result.isFailure, isTrue);
      expect(result.errorMessage,
          contains('Target duration (40 days) was completed'));

      final persisted = programRepo.getById('prog-completed-40')!;
      expect(persisted.status, ProgramV2Model.statusPendingFailure);
      expect(failureBox.isEmpty, isTrue);
    });

    test(
        '6. Completed custom target (e.g. 60/60) never becomes FAILED or WARNING',
        () async {
      await createProgram(
        id: 'prog-completed-60',
        targetDays: 60,
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-10-31',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-completed-60',
        startDayKey: '2026-09-01',
        count: 60,
      );

      final result = await service.finalizeFailure(
        programId: 'prog-completed-60',
        reasonCode: 'FORGOT',
        reasonLabelSnapshot: 'Lupa',
        capturedNow: DateTime(2026, 11, 2, 5, 0),
      );

      expect(result.outcome, ProgramMuhasabahOutcome.dataIntegrityError);
      expect(result.isFailure, isTrue);
      expect(result.errorMessage,
          contains('Target duration (60 days) was completed'));
    });

    test('7. Empty reasonCode rejected with invalidReason', () async {
      await createProgram(id: 'prog-empty-code');

      final result = await service.finalizeFailure(
        programId: 'prog-empty-code',
        reasonCode: '',
        reasonLabelSnapshot: 'Terlalu lelah',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.invalidReason);
      expect(result.isFailure, isTrue);
      expect(failureBox.isEmpty, isTrue);
    });

    test('8. Whitespace reasonCode rejected with invalidReason', () async {
      await createProgram(id: 'prog-ws-code');

      final result = await service.finalizeFailure(
        programId: 'prog-ws-code',
        reasonCode: '   ',
        reasonLabelSnapshot: 'Terlalu lelah',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.invalidReason);
      expect(result.isFailure, isTrue);
      expect(failureBox.isEmpty, isTrue);
    });

    test('9. Empty reasonLabelSnapshot rejected with invalidReason', () async {
      await createProgram(id: 'prog-empty-label');

      final result = await service.finalizeFailure(
        programId: 'prog-empty-label',
        reasonCode: 'OVERTIRED',
        reasonLabelSnapshot: '   ',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.invalidReason);
      expect(result.isFailure, isTrue);
      expect(failureBox.isEmpty, isTrue);
    });

    test('10. Optional note is safely stored and null note preserved',
        () async {
      await createProgram(
        id: 'prog-note-test',
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-note-test',
        startDayKey: '2026-09-01',
        count: 4,
      );

      final result = await service.finalizeFailure(
        programId: 'prog-note-test',
        reasonCode: 'OTHER',
        reasonLabelSnapshot: 'Lainnya',
        note: '  Catatan khusus jamaah  ',
      );

      expect(result.isSuccess, isTrue);
      expect(result.failureRecord!.note, 'Catatan khusus jamaah');
    });

    test('11. FailureRecord contains correct programId and missedDayKey',
        () async {
      await createProgram(
        id: 'prog-fields-test',
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-fields-test',
        startDayKey: '2026-09-01',
        count: 4,
      );

      final result = await service.finalizeFailure(
        programId: 'prog-fields-test',
        reasonCode: 'BUSY',
        reasonLabelSnapshot: 'Sibuk',
      );

      expect(result.isSuccess, isTrue);
      final record = result.failureRecord!;
      expect(record.programId, 'prog-fields-test');
      expect(record.missedDayKey, '2026-09-05');
      expect(record.id, 'fail_2026-09-05_prog-fields-test');
    });

    test('12. FailureRecord createdAt is preserved from captured instant',
        () async {
      await createProgram(
        id: 'prog-createdat-test',
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-createdat-test',
        startDayKey: '2026-09-01',
        count: 4,
      );

      final customInstant = DateTime(2026, 10, 20, 14, 30, 0);
      final result = await service.finalizeFailure(
        programId: 'prog-createdat-test',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
        capturedNow: customInstant,
      );

      expect(result.isSuccess, isTrue);
      expect(result.failureRecord!.createdAt, customInstant);
    });

    test('13. Program finalizedAt and updatedAt are correctly assigned',
        () async {
      await createProgram(
        id: 'prog-timestamps-test',
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-timestamps-test',
        startDayKey: '2026-09-01',
        count: 4,
      );

      final customInstant = DateTime(2026, 10, 20, 15, 0, 0);
      final result = await service.finalizeFailure(
        programId: 'prog-timestamps-test',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
        capturedNow: customInstant,
      );

      expect(result.isSuccess, isTrue);
      final prog = programRepo.getById('prog-timestamps-test')!;
      expect(prog.finalizedAt, customInstant);
      expect(prog.updatedAt, customInstant);
    });

    test('14. All unrelated Program fields are preserved intact', () async {
      final initialCreated = DateTime(2026, 8, 20, 10, 0);
      await createProgram(
        id: 'prog-preserve-fields',
        ibadahId: 'ibd-witir',
        ibadahName: 'Shalat Witir',
        targetDays: 50,
        startDayKey: '2026-09-01',
        reminderTime: '21:30',
        restartedFromProgramId: 'prog-ancestor',
        recipientNameSnapshot: 'Hamba Allah',
        createdAt: initialCreated,
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-preserve-fields',
        startDayKey: '2026-09-01',
        count: 4,
      );

      final result = await service.finalizeFailure(
        programId: 'prog-preserve-fields',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result.isSuccess, isTrue);
      final p = programRepo.getById('prog-preserve-fields')!;
      expect(p.id, 'prog-preserve-fields');
      expect(p.ibadahId, 'ibd-witir');
      expect(p.ibadahNameSnapshot, 'Shalat Witir');
      expect(p.targetDays, 50);
      expect(p.startDayKey, '2026-09-01');
      expect(p.reminderTime, '21:30');
      expect(p.restartedFromProgramId, 'prog-ancestor');
      expect(p.recipientNameSnapshot, 'Hamba Allah');
      expect(p.createdAt, initialCreated);
      expect(p.pendingMissedDayKey, '2026-09-05');
    });

    test('15. Existing DailyCheckIn history remains unchanged', () async {
      await createProgram(
        id: 'prog-checkin-untouched',
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-checkin-untouched',
        startDayKey: '2026-09-01',
        count: 4,
      );
      expect(checkInBox.length, 4);

      final result = await service.finalizeFailure(
        programId: 'prog-checkin-untouched',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result.isSuccess, isTrue);
      expect(checkInBox.length, 4);
      final checkIns = checkInRepo.getByProgramId('prog-checkin-untouched');
      expect(checkIns.length, 4);
    });

    test('16. Repeated submission creates no duplicate FailureRecord',
        () async {
      await createProgram(
        id: 'prog-idempotent-repeat',
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-idempotent-repeat',
        startDayKey: '2026-09-01',
        count: 4,
      );

      final result1 = await service.finalizeFailure(
        programId: 'prog-idempotent-repeat',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );
      expect(result1.isFailedCreated, isTrue);
      expect(failureBox.length, 1);

      // Repeat with identical reason
      final result2 = await service.finalizeFailure(
        programId: 'prog-idempotent-repeat',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );
      expect(result2.isAlreadyFinalized, isTrue);
      expect(result2.isSuccess, isTrue);
      expect(failureBox.length, 1);
    });

    test('17. Conflicting repeated reason is rejected with reasonConflict',
        () async {
      await createProgram(
        id: 'prog-conflict-reason',
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-conflict-reason',
        startDayKey: '2026-09-01',
        count: 4,
      );

      await service.finalizeFailure(
        programId: 'prog-conflict-reason',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      // Submit conflicting reason code
      final resultConflict = await service.finalizeFailure(
        programId: 'prog-conflict-reason',
        reasonCode: 'TRAVELING',
        reasonLabelSnapshot: 'Safar',
      );

      expect(resultConflict.outcome, ProgramMuhasabahOutcome.reasonConflict);
      expect(resultConflict.isFailure, isTrue);
      expect(
          resultConflict.errorMessage, contains('Conflicting failure reason'));
      expect(failureBox.get('fail_2026-09-05_prog-conflict-reason')!.reasonCode,
          'SICK');
    });

    test(
        '18. First write fails: program remains pending and no failure record persisted',
        () async {
      await createProgram(
        id: 'prog-first-write-fail',
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-first-write-fail',
        startDayKey: '2026-09-01',
        count: 4,
      );

      failureRepo.shouldThrowOnSave = true;

      final result = await service.finalizeFailure(
        programId: 'prog-first-write-fail',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.persistenceError);
      expect(result.isFailure, isTrue);

      final p = programRepo.getById('prog-first-write-fail')!;
      expect(p.status, ProgramV2Model.statusPendingFailure);
      expect(failureBox.isEmpty, isTrue);
    });

    test(
        '19. FailureRecord written, Program write fails: recoverable retry succeeds',
        () async {
      await createProgram(
        id: 'prog-two-box-recovery',
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-two-box-recovery',
        startDayKey: '2026-09-01',
        count: 4,
      );

      // Simulate failure on Program save only
      programRepo.shouldThrowOnSave = true;

      final result1 = await service.finalizeFailure(
        programId: 'prog-two-box-recovery',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result1.outcome, ProgramMuhasabahOutcome.persistenceError);
      expect(result1.isFailure, isTrue);

      // Failure record was saved
      expect(failureBox.length, 1);
      final p1 = programRepo.getById('prog-two-box-recovery')!;
      expect(p1.status, ProgramV2Model.statusPendingFailure);

      // Clear failure and retry
      programRepo.shouldThrowOnSave = false;

      final result2 = await service.finalizeFailure(
        programId: 'prog-two-box-recovery',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result2.outcome, ProgramMuhasabahOutcome.failedCreated);
      expect(result2.isSuccess, isTrue);
      // No duplicate record created
      expect(failureBox.length, 1);
      final p2 = programRepo.getById('prog-two-box-recovery')!;
      expect(p2.status, ProgramV2Model.statusFailed);
    });

    test(
        '20. Program write succeeds but throws (uncertain write): idempotent retry succeeds',
        () async {
      await createProgram(
        id: 'prog-uncertain-write',
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-uncertain-write',
        startDayKey: '2026-09-01',
        count: 4,
      );

      // Simulate crash immediately after Program write completed
      programRepo.throwAfterSave = true;

      final result1 = await service.finalizeFailure(
        programId: 'prog-uncertain-write',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result1.outcome, ProgramMuhasabahOutcome.persistenceError);
      expect(result1.isFailure, isTrue);

      programRepo.throwAfterSave = false;

      final result2 = await service.finalizeFailure(
        programId: 'prog-uncertain-write',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result2.outcome, ProgramMuhasabahOutcome.alreadyFinalized);
      expect(result2.isSuccess, isTrue);
      expect(result2.finalStatus, ProgramV2Model.statusFailed);
      expect(failureBox.length, 1);
    });

    test(
        '21. Hive flush/close/reopen preserves final program and FailureRecord',
        () async {
      await createProgram(
        id: 'prog-reopen-test',
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-reopen-test',
        startDayKey: '2026-09-01',
        count: 4,
      );

      await service.finalizeFailure(
        programId: 'prog-reopen-test',
        reasonCode: 'OVERTIRED',
        reasonLabelSnapshot: 'Terlalu lelah',
      );

      // Flush, close all boxes
      await programBox.flush();
      await failureBox.flush();
      await programBox.close();
      await failureBox.close();

      // Reopen
      final reopenedProgBox =
          await Hive.openBox<ProgramV2Model>('test_programs_box');
      final reopenedFailBox =
          await Hive.openBox<FailureRecordModel>('test_failures_box');

      final p = reopenedProgBox.get('prog-reopen-test')!;
      expect(p.status, ProgramV2Model.statusFailed);

      final f = reopenedFailBox.get('fail_2026-09-05_prog-reopen-test')!;
      expect(f.reasonCode, 'OVERTIRED');

      await reopenedProgBox.close();
      await reopenedFailBox.close();
    });

    test(
        '22. ACTIVE and SUCCESS status reject failure finalization with programNotPending',
        () async {
      await createProgram(
        id: 'prog-active-reject',
        status: ProgramV2Model.statusActive,
      );
      final activeResult = await service.finalizeFailure(
        programId: 'prog-active-reject',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );
      expect(activeResult.outcome, ProgramMuhasabahOutcome.programNotPending);
      expect(activeResult.isFailure, isTrue);

      await createProgram(
        id: 'prog-success-reject',
        status: ProgramV2Model.statusSuccess,
      );
      final successResult = await service.finalizeFailure(
        programId: 'prog-success-reject',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );
      expect(successResult.outcome, ProgramMuhasabahOutcome.programNotPending);
      expect(successResult.isFailure, isTrue);
    });

    test('23. Invalid or future pendingMissedDayKey returns dataIntegrityError',
        () async {
      // Missing pendingMissedDayKey
      await createProgram(
        id: 'prog-null-missed',
        pendingMissedDayKey: null,
      );
      final nullResult = await service.finalizeFailure(
        programId: 'prog-null-missed',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );
      expect(nullResult.outcome, ProgramMuhasabahOutcome.dataIntegrityError);

      // Malformed date
      await createProgram(
        id: 'prog-bad-missed',
        pendingMissedDayKey: 'invalid-date',
      );
      final badResult = await service.finalizeFailure(
        programId: 'prog-bad-missed',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );
      expect(badResult.outcome, ProgramMuhasabahOutcome.dataIntegrityError);

      // Precedes startDayKey
      await createProgram(
        id: 'prog-precede-missed',
        startDayKey: '2026-09-10',
        pendingMissedDayKey: '2026-09-05',
      );
      final precedeResult = await service.finalizeFailure(
        programId: 'prog-precede-missed',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );
      expect(precedeResult.outcome, ProgramMuhasabahOutcome.dataIntegrityError);

      // Future/open operational day (clock is 2026-10-25 05:00)
      await createProgram(
        id: 'prog-future-missed',
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-10-25', // Today is not closed
      );
      final futureResult = await service.finalizeFailure(
        programId: 'prog-future-missed',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );
      expect(futureResult.outcome, ProgramMuhasabahOutcome.dataIntegrityError);
    });

    test('24. Corrupted Program storage identity returns dataIntegrityError',
        () async {
      final corrupt = ProgramV2Model(
        id: 'underlying-id',
        ibadahId: 'ibd-tahajjud',
        ibadahNameSnapshot: 'Shalat Tahajjud',
        targetDays: 40,
        startDayKey: '2026-09-01',
        status: ProgramV2Model.statusPendingFailure,
        pendingMissedDayKey: '2026-09-05',
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      );
      await programBox.put('wrong-box-key', corrupt);

      final result = await service.finalizeFailure(
        programId: 'wrong-box-key',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.dataIntegrityError);
      expect(result.isFailure, isTrue);
      expect(result.errorMessage, contains('storage key identity mismatch'));
    });

    test(
        '25. Corrupted FailureRecord storage identity returns dataIntegrityError',
        () async {
      await createProgram(
        id: 'prog-corrupt-fail-key',
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-corrupt-fail-key',
        startDayKey: '2026-09-01',
        count: 4,
      );

      // Put anomalous failure record at canonical key with conflicting id
      final corruptRecord = FailureRecordModel(
        id: 'conflicting-id',
        programId: 'other-prog',
        missedDayKey: '2026-09-05',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
        createdAt: DateTime(2026, 9, 5),
      );
      await failureBox.put(
          'fail_2026-09-05_prog-corrupt-fail-key', corruptRecord);

      final result = await service.finalizeFailure(
        programId: 'prog-corrupt-fail-key',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.dataIntegrityError);
      expect(result.isFailure, isTrue);
    });

    test(
        '26. Nonconsecutive / duplicate DailyCheckIn records return dataIntegrityError',
        () async {
      await createProgram(
        id: 'prog-gap-checkins',
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05', // expects 4 days: 1, 2, 3, 4
      );

      // Only check in days 1, 2, 4 (day 3 missing)
      await createCheckIn(programId: 'prog-gap-checkins', dayKey: '2026-09-01');
      await createCheckIn(programId: 'prog-gap-checkins', dayKey: '2026-09-02');
      await createCheckIn(programId: 'prog-gap-checkins', dayKey: '2026-09-04');

      final result = await service.finalizeFailure(
        programId: 'prog-gap-checkins',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.dataIntegrityError);
      expect(result.isFailure, isTrue);
      expect(result.errorMessage, contains('integrity anomalies or gaps'));
    });

    test('27. Long offline delay does not change failure classification',
        () async {
      await createProgram(
        id: 'prog-long-offline',
        startDayKey: '2026-08-01',
        pendingMissedDayKey: '2026-08-11', // Day 11 missed
      );
      // 10 consecutive check-ins (days 1..10)
      await populateConsecutiveCheckIns(
        programId: 'prog-long-offline',
        startDayKey: '2026-08-01',
        count: 10,
      );

      // Submitting 2 months later (2026-10-25)
      final result = await service.finalizeFailure(
        programId: 'prog-long-offline',
        reasonCode: 'FORGOT',
        reasonLabelSnapshot: 'Lupa',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.failedCreated);
      expect(result.finalStatus, ProgramV2Model.statusFailed);
      expect(result.completedDays, 10);
    });

    test('28. Boundary dates and operational 03:00 boundary', () async {
      await createProgram(
        id: 'prog-nye-boundary',
        startDayKey: '2026-12-31',
        pendingMissedDayKey: '2026-12-31', // Day 1 missed
      );

      // 2027-01-01 02:59:59.999 is still within operational day 2026-12-31
      final preCutoff = DateTime(2027, 1, 1, 2, 59, 59, 999);
      final preResult = await service.finalizeFailure(
        programId: 'prog-nye-boundary',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
        capturedNow: preCutoff,
      );
      // At preCutoff, operational day 2026-12-31 has not closed yet!
      expect(preResult.outcome, ProgramMuhasabahOutcome.dataIntegrityError);
      expect(preResult.errorMessage, contains('not a closed operational day'));

      // 2027-01-01 03:00:00.000 crosses boundary; 2026-12-31 is now closed
      final postCutoff = DateTime(2027, 1, 1, 3, 0, 0, 0);
      final postResult = await service.finalizeFailure(
        programId: 'prog-nye-boundary',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
        capturedNow: postCutoff,
      );
      expect(postResult.outcome, ProgramMuhasabahOutcome.failedCreated);
      expect(postResult.finalStatus, ProgramV2Model.statusFailed);
      expect(postResult.completedDays, 0);
    });

    test('29. Multiple independent programs do not interfere', () async {
      await createProgram(
        id: 'prog-a',
        targetDays: 40,
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-a',
        startDayKey: '2026-09-01',
        count: 4,
      );

      await createProgram(
        id: 'prog-b',
        targetDays: 60,
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-10-15',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-b',
        startDayKey: '2026-09-01',
        count: 44,
      );

      final resA = await service.finalizeFailure(
        programId: 'prog-a',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );
      final resB = await service.finalizeFailure(
        programId: 'prog-b',
        reasonCode: 'TRAVELING',
        reasonLabelSnapshot: 'Safar',
      );

      expect(resA.finalStatus, ProgramV2Model.statusFailed);
      expect(resB.finalStatus, ProgramV2Model.statusWarning);
      expect(failureBox.length, 2);
    });

    test(
        '30. Concurrent calls through one service instance do not duplicate finalization',
        () async {
      await createProgram(
        id: 'prog-concurrent',
        targetDays: 40,
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-concurrent',
        startDayKey: '2026-09-01',
        count: 4,
      );

      // Run two parallel calls simultaneously
      final future1 = service.finalizeFailure(
        programId: 'prog-concurrent',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );
      final future2 = service.finalizeFailure(
        programId: 'prog-concurrent',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      final results = await Future.wait([future1, future2]);

      final outcomes = results.map((r) => r.outcome).toList();
      expect(outcomes, contains(ProgramMuhasabahOutcome.failedCreated));
      expect(outcomes, contains(ProgramMuhasabahOutcome.alreadyFinalized));
      expect(failureBox.length, 1);
    });

    test('31. Closed Hive boxes yield typed persistenceError', () async {
      await createProgram(
        id: 'prog-closed-box',
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );

      await programBox.close();

      final result = await service.finalizeFailure(
        programId: 'prog-closed-box',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.persistenceError);
      expect(result.isFailure, isTrue);
      expect(
          result.errorMessage, isNot(contains('Box has already been closed')));
    });

    test('32. Invalid and unknown program IDs return typed failures', () async {
      final blankResult = await service.finalizeFailure(
        programId: '   ',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );
      expect(blankResult.outcome, ProgramMuhasabahOutcome.invalidProgramId);

      final unknownResult = await service.finalizeFailure(
        programId: 'prog-not-exist',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );
      expect(unknownResult.outcome, ProgramMuhasabahOutcome.programNotFound);
    });

    test('33. Valid canonical record alone: retry succeeds and reuses record',
        () async {
      await createProgram(
        id: 'prog-retry-canon',
        targetDays: 40,
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-retry-canon',
        startDayKey: '2026-09-01',
        count: 4,
      );

      final expectedFailureId = FailureRecordV2Repository.buildFailureRecordId(
        '2026-09-05',
        'prog-retry-canon',
      );
      final preRecord = FailureRecordModel(
        id: expectedFailureId,
        programId: 'prog-retry-canon',
        missedDayKey: '2026-09-05',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
        note: 'Existing note',
        createdAt: DateTime(2026, 9, 6, 10, 0),
      );
      await failureRepo.save(preRecord);

      final result = await service.finalizeFailure(
        programId: 'prog-retry-canon',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.failedCreated);
      expect(result.finalStatus, ProgramV2Model.statusFailed);
      expect(result.failureRecord?.createdAt, DateTime(2026, 9, 6, 10, 0));
      expect(failureBox.length, 1);
    });

    test(
        '34. Valid canonical record plus duplicate at another Hive key returns dataIntegrityError without terminal write',
        () async {
      await createProgram(
        id: 'prog-dup-record',
        targetDays: 40,
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-dup-record',
        startDayKey: '2026-09-01',
        count: 4,
      );

      final canonicalId = FailureRecordV2Repository.buildFailureRecordId(
        '2026-09-05',
        'prog-dup-record',
      );
      final canonicalRecord = FailureRecordModel(
        id: canonicalId,
        programId: 'prog-dup-record',
        missedDayKey: '2026-09-05',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
        createdAt: DateTime(2026, 9, 6, 10, 0),
      );
      await failureBox.put(canonicalId, canonicalRecord);

      // Duplicate record under noncanonical key for same program & missed day
      final duplicateRecord = FailureRecordModel(
        id: 'dup_custom_id',
        programId: 'prog-dup-record',
        missedDayKey: '2026-09-05',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
        createdAt: DateTime(2026, 9, 6, 10, 5),
      );
      await failureBox.put('dup_custom_key', duplicateRecord);

      final result = await service.finalizeFailure(
        programId: 'prog-dup-record',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.dataIntegrityError);
      expect(result.errorMessage, contains('duplicate FailureRecord records'));

      // Verify program was NOT finalized to terminal status
      final persisted = programBox.get('prog-dup-record');
      expect(persisted?.status, ProgramV2Model.statusPendingFailure);
    });

    test(
        '35. Noncanonical record without canonical record returns dataIntegrityError',
        () async {
      await createProgram(
        id: 'prog-noncanonical-only',
        targetDays: 40,
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-noncanonical-only',
        startDayKey: '2026-09-01',
        count: 4,
      );

      final noncanonicalRecord = FailureRecordModel(
        id: 'anomalous_record_id',
        programId: 'prog-noncanonical-only',
        missedDayKey: '2026-09-05',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
        createdAt: DateTime(2026, 9, 6, 10, 0),
      );
      await failureBox.put('anomalous_storage_key', noncanonicalRecord);

      final result = await service.finalizeFailure(
        programId: 'prog-noncanonical-only',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.dataIntegrityError);
      expect(result.errorMessage, contains('noncanonical key or identity'));

      final persisted = programBox.get('prog-noncanonical-only');
      expect(persisted?.status, ProgramV2Model.statusPendingFailure);
    });

    test('36. Conflicting canonical key returns dataIntegrityError', () async {
      await createProgram(
        id: 'prog-canon-conflict',
        targetDays: 40,
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-canon-conflict',
        startDayKey: '2026-09-01',
        count: 4,
      );

      final canonicalId = FailureRecordV2Repository.buildFailureRecordId(
        '2026-09-05',
        'prog-canon-conflict',
      );
      // Canonical key occupied by record for a different program
      final conflictingRecord = FailureRecordModel(
        id: canonicalId,
        programId: 'different-program-id',
        missedDayKey: '2026-09-05',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
        createdAt: DateTime(2026, 9, 6, 10, 0),
      );
      await failureBox.put(canonicalId, conflictingRecord);

      final result = await service.finalizeFailure(
        programId: 'prog-canon-conflict',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.dataIntegrityError);
      expect(result.errorMessage,
          contains('occupied by an unexpected or conflicting record'));

      final persisted = programBox.get('prog-canon-conflict');
      expect(persisted?.status, ProgramV2Model.statusPendingFailure);
    });

    test(
        '37. Step 3: Re-read FailureRecord with changed programId returns dataIntegrityError without Program write',
        () async {
      await createProgram(
        id: 'prog-reread-progid',
        targetDays: 40,
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-reread-progid',
        startDayKey: '2026-09-01',
        count: 4,
      );

      // On getById (re-read step), return a record with mismatched programId
      failureRepo.onGetById = (id, _) {
        final actual = failureBox.get(id);
        if (actual != null) {
          return FailureRecordModel(
            id: actual.id,
            programId: 'tampered-program-id',
            missedDayKey: actual.missedDayKey,
            reasonCode: actual.reasonCode,
            reasonLabelSnapshot: actual.reasonLabelSnapshot,
            createdAt: actual.createdAt,
          );
        }
        return null;
      };

      final result = await service.finalizeFailure(
        programId: 'prog-reread-progid',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.dataIntegrityError);
      expect(result.errorMessage, contains('corrupted or altered'));

      final persisted = programBox.get('prog-reread-progid');
      expect(persisted?.status, ProgramV2Model.statusPendingFailure);
    });

    test(
        '38. Step 3: Re-read FailureRecord with changed missedDayKey returns dataIntegrityError without Program write',
        () async {
      await createProgram(
        id: 'prog-reread-missedkey',
        targetDays: 40,
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-reread-missedkey',
        startDayKey: '2026-09-01',
        count: 4,
      );

      failureRepo.onGetById = (id, _) {
        final actual = failureBox.get(id);
        if (actual != null) {
          return FailureRecordModel(
            id: actual.id,
            programId: actual.programId,
            missedDayKey: '2026-09-99',
            reasonCode: actual.reasonCode,
            reasonLabelSnapshot: actual.reasonLabelSnapshot,
            createdAt: actual.createdAt,
          );
        }
        return null;
      };

      final result = await service.finalizeFailure(
        programId: 'prog-reread-missedkey',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.dataIntegrityError);
      expect(result.errorMessage, contains('corrupted or altered'));

      final persisted = programBox.get('prog-reread-missedkey');
      expect(persisted?.status, ProgramV2Model.statusPendingFailure);
    });

    test(
        '39. Step 3: Re-read FailureRecord with noncanonical Hive key returns dataIntegrityError without Program write',
        () async {
      await createProgram(
        id: 'prog-reread-badkey',
        targetDays: 40,
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-reread-badkey',
        startDayKey: '2026-09-01',
        count: 4,
      );

      failureRepo.onGetById = (id, _) {
        final actual = failureBox.get(id);
        if (actual != null) {
          return _NoncanonicalKeyFailureRecordModel(
            id: actual.id,
            programId: actual.programId,
            missedDayKey: actual.missedDayKey,
            reasonCode: actual.reasonCode,
            reasonLabelSnapshot: actual.reasonLabelSnapshot,
            createdAt: actual.createdAt,
            customKey: 'rogue_hive_key',
          );
        }
        return null;
      };

      final result = await service.finalizeFailure(
        programId: 'prog-reread-badkey',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.dataIntegrityError);
      expect(result.errorMessage, contains('corrupted or altered'));

      final persisted = programBox.get('prog-reread-badkey');
      expect(persisted?.status, ProgramV2Model.statusPendingFailure);
    });

    test(
        '40. Step 3: Valid re-read allows finalization and writes terminal Program status',
        () async {
      await createProgram(
        id: 'prog-reread-valid',
        targetDays: 40,
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-reread-valid',
        startDayKey: '2026-09-01',
        count: 4,
      );

      final result = await service.finalizeFailure(
        programId: 'prog-reread-valid',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.failedCreated);
      final persisted = programBox.get('prog-reread-valid');
      expect(persisted?.status, ProgramV2Model.statusFailed);
      expect(persisted?.finalizedAt, isNotNull);
    });

    test(
        '41. Step 4: Closed DailyCheckIn box during first finalization yields persistenceError without mutation',
        () async {
      await createProgram(
        id: 'prog-closed-checkin-1',
        targetDays: 40,
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );

      await checkInBox.close();

      final result = await service.finalizeFailure(
        programId: 'prog-closed-checkin-1',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.persistenceError);
      expect(
          result.errorMessage, isNot(contains('Box has already been closed')));
      expect(failureBox.length, 0);

      // Program unchanged
      final persisted = programBox.get('prog-closed-checkin-1');
      expect(persisted?.status, ProgramV2Model.statusPendingFailure);
    });

    test(
        '42. Step 4: Closed DailyCheckIn box during idempotent finalized retry yields persistenceError',
        () async {
      await createProgram(
        id: 'prog-closed-checkin-retry',
        targetDays: 40,
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-closed-checkin-retry',
        startDayKey: '2026-09-01',
        count: 4,
      );

      // Finalize first normally
      final firstResult = await service.finalizeFailure(
        programId: 'prog-closed-checkin-retry',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );
      expect(firstResult.outcome, ProgramMuhasabahOutcome.failedCreated);

      // Now close checkInBox and attempt idempotent retry
      await checkInBox.close();

      final retryResult = await service.finalizeFailure(
        programId: 'prog-closed-checkin-retry',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(retryResult.outcome, ProgramMuhasabahOutcome.persistenceError);
      expect(retryResult.errorMessage,
          isNot(contains('Box has already been closed')));
    });

    test('43. Step 4: Truly corrupt DailyCheckIn returns dataIntegrityError',
        () async {
      await createProgram(
        id: 'prog-corrupt-checkin',
        targetDays: 40,
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );

      // Create a corrupted check-in with invalid dayKey
      final corrupt = DailyCheckInModel(
        id: 'corrupt-id',
        programId: 'prog-corrupt-checkin',
        dayKey: 'invalid-day-key-format',
        checkedAt: DateTime(2026, 9, 1, 10, 0),
        createdAt: DateTime(2026, 9, 1, 10, 0),
      );
      await checkInBox.put('corrupt-id', corrupt);

      final result = await service.finalizeFailure(
        programId: 'prog-corrupt-checkin',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.dataIntegrityError);
      expect(failureBox.length, 0);

      final persisted = programBox.get('prog-corrupt-checkin');
      expect(persisted?.status, ProgramV2Model.statusPendingFailure);
    });

    test(
        '44. Step 5: Conflicting DailyCheckIn stored at missed day canonical Hive key returns dataIntegrityError',
        () async {
      await createProgram(
        id: 'prog-missed-key-occupied',
        targetDays: 40,
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-missed-key-occupied',
        startDayKey: '2026-09-01',
        count: 4,
      );

      // Deliberately occupy the canonical key for the claimed missed day (2026-09-05)
      final canonicalMissedCheckInId = DailyCheckInV2Repository.buildCheckInId(
        '2026-09-05',
        'prog-missed-key-occupied',
      );
      final conflictingCheckIn = DailyCheckInModel(
        id: canonicalMissedCheckInId,
        programId: 'other-program',
        dayKey: '2026-09-05',
        checkedAt: DateTime(2026, 9, 5, 12, 0),
        createdAt: DateTime(2026, 9, 5, 12, 0),
      );
      await checkInBox.put(canonicalMissedCheckInId, conflictingCheckIn);

      final result = await service.finalizeFailure(
        programId: 'prog-missed-key-occupied',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.dataIntegrityError);
      expect(result.errorMessage,
          contains('occupied by an existing check-in record'));
      expect(failureBox.length, 0);

      final persisted = programBox.get('prog-missed-key-occupied');
      expect(persisted?.status, ProgramV2Model.statusPendingFailure);
    });

    test(
        '45. Step 6: Status consistency on retry: FAILED with 39 valid days succeeds as alreadyFinalized',
        () async {
      await createProgram(
        id: 'prog-retry-failed-39',
        targetDays: 60,
        startDayKey: '2026-09-01',
        status: ProgramV2Model.statusFailed,
        pendingMissedDayKey: '2026-10-10', // Day 40 missed
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-retry-failed-39',
        startDayKey: '2026-09-01',
        count: 39,
      );

      final failureId = FailureRecordV2Repository.buildFailureRecordId(
        '2026-10-10',
        'prog-retry-failed-39',
      );
      await failureRepo.save(FailureRecordModel(
        id: failureId,
        programId: 'prog-retry-failed-39',
        missedDayKey: '2026-10-10',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
        createdAt: DateTime(2026, 10, 11, 8, 0),
      ));

      final result = await service.finalizeFailure(
        programId: 'prog-retry-failed-39',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.alreadyFinalized);
      expect(result.finalStatus, ProgramV2Model.statusFailed);
      expect(result.completedDays, 39);
    });

    test(
        '46. Step 6: Status consistency on retry: WARNING with 40 valid days before target succeeds as alreadyFinalized',
        () async {
      await createProgram(
        id: 'prog-retry-warning-40',
        targetDays: 60,
        startDayKey: '2026-09-01',
        status: ProgramV2Model.statusWarning,
        pendingMissedDayKey: '2026-10-11', // Day 41 missed
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-retry-warning-40',
        startDayKey: '2026-09-01',
        count: 40,
      );

      final failureId = FailureRecordV2Repository.buildFailureRecordId(
        '2026-10-11',
        'prog-retry-warning-40',
      );
      await failureRepo.save(FailureRecordModel(
        id: failureId,
        programId: 'prog-retry-warning-40',
        missedDayKey: '2026-10-11',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
        createdAt: DateTime(2026, 10, 12, 8, 0),
      ));

      final result = await service.finalizeFailure(
        programId: 'prog-retry-warning-40',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.alreadyFinalized);
      expect(result.finalStatus, ProgramV2Model.statusWarning);
      expect(result.completedDays, 40);
    });

    test(
        '47. Step 6: Status consistency on retry: Incorrect WARNING with 39 valid days returns dataIntegrityError',
        () async {
      await createProgram(
        id: 'prog-retry-wrong-warning',
        targetDays: 60,
        startDayKey: '2026-09-01',
        status: ProgramV2Model
            .statusWarning, // Inconsistent with 39 completed days!
        pendingMissedDayKey: '2026-10-10',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-retry-wrong-warning',
        startDayKey: '2026-09-01',
        count: 39,
      );

      final failureId = FailureRecordV2Repository.buildFailureRecordId(
        '2026-10-10',
        'prog-retry-wrong-warning',
      );
      await failureRepo.save(FailureRecordModel(
        id: failureId,
        programId: 'prog-retry-wrong-warning',
        missedDayKey: '2026-10-10',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
        createdAt: DateTime(2026, 10, 11, 8, 0),
      ));

      final result = await service.finalizeFailure(
        programId: 'prog-retry-wrong-warning',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.dataIntegrityError);
      expect(result.errorMessage,
          contains('disagrees with authoritative progress status'));

      // Inconsistent status is NOT auto-corrected
      final persisted = programBox.get('prog-retry-wrong-warning');
      expect(persisted?.status, ProgramV2Model.statusWarning);
    });

    test(
        '48. Step 6: Status consistency on retry: Incorrect FAILED with 40 valid days before target returns dataIntegrityError',
        () async {
      await createProgram(
        id: 'prog-retry-wrong-failed',
        targetDays: 60,
        startDayKey: '2026-09-01',
        status:
            ProgramV2Model.statusFailed, // Inconsistent with 40 completed days!
        pendingMissedDayKey: '2026-10-11',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-retry-wrong-failed',
        startDayKey: '2026-09-01',
        count: 40,
      );

      final failureId = FailureRecordV2Repository.buildFailureRecordId(
        '2026-10-11',
        'prog-retry-wrong-failed',
      );
      await failureRepo.save(FailureRecordModel(
        id: failureId,
        programId: 'prog-retry-wrong-failed',
        missedDayKey: '2026-10-11',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
        createdAt: DateTime(2026, 10, 12, 8, 0),
      ));

      final result = await service.finalizeFailure(
        programId: 'prog-retry-wrong-failed',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.dataIntegrityError);
      expect(result.errorMessage,
          contains('disagrees with authoritative progress status'));

      final persisted = programBox.get('prog-retry-wrong-failed');
      expect(persisted?.status, ProgramV2Model.statusFailed);
    });

    test(
        '49. Step 6: Status consistency on retry: Completed target (40/40) in failure status returns dataIntegrityError',
        () async {
      await createProgram(
        id: 'prog-retry-completed-target',
        targetDays: 40,
        startDayKey: '2026-09-01',
        status: ProgramV2Model.statusFailed,
        pendingMissedDayKey: '2026-10-11',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-retry-completed-target',
        startDayKey: '2026-09-01',
        count: 40,
      );

      final failureId = FailureRecordV2Repository.buildFailureRecordId(
        '2026-10-11',
        'prog-retry-completed-target',
      );
      await failureRepo.save(FailureRecordModel(
        id: failureId,
        programId: 'prog-retry-completed-target',
        missedDayKey: '2026-10-11',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
        createdAt: DateTime(2026, 10, 12, 8, 0),
      ));

      final result = await service.finalizeFailure(
        programId: 'prog-retry-completed-target',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.dataIntegrityError);
      expect(result.errorMessage,
          contains('Target duration (40 days) was completed'));
    });

    // =========================================================================
    // TASK MV2-B0-02-04-03-02-R2 REGRESSION TESTS
    // =========================================================================

    // ISSUE 1: ONE FAILURE INTERRUPTION PER PROGRAM
    test(
        '50. Issue 1: Valid canonical FailureRecord only: finalization succeeds',
        () async {
      await createProgram(
        id: 'prog-r2-canonical-only',
        targetDays: 40,
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-r2-canonical-only',
        startDayKey: '2026-09-01',
        count: 4,
      );

      final canonicalId = FailureRecordV2Repository.buildFailureRecordId(
        '2026-09-05',
        'prog-r2-canonical-only',
      );
      final existingRecord = FailureRecordModel(
        id: canonicalId,
        programId: 'prog-r2-canonical-only',
        missedDayKey: '2026-09-05',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
        createdAt: DateTime(2026, 9, 6, 10, 0),
      );
      await failureRepo.save(existingRecord);

      final result = await service.finalizeFailure(
        programId: 'prog-r2-canonical-only',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.failedCreated);
      expect(result.isSuccess, isTrue);
      expect(result.finalStatus, ProgramV2Model.statusFailed);
      expect(result.failureRecord?.id, canonicalId);

      final persistedProgram = programBox.get('prog-r2-canonical-only');
      expect(persistedProgram?.status, ProgramV2Model.statusFailed);
      expect(failureBox.length, 1);
    });

    test(
        '51. Issue 1: Canonical FailureRecord plus an additional record for same program with different missedDayKey returns dataIntegrityError without mutation',
        () async {
      await createProgram(
        id: 'prog-r2-diff-missed',
        targetDays: 40,
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-r2-diff-missed',
        startDayKey: '2026-09-01',
        count: 4,
      );

      final canonicalId = FailureRecordV2Repository.buildFailureRecordId(
        '2026-09-05',
        'prog-r2-diff-missed',
      );
      final canonicalRecord = FailureRecordModel(
        id: canonicalId,
        programId: 'prog-r2-diff-missed',
        missedDayKey: '2026-09-05',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
        createdAt: DateTime(2026, 9, 6, 10, 0),
      );
      await failureRepo.save(canonicalRecord);

      // Additional record for the same program carrying a different missedDayKey
      final anomalousId = FailureRecordV2Repository.buildFailureRecordId(
        '2026-09-03',
        'prog-r2-diff-missed',
      );
      final anomalousRecord = FailureRecordModel(
        id: anomalousId,
        programId: 'prog-r2-diff-missed',
        missedDayKey: '2026-09-03',
        reasonCode: 'FORGOT',
        reasonLabelSnapshot: 'Lupa',
        createdAt: DateTime(2026, 9, 4, 10, 0),
      );
      await failureRepo.save(anomalousRecord);

      final result = await service.finalizeFailure(
        programId: 'prog-r2-diff-missed',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.dataIntegrityError);
      expect(result.errorMessage, contains('FailureRecord records'));

      // Verify no Program or FailureRecord mutation
      final persistedProgram = programBox.get('prog-r2-diff-missed');
      expect(persistedProgram?.status, ProgramV2Model.statusPendingFailure);
      expect(failureBox.length, 2);
      expect(failureBox.get(canonicalId)?.reasonCode, 'SICK');
      expect(failureBox.get(anomalousId)?.reasonCode, 'FORGOT');
    });

    test(
        '52. Issue 1: Anomalous condition on already-finalized FAILED/WARNING retry returns dataIntegrityError without mutation',
        () async {
      await createProgram(
        id: 'prog-r2-finalized-anomalous',
        targetDays: 40,
        startDayKey: '2026-09-01',
        status: ProgramV2Model.statusFailed,
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-r2-finalized-anomalous',
        startDayKey: '2026-09-01',
        count: 4,
      );

      final canonicalId = FailureRecordV2Repository.buildFailureRecordId(
        '2026-09-05',
        'prog-r2-finalized-anomalous',
      );
      final canonicalRecord = FailureRecordModel(
        id: canonicalId,
        programId: 'prog-r2-finalized-anomalous',
        missedDayKey: '2026-09-05',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
        createdAt: DateTime(2026, 9, 6, 10, 0),
      );
      await failureRepo.save(canonicalRecord);

      // Additional anomalous failure record for same program but different missedDayKey
      final anomalousId = FailureRecordV2Repository.buildFailureRecordId(
        '2026-09-02',
        'prog-r2-finalized-anomalous',
      );
      final anomalousRecord = FailureRecordModel(
        id: anomalousId,
        programId: 'prog-r2-finalized-anomalous',
        missedDayKey: '2026-09-02',
        reasonCode: 'FORGOT',
        reasonLabelSnapshot: 'Lupa',
        createdAt: DateTime(2026, 9, 3, 10, 0),
      );
      await failureRepo.save(anomalousRecord);

      final result = await service.finalizeFailure(
        programId: 'prog-r2-finalized-anomalous',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.dataIntegrityError);
      expect(result.errorMessage, contains('FailureRecord records'));

      // Verify no Program or FailureRecord mutation
      final persistedProgram = programBox.get('prog-r2-finalized-anomalous');
      expect(persistedProgram?.status, ProgramV2Model.statusFailed);
      expect(failureBox.length, 2);
    });

    test(
        '53. Issue 1: Single FailureRecord with conflicting missedDayKey for pending program returns dataIntegrityError without mutation',
        () async {
      await createProgram(
        id: 'prog-r2-single-conflicting-missed',
        targetDays: 40,
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-r2-single-conflicting-missed',
        startDayKey: '2026-09-01',
        count: 4,
      );

      // Only 1 record in box for this program, but carries a different missedDayKey
      final conflictingId = FailureRecordV2Repository.buildFailureRecordId(
        '2026-09-04',
        'prog-r2-single-conflicting-missed',
      );
      await failureRepo.save(FailureRecordModel(
        id: conflictingId,
        programId: 'prog-r2-single-conflicting-missed',
        missedDayKey: '2026-09-04',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
        createdAt: DateTime(2026, 9, 5, 10, 0),
      ));

      final result = await service.finalizeFailure(
        programId: 'prog-r2-single-conflicting-missed',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.dataIntegrityError);
      expect(result.errorMessage, contains('conflicting missed day'));

      final persistedProgram =
          programBox.get('prog-r2-single-conflicting-missed');
      expect(persistedProgram?.status, ProgramV2Model.statusPendingFailure);
      expect(failureBox.length, 1);
    });

    // ISSUE 2: CONCURRENT TERMINAL STATUS RE-READ
    test(
        '54. Issue 2: Concurrent terminal FAILED with matching program snapshot and FailureRecord returns alreadyFinalized',
        () async {
      await createProgram(
        id: 'prog-r2-concurrent-terminal-valid',
        targetDays: 40,
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-r2-concurrent-terminal-valid',
        startDayKey: '2026-09-01',
        count: 4,
      );

      final originalProgram =
          programBox.get('prog-r2-concurrent-terminal-valid')!;

      // On re-read in Step 11, program was finalized concurrently to FAILED with identical identity snapshot
      programRepo.onGetById = (id, count) {
        if (id == 'prog-r2-concurrent-terminal-valid' && count >= 2) {
          return ProgramV2Model(
            id: originalProgram.id,
            ibadahId: originalProgram.ibadahId,
            ibadahNameSnapshot: originalProgram.ibadahNameSnapshot,
            targetDays: originalProgram.targetDays,
            startDayKey: originalProgram.startDayKey,
            status: ProgramV2Model.statusFailed,
            reminderTime: originalProgram.reminderTime,
            restartedFromProgramId: originalProgram.restartedFromProgramId,
            recipientNameSnapshot: originalProgram.recipientNameSnapshot,
            createdAt: originalProgram.createdAt,
            updatedAt: DateTime(2026, 9, 6, 10, 0),
            finalizedAt: DateTime(2026, 9, 6, 10, 0),
            pendingMissedDayKey: originalProgram.pendingMissedDayKey,
          );
        }
        return null;
      };

      final result = await service.finalizeFailure(
        programId: 'prog-r2-concurrent-terminal-valid',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.alreadyFinalized);
      expect(result.finalStatus, ProgramV2Model.statusFailed);
      expect(result.failureRecord?.reasonCode, 'SICK');
      expect(result.program?.status, ProgramV2Model.statusFailed);
    });

    test(
        '55. Issue 2: Concurrent terminal FAILED with changed pendingMissedDayKey returns dataIntegrityError',
        () async {
      await createProgram(
        id: 'prog-r2-concurrent-changed-missed',
        targetDays: 40,
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-r2-concurrent-changed-missed',
        startDayKey: '2026-09-01',
        count: 4,
      );

      final originalProgram =
          programBox.get('prog-r2-concurrent-changed-missed')!;

      // Re-read returns terminal FAILED, but with a changed pendingMissedDayKey
      programRepo.onGetById = (id, count) {
        if (id == 'prog-r2-concurrent-changed-missed' && count >= 2) {
          return ProgramV2Model(
            id: originalProgram.id,
            ibadahId: originalProgram.ibadahId,
            ibadahNameSnapshot: originalProgram.ibadahNameSnapshot,
            targetDays: originalProgram.targetDays,
            startDayKey: originalProgram.startDayKey,
            status: ProgramV2Model.statusFailed,
            reminderTime: originalProgram.reminderTime,
            restartedFromProgramId: originalProgram.restartedFromProgramId,
            recipientNameSnapshot: originalProgram.recipientNameSnapshot,
            createdAt: originalProgram.createdAt,
            updatedAt: DateTime(2026, 9, 6, 10, 0),
            finalizedAt: DateTime(2026, 9, 6, 10, 0),
            pendingMissedDayKey: '2026-09-06', // Changed!
          );
        }
        return null;
      };

      final result = await service.finalizeFailure(
        programId: 'prog-r2-concurrent-changed-missed',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.dataIntegrityError);
      expect(result.errorMessage,
          contains('Program snapshot changed concurrently'));
    });

    test(
        '56. Issue 2: Concurrent terminal state with changed targetDays or startDayKey returns dataIntegrityError',
        () async {
      await createProgram(
        id: 'prog-r2-concurrent-changed-fields',
        targetDays: 40,
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-r2-concurrent-changed-fields',
        startDayKey: '2026-09-01',
        count: 4,
      );

      final originalProgram =
          programBox.get('prog-r2-concurrent-changed-fields')!;

      // Subcase A: targetDays changed concurrently
      programRepo.onGetById = (id, count) {
        if (id == 'prog-r2-concurrent-changed-fields' && count >= 2) {
          return ProgramV2Model(
            id: originalProgram.id,
            ibadahId: originalProgram.ibadahId,
            ibadahNameSnapshot: originalProgram.ibadahNameSnapshot,
            targetDays: 60, // Changed from 40!
            startDayKey: originalProgram.startDayKey,
            status: ProgramV2Model.statusFailed,
            reminderTime: originalProgram.reminderTime,
            restartedFromProgramId: originalProgram.restartedFromProgramId,
            recipientNameSnapshot: originalProgram.recipientNameSnapshot,
            createdAt: originalProgram.createdAt,
            updatedAt: DateTime(2026, 9, 6, 10, 0),
            finalizedAt: DateTime(2026, 9, 6, 10, 0),
            pendingMissedDayKey: originalProgram.pendingMissedDayKey,
          );
        }
        return null;
      };

      final resultTarget = await service.finalizeFailure(
        programId: 'prog-r2-concurrent-changed-fields',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(resultTarget.outcome, ProgramMuhasabahOutcome.dataIntegrityError);
      expect(resultTarget.errorMessage,
          contains('Program snapshot changed concurrently'));

      // Subcase B: startDayKey changed concurrently
      programRepo.resetOverrides();
      programRepo.onGetById = (id, count) {
        if (id == 'prog-r2-concurrent-changed-fields' && count >= 2) {
          return ProgramV2Model(
            id: originalProgram.id,
            ibadahId: originalProgram.ibadahId,
            ibadahNameSnapshot: originalProgram.ibadahNameSnapshot,
            targetDays: originalProgram.targetDays,
            startDayKey: '2026-09-02', // Changed from 2026-09-01!
            status: ProgramV2Model.statusFailed,
            reminderTime: originalProgram.reminderTime,
            restartedFromProgramId: originalProgram.restartedFromProgramId,
            recipientNameSnapshot: originalProgram.recipientNameSnapshot,
            createdAt: originalProgram.createdAt,
            updatedAt: DateTime(2026, 9, 6, 10, 0),
            finalizedAt: DateTime(2026, 9, 6, 10, 0),
            pendingMissedDayKey: originalProgram.pendingMissedDayKey,
          );
        }
        return null;
      };

      final resultStart = await service.finalizeFailure(
        programId: 'prog-r2-concurrent-changed-fields',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(resultStart.outcome, ProgramMuhasabahOutcome.dataIntegrityError);
      expect(resultStart.errorMessage,
          contains('Program snapshot changed concurrently'));
    });

    test(
        '57. Issue 2: Concurrent terminal state with missing or mismatched FailureRecord returns dataIntegrityError',
        () async {
      await createProgram(
        id: 'prog-r2-concurrent-bad-failure',
        targetDays: 40,
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-r2-concurrent-bad-failure',
        startDayKey: '2026-09-01',
        count: 4,
      );

      final originalProgram = programBox.get('prog-r2-concurrent-bad-failure')!;

      // Program is concurrently terminal
      programRepo.onGetById = (id, count) {
        if (id == 'prog-r2-concurrent-bad-failure' && count >= 2) {
          return ProgramV2Model(
            id: originalProgram.id,
            ibadahId: originalProgram.ibadahId,
            ibadahNameSnapshot: originalProgram.ibadahNameSnapshot,
            targetDays: originalProgram.targetDays,
            startDayKey: originalProgram.startDayKey,
            status: ProgramV2Model.statusFailed,
            reminderTime: originalProgram.reminderTime,
            restartedFromProgramId: originalProgram.restartedFromProgramId,
            recipientNameSnapshot: originalProgram.recipientNameSnapshot,
            createdAt: originalProgram.createdAt,
            updatedAt: DateTime(2026, 9, 6, 10, 0),
            finalizedAt: DateTime(2026, 9, 6, 10, 0),
            pendingMissedDayKey: originalProgram.pendingMissedDayKey,
          );
        }
        return null;
      };

      failureRepo.returnNullOnGetById = true;

      final resultMissing = await service.finalizeFailure(
        programId: 'prog-r2-concurrent-bad-failure',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(resultMissing.outcome, ProgramMuhasabahOutcome.dataIntegrityError);
      expect(resultMissing.errorMessage,
          contains('Persisted failure record was corrupted or altered'));
    });

    test(
        '58. Issue 2: Concurrent terminal state with mismatched FailureRecord returns dataIntegrityError',
        () async {
      await createProgram(
        id: 'prog-r2-concurrent-mismatched-failure',
        targetDays: 40,
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-r2-concurrent-mismatched-failure',
        startDayKey: '2026-09-01',
        count: 4,
      );

      final originalProgram =
          programBox.get('prog-r2-concurrent-mismatched-failure')!;

      // Program is concurrently terminal on re-read (Step 11)
      programRepo.onGetById = (id, count) {
        if (id == 'prog-r2-concurrent-mismatched-failure' && count >= 2) {
          return ProgramV2Model(
            id: originalProgram.id,
            ibadahId: originalProgram.ibadahId,
            ibadahNameSnapshot: originalProgram.ibadahNameSnapshot,
            targetDays: originalProgram.targetDays,
            startDayKey: originalProgram.startDayKey,
            status: ProgramV2Model.statusFailed,
            reminderTime: originalProgram.reminderTime,
            restartedFromProgramId: originalProgram.restartedFromProgramId,
            recipientNameSnapshot: originalProgram.recipientNameSnapshot,
            createdAt: originalProgram.createdAt,
            updatedAt: DateTime(2026, 9, 6, 10, 0),
            finalizedAt: DateTime(2026, 9, 6, 10, 0),
            pendingMissedDayKey: originalProgram.pendingMissedDayKey,
          );
        }
        return null;
      };

      final canonicalFailureId = FailureRecordV2Repository.buildFailureRecordId(
        '2026-09-05',
        'prog-r2-concurrent-mismatched-failure',
      );
      failureRepo.onGetById = (id, count) {
        return FailureRecordModel(
          id: canonicalFailureId,
          programId: 'prog-r2-concurrent-mismatched-failure',
          missedDayKey: '2026-09-05',
          reasonCode: 'FORGOT', // Mismatched reasonCode!
          reasonLabelSnapshot: 'Lupa',
          createdAt: DateTime(2026, 9, 6, 10, 0),
        );
      };

      final resultMismatched = await service.finalizeFailure(
        programId: 'prog-r2-concurrent-mismatched-failure',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
      );

      expect(
          resultMismatched.outcome, ProgramMuhasabahOutcome.dataIntegrityError);
      expect(resultMismatched.errorMessage,
          contains('Persisted failure record was corrupted or altered'));
    });

    test('59. Issue 2: Valid normal finalization remains unaffected', () async {
      await createProgram(
        id: 'prog-r2-normal-flow',
        targetDays: 40,
        startDayKey: '2026-09-01',
        pendingMissedDayKey: '2026-09-05',
      );
      await populateConsecutiveCheckIns(
        programId: 'prog-r2-normal-flow',
        startDayKey: '2026-09-01',
        count: 4,
      );

      final result = await service.finalizeFailure(
        programId: 'prog-r2-normal-flow',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit',
        note: 'Normal finalization note',
      );

      expect(result.outcome, ProgramMuhasabahOutcome.failedCreated);
      expect(result.isSuccess, isTrue);
      expect(result.finalStatus, ProgramV2Model.statusFailed);
      expect(result.completedDays, 4);

      final persistedProgram = programBox.get('prog-r2-normal-flow');
      expect(persistedProgram?.status, ProgramV2Model.statusFailed);
      expect(persistedProgram?.finalizedAt, isNotNull);

      final canonicalId = FailureRecordV2Repository.buildFailureRecordId(
        '2026-09-05',
        'prog-r2-normal-flow',
      );
      final persistedFailure = failureBox.get(canonicalId);
      expect(persistedFailure, isNotNull);
      expect(persistedFailure?.reasonCode, 'SICK');
      expect(persistedFailure?.note, 'Normal finalization note');
    });
  });
}
