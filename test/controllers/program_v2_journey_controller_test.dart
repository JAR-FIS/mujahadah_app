import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:mujahadah/controllers/ibadah_controller.dart';
import 'package:mujahadah/controllers/main_controller.dart';
import 'package:mujahadah/controllers/program_v2_journey_controller.dart';
import 'package:mujahadah/core/date/date_service.dart';
import 'package:mujahadah/core/runtime/program_v2_lifecycle_coordinator.dart';
import 'package:mujahadah/core/runtime/v2_recipient_name_provider.dart';
import 'package:mujahadah/core/runtime/v2_runtime.dart';
import 'package:mujahadah/models/achievement_model.dart';
import 'package:mujahadah/models/daily_checkin_model.dart';
import 'package:mujahadah/models/failure_record_model.dart';
import 'package:mujahadah/models/ibadah_model.dart';
import 'package:mujahadah/models/program_model.dart';
import 'package:mujahadah/models/program_v2_model.dart';
import 'package:mujahadah/models/user_model.dart';
import 'package:mujahadah/services/program_v2_journey_orchestrator.dart';
import 'package:mujahadah/views/screens/main_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<ProgramV2Model> programBox;
  late Box<DailyCheckInModel> checkInBox;
  late Box<AchievementModel> achievementBox;
  late Box<FailureRecordModel> failureBox;
  late Box<ProgramModel> v1ProgramBox;

  late DateTime currentClock;
  late DateService dateService;
  late V2Runtime runtime;
  late ProgramV2JourneyController controller;
  late ProgramV2LifecycleCoordinator coordinator;

  String getOffsetDayKey(DateTime start, int offset) {
    final d = DateTime.utc(start.year, start.month, start.day + offset);
    return DateService.formatCalendarDayKey(d);
  }

  Future<void> seedProgram({
    required String id,
    required String startDayKey,
    int targetDays = 40,
    String status = ProgramV2Model.statusActive,
    String? pendingMissedDayKey,
    String? recipientNameSnapshot,
    DateTime? finalizedAt,
  }) async {
    final p = ProgramV2Model(
      id: id,
      ibadahId: 'ibadah_tahajjud',
      ibadahNameSnapshot: 'Tahajjud',
      targetDays: targetDays,
      startDayKey: startDayKey,
      status: status,
      pendingMissedDayKey: pendingMissedDayKey,
      recipientNameSnapshot: recipientNameSnapshot,
      finalizedAt: finalizedAt,
      createdAt: currentClock,
      updatedAt: currentClock,
    );
    await runtime.programRepository.save(p);
  }

  Future<void> seedCheckIns({
    required String programId,
    required List<String> dayKeys,
  }) async {
    for (final day in dayKeys) {
      final id = '${day}_$programId';
      final dt = DateService.parseDayKey(day);
      final checkInTime = DateTime(dt.year, dt.month, dt.day, 5, 0, 0);
      final checkIn = DailyCheckInModel(
        id: id,
        programId: programId,
        dayKey: day,
        checkedAt: checkInTime,
        createdAt: checkInTime,
      );
      await runtime.checkInRepository.box.put(id, checkIn);
    }
  }

  setUpAll(() {
    // Register all legacy V1 adapters for collision & isolation testing
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(UserModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(IbadahModelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ProgramModelAdapter());
    }

    // Register V2 adapters via V2Runtime
    V2Runtime.registerAdapters();
  });

  setUp(() async {
    Get.reset();
    tempDir = Directory.systemTemp.createTempSync('v2_runtime_wiring_test_');
    Hive.init(tempDir.path);

    programBox = await Hive.openBox<ProgramV2Model>(V2Runtime.programsBoxName);
    checkInBox =
        await Hive.openBox<DailyCheckInModel>(V2Runtime.dailyCheckInsBoxName);
    achievementBox =
        await Hive.openBox<AchievementModel>(V2Runtime.achievementsBoxName);
    failureBox =
        await Hive.openBox<FailureRecordModel>(V2Runtime.failureRecordsBoxName);

    // Open legacy V1 box to verify non-interference
    v1ProgramBox = await Hive.openBox<ProgramModel>('program');

    currentClock = DateTime(2026, 10, 18, 5, 0, 0);
    dateService = DateService(nowProvider: () => currentClock);

    runtime = V2Runtime.fromBoxes(
      programBox: programBox,
      checkInBox: checkInBox,
      failureBox: failureBox,
      achievementBox: achievementBox,
      dateService: dateService,
      recipientNameProvider: const UnavailableRecipientNameProvider(),
    );

    controller = runtime.createJourneyController();
    coordinator = runtime.createLifecycleCoordinator(controller: controller);
  });

  tearDown(() async {
    coordinator.dispose();
    await programBox.close();
    await checkInBox.close();
    await achievementBox.close();
    await failureBox.close();
    await v1ProgramBox.close();

    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('V2 Runtime & Wiring Foundation Tests', () {
    test('1. All V2 adapters registered successfully', () {
      expect(Hive.isAdapterRegistered(3), isTrue,
          reason: 'DailyCheckInModelAdapter (typeId 3) registered');
      expect(Hive.isAdapterRegistered(4), isTrue,
          reason: 'FailureRecordModelAdapter (typeId 4) registered');
      expect(Hive.isAdapterRegistered(5), isTrue,
          reason: 'AchievementModelAdapter (typeId 5) registered');
      expect(Hive.isAdapterRegistered(6), isTrue,
          reason: 'ProgramV2ModelAdapter (typeId 6) registered');
    });

    test('2. No duplicate adapter registration on repeated initialization', () {
      // Calling registerAdapters repeatedly must be idempotent and non-throwing
      expect(() {
        V2Runtime.registerAdapters();
        V2Runtime.registerAdapters();
        V2Runtime.registerAdapters();
      }, returnsNormally);

      expect(Hive.isAdapterRegistered(3), isTrue);
      expect(Hive.isAdapterRegistered(4), isTrue);
      expect(Hive.isAdapterRegistered(5), isTrue);
      expect(Hive.isAdapterRegistered(6), isTrue);
    });

    test('3. V2 box names do not collide with V1 storage', () {
      const v1BoxNames = ['settings', 'user', 'ibadah', 'program'];

      expect(V2Runtime.programsBoxName, 'programs_v2');
      expect(V2Runtime.dailyCheckInsBoxName, 'daily_checkins_v2');
      expect(V2Runtime.failureRecordsBoxName, 'failure_records_v2');
      expect(V2Runtime.achievementsBoxName, 'achievements_v2');

      for (final boxName in V2Runtime.allV2BoxNames) {
        expect(v1BoxNames.contains(boxName), isFalse,
            reason: 'V2 box name "$boxName" must not collide with V1 storage');
      }
    });

    test(
        '4. Repository and domain service dependencies are shared consistently',
        () {
      expect(runtime.programRepository.box, same(programBox));
      expect(runtime.checkInRepository.box, same(checkInBox));
      expect(runtime.failureRecordRepository.box, same(failureBox));
      expect(runtime.achievementRepository.box, same(achievementBox));

      expect(runtime.orchestrator, isNotNull);
      expect(runtime.dailyCheckInService, isNotNull);
      expect(runtime.reconciliationService, isNotNull);
      expect(runtime.muhasabahService, isNotNull);
      expect(runtime.successService, isNotNull);
      expect(runtime.creationService, isNotNull);
    });

    test('5. Composition root constructs the approved orchestrator', () {
      expect(runtime.orchestrator, isA<ProgramV2JourneyOrchestrator>());
      final ctrl = runtime.createJourneyController();
      expect(ctrl, isA<ProgramV2JourneyController>());
      final coord = runtime.createLifecycleCoordinator();
      expect(coord, isA<ProgramV2LifecycleCoordinator>());
    });

    test('6. V2 controller confirmed check-in delegates to orchestrator',
        () async {
      await seedProgram(id: 'prog_1', startDayKey: '2026-10-18');

      final result = await controller.checkIn(
        programId: 'prog_1',
        confirmedByUser: true,
      );

      expect(result.isSuccess, isTrue);
      expect(result.outcome, OrchestratedCheckInOutcome.checkInCompleted);
      expect(controller.lastCheckInResult.value, equals(result));
      expect(controller.completedCheckIns['prog_1'], isNotNull);
      expect(runtime.checkInRepository.getAll().length, 1);
    });

    test('7. Controller cancellation does not write a check-in', () async {
      await seedProgram(id: 'prog_1', startDayKey: '2026-10-18');

      final result = await controller.checkIn(
        programId: 'prog_1',
        confirmedByUser: false,
      );

      expect(result.isSuccess, isFalse);
      expect(result.outcome, OrchestratedCheckInOutcome.confirmationRequired);
      expect(runtime.checkInRepository.getAll(), isEmpty);
    });

    test('8. Muhasabah required is represented as a pending user action',
        () async {
      await seedProgram(id: 'prog_1', startDayKey: '2026-10-18');
      // Advance clock past 03:00 boundary to day 20 (missed day 18 and 19)
      currentClock = DateTime(2026, 10, 20, 5, 0, 0);

      final result = await controller.checkIn(
        programId: 'prog_1',
        confirmedByUser: true,
      );

      expect(result.isSuccess, isFalse);
      expect(result.isMuhasabahRequired, isTrue);
      expect(result.outcome, OrchestratedCheckInOutcome.muhasabahRequired);
      expect(controller.pendingMuhasabahActions['prog_1'], '2026-10-18');
      expect(runtime.checkInRepository.getAll(), isEmpty);
    });

    test('9. Missing Muhasabah reason is rejected', () async {
      await seedProgram(
        id: 'prog_1',
        startDayKey: '2026-10-18',
        status: ProgramV2Model.statusPendingFailure,
        pendingMissedDayKey: '2026-10-18',
      );

      final result = await controller.submitMuhasabah(
        programId: 'prog_1',
        reasonCode: '   ',
        reasonLabelSnapshot: '',
      );

      expect(result.isSuccess, isFalse);
      expect(result.outcome, OrchestratedMuhasabahOutcome.invalidReason);
      expect(runtime.failureRecordRepository.getAll(), isEmpty);
      expect(runtime.programRepository.getById('prog_1')!.status,
          ProgramV2Model.statusPendingFailure);
    });

    test(
        '10. SUCCESS Finalization and Achievement recovery results are preserved',
        () async {
      final start = DateService.parseDayKey('2026-09-01');
      final days = List.generate(40, (i) => getOffsetDayKey(start, i));
      await seedProgram(
          id: 'prog_1', startDayKey: '2026-09-01', targetDays: 40);
      await seedCheckIns(programId: 'prog_1', dayKeys: days);

      final result = await controller.finalizeSuccess(
        programId: 'prog_1',
        recipientNameSnapshot: 'Haji Ahmad Dahlan',
      );

      expect(result.isSuccess, isTrue);
      expect(result.outcome, OrchestratedSuccessOutcome.successFinalized);
      expect(controller.finalizationStatuses['prog_1'],
          ProgramV2Model.statusSuccess);
      expect(runtime.achievementRepository.getAll().length, 1);
    });

    test('11. Missing recipient name is represented without fabrication',
        () async {
      final start = DateService.parseDayKey('2026-09-01');
      final days = List.generate(40, (i) => getOffsetDayKey(start, i));
      await seedProgram(
          id: 'prog_1', startDayKey: '2026-09-01', targetDays: 40);
      await seedCheckIns(programId: 'prog_1', dayKeys: days);

      // Using controller with UnavailableRecipientNameProvider and no snapshot parameter
      final result = await controller.finalizeSuccess(programId: 'prog_1');

      expect(result.isSuccess, isFalse);
      expect(result.outcome, OrchestratedSuccessOutcome.invalidRecipientName);
      expect(controller.needsRecipientNameActions.contains('prog_1'), isTrue);
      expect(runtime.achievementRepository.getAll(), isEmpty);
      expect(runtime.checkInRepository.getAll().length, 40);
    });

    test('12. Initial reconciliation is callable explicitly', () async {
      await seedProgram(id: 'prog_1', startDayKey: '2026-10-18');
      await seedProgram(id: 'prog_2', startDayKey: '2026-10-18');

      final result = await coordinator.handleStartup(capturedNow: currentClock);

      expect(result.items.length, 2);
      expect(controller.reconciliationResults.containsKey('prog_1'), isTrue);
      expect(controller.reconciliationResults.containsKey('prog_2'), isTrue);
    });

    test('13. App resumed triggers reconciliation', () async {
      coordinator.attach();
      await seedProgram(id: 'prog_1', startDayKey: '2026-10-18');

      coordinator.didChangeAppLifecycleState(AppLifecycleState.resumed);

      // Await next microtask turn for unawaited async operation
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.reconciliationResults.containsKey('prog_1'), isTrue);
      expect(coordinator.isAttached, isTrue);
    });

    test(
        '14. Duplicate rapid resume notifications do not spawn overlapping processing',
        () async {
      await seedProgram(id: 'prog_1', startDayKey: '2026-10-18');

      final f1 = coordinator.handleResume(capturedNow: currentClock);
      final f2 = coordinator.handleResume(capturedNow: currentClock);

      final r1 = await f1;
      final r2 = await f2;

      expect(identical(r1, r2), isTrue,
          reason:
              'Rapid duplicate calls must return the same in-flight Future');
    });

    test('15. Lifecycle observer unregisters on disposal', () {
      expect(coordinator.isAttached, isFalse);
      coordinator.attach();
      expect(coordinator.isAttached, isTrue);

      coordinator.dispose();
      expect(coordinator.isAttached, isFalse);

      // Repeated disposal must be safe
      expect(() => coordinator.dispose(), returnsNormally);
    });

    test('16. Persistence errors do not crash lifecycle callbacks', () async {
      coordinator.attach();
      // Close box to simulate storage failure
      await programBox.close();

      expect(() {
        coordinator.didChangeAppLifecycleState(AppLifecycleState.resumed);
      }, returnsNormally);

      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Reopen for tearDown
      programBox =
          await Hive.openBox<ProgramV2Model>(V2Runtime.programsBoxName);
    });

    test('17. One corrupted program does not erase unrelated program results',
        () async {
      await seedProgram(
        id: 'prog_valid',
        startDayKey: '2026-10-18',
        targetDays: 40,
      );
      // Genuinely corrupt record: targetDays is 10 (violates invariant 40..365)
      await seedProgram(
        id: 'prog_corrupt',
        startDayKey: '2026-10-18',
        targetDays: 10,
      );

      final result = await coordinator.handleStartup(capturedNow: currentClock);

      expect(result.items.length, 2);
      final validItem =
          result.items.firstWhere((i) => i.programId == 'prog_valid');
      final corruptItem =
          result.items.firstWhere((i) => i.programId == 'prog_corrupt');

      expect(validItem.action, ProgramResumeAction.onTrack);
      expect(corruptItem.action, ProgramResumeAction.error);
      expect(corruptItem.errorMessage, contains('Invalid program targetDays'));
      expect(
          controller.reconciliationResults.containsKey('prog_valid'), isTrue);
      expect(
          controller.reconciliationResults.containsKey('prog_corrupt'), isTrue);
    });

    test('18. No V1 ProgramModel record is accessed by the V2 controller',
        () async {
      final v1Record = ProgramModel(
        id: 'v1_prog_100',
        namaIbadah: 'Tahajjud V1 Legacy',
        targetHari: 40,
        tglMulai: DateTime(2026, 1, 1),
        hariBerjalan: 5,
        jamPengingat: '05:00',
        status: 'ACTIVE',
      );
      await v1ProgramBox.put(v1Record.id, v1Record);

      await seedProgram(id: 'prog_v2_1', startDayKey: '2026-10-18');

      await controller.checkIn(
        programId: 'prog_v2_1',
        confirmedByUser: true,
      );

      final v1After = v1ProgramBox.get('v1_prog_100');
      expect(v1After, isNotNull);
      expect(v1After!.namaIbadah, 'Tahajjud V1 Legacy');
      expect(v1After.hariBerjalan, 5);
      expect(v1ProgramBox.length, 1);
    });

    test('19. No V1 UI startup path is activated by the V2 runtime tests', () {
      expect(Get.isRegistered<MainController>(), isFalse);
      expect(Get.isRegistered<IbadahController>(), isFalse);
      expect(Get.isRegistered<MainScreenController>(), isFalse);
    });

    test('20. Reopened Hive boxes preserve V2 records', () async {
      await seedProgram(id: 'prog_preserve', startDayKey: '2026-10-18');
      final checkIn = DailyCheckInModel(
        id: '2026-10-18_prog_preserve',
        programId: 'prog_preserve',
        dayKey: '2026-10-18',
        checkedAt: currentClock,
        createdAt: currentClock,
      );
      await checkInBox.put(checkIn.id, checkIn);

      final ach = AchievementModel(
        id: 'ach_final_prog_preserve',
        programId: 'prog_preserve',
        type: AchievementModel.typeFinalSuccess,
        milestoneDays: 40,
        achievedAt: currentClock,
        createdAt: currentClock,
      );
      await achievementBox.put(ach.id, ach);

      final fail = FailureRecordModel(
        id: 'fail_2026-10-18_prog_preserve',
        programId: 'prog_preserve',
        missedDayKey: '2026-10-18',
        reasonCode: 'SAKIT',
        reasonLabelSnapshot: 'Sakit Medis',
        createdAt: currentClock,
      );
      await failureBox.put(fail.id, fail);

      await programBox.flush();
      await checkInBox.flush();
      await achievementBox.flush();
      await failureBox.flush();

      await programBox.close();
      await checkInBox.close();
      await achievementBox.close();
      await failureBox.close();

      // Reopen boxes from disk
      final reopenedProgramBox =
          await Hive.openBox<ProgramV2Model>(V2Runtime.programsBoxName);
      final reopenedCheckInBox =
          await Hive.openBox<DailyCheckInModel>(V2Runtime.dailyCheckInsBoxName);
      final reopenedAchBox =
          await Hive.openBox<AchievementModel>(V2Runtime.achievementsBoxName);
      final reopenedFailBox = await Hive.openBox<FailureRecordModel>(
          V2Runtime.failureRecordsBoxName);

      expect(reopenedProgramBox.get('prog_preserve')!.id, 'prog_preserve');
      expect(reopenedCheckInBox.get('2026-10-18_prog_preserve')!.dayKey,
          '2026-10-18');
      expect(
          reopenedAchBox.get('ach_final_prog_preserve')!.type, 'FINAL_SUCCESS');
      expect(reopenedFailBox.get('fail_2026-10-18_prog_preserve')!.reasonCode,
          'SAKIT');

      // Reassign for tearDown
      programBox = reopenedProgramBox;
      checkInBox = reopenedCheckInBox;
      achievementBox = reopenedAchBox;
      failureBox = reopenedFailBox;
    });

    test(
        '21. R1-1: Completed 40/40 ACTIVE program is finalized on automatic resume when provider supplies valid name',
        () async {
      final start = DateService.parseDayKey('2026-09-01');
      final days = List.generate(40, (i) => getOffsetDayKey(start, i));
      await seedProgram(
        id: 'prog_auto_resume',
        startDayKey: '2026-09-01',
        targetDays: 40,
      );
      await seedCheckIns(programId: 'prog_auto_resume', dayKeys: days);

      final customProvider = CallbackRecipientNameProvider(
        ({program}) => 'Kyai Ahmad Dahlan',
      );
      final resumeController = ProgramV2JourneyController(
        orchestrator: runtime.orchestrator,
        recipientNameProvider: customProvider,
        programRepository: runtime.programRepository,
      );

      final result = await resumeController.reconcileOnResume(
        capturedNow: currentClock,
      );

      expect(result.items.length, 1);
      final item = result.items.first;
      expect(item.action, ProgramResumeAction.successFinalized);
      expect(resumeController.finalizationStatuses['prog_auto_resume'],
          ProgramV2Model.statusSuccess);
      expect(
          resumeController.needsRecipientNameActions
              .contains('prog_auto_resume'),
          isFalse);
      expect(runtime.achievementRepository.getAll().length, 1);
      final ach = runtime.achievementRepository.getAll().first;
      expect(ach.type, AchievementModel.typeFinalSuccess);
      expect(ach.recipientNameSnapshot, 'Kyai Ahmad Dahlan');
    });

    test(
        '22. R1-2: Missing name produces needsRecipientName without deleting check-ins',
        () async {
      final start = DateService.parseDayKey('2026-09-01');
      final days = List.generate(40, (i) => getOffsetDayKey(start, i));
      await seedProgram(
        id: 'prog_missing_name',
        startDayKey: '2026-09-01',
        targetDays: 40,
      );
      await seedCheckIns(programId: 'prog_missing_name', dayKeys: days);

      final missingProvider = CallbackRecipientNameProvider(
        ({program}) => null,
      );
      final resumeController = ProgramV2JourneyController(
        orchestrator: runtime.orchestrator,
        recipientNameProvider: missingProvider,
        programRepository: runtime.programRepository,
      );

      final result = await resumeController.reconcileOnResume(
        capturedNow: currentClock,
      );

      expect(result.items.length, 1);
      expect(result.items.first.action, ProgramResumeAction.needsRecipientName);
      expect(
          resumeController.needsRecipientNameActions
              .contains('prog_missing_name'),
          isTrue);
      // Zero-loss check-in guarantee
      expect(runtime.checkInRepository.getAll().length, 40);
      expect(runtime.achievementRepository.getAll(), isEmpty);
      expect(runtime.programRepository.getById('prog_missing_name')!.status,
          ProgramV2Model.statusActive);
    });

    test(
        '23. R1-3: After name becomes available, subsequent resume completes SUCCESS and creates exactly one Achievement',
        () async {
      final start = DateService.parseDayKey('2026-09-01');
      final days = List.generate(40, (i) => getOffsetDayKey(start, i));
      await seedProgram(
        id: 'prog_seq_resume',
        startDayKey: '2026-09-01',
        targetDays: 40,
      );
      await seedCheckIns(programId: 'prog_seq_resume', dayKeys: days);

      String? providerName;
      final dynamicProvider = CallbackRecipientNameProvider(
        ({program}) => providerName,
      );
      final resumeController = ProgramV2JourneyController(
        orchestrator: runtime.orchestrator,
        recipientNameProvider: dynamicProvider,
        programRepository: runtime.programRepository,
      );

      // Phase 1: Name is null -> needsRecipientName
      final r1 =
          await resumeController.reconcileOnResume(capturedNow: currentClock);
      expect(r1.items.first.action, ProgramResumeAction.needsRecipientName);
      expect(
          resumeController.needsRecipientNameActions
              .contains('prog_seq_resume'),
          isTrue);
      expect(runtime.achievementRepository.getAll(), isEmpty);

      // Phase 2: Name becomes available
      providerName = 'Haji Muhammad Sholeh';
      final r2 =
          await resumeController.reconcileOnResume(capturedNow: currentClock);
      expect(r2.items.first.action, ProgramResumeAction.successFinalized);
      expect(
          resumeController.needsRecipientNameActions
              .contains('prog_seq_resume'),
          isFalse);
      expect(resumeController.finalizationStatuses['prog_seq_resume'],
          ProgramV2Model.statusSuccess);

      // Verify exactly one FINAL_SUCCESS achievement was created
      final achievements = runtime.achievementRepository.getAll();
      expect(achievements.length, 1);
      expect(achievements.first.type, AchievementModel.typeFinalSuccess);
      expect(achievements.first.recipientNameSnapshot, 'Haji Muhammad Sholeh');
    });

    test(
        '24. R1-4: Program-specific provider resolution is respected when implemented',
        () async {
      final start = DateService.parseDayKey('2026-09-01');
      final days = List.generate(40, (i) => getOffsetDayKey(start, i));
      await seedProgram(
        id: 'prog_alpha',
        startDayKey: '2026-09-01',
        targetDays: 40,
      );
      await seedProgram(
        id: 'prog_beta',
        startDayKey: '2026-09-01',
        targetDays: 40,
      );
      await seedCheckIns(programId: 'prog_alpha', dayKeys: days);
      await seedCheckIns(programId: 'prog_beta', dayKeys: days);

      final specificProvider = CallbackRecipientNameProvider(
        ({program}) {
          if (program?.id == 'prog_alpha') return 'Recipient Alpha';
          if (program?.id == 'prog_beta') return 'Recipient Beta';
          return null;
        },
      );
      final resumeController = ProgramV2JourneyController(
        orchestrator: runtime.orchestrator,
        recipientNameProvider: specificProvider,
        programRepository: runtime.programRepository,
      );

      final result = await resumeController.reconcileOnResume(
        capturedNow: currentClock,
      );

      expect(result.items.length, 2);
      final progA = runtime.programRepository.getById('prog_alpha')!;
      final progB = runtime.programRepository.getById('prog_beta')!;

      expect(progA.status, ProgramV2Model.statusSuccess);
      expect(progA.recipientNameSnapshot, 'Recipient Alpha');
      expect(progB.status, ProgramV2Model.statusSuccess);
      expect(progB.recipientNameSnapshot, 'Recipient Beta');

      final achA = runtime.achievementRepository.getByProgramId('prog_alpha');
      final achB = runtime.achievementRepository.getByProgramId('prog_beta');
      expect(achA.length, 1);
      expect(achA.first.recipientNameSnapshot, 'Recipient Alpha');
      expect(achB.length, 1);
      expect(achB.first.recipientNameSnapshot, 'Recipient Beta');
    });

    test('25. R1-5: A cancelled check-in never invokes the provider', () async {
      await seedProgram(id: 'prog_cancel', startDayKey: '2026-10-18');
      var providerInvocationCount = 0;
      final trackingProvider = CallbackRecipientNameProvider(
        ({program}) {
          providerInvocationCount++;
          return 'Should Not Be Called';
        },
      );
      final testController = ProgramV2JourneyController(
        orchestrator: runtime.orchestrator,
        recipientNameProvider: trackingProvider,
        programRepository: runtime.programRepository,
      );

      final result = await testController.checkIn(
        programId: 'prog_cancel',
        confirmedByUser: false,
      );

      expect(result.isSuccess, isFalse);
      expect(result.outcome, OrchestratedCheckInOutcome.confirmationRequired);
      expect(providerInvocationCount, 0);
      expect(runtime.checkInRepository.getAll(), isEmpty);
    });

    test(
        '26. R1-6: Provider throwing HiveError or exception does not abort check-in or escape Future',
        () async {
      await seedProgram(id: 'prog_hive_err', startDayKey: '2026-10-18');
      final hiveThrowingProvider = CallbackRecipientNameProvider(
        ({program}) =>
            throw HiveError('Corrupt profile box C:\\data\\profile.hive'),
      );
      final testController1 = ProgramV2JourneyController(
        orchestrator: runtime.orchestrator,
        recipientNameProvider: hiveThrowingProvider,
        programRepository: runtime.programRepository,
      );

      final r1 = await testController1.checkIn(
        programId: 'prog_hive_err',
        confirmedByUser: true,
      );
      expect(r1.isSuccess, isTrue);
      expect(r1.outcome, OrchestratedCheckInOutcome.checkInCompleted);
      expect(r1.checkIn, isNotNull);
      expect(testController1.profileLookupDiagnostics['prog_hive_err'],
          'Storage operation failed during profile lookup.');
      expect(runtime.checkInRepository.getAll().length, 1);

      await seedProgram(id: 'prog_gen_err', startDayKey: '2026-10-18');
      final generalThrowingProvider = CallbackRecipientNameProvider(
        ({program}) =>
            throw StateError('Unexpected state error in profile lookup'),
      );
      final testController2 = ProgramV2JourneyController(
        orchestrator: runtime.orchestrator,
        recipientNameProvider: generalThrowingProvider,
        programRepository: runtime.programRepository,
      );

      final r2 = await testController2.checkIn(
        programId: 'prog_gen_err',
        confirmedByUser: true,
      );
      expect(r2.isSuccess, isTrue);
      expect(r2.outcome, OrchestratedCheckInOutcome.checkInCompleted);
      expect(testController2.profileLookupDiagnostics['prog_gen_err'],
          'Unexpected error occurred during profile lookup.');

      final r3 =
          await testController1.finalizeSuccess(programId: 'prog_hive_err');
      expect(r3.outcome, OrchestratedSuccessOutcome.persistenceError);
      expect(testController1.hasPersistenceError.value, isTrue);
      expect(testController1.lastErrorMessage.value,
          'Storage operation failed during profile lookup.');

      final r4 =
          await testController2.finalizeSuccess(programId: 'prog_gen_err');
      expect(r4.outcome, OrchestratedSuccessOutcome.unexpectedError);
      expect(testController2.hasPersistenceError.value, isFalse);
      expect(testController2.lastErrorMessage.value,
          'Unexpected error occurred during profile lookup.');
    });

    test(
        '27. R1-7: Public error messages contain no injected exception details',
        () async {
      await seedProgram(id: 'prog_sec_err', startDayKey: '2026-10-18');
      const secretPath = 'C:\\secrets\\production\\database.hive';
      const secretError = 'FATAL_CORRUPT_EXCEPTION: memory leak at 0xDEADBEEF';
      final leakingProvider = CallbackRecipientNameProvider(
        ({program}) => throw HiveError('$secretError in $secretPath'),
      );
      final testController = ProgramV2JourneyController(
        orchestrator: runtime.orchestrator,
        recipientNameProvider: leakingProvider,
        programRepository: runtime.programRepository,
      );

      final res = await testController.checkIn(
        programId: 'prog_sec_err',
        confirmedByUser: true,
      );
      expect(res.isSuccess, isTrue);
      final diag = testController.profileLookupDiagnostics['prog_sec_err'];
      expect(diag, isNotNull);
      expect(diag!.contains('secret'), isFalse);
      expect(diag.contains('DEADBEEF'), isFalse);
      expect(diag.contains(secretPath), isFalse);
      expect(diag.contains('database.hive'), isFalse);

      final failRes =
          await testController.finalizeSuccess(programId: 'prog_sec_err');
      expect(failRes.isSuccess, isFalse);
      expect(failRes.errorMessage, isNotNull);
      expect(failRes.errorMessage!.contains('secret'), isFalse);
      expect(failRes.errorMessage!.contains('DEADBEEF'), isFalse);
      expect(failRes.errorMessage!.contains(secretPath), isFalse);
      expect(failRes.errorMessage!.contains('database.hive'), isFalse);

      expect(testController.lastErrorMessage.value, isNotNull);
      expect(
          testController.lastErrorMessage.value!.contains('secret'), isFalse);
      expect(
          testController.lastErrorMessage.value!.contains(secretPath), isFalse);
    });

    test(
        '28. R1-8: Concurrent check-in and resume never clear isProcessing prematurely',
        () async {
      await seedProgram(id: 'prog_concurrent_1', startDayKey: '2026-10-18');
      await seedProgram(id: 'prog_concurrent_2', startDayKey: '2026-10-18');

      final resumeGate = Completer<String?>();
      final controlledProvider = CallbackRecipientNameProvider(
        ({program}) async {
          if (program?.id == 'prog_concurrent_2') {
            return await resumeGate.future;
          }
          return 'User Fast';
        },
      );
      final testController = ProgramV2JourneyController(
        orchestrator: runtime.orchestrator,
        recipientNameProvider: controlledProvider,
        programRepository: runtime.programRepository,
      );

      // Start resume (it will pause in provider awaiting resumeGate for prog_concurrent_2)
      final resumeFuture = testController.reconcileOnResume(
        capturedNow: currentClock,
      );

      // Verify controller is processing
      expect(testController.isProcessing, isTrue);

      // Now run check-in concurrently with explicit recipient snapshot
      final checkInResult = await testController.checkIn(
        programId: 'prog_concurrent_1',
        confirmedByUser: true,
        recipientNameSnapshot: 'Immediate CheckIn',
      );
      expect(checkInResult.isSuccess, isTrue);

      // Check-in finished, but resume is STILL waiting on gate!
      // isProcessing MUST remain true!
      expect(testController.isProcessing, isTrue,
          reason:
              'isProcessing must remain true while resume operation is still in progress');

      // Release resume gate
      resumeGate.complete('User Resumed');
      final resumeResult = await resumeFuture;
      expect(resumeResult, isNotNull);

      // Now that both operations are finished, isProcessing must be false
      expect(testController.isProcessing, isFalse);
    });

    test('29. R1-9: Batch Achievement recovery updates SUCCESS state',
        () async {
      final start = DateService.parseDayKey('2026-09-01');
      final days = List.generate(40, (i) => getOffsetDayKey(start, i));
      await seedProgram(
        id: 'prog_recover_ach',
        startDayKey: '2026-09-01',
        targetDays: 40,
        status: ProgramV2Model.statusSuccess,
        recipientNameSnapshot: 'Kyai Ahmad Dahlan',
        finalizedAt: currentClock,
      );
      await seedCheckIns(programId: 'prog_recover_ach', dayKeys: days);
      // Ensure achievementBox is empty
      expect(runtime.achievementRepository.getAll(), isEmpty);

      final resumeController = ProgramV2JourneyController(
        orchestrator: runtime.orchestrator,
        recipientNameProvider: const UnavailableRecipientNameProvider(),
        programRepository: runtime.programRepository,
      );

      final result = await resumeController.reconcileOnResume(
        capturedNow: currentClock,
      );

      expect(result.items.length, 1);
      final item = result.items.first;
      expect(item.action, ProgramResumeAction.achievementRecovered);
      expect(resumeController.finalizationStatuses['prog_recover_ach'],
          ProgramV2Model.statusSuccess);
      expect(
          resumeController.needsRecipientNameActions
              .contains('prog_recover_ach'),
          isFalse);
      expect(runtime.achievementRepository.getAll().length, 1);
      final ach = runtime.achievementRepository.getAll().first;
      expect(ach.type, AchievementModel.typeFinalSuccess);
      expect(ach.recipientNameSnapshot, 'Kyai Ahmad Dahlan');
    });

    test(
        '30. R1-10: Successful retry clears needsRecipientName and stale error state',
        () async {
      final start = DateService.parseDayKey('2026-09-01');
      final days = List.generate(40, (i) => getOffsetDayKey(start, i));
      await seedProgram(
        id: 'prog_retry',
        startDayKey: '2026-09-01',
        targetDays: 40,
      );
      await seedCheckIns(programId: 'prog_retry', dayKeys: days);

      final retryController = ProgramV2JourneyController(
        orchestrator: runtime.orchestrator,
        recipientNameProvider: const UnavailableRecipientNameProvider(),
        programRepository: runtime.programRepository,
      );

      // Attempt 1: finalize without name -> fails with invalidRecipientName
      final r1 = await retryController.finalizeSuccess(programId: 'prog_retry');
      expect(r1.isSuccess, isFalse);
      expect(r1.outcome, OrchestratedSuccessOutcome.invalidRecipientName);
      expect(retryController.needsRecipientNameActions.contains('prog_retry'),
          isTrue);
      expect(retryController.lastErrorMessage.value, isNotNull);

      // Attempt 2: retry with valid recipient name
      final r2 = await retryController.finalizeSuccess(
        programId: 'prog_retry',
        recipientNameSnapshot: 'Haji Ahmad Dahlan',
      );
      expect(r2.isSuccess, isTrue);
      expect(r2.outcome, OrchestratedSuccessOutcome.successFinalized);

      // State is cleaned up
      expect(retryController.needsRecipientNameActions.contains('prog_retry'),
          isFalse);
      expect(retryController.lastErrorMessage.value, isNull);
      expect(retryController.finalizationStatuses['prog_retry'],
          ProgramV2Model.statusSuccess);
    });

    test('31. R1-11: Repeated installation of the same runtime is safe', () {
      Get.reset();
      expect(Get.isRegistered<V2Runtime>(), isFalse);

      // First installation
      runtime.installDependencies();
      expect(Get.isRegistered<V2Runtime>(), isTrue);
      expect(identical(Get.find<V2Runtime>(), runtime), isTrue);

      // Repeated installation of exact same instance must succeed idempotently
      expect(() => runtime.installDependencies(), returnsNormally);
      expect(identical(Get.find<V2Runtime>(), runtime), isTrue);
    });

    test(
        '32. R1-12: Conflicting installation is rejected without replacing existing V2 dependencies',
        () {
      Get.reset();
      runtime.installDependencies();
      expect(identical(Get.find<V2Runtime>(), runtime), isTrue);

      // Construct a different runtime instance
      final conflictingRuntime = V2Runtime.fromBoxes(
        programBox: programBox,
        checkInBox: checkInBox,
        failureBox: failureBox,
        achievementBox: achievementBox,
        dateService: dateService,
      );

      // Installing a different runtime must throw StateError
      expect(
        () => conflictingRuntime.installDependencies(),
        throwsA(isA<StateError>()),
      );

      // Existing registration is intact and not replaced
      expect(identical(Get.find<V2Runtime>(), runtime), isTrue);
    });

    test(
        '33. R2-1: Profile provider throws on day 12/40: confirmed check-in still persists and returns checkInCompleted',
        () async {
      final start = DateService.parseDayKey('2026-09-01');
      final pastDays = List.generate(11, (i) => getOffsetDayKey(start, i));
      await seedProgram(
        id: 'prog_day12',
        startDayKey: '2026-09-01',
        targetDays: 40,
      );
      await seedCheckIns(programId: 'prog_day12', dayKeys: pastDays);

      final day12Dt = DateService.parseDayKey(getOffsetDayKey(start, 11));
      currentClock =
          DateTime(day12Dt.year, day12Dt.month, day12Dt.day, 5, 0, 0);

      final failingProvider = CallbackRecipientNameProvider(
        ({program}) =>
            throw HiveError('Simulated disk failure during profile lookup'),
      );
      final testController = ProgramV2JourneyController(
        orchestrator: runtime.orchestrator,
        recipientNameProvider: failingProvider,
        programRepository: runtime.programRepository,
      );

      final result = await testController.checkIn(
        programId: 'prog_day12',
        confirmedByUser: true,
      );

      expect(result.isSuccess, isTrue);
      expect(result.outcome, OrchestratedCheckInOutcome.checkInCompleted);
      expect(result.checkIn, isNotNull);
      expect(result.checkIn!.dayKey, getOffsetDayKey(start, 11));
      expect(runtime.checkInRepository.getAll().length, 12);
      expect(testController.completedCheckIns['prog_day12'], isNotNull);
      expect(testController.profileLookupDiagnostics['prog_day12'],
          'Storage operation failed during profile lookup.');
    });

    test(
        '34. R2-2: Provider throws on final target day (day 40/40): last check-in persists and returns needsRecipientName',
        () async {
      final start = DateService.parseDayKey('2026-09-01');
      final pastDays = List.generate(39, (i) => getOffsetDayKey(start, i));
      await seedProgram(
        id: 'prog_day40',
        startDayKey: '2026-09-01',
        targetDays: 40,
      );
      await seedCheckIns(programId: 'prog_day40', dayKeys: pastDays);

      final day40Dt = DateService.parseDayKey(getOffsetDayKey(start, 39));
      currentClock =
          DateTime(day40Dt.year, day40Dt.month, day40Dt.day, 5, 0, 0);

      final failingProvider = CallbackRecipientNameProvider(
        ({program}) => throw HiveError('Corrupt profile partition'),
      );
      final testController = ProgramV2JourneyController(
        orchestrator: runtime.orchestrator,
        recipientNameProvider: failingProvider,
        programRepository: runtime.programRepository,
      );

      final result = await testController.checkIn(
        programId: 'prog_day40',
        confirmedByUser: true,
      );

      expect(result.isSuccess, isTrue);
      expect(result.outcome, OrchestratedCheckInOutcome.needsRecipientName);
      expect(result.checkIn, isNotNull);
      expect(result.checkIn!.dayKey, getOffsetDayKey(start, 39));
      expect(runtime.checkInRepository.getAll().length, 40);
      expect(testController.completedCheckIns['prog_day40'], isNotNull);
      expect(testController.needsRecipientNameActions.contains('prog_day40'),
          isTrue);
      expect(runtime.achievementRepository.getAll(), isEmpty);
      expect(testController.profileLookupDiagnostics['prog_day40'],
          'Storage operation failed during profile lookup.');
    });

    test(
        '35. R2-3: After providing a valid name, SUCCESS finalization completes with exactly one FINAL_SUCCESS Achievement',
        () async {
      final start = DateService.parseDayKey('2026-09-01');
      final pastDays = List.generate(39, (i) => getOffsetDayKey(start, i));
      await seedProgram(
        id: 'prog_finalize_retry',
        startDayKey: '2026-09-01',
        targetDays: 40,
      );
      await seedCheckIns(programId: 'prog_finalize_retry', dayKeys: pastDays);

      final day40Dt = DateService.parseDayKey(getOffsetDayKey(start, 39));
      currentClock =
          DateTime(day40Dt.year, day40Dt.month, day40Dt.day, 5, 0, 0);

      final failingProvider = CallbackRecipientNameProvider(
        ({program}) => throw HiveError('Temporary profile read failure'),
      );
      final testController = ProgramV2JourneyController(
        orchestrator: runtime.orchestrator,
        recipientNameProvider: failingProvider,
        programRepository: runtime.programRepository,
      );

      await testController.checkIn(
        programId: 'prog_finalize_retry',
        confirmedByUser: true,
      );
      expect(
          testController.needsRecipientNameActions
              .contains('prog_finalize_retry'),
          isTrue);
      expect(
          testController.profileLookupDiagnostics
              .containsKey('prog_finalize_retry'),
          isTrue);

      final finalizeResult = await testController.finalizeSuccess(
        programId: 'prog_finalize_retry',
        recipientNameSnapshot: 'Kyai Haji Ahmad Dahlan',
      );

      expect(finalizeResult.isSuccess, isTrue);
      expect(
          finalizeResult.outcome, OrchestratedSuccessOutcome.successFinalized);
      expect(testController.finalizationStatuses['prog_finalize_retry'],
          ProgramV2Model.statusSuccess);
      expect(
          testController.needsRecipientNameActions
              .contains('prog_finalize_retry'),
          isFalse);
      expect(
          testController.profileLookupDiagnostics
              .containsKey('prog_finalize_retry'),
          isFalse);

      final achs =
          runtime.achievementRepository.getByProgramId('prog_finalize_retry');
      expect(achs.length, 1);
      expect(achs.first.type, AchievementModel.typeFinalSuccess);
      expect(achs.first.recipientNameSnapshot, 'Kyai Haji Ahmad Dahlan');
    });

    test(
        '36. R2-4: Batch resume resilience: one program provider throws while another receives valid name; valid program finalizes',
        () async {
      final start = DateService.parseDayKey('2026-09-01');
      final all40Days = List.generate(40, (i) => getOffsetDayKey(start, i));
      await seedProgram(
        id: 'prog_fail_resume',
        startDayKey: '2026-09-01',
        targetDays: 40,
      );
      await seedProgram(
        id: 'prog_ok_resume',
        startDayKey: '2026-09-01',
        targetDays: 40,
      );
      await seedCheckIns(programId: 'prog_fail_resume', dayKeys: all40Days);
      await seedCheckIns(programId: 'prog_ok_resume', dayKeys: all40Days);

      final selectiveProvider = CallbackRecipientNameProvider(
        ({program}) {
          if (program?.id == 'prog_fail_resume') {
            throw HiveError('Provider disk error for prog_fail_resume');
          }
          if (program?.id == 'prog_ok_resume') {
            return 'Kyai Syarif';
          }
          return null;
        },
      );
      final testController = ProgramV2JourneyController(
        orchestrator: runtime.orchestrator,
        recipientNameProvider: selectiveProvider,
        programRepository: runtime.programRepository,
      );

      final bootstrapResult = await testController.reconcileOnResume(
        capturedNow: currentClock,
      );

      expect(bootstrapResult.items.length, 2);

      // prog_ok_resume must successfully finalize
      expect(testController.finalizationStatuses['prog_ok_resume'],
          ProgramV2Model.statusSuccess);
      expect(runtime.programRepository.getById('prog_ok_resume')!.status,
          ProgramV2Model.statusSuccess);
      final okAchs =
          runtime.achievementRepository.getByProgramId('prog_ok_resume');
      expect(okAchs.length, 1);
      expect(okAchs.first.recipientNameSnapshot, 'Kyai Syarif');
      expect(
          testController.profileLookupDiagnostics.containsKey('prog_ok_resume'),
          isFalse);

      // prog_fail_resume must not finalize, check-ins are preserved, and diagnostic is observable
      expect(
          testController.needsRecipientNameActions.contains('prog_fail_resume'),
          isTrue);
      expect(runtime.programRepository.getById('prog_fail_resume')!.status,
          ProgramV2Model.statusActive);
      expect(runtime.achievementRepository.getByProgramId('prog_fail_resume'),
          isEmpty);
      expect(testController.profileLookupDiagnostics['prog_fail_resume'],
          'Storage operation failed during profile lookup.');
      expect(
          testController.profileLookupDiagnostics['prog_fail_resume']!
              .contains('prog_fail_resume'),
          isFalse,
          reason: 'Raw exception strings must never be exposed');
    });

    test(
        '37. R2-5: Failed provider lookup is observable and not silently represented as simply an unconfigured profile',
        () async {
      final start = DateService.parseDayKey('2026-09-01');
      final all40Days = List.generate(40, (i) => getOffsetDayKey(start, i));
      await seedProgram(
        id: 'prog_unconfigured_profile',
        startDayKey: '2026-09-01',
        targetDays: 40,
      );
      await seedProgram(
        id: 'prog_broken_profile',
        startDayKey: '2026-09-01',
        targetDays: 40,
      );
      await seedCheckIns(
          programId: 'prog_unconfigured_profile', dayKeys: all40Days);
      await seedCheckIns(programId: 'prog_broken_profile', dayKeys: all40Days);

      final mixedProvider = CallbackRecipientNameProvider(
        ({program}) {
          if (program?.id == 'prog_unconfigured_profile') {
            return null; // Validly unconfigured
          }
          if (program?.id == 'prog_broken_profile') {
            throw HiveError('Corrupt profile storage'); // Read failure
          }
          return null;
        },
      );
      final testController = ProgramV2JourneyController(
        orchestrator: runtime.orchestrator,
        recipientNameProvider: mixedProvider,
        programRepository: runtime.programRepository,
      );

      await testController.reconcileOnResume(capturedNow: currentClock);

      expect(
          testController.needsRecipientNameActions
              .contains('prog_unconfigured_profile'),
          isTrue);
      expect(
          testController.needsRecipientNameActions
              .contains('prog_broken_profile'),
          isTrue);

      expect(
          testController.profileLookupDiagnostics
              .containsKey('prog_unconfigured_profile'),
          isFalse,
          reason:
              'Unconfigured profile returns null without throwing and must not record a lookup failure');
      expect(
          testController.profileLookupDiagnostics
              .containsKey('prog_broken_profile'),
          isTrue,
          reason: 'Broken provider throws and must record a diagnostic');
      expect(testController.profileLookupDiagnostics['prog_broken_profile'],
          'Storage operation failed during profile lookup.');
    });

    test(
        '38. R2-6: Subsequent successful resume clears earlier profile lookup diagnostic',
        () async {
      final start = DateService.parseDayKey('2026-09-01');
      final all40Days = List.generate(40, (i) => getOffsetDayKey(start, i));
      await seedProgram(
        id: 'prog_heal_resume',
        startDayKey: '2026-09-01',
        targetDays: 40,
      );
      await seedCheckIns(programId: 'prog_heal_resume', dayKeys: all40Days);

      String? Function()? dynamicResolver;
      final dynamicProvider = CallbackRecipientNameProvider(
        ({program}) => dynamicResolver?.call(),
      );
      final testController = ProgramV2JourneyController(
        orchestrator: runtime.orchestrator,
        recipientNameProvider: dynamicProvider,
        programRepository: runtime.programRepository,
      );

      // Run 1: Provider throws
      dynamicResolver =
          () => throw HiveError('Profile box temporarily unavailable');
      await testController.reconcileOnResume(capturedNow: currentClock);
      expect(
          testController.profileLookupDiagnostics
              .containsKey('prog_heal_resume'),
          isTrue);
      expect(
          testController.needsRecipientNameActions.contains('prog_heal_resume'),
          isTrue);

      // Run 2: Provider recovers and returns a valid name
      dynamicResolver = () => 'Haji Mas Mansur';
      await testController.reconcileOnResume(capturedNow: currentClock);

      expect(testController.finalizationStatuses['prog_heal_resume'],
          ProgramV2Model.statusSuccess);
      expect(
          testController.needsRecipientNameActions.contains('prog_heal_resume'),
          isFalse);
      expect(
          testController.profileLookupDiagnostics
              .containsKey('prog_heal_resume'),
          isFalse,
          reason: 'Successful resolution must clear earlier diagnostic');
    });
  });
}
