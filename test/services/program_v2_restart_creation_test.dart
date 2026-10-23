import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
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
    tempDir = Directory.systemTemp.createTempSync('restart_creation_test_');
    Hive.init(tempDir.path);
    box = await Hive.openBox<ProgramV2Model>('test_restart_box');
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

  group('Program V2 Restart Creation & Invariant Validation', () {
    test(
        '1. Normal creation without restart source preserves null restartedFromProgramId',
        () async {
      final result = await service.createProgram(
        ibadahId: 'ibd-tahajjud',
        ibadahNameSnapshot: 'Shalat Tahajjud',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
      );

      expect(result.isSuccess, isTrue);
      expect(result.program!.restartedFromProgramId, isNull);
    });

    test(
        '2. Restart from terminal SUCCESS program creates new ACTIVE program with link',
        () async {
      final oldSuccess = ProgramV2Model(
        id: 'prog_success_old',
        ibadahId: 'ibd-tahajjud',
        ibadahNameSnapshot: 'Shalat Tahajjud',
        targetDays: 40,
        startDayKey: '2026-09-01',
        status: ProgramV2Model.statusSuccess,
        reminderTime: '03:30',
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 10, 11),
        finalizedAt: DateTime(2026, 10, 11),
      );
      await repository.save(oldSuccess);

      final result = await service.createProgram(
        ibadahId: 'ibd-tahajjud',
        ibadahNameSnapshot: 'Shalat Tahajjud',
        targetDays: 60,
        startSelection: ProgramStartSelection.today,
        reminderTime: '03:30',
        restartedFromProgramId: oldSuccess.id,
      );

      expect(result.isSuccess, isTrue);
      final newProg = result.program!;
      expect(newProg.id, isNot(equals(oldSuccess.id)));
      expect(newProg.status, equals(ProgramV2Model.statusActive));
      expect(newProg.restartedFromProgramId, equals(oldSuccess.id));
      expect(newProg.targetDays, equals(60));

      // Old program remains completely untouched
      final storedOld = repository.getById(oldSuccess.id);
      expect(storedOld, isNotNull);
      expect(storedOld!.status, equals(ProgramV2Model.statusSuccess));
      expect(storedOld.targetDays, equals(40));
      expect(storedOld.finalizedAt, isNotNull);
      expect(storedOld.restartedFromProgramId, isNull);
      expect(repository.getAll().length, equals(2));
    });

    test(
        '3. Restart from terminal FAILED program creates new ACTIVE program with link',
        () async {
      final oldFailed = ProgramV2Model(
        id: 'prog_failed_old',
        ibadahId: 'ibd-dhuha',
        ibadahNameSnapshot: 'Shalat Dhuha',
        targetDays: 40,
        startDayKey: '2026-10-01',
        status: ProgramV2Model.statusFailed,
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 15),
        finalizedAt: DateTime(2026, 10, 15),
        pendingMissedDayKey: '2026-10-15',
      );
      await repository.save(oldFailed);

      final result = await service.createProgram(
        ibadahId: 'ibd-dhuha',
        ibadahNameSnapshot: 'Shalat Dhuha',
        targetDays: 40,
        startSelection: ProgramStartSelection.tomorrow,
        restartedFromProgramId: oldFailed.id,
      );

      expect(result.isSuccess, isTrue);
      final newProg = result.program!;
      expect(newProg.id, isNot(equals(oldFailed.id)));
      expect(newProg.status, equals(ProgramV2Model.statusActive));
      expect(newProg.restartedFromProgramId, equals(oldFailed.id));

      // Old program preserved
      final storedOld = repository.getById(oldFailed.id);
      expect(storedOld!.status, equals(ProgramV2Model.statusFailed));
      expect(storedOld.pendingMissedDayKey, equals('2026-10-15'));
    });

    test(
        '4. Restart from terminal WARNING program creates new ACTIVE program with link',
        () async {
      final oldWarning = ProgramV2Model(
        id: 'prog_warning_old',
        ibadahId: 'ibd-witir',
        ibadahNameSnapshot: 'Shalat Witir',
        targetDays: 60,
        startDayKey: '2026-08-01',
        status: ProgramV2Model.statusWarning,
        createdAt: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 9, 15),
        finalizedAt: DateTime(2026, 9, 15),
        pendingMissedDayKey: '2026-09-15',
      );
      await repository.save(oldWarning);

      final result = await service.createProgram(
        ibadahId: 'ibd-witir',
        ibadahNameSnapshot: 'Shalat Witir',
        targetDays: 60,
        startSelection: ProgramStartSelection.today,
        restartedFromProgramId: oldWarning.id,
      );

      expect(result.isSuccess, isTrue);
      expect(result.program!.status, equals(ProgramV2Model.statusActive));
      expect(result.program!.restartedFromProgramId, equals(oldWarning.id));
    });

    test('5. Rejects restart when source program is non-terminal ACTIVE',
        () async {
      final activeProg = ProgramV2Model(
        id: 'prog_active_source',
        ibadahId: 'ibd-quran',
        ibadahNameSnapshot: 'Tilawah Quran',
        targetDays: 40,
        startDayKey: '2026-10-20',
        status: ProgramV2Model.statusActive,
        createdAt: DateTime(2026, 10, 20),
        updatedAt: DateTime(2026, 10, 20),
      );
      await repository.save(activeProg);

      final result = await service.createProgram(
        ibadahId: 'ibd-quran',
        ibadahNameSnapshot: 'Tilawah Quran',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
        restartedFromProgramId: activeProg.id,
      );

      expect(result.isFailure, isTrue);
      // Fails because active program exclusivity or invalidRestartSource
      expect(
        result.failureReason ==
                ProgramCreationFailureReason.duplicateActiveProgram ||
            result.failureReason ==
                ProgramCreationFailureReason.invalidRestartSource,
        isTrue,
      );
    });

    test(
        '6. Rejects restart when source program is non-terminal PENDING_FAILURE',
        () async {
      final pendingProg = ProgramV2Model(
        id: 'prog_pending_source',
        ibadahId: 'ibd-sedekah',
        ibadahNameSnapshot: 'Sedekah Subuh',
        targetDays: 40,
        startDayKey: '2026-10-10',
        status: ProgramV2Model.statusPendingFailure,
        createdAt: DateTime(2026, 10, 10),
        updatedAt: DateTime(2026, 10, 22),
        pendingMissedDayKey: '2026-10-22',
      );
      await repository.save(pendingProg);

      final result = await service.createProgram(
        ibadahId: 'ibd-sedekah',
        ibadahNameSnapshot: 'Sedekah Subuh',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
        restartedFromProgramId: pendingProg.id,
      );

      expect(result.isFailure, isTrue);
      expect(
        result.failureReason ==
                ProgramCreationFailureReason.duplicateActiveProgram ||
            result.failureReason ==
                ProgramCreationFailureReason.invalidRestartSource,
        isTrue,
      );
    });

    test('7. Rejects restart when source program ID does not exist in storage',
        () async {
      final result = await service.createProgram(
        ibadahId: 'ibd-tahajjud',
        ibadahNameSnapshot: 'Shalat Tahajjud',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
        restartedFromProgramId: 'prog_ghost_nonexistent',
      );

      expect(result.isFailure, isTrue);
      expect(result.failureReason,
          equals(ProgramCreationFailureReason.invalidRestartSource));
    });

    test('8. Rejects restart when source program ID is whitespace or blank',
        () async {
      final result = await service.createProgram(
        ibadahId: 'ibd-tahajjud',
        ibadahNameSnapshot: 'Shalat Tahajjud',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
        restartedFromProgramId: '   ',
      );

      expect(result.isFailure, isTrue);
      expect(result.failureReason,
          equals(ProgramCreationFailureReason.invalidRestartSource));
    });

    test('9. Rejects restart when source ibadahId mismatches request ibadahId',
        () async {
      final oldSuccess = ProgramV2Model(
        id: 'prog_success_dhuha',
        ibadahId: 'ibd-dhuha',
        ibadahNameSnapshot: 'Shalat Dhuha',
        targetDays: 40,
        startDayKey: '2026-09-01',
        status: ProgramV2Model.statusSuccess,
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 10, 11),
        finalizedAt: DateTime(2026, 10, 11),
      );
      await repository.save(oldSuccess);

      // Attempting to restart Tahajjud from a Dhuha source
      final result = await service.createProgram(
        ibadahId: 'ibd-tahajjud',
        ibadahNameSnapshot: 'Shalat Tahajjud',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
        restartedFromProgramId: oldSuccess.id,
      );

      expect(result.isFailure, isTrue);
      expect(result.failureReason,
          equals(ProgramCreationFailureReason.invalidRestartSource));
    });

    test('10. createFromRequest carries restartedFromProgramId accurately',
        () async {
      final oldSuccess = ProgramV2Model(
        id: 'prog_req_source',
        ibadahId: 'ibd-istighfar',
        ibadahNameSnapshot: 'Istighfar 100x',
        targetDays: 40,
        startDayKey: '2026-09-01',
        status: ProgramV2Model.statusSuccess,
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 10, 11),
        finalizedAt: DateTime(2026, 10, 11),
      );
      await repository.save(oldSuccess);

      final request = CreateProgramV2Request(
        ibadahId: 'ibd-istighfar',
        ibadahNameSnapshot: 'Istighfar 100x',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
        restartedFromProgramId: oldSuccess.id,
      );

      final result = await service.createFromRequest(request);
      expect(result.isSuccess, isTrue);
      expect(result.program!.restartedFromProgramId, equals(oldSuccess.id));
    });

    test('11. Restart link survives box flush, close, and disk reload',
        () async {
      final oldSuccess = ProgramV2Model(
        id: 'prog_persist_source',
        ibadahId: 'ibd-rawatib',
        ibadahNameSnapshot: 'Shalat Rawatib',
        targetDays: 40,
        startDayKey: '2026-09-01',
        status: ProgramV2Model.statusSuccess,
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 10, 11),
        finalizedAt: DateTime(2026, 10, 11),
      );
      await repository.save(oldSuccess);

      final created = await service.createProgram(
        ibadahId: 'ibd-rawatib',
        ibadahNameSnapshot: 'Shalat Rawatib',
        targetDays: 40,
        startSelection: ProgramStartSelection.today,
        restartedFromProgramId: oldSuccess.id,
      );
      expect(created.isSuccess, isTrue);
      final newProgId = created.program!.id;

      // Close box and reopen
      await repository.flush();
      await box.close();

      final reopenedBox =
          await Hive.openBox<ProgramV2Model>('test_restart_box');
      final reopenedRepo = ProgramV2Repository(box: reopenedBox);

      final storedNew = reopenedRepo.getById(newProgId);
      expect(storedNew, isNotNull);
      expect(storedNew!.restartedFromProgramId, equals(oldSuccess.id));

      final storedOld = reopenedRepo.getById(oldSuccess.id);
      expect(storedOld, isNotNull);
      expect(storedOld!.status, equals(ProgramV2Model.statusSuccess));

      box = reopenedBox;
    });
  });
}
