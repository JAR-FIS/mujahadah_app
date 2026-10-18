import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mujahadah/core/date/date_service.dart';
import 'package:mujahadah/models/achievement_model.dart';
import 'package:mujahadah/models/daily_checkin_model.dart';
import 'package:mujahadah/models/failure_record_model.dart';
import 'package:mujahadah/models/ibadah_model.dart';
import 'package:mujahadah/models/program_model.dart';
import 'package:mujahadah/models/user_model.dart';

void main() {
  late Directory tempDir;
  late DateService dateService;

  setUpAll(() async {
    tempDir =
        Directory.systemTemp.createTempSync('mujahadah_hive_models_test_');
    Hive.init(tempDir.path);

    // Register existing V1 adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(UserModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(IbadahModelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ProgramModelAdapter());
    }

    // Register new V2 adapters
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(DailyCheckInModelAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(FailureRecordModelAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(AchievementModelAdapter());
    }

    dateService = DateService();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Hive Safety & TypeID Collision Prevention', () {
    test('New adapters define exact expected typeIds', () {
      expect(DailyCheckInModelAdapter().typeId, 3);
      expect(FailureRecordModelAdapter().typeId, 4);
      expect(AchievementModelAdapter().typeId, 5);
    });

    test('All registered adapters have distinct, non-colliding typeIds', () {
      final List<TypeAdapter<dynamic>> adapters = [
        UserModelAdapter(),
        IbadahModelAdapter(),
        ProgramModelAdapter(),
        DailyCheckInModelAdapter(),
        FailureRecordModelAdapter(),
        AchievementModelAdapter(),
      ];

      final typeIds = adapters.map((a) => a.typeId).toList();
      final uniqueTypeIds = typeIds.toSet();

      expect(uniqueTypeIds.length, equals(adapters.length),
          reason: 'Every adapter must have a unique typeId');
      expect(typeIds, equals([0, 1, 2, 3, 4, 5]));
    });

    test('Temporary storage is isolated from production application data', () {
      expect(tempDir.existsSync(), isTrue);
      expect(tempDir.path, contains('mujahadah_hive_models_test_'));
    });
  });

  group('DailyCheckInModel Contract & Persistence', () {
    test('Constructor instantiates all fields correctly', () {
      final checkedAt = DateTime(2026, 10, 18, 5, 30, 0);
      final createdAt = DateTime(2026, 10, 18, 5, 30, 1);
      final dayKey = dateService.getMujahadahDayKey(checkedAt);

      final record = DailyCheckInModel(
        id: 'checkin-001',
        programId: 'prog-100',
        dayKey: dayKey,
        checkedAt: checkedAt,
        createdAt: createdAt,
      );

      expect(record.id, 'checkin-001');
      expect(record.programId, 'prog-100');
      expect(record.dayKey, '2026-10-18');
      expect(DateService.isValidDayKey(record.dayKey), isTrue);
      expect(record.checkedAt, checkedAt);
      expect(record.createdAt, createdAt);
    });

    test('Preserves exact timestamps and DateService dayKey contract', () {
      // 02:45 is before 03:00 boundary, so dayKey belongs to 2026-10-17
      final checkedAt = DateTime(2026, 10, 18, 2, 45, 12, 345);
      final createdAt = DateTime(2026, 10, 18, 2, 45, 13);
      final dayKey = dateService.getMujahadahDayKey(checkedAt);

      final record = DailyCheckInModel(
        id: 'checkin-early',
        programId: 'prog-tahajjud',
        dayKey: dayKey,
        checkedAt: checkedAt,
        createdAt: createdAt,
      );

      expect(record.dayKey, '2026-10-17');
      expect(record.checkedAt.millisecond, 345);
      expect(DateService.isValidDayKey(record.dayKey), isTrue);
    });

    test('Hive in-memory serialization and deserialization round trip',
        () async {
      final box = await Hive.openBox<DailyCheckInModel>('test_daily_checkin');
      try {
        final checkedAt = DateTime(2026, 10, 18, 6, 0, 0);
        final createdAt = DateTime(2026, 10, 18, 6, 0, 5);

        final original = DailyCheckInModel(
          id: 'checkin-roundtrip-1',
          programId: 'prog-subuh',
          dayKey: '2026-10-18',
          checkedAt: checkedAt,
          createdAt: createdAt,
        );

        await box.put(original.id, original);

        final retrieved = box.get(original.id);
        expect(retrieved, isNotNull);
        expect(retrieved!.id, original.id);
        expect(retrieved.programId, original.programId);
        expect(retrieved.dayKey, original.dayKey);
        expect(
            retrieved.checkedAt.isAtSameMomentAs(original.checkedAt), isTrue);
        expect(
            retrieved.createdAt.isAtSameMomentAs(original.createdAt), isTrue);
      } finally {
        await box.close();
      }
    });

    test('Persistent disk round-trip survives box close and reopen', () async {
      const boxName = 'test_checkin_disk_reopen';
      final checkedAt = DateTime(2026, 10, 18, 5, 30, 45, 789);
      final createdAt = DateTime(2026, 10, 18, 5, 30, 46, 100);

      final original = DailyCheckInModel(
        id: 'checkin-disk-1',
        programId: 'prog-disk',
        dayKey: '2026-10-18',
        checkedAt: checkedAt,
        createdAt: createdAt,
      );

      // Phase 1: Write to box, flush, and close
      var box = await Hive.openBox<DailyCheckInModel>(boxName);
      try {
        await box.put(original.id, original);
        await box.flush();
      } finally {
        await box.close();
      }

      // Phase 2: Reopen box from disk and verify persistence
      box = await Hive.openBox<DailyCheckInModel>(boxName);
      try {
        final retrieved = box.get(original.id);
        expect(retrieved, isNotNull);
        expect(retrieved!.id, original.id);
        expect(retrieved.programId, original.programId);
        expect(retrieved.dayKey, original.dayKey);
        expect(
            retrieved.checkedAt.isAtSameMomentAs(original.checkedAt), isTrue);
        expect(retrieved.checkedAt.millisecond, 789);
        expect(
            retrieved.createdAt.isAtSameMomentAs(original.createdAt), isTrue);
        expect(retrieved.createdAt.millisecond, 100);
      } finally {
        await box.close();
      }
    });

    test('Multiple records across separate day keys can be stored and reopened',
        () async {
      const boxName = 'test_checkin_multi_reopen';
      final dayKeys = ['2026-10-18', '2026-10-19', '2026-10-20'];

      // Write 3 records, flush, close
      var box = await Hive.openBox<DailyCheckInModel>(boxName);
      try {
        for (var i = 0; i < dayKeys.length; i++) {
          final record = DailyCheckInModel(
            id: 'checkin-$i',
            programId: 'prog-dhuha',
            dayKey: dayKeys[i],
            checkedAt: DateTime(2026, 10, 18 + i, 8, 30),
            createdAt: DateTime(2026, 10, 18 + i, 8, 30, 1),
          );
          await box.put(record.id, record);
        }
        await box.flush();
      } finally {
        await box.close();
      }

      // Reopen and verify
      box = await Hive.openBox<DailyCheckInModel>(boxName);
      try {
        expect(box.length, 3);
        for (var i = 0; i < dayKeys.length; i++) {
          final retrieved = box.get('checkin-$i');
          expect(retrieved, isNotNull);
          expect(retrieved!.dayKey, dayKeys[i]);
          expect(DateService.isValidDayKey(retrieved.dayKey), isTrue);
        }
      } finally {
        await box.close();
      }
    });
  });

  group('FailureRecordModel Contract & Persistence', () {
    test('Constructor instantiates all required and optional fields', () {
      final createdAt = DateTime(2026, 10, 19, 3, 1, 0);
      final record = FailureRecordModel(
        id: 'fail-001',
        programId: 'prog-100',
        missedDayKey: '2026-10-18',
        reasonCode: 'OVERTIRED',
        reasonLabelSnapshot: 'Terlalu lelah / tertidur',
        note: 'Lembur pekerjaan hingga larut malam',
        createdAt: createdAt,
      );

      expect(record.id, 'fail-001');
      expect(record.programId, 'prog-100');
      expect(record.missedDayKey, '2026-10-18');
      expect(record.reasonCode, 'OVERTIRED');
      expect(record.reasonLabelSnapshot, 'Terlalu lelah / tertidur');
      expect(record.note, 'Lembur pekerjaan hingga larut malam');
      expect(record.createdAt, createdAt);
    });

    test('Reason code remains independent of presentation label snapshot', () {
      final record = FailureRecordModel(
        id: 'fail-intl',
        programId: 'prog-200',
        missedDayKey: '2026-10-18',
        reasonCode: 'SICK',
        reasonLabelSnapshot: 'Sakit / Tidak enak badan',
        createdAt: DateTime(2026, 10, 19, 3, 0),
      );

      expect(record.reasonCode, 'SICK');
      expect(record.reasonLabelSnapshot, 'Sakit / Tidak enak badan');
      expect(record.note, isNull);
    });

    test('Null note is safely preserved', () {
      final record = FailureRecordModel(
        id: 'fail-null-note',
        programId: 'prog-300',
        missedDayKey: '2026-10-18',
        reasonCode: 'FORGOT',
        reasonLabelSnapshot: 'Lupa',
        note: null,
        createdAt: DateTime(2026, 10, 19, 3, 5),
      );

      expect(record.note, isNull);
    });

    test('Persistent disk round-trip across box close and reopen (with note)',
        () async {
      const boxName = 'test_failure_reopen_note';
      final createdAt = DateTime(2026, 10, 19, 3, 2, 10, 654);

      final original = FailureRecordModel(
        id: 'fail-box-reopen-1',
        programId: 'prog-rawatib',
        missedDayKey: '2026-10-18',
        reasonCode: 'TRAVELING',
        reasonLabelSnapshot: 'Sedang dalam perjalanan (Safar)',
        note: 'Penerbangan malam delay',
        createdAt: createdAt,
      );

      // Phase 1: Write, flush, close
      var box = await Hive.openBox<FailureRecordModel>(boxName);
      try {
        await box.put(original.id, original);
        await box.flush();
      } finally {
        await box.close();
      }

      // Phase 2: Reopen from disk, retrieve and verify
      box = await Hive.openBox<FailureRecordModel>(boxName);
      try {
        final retrieved = box.get(original.id);
        expect(retrieved, isNotNull);
        expect(retrieved!.id, original.id);
        expect(retrieved.programId, original.programId);
        expect(retrieved.missedDayKey, original.missedDayKey);
        expect(retrieved.reasonCode, original.reasonCode);
        expect(retrieved.reasonLabelSnapshot, original.reasonLabelSnapshot);
        expect(retrieved.note, 'Penerbangan malam delay');
        expect(
            retrieved.createdAt.isAtSameMomentAs(original.createdAt), isTrue);
        expect(retrieved.createdAt.millisecond, 654);
      } finally {
        await box.close();
      }
    });

    test('Persistent disk round-trip across box close and reopen (null note)',
        () async {
      const boxName = 'test_failure_reopen_null_note';
      final createdAt = DateTime(2026, 10, 19, 3, 10, 0, 111);

      final original = FailureRecordModel(
        id: 'fail-box-reopen-2',
        programId: 'prog-rawatib',
        missedDayKey: '2026-10-18',
        reasonCode: 'OTHER',
        reasonLabelSnapshot: 'Lainnya',
        note: null,
        createdAt: createdAt,
      );

      // Phase 1: Write, flush, close
      var box = await Hive.openBox<FailureRecordModel>(boxName);
      try {
        await box.put(original.id, original);
        await box.flush();
      } finally {
        await box.close();
      }

      // Phase 2: Reopen from disk, retrieve and verify
      box = await Hive.openBox<FailureRecordModel>(boxName);
      try {
        final retrieved = box.get(original.id);
        expect(retrieved, isNotNull);
        expect(retrieved!.id, original.id);
        expect(retrieved.programId, original.programId);
        expect(retrieved.missedDayKey, original.missedDayKey);
        expect(retrieved.reasonCode, 'OTHER');
        expect(retrieved.reasonLabelSnapshot, 'Lainnya');
        expect(retrieved.note, isNull);
        expect(
            retrieved.createdAt.isAtSameMomentAs(original.createdAt), isTrue);
        expect(retrieved.createdAt.millisecond, 111);
      } finally {
        await box.close();
      }
    });
  });

  group('AchievementModel Contract & Persistence', () {
    test('MILESTONE record can be constructed and fields preserved', () {
      final achievedAt = DateTime(2026, 11, 27, 4, 0, 0);
      final createdAt = DateTime(2026, 11, 27, 4, 0, 1);

      final record = AchievementModel(
        id: 'ach-40',
        programId: 'prog-tahajjud-40',
        type: AchievementModel.typeMilestone,
        milestoneDays: 40,
        achievedAt: achievedAt,
        recipientNameSnapshot: 'Ahmad Fauzi',
        createdAt: createdAt,
      );

      expect(record.id, 'ach-40');
      expect(record.programId, 'prog-tahajjud-40');
      expect(record.type, 'MILESTONE');
      expect(record.milestoneDays, 40);
      expect(record.achievedAt, achievedAt);
      expect(record.recipientNameSnapshot, 'Ahmad Fauzi');
      expect(record.createdAt, createdAt);
    });

    test('FINAL_SUCCESS record can be constructed with null recipient name',
        () {
      final achievedAt = DateTime(2027, 1, 26, 5, 0, 0);
      final createdAt = DateTime(2027, 1, 26, 5, 0, 2);

      final record = AchievementModel(
        id: 'ach-100-final',
        programId: 'prog-tahajjud-100',
        type: AchievementModel.typeFinalSuccess,
        milestoneDays: 100,
        achievedAt: achievedAt,
        recipientNameSnapshot: null,
        createdAt: createdAt,
      );

      expect(record.id, 'ach-100-final');
      expect(record.programId, 'prog-tahajjud-100');
      expect(record.type, 'FINAL_SUCCESS');
      expect(record.milestoneDays, 100);
      expect(record.achievedAt, achievedAt);
      expect(record.recipientNameSnapshot, isNull);
      expect(record.createdAt, createdAt);
    });

    test(
        'Persistent disk round-trip across box close and reopen for MILESTONE (with recipient)',
        () async {
      const boxName = 'test_ach_reopen_milestone';
      final achievedAt = DateTime(2026, 11, 27, 4, 30, 15, 333);
      final createdAt = DateTime(2026, 11, 27, 4, 30, 16, 444);

      final original = AchievementModel(
        id: 'ach-reopen-ms',
        programId: 'prog-qiyam',
        type: AchievementModel.typeMilestone,
        milestoneDays: 40,
        achievedAt: achievedAt,
        recipientNameSnapshot: 'Muhammad Rizki',
        createdAt: createdAt,
      );

      // Phase 1: Write, flush, close
      var box = await Hive.openBox<AchievementModel>(boxName);
      try {
        await box.put(original.id, original);
        await box.flush();
      } finally {
        await box.close();
      }

      // Phase 2: Reopen from disk, retrieve and verify
      box = await Hive.openBox<AchievementModel>(boxName);
      try {
        final retrieved = box.get(original.id);
        expect(retrieved, isNotNull);
        expect(retrieved!.id, original.id);
        expect(retrieved.programId, original.programId);
        expect(retrieved.type, AchievementModel.typeMilestone);
        expect(retrieved.milestoneDays, 40);
        expect(
            retrieved.achievedAt.isAtSameMomentAs(original.achievedAt), isTrue);
        expect(retrieved.achievedAt.millisecond, 333);
        expect(retrieved.recipientNameSnapshot, 'Muhammad Rizki');
        expect(
            retrieved.createdAt.isAtSameMomentAs(original.createdAt), isTrue);
        expect(retrieved.createdAt.millisecond, 444);
      } finally {
        await box.close();
      }
    });

    test(
        'Persistent disk round-trip across box close and reopen for FINAL_SUCCESS (null recipient)',
        () async {
      const boxName = 'test_ach_reopen_final';
      final achievedAt = DateTime(2026, 12, 7, 5, 0, 10, 555);
      final createdAt = DateTime(2026, 12, 7, 5, 0, 11, 666);

      final original = AchievementModel(
        id: 'ach-reopen-final',
        programId: 'prog-qiyam',
        type: AchievementModel.typeFinalSuccess,
        milestoneDays: 60,
        achievedAt: achievedAt,
        recipientNameSnapshot: null,
        createdAt: createdAt,
      );

      // Phase 1: Write, flush, close
      var box = await Hive.openBox<AchievementModel>(boxName);
      try {
        await box.put(original.id, original);
        await box.flush();
      } finally {
        await box.close();
      }

      // Phase 2: Reopen from disk, retrieve and verify
      box = await Hive.openBox<AchievementModel>(boxName);
      try {
        final retrieved = box.get(original.id);
        expect(retrieved, isNotNull);
        expect(retrieved!.id, original.id);
        expect(retrieved.programId, original.programId);
        expect(retrieved.type, AchievementModel.typeFinalSuccess);
        expect(retrieved.milestoneDays, 60);
        expect(retrieved.recipientNameSnapshot, isNull);
        expect(
            retrieved.achievedAt.isAtSameMomentAs(original.achievedAt), isTrue);
        expect(retrieved.achievedAt.millisecond, 555);
        expect(
            retrieved.createdAt.isAtSameMomentAs(original.createdAt), isTrue);
        expect(retrieved.createdAt.millisecond, 666);
      } finally {
        await box.close();
      }
    });
  });

  group('Timestamp Persistence & Operational Boundary Instant Verification',
      () {
    test(
        'Exact timestamps preserved at millisecond precision across disk persistence',
        () async {
      const boxName = 'test_ts_precision_disk';
      final checkedAt = DateTime(2026, 10, 18, 4, 15, 30, 891);
      final createdAt = DateTime(2026, 10, 18, 4, 15, 31, 23);

      final original = DailyCheckInModel(
        id: 'checkin-ts-precision',
        programId: 'prog-precision',
        dayKey: '2026-10-18',
        checkedAt: checkedAt,
        createdAt: createdAt,
      );

      var box = await Hive.openBox<DailyCheckInModel>(boxName);
      try {
        await box.put(original.id, original);
        await box.flush();
      } finally {
        await box.close();
      }

      box = await Hive.openBox<DailyCheckInModel>(boxName);
      try {
        final retrieved = box.get(original.id);
        expect(retrieved, isNotNull);
        expect(retrieved!.checkedAt.isAtSameMomentAs(checkedAt), isTrue);
        expect(retrieved.checkedAt.millisecond, equals(891));
        expect(retrieved.checkedAt.millisecondsSinceEpoch,
            equals(checkedAt.millisecondsSinceEpoch));
        expect(retrieved.createdAt.isAtSameMomentAs(createdAt), isTrue);
        expect(retrieved.createdAt.millisecond, equals(23));
        expect(retrieved.createdAt.millisecondsSinceEpoch,
            equals(createdAt.millisecondsSinceEpoch));
      } finally {
        await box.close();
      }
    });

    test(
        'Check-in immediately before 03:00 boundary (02:59:59.999) persists previous dayKey',
        () async {
      const boxName = 'test_boundary_before_0300';
      // Local 02:59:59.999 is part of the previous Mujahadah day
      final checkedAt = DateTime(2026, 10, 18, 2, 59, 59, 999);
      final dayKey = dateService.getMujahadahDayKey(checkedAt);
      expect(dayKey, equals('2026-10-17'));

      final original = DailyCheckInModel(
        id: 'checkin-boundary-prev',
        programId: 'prog-tahajjud',
        dayKey: dayKey,
        checkedAt: checkedAt,
        createdAt: DateTime(2026, 10, 18, 3, 0, 0),
      );

      var box = await Hive.openBox<DailyCheckInModel>(boxName);
      try {
        await box.put(original.id, original);
        await box.flush();
      } finally {
        await box.close();
      }

      box = await Hive.openBox<DailyCheckInModel>(boxName);
      try {
        final retrieved = box.get(original.id);
        expect(retrieved, isNotNull);
        expect(retrieved!.dayKey, equals('2026-10-17'));
        expect(retrieved.checkedAt.isAtSameMomentAs(checkedAt), isTrue);
        expect(DateService.isValidDayKey(retrieved.dayKey), isTrue);
        expect(dateService.isInMujahadahDay(retrieved.checkedAt, '2026-10-17'),
            isTrue);
        expect(dateService.isInMujahadahDay(retrieved.checkedAt, '2026-10-18'),
            isFalse);
      } finally {
        await box.close();
      }
    });

    test(
        'Check-in exactly at 03:00 boundary (03:00:00.000) persists new dayKey',
        () async {
      const boxName = 'test_boundary_exact_0300';
      // Local 03:00:00.000 begins the new Mujahadah day
      final checkedAt = DateTime(2026, 10, 18, 3, 0, 0, 0);
      final dayKey = dateService.getMujahadahDayKey(checkedAt);
      expect(dayKey, equals('2026-10-18'));

      final original = DailyCheckInModel(
        id: 'checkin-boundary-curr',
        programId: 'prog-subuh',
        dayKey: dayKey,
        checkedAt: checkedAt,
        createdAt: DateTime(2026, 10, 18, 3, 0, 1),
      );

      var box = await Hive.openBox<DailyCheckInModel>(boxName);
      try {
        await box.put(original.id, original);
        await box.flush();
      } finally {
        await box.close();
      }

      box = await Hive.openBox<DailyCheckInModel>(boxName);
      try {
        final retrieved = box.get(original.id);
        expect(retrieved, isNotNull);
        expect(retrieved!.dayKey, equals('2026-10-18'));
        expect(retrieved.checkedAt.isAtSameMomentAs(checkedAt), isTrue);
        expect(DateService.isValidDayKey(retrieved.dayKey), isTrue);
        expect(dateService.isInMujahadahDay(retrieved.checkedAt, '2026-10-18'),
            isTrue);
        expect(dateService.isInMujahadahDay(retrieved.checkedAt, '2026-10-17'),
            isFalse);
      } finally {
        await box.close();
      }
    });

    test(
        'UTC timestamp round-trip preserves exact same instant via isAtSameMomentAs',
        () async {
      const boxName = 'test_utc_instant_roundtrip';
      final utcInstant = DateTime.utc(2026, 10, 18, 14, 30, 45, 678);
      final derivedDayKey = dateService.getMujahadahDayKey(utcInstant);

      final original = DailyCheckInModel(
        id: 'checkin-utc',
        programId: 'prog-utc',
        dayKey: derivedDayKey,
        checkedAt: utcInstant,
        createdAt: utcInstant,
      );

      var box = await Hive.openBox<DailyCheckInModel>(boxName);
      try {
        await box.put(original.id, original);
        await box.flush();
      } finally {
        await box.close();
      }

      box = await Hive.openBox<DailyCheckInModel>(boxName);
      try {
        final retrieved = box.get(original.id);
        expect(retrieved, isNotNull);
        expect(retrieved!.checkedAt.isAtSameMomentAs(utcInstant), isTrue);
        expect(retrieved.checkedAt.millisecondsSinceEpoch,
            equals(utcInstant.millisecondsSinceEpoch));
        expect(retrieved.dayKey, equals(derivedDayKey));
      } finally {
        await box.close();
      }
    });

    test(
        'Check-in timestamp and DateService-derived dayKey remain consistent after disk retrieval',
        () async {
      const boxName = 'test_consistency_check';
      final sampleInstants = [
        DateTime(2026, 10, 18, 0, 15), // maps to 2026-10-17
        DateTime(2026, 10, 18, 2, 59), // maps to 2026-10-17
        DateTime(2026, 10, 18, 3, 0), // maps to 2026-10-18
        DateTime(2026, 10, 18, 12, 30), // maps to 2026-10-18
        DateTime(2026, 10, 18, 23, 45), // maps to 2026-10-18
      ];

      var box = await Hive.openBox<DailyCheckInModel>(boxName);
      try {
        for (var i = 0; i < sampleInstants.length; i++) {
          final instant = sampleInstants[i];
          final expectedDayKey = dateService.getMujahadahDayKey(instant);
          final record = DailyCheckInModel(
            id: 'consistency-$i',
            programId: 'prog-consistency',
            dayKey: expectedDayKey,
            checkedAt: instant,
            createdAt: instant,
          );
          await box.put(record.id, record);
        }
        await box.flush();
      } finally {
        await box.close();
      }

      box = await Hive.openBox<DailyCheckInModel>(boxName);
      try {
        for (var i = 0; i < sampleInstants.length; i++) {
          final retrieved = box.get('consistency-$i');
          expect(retrieved, isNotNull);
          // Key consistency contract:
          // The stored dayKey must match what DateService produces from the retrieved checkedAt instant
          final rederivedDayKey =
              dateService.getMujahadahDayKey(retrieved!.checkedAt);
          expect(retrieved.dayKey, equals(rederivedDayKey));
          expect(
              dateService.isInMujahadahDay(
                  retrieved.checkedAt, retrieved.dayKey),
              isTrue);
        }
      } finally {
        await box.close();
      }
    });
  });
}
