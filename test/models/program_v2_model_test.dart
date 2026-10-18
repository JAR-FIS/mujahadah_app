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

void main() {
  late Directory tempDir;
  late DateService dateService;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('mujahadah_prog_v2_test_');
    Hive.init(tempDir.path);

    // Register V1 adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(UserModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(IbadahModelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ProgramModelAdapter());
    }

    // Register V2 adapters
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

    dateService = DateService();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Schema Safety & TypeID Registry', () {
    test('ProgramV2ModelAdapter defines typeId 6', () {
      expect(ProgramV2ModelAdapter().typeId, equals(6));
    });

    test('All registered adapters (0 through 6) have unique typeIds', () {
      final List<TypeAdapter<dynamic>> adapters = [
        UserModelAdapter(),
        IbadahModelAdapter(),
        ProgramModelAdapter(),
        DailyCheckInModelAdapter(),
        FailureRecordModelAdapter(),
        AchievementModelAdapter(),
        ProgramV2ModelAdapter(),
      ];

      final typeIds = adapters.map((a) => a.typeId).toList();
      final uniqueTypeIds = typeIds.toSet();

      expect(uniqueTypeIds.length, equals(adapters.length),
          reason: 'Every adapter must possess a distinct typeId');
      expect(typeIds, equals([0, 1, 2, 3, 4, 5, 6]));
    });

    test('Isolated test storage does not affect production paths', () {
      expect(tempDir.existsSync(), isTrue);
      expect(tempDir.path, contains('mujahadah_prog_v2_test_'));
    });
  });

  group('Model Construction & Contract Verification', () {
    test('Constructs standard 40-day target program with required fields', () {
      final now = DateTime(2026, 10, 18, 5, 0, 0);
      final program = ProgramV2Model(
        id: 'prog-v2-40',
        ibadahId: 'ibd-tahajjud',
        ibadahNameSnapshot: 'Sholat Tahajjud',
        targetDays: 40,
        startDayKey: '2026-10-18',
        status: ProgramV2Model.statusActive,
        reminderTime: '03:15',
        createdAt: now,
        updatedAt: now,
      );

      expect(program.id, 'prog-v2-40');
      expect(program.ibadahId, 'ibd-tahajjud');
      expect(program.ibadahNameSnapshot, 'Sholat Tahajjud');
      expect(program.targetDays, 40);
      expect(program.startDayKey, '2026-10-18');
      expect(program.status, ProgramV2Model.statusActive);
      expect(program.reminderTime, '03:15');
      expect(program.restartedFromProgramId, isNull);
      expect(program.recipientNameSnapshot, isNull);
      expect(program.finalizedAt, isNull);
      expect(program.pendingMissedDayKey, isNull);
      expect(program.createdAt, now);
      expect(program.updatedAt, now);
    });

    test('Can represent custom 365-day target program', () {
      final now = DateTime(2026, 10, 18, 6, 0);
      final program = ProgramV2Model(
        id: 'prog-v2-365',
        ibadahId: 'ibd-tilawah',
        ibadahNameSnapshot: 'One Day One Juz',
        targetDays: 365,
        startDayKey: '2026-10-18',
        status: ProgramV2Model.statusActive,
        createdAt: now,
        updatedAt: now,
      );

      expect(program.targetDays, 365);
      expect(program.reminderTime, isNull);
    });

    test('Preserves immutable ibadah reference and name snapshot', () {
      final now = DateTime(2026, 10, 18, 7, 0);
      final program = ProgramV2Model(
        id: 'prog-v2-snapshot',
        ibadahId: 'ibd-dhuha-custom',
        ibadahNameSnapshot: 'Sholat Dhuha 4 Rakaat',
        targetDays: 60,
        startDayKey: '2026-10-18',
        status: ProgramV2Model.statusActive,
        createdAt: now,
        updatedAt: now,
      );

      expect(program.ibadahId, 'ibd-dhuha-custom');
      expect(program.ibadahNameSnapshot, 'Sholat Dhuha 4 Rakaat');
    });

    test('Nullable fields remain safely null before terminal or failure events',
        () {
      final now = DateTime(2026, 10, 18, 8, 0);
      final program = ProgramV2Model(
        id: 'prog-v2-null-fields',
        ibadahId: 'ibd-subuh',
        ibadahNameSnapshot: 'Sholat Subuh Berjamaah',
        targetDays: 90,
        startDayKey: '2026-10-19',
        status: ProgramV2Model.statusActive,
        reminderTime: null,
        restartedFromProgramId: null,
        recipientNameSnapshot: null,
        finalizedAt: null,
        pendingMissedDayKey: null,
        createdAt: now,
        updatedAt: now,
      );

      expect(program.reminderTime, isNull);
      expect(program.restartedFromProgramId, isNull);
      expect(program.recipientNameSnapshot, isNull);
      expect(program.finalizedAt, isNull);
      expect(program.pendingMissedDayKey, isNull);
    });
  });

  group('Lifecycle Status Contract', () {
    test('Contains exactly the five approved status constants', () {
      expect(ProgramV2Model.statusActive, 'ACTIVE');
      expect(ProgramV2Model.statusPendingFailure, 'PENDING_FAILURE');
      expect(ProgramV2Model.statusSuccess, 'SUCCESS');
      expect(ProgramV2Model.statusFailed, 'FAILED');
      expect(ProgramV2Model.statusWarning, 'WARNING');

      expect(ProgramV2Model.validStatuses, [
        'ACTIVE',
        'PENDING_FAILURE',
        'SUCCESS',
        'FAILED',
        'WARNING',
      ]);
      expect(ProgramV2Model.validStatuses.length, equals(5));
    });

    test('No non-approved statuses (e.g. SCHEDULED) exist in validStatuses',
        () {
      expect(ProgramV2Model.validStatuses.contains('SCHEDULED'), isFalse);
      expect(ProgramV2Model.validStatuses.contains('CANCELLED'), isFalse);
      expect(ProgramV2Model.validStatuses.contains('PAUSED'), isFalse);
    });
  });

  group('Date Handling & Operational Boundary Compatibility', () {
    test(
        'Deterministic Today and Tomorrow start resolution before 03:00 boundary',
        () {
      // Fixed clock: 2026-10-18 02:30:00 (before 03:00)
      final fixedClockBefore = DateTime(2026, 10, 18, 2, 30, 0);
      final mockDateService = DateService(nowProvider: () => fixedClockBefore);

      final todayKey = mockDateService.getTodayDayKey();
      final tomorrowKey = mockDateService.getNextDayKey(todayKey);

      expect(todayKey, equals('2026-10-17'));
      expect(tomorrowKey, equals('2026-10-18'));
      expect(DateService.isValidDayKey(todayKey), isTrue);
      expect(DateService.isValidDayKey(tomorrowKey), isTrue);

      final programToday = ProgramV2Model(
        id: 'prog-v2-today-early',
        ibadahId: 'ibd-tahajjud',
        ibadahNameSnapshot: 'Tahajjud',
        targetDays: 40,
        startDayKey: todayKey,
        status: ProgramV2Model.statusActive,
        createdAt: fixedClockBefore,
        updatedAt: fixedClockBefore,
      );

      final programTomorrow = ProgramV2Model(
        id: 'prog-v2-tomorrow-early',
        ibadahId: 'ibd-witir',
        ibadahNameSnapshot: 'Sholat Witir',
        targetDays: 40,
        startDayKey: tomorrowKey,
        status: ProgramV2Model.statusActive,
        createdAt: fixedClockBefore,
        updatedAt: fixedClockBefore,
      );

      expect(programToday.startDayKey, equals('2026-10-17'));
      expect(programTomorrow.startDayKey, equals('2026-10-18'));
      expect(
          mockDateService.differenceInDays(
              programToday.startDayKey, programTomorrow.startDayKey),
          equals(1));
    });

    test(
        'Deterministic Today and Tomorrow start resolution at or after 03:00 boundary',
        () {
      // Fixed clock: 2026-10-18 03:00:00 (at 03:00)
      final fixedClockAt = DateTime(2026, 10, 18, 3, 0, 0);
      final mockDateService = DateService(nowProvider: () => fixedClockAt);

      final todayKey = mockDateService.getTodayDayKey();
      final tomorrowKey = mockDateService.getNextDayKey(todayKey);

      expect(todayKey, equals('2026-10-18'));
      expect(tomorrowKey, equals('2026-10-19'));
      expect(DateService.isValidDayKey(todayKey), isTrue);
      expect(DateService.isValidDayKey(tomorrowKey), isTrue);

      final programToday = ProgramV2Model(
        id: 'prog-v2-today-curr',
        ibadahId: 'ibd-subuh',
        ibadahNameSnapshot: 'Sholat Subuh',
        targetDays: 40,
        startDayKey: todayKey,
        status: ProgramV2Model.statusActive,
        createdAt: fixedClockAt,
        updatedAt: fixedClockAt,
      );

      final programTomorrow = ProgramV2Model(
        id: 'prog-v2-tomorrow-curr',
        ibadahId: 'ibd-dhuha',
        ibadahNameSnapshot: 'Sholat Dhuha',
        targetDays: 40,
        startDayKey: tomorrowKey,
        status: ProgramV2Model.statusActive,
        createdAt: fixedClockAt,
        updatedAt: fixedClockAt,
      );

      expect(programToday.startDayKey, equals('2026-10-18'));
      expect(programTomorrow.startDayKey, equals('2026-10-19'));
      expect(
          mockDateService.differenceInDays(
              programToday.startDayKey, programTomorrow.startDayKey),
          equals(1));
    });

    test('Evaluates operational boundary around 03:00 correctly', () {
      // Local 02:59:59.999 maps to previous day
      final beforeBoundary = DateTime(2026, 10, 18, 2, 59, 59, 999);
      final keyBefore = dateService.getMujahadahDayKey(beforeBoundary);
      expect(keyBefore, equals('2026-10-17'));

      // Local 03:00:00.000 maps to new day
      final atBoundary = DateTime(2026, 10, 18, 3, 0, 0, 0);
      final keyAt = dateService.getMujahadahDayKey(atBoundary);
      expect(keyAt, equals('2026-10-18'));

      final progBefore = ProgramV2Model(
        id: 'prog-boundary-1',
        ibadahId: 'ibd-tahajjud',
        ibadahNameSnapshot: 'Tahajjud',
        targetDays: 40,
        startDayKey: keyBefore,
        status: ProgramV2Model.statusActive,
        createdAt: beforeBoundary,
        updatedAt: beforeBoundary,
      );

      final progAt = ProgramV2Model(
        id: 'prog-boundary-2',
        ibadahId: 'ibd-tahajjud',
        ibadahNameSnapshot: 'Tahajjud',
        targetDays: 40,
        startDayKey: keyAt,
        status: ProgramV2Model.statusActive,
        createdAt: atBoundary,
        updatedAt: atBoundary,
      );

      expect(progBefore.startDayKey, '2026-10-17');
      expect(progAt.startDayKey, '2026-10-18');
    });
  });

  group('History & Restart Lineage', () {
    test(
        'Archived program and restarted program coexist with lineage reference',
        () {
      final archivedAt = DateTime(2026, 11, 10, 3, 30);
      final originalProgram = ProgramV2Model(
        id: 'prog-v2-orig',
        ibadahId: 'ibd-rawatib',
        ibadahNameSnapshot: 'Rawatib Qobliyah & Ba\'diyah',
        targetDays: 40,
        startDayKey: '2026-10-01',
        status: ProgramV2Model.statusFailed,
        reminderTime: '12:00',
        createdAt: DateTime(2026, 10, 1, 3, 0),
        updatedAt: archivedAt,
        finalizedAt: archivedAt,
      );

      final restartedProgram = ProgramV2Model(
        id: 'prog-v2-restarted',
        ibadahId: 'ibd-rawatib',
        ibadahNameSnapshot: 'Rawatib Qobliyah & Ba\'diyah',
        targetDays: 40,
        startDayKey: '2026-11-10',
        status: ProgramV2Model.statusActive,
        reminderTime: '12:15',
        restartedFromProgramId: originalProgram.id,
        createdAt: archivedAt,
        updatedAt: archivedAt,
      );

      expect(originalProgram.status, ProgramV2Model.statusFailed);
      expect(originalProgram.finalizedAt, archivedAt);
      expect(restartedProgram.status, ProgramV2Model.statusActive);
      expect(restartedProgram.restartedFromProgramId, originalProgram.id);
      expect(restartedProgram.id, isNot(equals(originalProgram.id)));
      expect(restartedProgram.ibadahNameSnapshot,
          equals(originalProgram.ibadahNameSnapshot));
    });
  });

  group('Persistent Disk Round-Trip (Flush, Close, Reopen, Retrieve)', () {
    test(
        'ACTIVE program round-trip preserves all fields and millisecond precision',
        () async {
      const boxName = 'test_v2_active_disk';
      final createdAt = DateTime(2026, 10, 18, 4, 30, 12, 789);
      final updatedAt = DateTime(2026, 10, 18, 4, 30, 15, 123);

      final original = ProgramV2Model(
        id: 'prog-active-disk',
        ibadahId: 'ibd-subuh',
        ibadahNameSnapshot: 'Sholat Subuh',
        targetDays: 40,
        startDayKey: '2026-10-18',
        status: ProgramV2Model.statusActive,
        reminderTime: '04:15',
        restartedFromProgramId: null,
        recipientNameSnapshot: null,
        createdAt: createdAt,
        updatedAt: updatedAt,
        finalizedAt: null,
        pendingMissedDayKey: null,
      );

      // Phase 1: Write, flush, close
      var box = await Hive.openBox<ProgramV2Model>(boxName);
      try {
        await box.put(original.id, original);
        await box.flush();
      } finally {
        await box.close();
      }

      // Phase 2: Reopen from disk, retrieve and verify
      box = await Hive.openBox<ProgramV2Model>(boxName);
      try {
        final retrieved = box.get(original.id);
        expect(retrieved, isNotNull);
        expect(retrieved!.id, original.id);
        expect(retrieved.ibadahId, original.ibadahId);
        expect(retrieved.ibadahNameSnapshot, original.ibadahNameSnapshot);
        expect(retrieved.targetDays, 40);
        expect(retrieved.startDayKey, '2026-10-18');
        expect(retrieved.status, ProgramV2Model.statusActive);
        expect(retrieved.reminderTime, '04:15');
        expect(retrieved.restartedFromProgramId, isNull);
        expect(retrieved.recipientNameSnapshot, isNull);
        expect(retrieved.finalizedAt, isNull);
        expect(retrieved.pendingMissedDayKey, isNull);
        expect(retrieved.createdAt.isAtSameMomentAs(createdAt), isTrue);
        expect(retrieved.createdAt.millisecond, 789);
        expect(retrieved.updatedAt.isAtSameMomentAs(updatedAt), isTrue);
        expect(retrieved.updatedAt.millisecond, 123);
      } finally {
        await box.close();
      }
    });

    test(
        'PENDING_FAILURE program preserves pendingMissedDayKey across disk persistence',
        () async {
      const boxName = 'test_v2_pending_failure_disk';
      final createdAt = DateTime(2026, 10, 1, 3, 0);
      final updatedAt = DateTime(2026, 10, 19, 3, 5, 0, 456);

      final original = ProgramV2Model(
        id: 'prog-pending-fail',
        ibadahId: 'ibd-tahajjud',
        ibadahNameSnapshot: 'Tahajjud',
        targetDays: 40,
        startDayKey: '2026-10-01',
        status: ProgramV2Model.statusPendingFailure,
        reminderTime: '03:00',
        pendingMissedDayKey: '2026-10-18',
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      var box = await Hive.openBox<ProgramV2Model>(boxName);
      try {
        await box.put(original.id, original);
        await box.flush();
      } finally {
        await box.close();
      }

      box = await Hive.openBox<ProgramV2Model>(boxName);
      try {
        final retrieved = box.get(original.id);
        expect(retrieved, isNotNull);
        expect(retrieved!.status, ProgramV2Model.statusPendingFailure);
        expect(retrieved.pendingMissedDayKey, '2026-10-18');
        expect(
            DateService.isValidDayKey(retrieved.pendingMissedDayKey!), isTrue);
        expect(retrieved.finalizedAt, isNull);
        expect(retrieved.updatedAt.millisecond, 456);
      } finally {
        await box.close();
      }
    });

    test(
        'SUCCESS program preserves finalizedAt and recipientNameSnapshot across disk persistence',
        () async {
      const boxName = 'test_v2_success_disk';
      final createdAt = DateTime(2026, 9, 1, 3, 0);
      final finalizedAt = DateTime(2026, 10, 11, 4, 0, 0, 999);

      final original = ProgramV2Model(
        id: 'prog-success-disk',
        ibadahId: 'ibd-dhuha',
        ibadahNameSnapshot: 'Sholat Dhuha',
        targetDays: 40,
        startDayKey: '2026-09-01',
        status: ProgramV2Model.statusSuccess,
        reminderTime: '08:00',
        recipientNameSnapshot: 'Fulan bin Fulan',
        createdAt: createdAt,
        updatedAt: finalizedAt,
        finalizedAt: finalizedAt,
      );

      var box = await Hive.openBox<ProgramV2Model>(boxName);
      try {
        await box.put(original.id, original);
        await box.flush();
      } finally {
        await box.close();
      }

      box = await Hive.openBox<ProgramV2Model>(boxName);
      try {
        final retrieved = box.get(original.id);
        expect(retrieved, isNotNull);
        expect(retrieved!.status, ProgramV2Model.statusSuccess);
        expect(retrieved.recipientNameSnapshot, 'Fulan bin Fulan');
        expect(retrieved.finalizedAt, isNotNull);
        expect(retrieved.finalizedAt!.isAtSameMomentAs(finalizedAt), isTrue);
        expect(retrieved.finalizedAt!.millisecond, 999);
      } finally {
        await box.close();
      }
    });

    test(
        'FAILED and WARNING programs preserve restart lineage across disk persistence',
        () async {
      const boxName = 'test_v2_lineage_disk';
      final failedFinalized = DateTime(2026, 9, 20, 3, 15, 0, 789);
      final warningFinalized = DateTime(2026, 10, 20, 3, 30, 0, 456);
      final restartedCreated = DateTime(2026, 10, 20, 3, 35, 0, 100);

      // 1. Terminal FAILED program (< 40 days)
      final failedProg = ProgramV2Model(
        id: 'prog-failed-1',
        ibadahId: 'ibd-witir',
        ibadahNameSnapshot: 'Witir Malam',
        targetDays: 40,
        startDayKey: '2026-09-01',
        status: ProgramV2Model.statusFailed,
        createdAt: DateTime(2026, 9, 1, 3, 0),
        updatedAt: failedFinalized,
        finalizedAt: failedFinalized,
      );

      // 2. Terminal WARNING program (>= 40 days but before target)
      final warningProg = ProgramV2Model(
        id: 'prog-warning-1',
        ibadahId: 'ibd-tahajjud',
        ibadahNameSnapshot: 'Tahajjud Malam',
        targetDays: 60,
        startDayKey: '2026-09-01',
        status: ProgramV2Model.statusWarning,
        createdAt: DateTime(2026, 9, 1, 3, 0),
        updatedAt: warningFinalized,
        finalizedAt: warningFinalized,
      );

      // 3. Restarted ACTIVE program referencing archived predecessor
      final restartedProg = ProgramV2Model(
        id: 'prog-restarted-1',
        ibadahId: 'ibd-tahajjud',
        ibadahNameSnapshot: 'Tahajjud Malam',
        targetDays: 60,
        startDayKey: '2026-10-20',
        status: ProgramV2Model.statusActive,
        restartedFromProgramId: warningProg.id,
        createdAt: restartedCreated,
        updatedAt: restartedCreated,
      );

      // Phase 1: Write all 3 programs, flush to disk, and close
      var box = await Hive.openBox<ProgramV2Model>(boxName);
      try {
        await box.put(failedProg.id, failedProg);
        await box.put(warningProg.id, warningProg);
        await box.put(restartedProg.id, restartedProg);
        await box.flush();
      } finally {
        await box.close();
      }

      // Phase 2: Reopen from disk, retrieve and verify all fields
      box = await Hive.openBox<ProgramV2Model>(boxName);
      try {
        expect(box.length, 3);

        // Verify FAILED program
        final retrievedFailed = box.get('prog-failed-1');
        expect(retrievedFailed, isNotNull);
        expect(retrievedFailed!.id, 'prog-failed-1');
        expect(retrievedFailed.status, ProgramV2Model.statusFailed);
        expect(retrievedFailed.finalizedAt, isNotNull);
        expect(retrievedFailed.finalizedAt!.isAtSameMomentAs(failedFinalized),
            isTrue);
        expect(retrievedFailed.finalizedAt!.millisecond, 789);
        expect(retrievedFailed.restartedFromProgramId, isNull);

        // Verify WARNING program
        final retrievedWarning = box.get('prog-warning-1');
        expect(retrievedWarning, isNotNull);
        expect(retrievedWarning!.id, 'prog-warning-1');
        expect(retrievedWarning.status, ProgramV2Model.statusWarning);
        expect(retrievedWarning.finalizedAt, isNotNull);
        expect(retrievedWarning.finalizedAt!.isAtSameMomentAs(warningFinalized),
            isTrue);
        expect(retrievedWarning.finalizedAt!.millisecond, 456);
        expect(retrievedWarning.restartedFromProgramId, isNull);

        // Verify Restarted ACTIVE program
        final retrievedRestarted = box.get('prog-restarted-1');
        expect(retrievedRestarted, isNotNull);
        expect(retrievedRestarted!.id, 'prog-restarted-1');
        expect(retrievedRestarted.status, ProgramV2Model.statusActive);
        expect(retrievedRestarted.restartedFromProgramId, 'prog-warning-1');
        expect(retrievedRestarted.finalizedAt, isNull);
        expect(retrievedRestarted.ibadahNameSnapshot,
            equals(retrievedWarning.ibadahNameSnapshot));
      } finally {
        await box.close();
      }
    });

    test('Preserves UTC DateTime instances accurately via isAtSameMomentAs',
        () async {
      const boxName = 'test_v2_utc_disk';
      final utcCreatedAt = DateTime.utc(2026, 10, 18, 12, 0, 0, 555);
      final utcUpdatedAt = DateTime.utc(2026, 10, 18, 12, 5, 0, 666);

      final original = ProgramV2Model(
        id: 'prog-utc-disk',
        ibadahId: 'ibd-tilawah',
        ibadahNameSnapshot: 'Tilawah',
        targetDays: 100,
        startDayKey: '2026-10-18',
        status: ProgramV2Model.statusActive,
        createdAt: utcCreatedAt,
        updatedAt: utcUpdatedAt,
      );

      var box = await Hive.openBox<ProgramV2Model>(boxName);
      try {
        await box.put(original.id, original);
        await box.flush();
      } finally {
        await box.close();
      }

      box = await Hive.openBox<ProgramV2Model>(boxName);
      try {
        final retrieved = box.get(original.id);
        expect(retrieved, isNotNull);
        expect(retrieved!.createdAt.isAtSameMomentAs(utcCreatedAt), isTrue);
        expect(retrieved.createdAt.millisecondsSinceEpoch,
            equals(utcCreatedAt.millisecondsSinceEpoch));
        expect(retrieved.updatedAt.isAtSameMomentAs(utcUpdatedAt), isTrue);
        expect(retrieved.updatedAt.millisecondsSinceEpoch,
            equals(utcUpdatedAt.millisecondsSinceEpoch));
      } finally {
        await box.close();
      }
    });
  });
}
