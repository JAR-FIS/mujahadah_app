import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:mujahadah/controllers/v2_navigation_controller.dart';
import 'package:mujahadah/controllers/v2_program_hub_controller.dart';
import 'package:mujahadah/core/date/date_service.dart';
import 'package:mujahadah/core/runtime/v2_runtime.dart';
import 'package:mujahadah/models/achievement_model.dart';
import 'package:mujahadah/models/daily_checkin_model.dart';
import 'package:mujahadah/models/failure_record_model.dart';
import 'package:mujahadah/models/program_v2_model.dart';
import 'package:mujahadah/repositories/achievement_v2_repository.dart';
import 'package:mujahadah/repositories/daily_checkin_v2_repository.dart';
import 'package:mujahadah/repositories/failure_record_v2_repository.dart';
import 'package:mujahadah/repositories/program_v2_repository.dart';
import 'package:mujahadah/services/daily_checkin_v2_service.dart';
import 'package:mujahadah/services/program_v2_journey_orchestrator.dart';
import 'package:mujahadah/services/program_v2_muhasabah_service.dart';
import 'package:mujahadah/services/program_v2_reconciliation_service.dart';
import 'package:mujahadah/services/program_v2_success_service.dart';
import 'package:mujahadah/theme/v2_theme.dart';
import 'package:mujahadah/views/v2/program/v2_muhasabah_view.dart';
import 'package:mujahadah/views/v2/program/v2_program_detail_view.dart';
import 'package:mujahadah/views/v2/program/v2_program_hub_view.dart';
import 'package:mujahadah/views/v2/shell/v2_app_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<ProgramV2Model> programBox;
  late Box<DailyCheckInModel> checkInBox;
  late Box<FailureRecordModel> failureBox;
  late Box<AchievementModel> achievementBox;

  late ProgramV2Repository programRepo;
  late DailyCheckInV2Repository checkInRepo;
  late FailureRecordV2Repository failureRepo;
  late AchievementV2Repository achievementRepo;

  late DailyCheckInV2Service checkInService;
  late ProgramV2ReconciliationService reconciliationService;
  late ProgramV2MuhasabahService muhasabahService;
  late ProgramV2SuccessService successService;
  late ProgramV2JourneyOrchestrator orchestrator;

  DateTime simulatedNow = DateTime(2026, 10, 22, 17, 0);
  DateService createDeterministicDateService() {
    return DateService(nowProvider: () => simulatedNow);
  }

  final testReasons = [
    const MuhasabahReasonOption(
      code: 'sakit',
      label: 'Sakit / Kurang Sehat',
      description: 'Kondisi fisik tidak memungkinkan untuk beribadah.',
    ),
    const MuhasabahReasonOption(
      code: 'safar',
      label: 'Safar / Perjalanan',
      description: 'Sedang dalam perjalanan jauh.',
    ),
    const MuhasabahReasonOption(
      code: 'lupa_terlewat',
      label: 'Lupa / Tertidur',
      description: 'Terlewat karena tertidur atau kelupaan.',
    ),
  ];

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('v2_muhasabah_test_');
    Hive.init(tempDir.path);
    V2Runtime.registerAdapters();

    programBox = await Hive.openBox<ProgramV2Model>('test_muhasabah_prog_box');
    checkInBox =
        await Hive.openBox<DailyCheckInModel>('test_muhasabah_checkin_box');
    failureBox =
        await Hive.openBox<FailureRecordModel>('test_muhasabah_failure_box');
    achievementBox =
        await Hive.openBox<AchievementModel>('test_muhasabah_achieve_box');

    programRepo = ProgramV2Repository(box: programBox);
    checkInRepo = DailyCheckInV2Repository(box: checkInBox);
    failureRepo = FailureRecordV2Repository(box: failureBox);
    achievementRepo = AchievementV2Repository(box: achievementBox);
  });

  tearDownAll(() async {
    await programBox.close();
    await checkInBox.close();
    await failureBox.close();
    await achievementBox.close();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  setUp(() async {
    Get.reset();
    await programBox.deleteAll(programBox.keys.toList());
    await checkInBox.deleteAll(checkInBox.keys.toList());
    await failureBox.deleteAll(failureBox.keys.toList());
    await achievementBox.deleteAll(achievementBox.keys.toList());

    simulatedNow = DateTime(2026, 10, 22, 17, 0);
    final dateService = createDeterministicDateService();

    checkInService = DailyCheckInV2Service(
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
      failureRecordRepository: failureRepo,
      achievementRepository: achievementRepo,
      dateService: dateService,
    );

    orchestrator = ProgramV2JourneyOrchestrator(
      programRepository: programRepo,
      dailyCheckInService: checkInService,
      reconciliationService: reconciliationService,
      muhasabahService: muhasabahService,
      successService: successService,
      dateService: dateService,
    );
  });

  tearDown(() {
    Get.reset();
  });

  ProgramV2Model createPendingProgram({
    String id = 'prog-pending-1',
    String ibadahName = 'Sholat Tahajud',
    int targetDays = 40,
    String startDayKey = '2026-10-01',
    String? missedDayKey = '2026-10-21',
  }) {
    return ProgramV2Model(
      id: id,
      ibadahId: 'ibadah-1',
      ibadahNameSnapshot: ibadahName,
      targetDays: targetDays,
      startDayKey: startDayKey,
      status: ProgramV2Model.statusPendingFailure,
      pendingMissedDayKey: missedDayKey,
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 21),
    );
  }

  Future<void> saveProgram(WidgetTester tester, ProgramV2Model prog) async {
    await tester.runAsync(() async {
      await programRepo.save(prog);
    });
  }

  Future<void> saveCheckIn(
      WidgetTester tester, DailyCheckInModel checkin) async {
    await tester.runAsync(() async {
      await checkInRepo.save(checkin);
    });
  }

  group('Mandatory Test 1: PENDING_FAILURE S21 -> S22 -> Back navigation flow',
      () {
    testWidgets(
        'S21 Mulai Muhasabah opens S22, Back returns to S21 without persistence, S17 state preserved',
        (tester) async {
      final prog = createPendingProgram();
      await saveProgram(tester, prog);

      final controller = V2ProgramHubController(
        programRepository: programRepo,
        initialTab: ProgramHubTab.ibadahSaya,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            controller: controller,
            programRepository: programRepo,
            journeyOrchestrator: orchestrator,
            muhasabahService: muhasabahService,
            muhasabahReasonOptions: testReasons,
            dateService: createDeterministicDateService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open S21
      controller.openProgramDetail(prog);
      await tester.pumpAndSettle();
      expect(find.byType(V2ProgramDetailView), findsOneWidget);
      expect(find.text('Perlu Muhasabah'), findsWidgets);

      // Tap Mulai Muhasabah on S21
      final mulaiBtn =
          find.byKey(const ValueKey('v2_program_detail_muhasabah_button'));
      expect(mulaiBtn, findsOneWidget);
      await tester.ensureVisible(mulaiBtn);
      await tester.tap(mulaiBtn);
      await tester.pumpAndSettle();

      // S22 Muhasabah is now open
      expect(find.byKey(const ValueKey('v2_muhasabah_view')), findsOneWidget);
      expect(find.text('Sholat Tahajud'), findsWidgets);
      expect(find.text('Hari terlewat: 21 Oktober 2026'), findsOneWidget);

      // Tap Back on S22
      final backBtn = find.byKey(const ValueKey('v2_muhasabah_back_button'));
      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      // Back to S21
      expect(find.byType(V2ProgramDetailView), findsOneWidget);
      expect(find.byKey(const ValueKey('v2_muhasabah_view')), findsNothing);

      // Program unchanged in repo
      final fresh = programRepo.getById(prog.id);
      expect(fresh!.status, equals(ProgramV2Model.statusPendingFailure));
      expect(failureRepo.getAll(), isEmpty);

      // Tap Back on S21
      final s21Back =
          find.byKey(const ValueKey('v2_program_detail_back_button'));
      await tester.tap(s21Back);
      await tester.pumpAndSettle();

      // S17 Hub Ibadah Saya preserved
      expect(controller.currentTab, equals(ProgramHubTab.ibadahSaya));
      expect(controller.currentStep, equals(ProgramScreenStep.hub));
    });
  });

  group('Mandatory Test 2: Status Validation & Non-Pending Rejection', () {
    for (final invalidStatus in [
      ProgramV2Model.statusActive,
      ProgramV2Model.statusSuccess,
      ProgramV2Model.statusFailed,
      ProgramV2Model.statusWarning,
    ]) {
      testWidgets('Non-pending status $invalidStatus cannot enter finalization',
          (tester) async {
        final prog = ProgramV2Model(
          id: 'prog-$invalidStatus',
          ibadahId: 'ibadah-1',
          ibadahNameSnapshot: 'Puasa Daud',
          targetDays: 40,
          startDayKey: '2026-10-01',
          status: invalidStatus,
          createdAt: DateTime(2026, 10, 1),
          updatedAt: DateTime(2026, 10, 22),
        );

        bool backCalled = false;
        await tester.pumpWidget(
          GetMaterialApp(
            theme: V2Theme.lightTheme,
            home: V2MuhasabahView(
              program: prog,
              reasonOptions: testReasons,
              orchestrator: orchestrator,
              onBack: () => backCalled = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('v2_muhasabah_non_pending_notice')),
            findsOneWidget);
        expect(find.text('Program Tidak Memerlukan Muhasabah'), findsOneWidget);
        expect(find.byKey(const ValueKey('v2_muhasabah_submit_button')),
            findsNothing);

        await tester.tap(
            find.byKey(const ValueKey('v2_muhasabah_non_pending_back_button')));
        await tester.pumpAndSettle();
        expect(backCalled, isTrue);
      });
    }
  });

  group('Mandatory Test 3: Mandatory Reason & Fail-Closed Guard', () {
    testWidgets('Submit disabled without reason selection', (tester) async {
      final prog = createPendingProgram();
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2MuhasabahView(
            program: prog,
            reasonOptions: testReasons,
            orchestrator: orchestrator,
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final submitBtn = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('v2_muhasabah_submit_button')),
      );
      expect(submitBtn.onPressed, isNull);
    });

    testWidgets('Fail-closed notice shown when reasonOptions is empty or null',
        (tester) async {
      final prog = createPendingProgram();
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2MuhasabahView(
            program: prog,
            reasonOptions: null, // absent approved reasons
            orchestrator: orchestrator,
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('v2_muhasabah_no_reasons_notice')),
          findsOneWidget);
      expect(
        find.textContaining('belum tersedia dari katalog resmi'),
        findsOneWidget,
      );

      final submitBtn = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('v2_muhasabah_submit_button')),
      );
      expect(submitBtn.onPressed, isNull);
    });

    testWidgets('Dialog cancellation aborts submission without write',
        (tester) async {
      final prog = createPendingProgram();
      await saveProgram(tester, prog);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2MuhasabahView(
            program: prog,
            programRepository: programRepo,
            reasonOptions: testReasons,
            orchestrator: orchestrator,
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select reason
      await tester.tap(find.text('Sakit / Kurang Sehat'));
      await tester.pumpAndSettle();

      // Submit button is now enabled
      final submitBtn =
          find.byKey(const ValueKey('v2_muhasabah_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Dialog is open
      expect(find.byKey(const ValueKey('v2_muhasabah_confirm_dialog')),
          findsOneWidget);

      // Tap Batal on dialog
      await tester
          .tap(find.byKey(const ValueKey('v2_muhasabah_dialog_cancel')));
      await tester.pumpAndSettle();

      // Dialog dismissed, still on S22 form, no records persisted
      expect(find.byKey(const ValueKey('v2_muhasabah_confirm_dialog')),
          findsNothing);
      expect(find.byKey(const ValueKey('v2_muhasabah_completed_view')),
          findsNothing);
      expect(failureRepo.getAll(), isEmpty);
    });

    testWidgets('Unwired handler disables submit and shows honest notice',
        (tester) async {
      final prog = createPendingProgram();
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2MuhasabahView(
            program: prog,
            reasonOptions: testReasons,
            // no orchestrator, no service, no callback
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('v2_muhasabah_unwired_notice')),
          findsOneWidget);

      await tester.tap(find.text('Sakit / Kurang Sehat'));
      await tester.pumpAndSettle();

      final submitBtn = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('v2_muhasabah_submit_button')),
      );
      expect(submitBtn.onPressed, isNull);
    });
  });

  group('Mandatory Test 4: Reason & Note Sanitization', () {
    testWidgets(
        'Submits exact reason code and snapshot, and trims whitespace in notes',
        (tester) async {
      final prog = createPendingProgram();
      await saveProgram(tester, prog);

      String? submittedCode;
      String? submittedLabel;
      String? submittedNote;

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2MuhasabahView(
            program: prog,
            reasonOptions: testReasons,
            onMuhasabahSubmit: ({
              required programId,
              required reasonCode,
              required reasonLabelSnapshot,
              note,
            }) async {
              submittedCode = reasonCode;
              submittedLabel = reasonLabelSnapshot;
              submittedNote = note;
              final updatedProg = ProgramV2Model(
                id: prog.id,
                ibadahId: prog.ibadahId,
                ibadahNameSnapshot: prog.ibadahNameSnapshot,
                targetDays: prog.targetDays,
                startDayKey: prog.startDayKey,
                status: ProgramV2Model.statusFailed,
                createdAt: prog.createdAt,
                updatedAt: DateTime.now(),
              );
              final failureRec = FailureRecordModel(
                id: FailureRecordV2Repository.buildFailureRecordId(
                    prog.pendingMissedDayKey!, prog.id),
                programId: prog.id,
                missedDayKey: prog.pendingMissedDayKey!,
                reasonCode: reasonCode,
                reasonLabelSnapshot: reasonLabelSnapshot,
                note: note,
                createdAt: DateTime.now(),
              );
              return OrchestratedMuhasabahResult.fromOutcome(
                outcome: OrchestratedMuhasabahOutcome.failedCreated,
                programId: programId,
                finalStatus: ProgramV2Model.statusFailed,
                program: updatedProg,
                failureRecord: failureRec,
                completedDays: 5,
              );
            },
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select reason 'safar'
      await tester.tap(find.text('Safar / Perjalanan'));
      await tester.pumpAndSettle();

      // Enter note with whitespace
      await tester.enterText(
        find.byKey(const ValueKey('v2_muhasabah_note_input')),
        '   Perjalanan dinas ke luar kota   ',
      );
      await tester.pumpAndSettle();

      // Submit
      final submitBtn =
          find.byKey(const ValueKey('v2_muhasabah_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('v2_muhasabah_dialog_confirm')));
      await tester.pumpAndSettle();

      expect(submittedCode, equals('safar'));
      expect(submittedLabel, equals('Safar / Perjalanan'));
      expect(submittedNote, equals('Perjalanan dinas ke luar kota'));
    });
  });

  group('Mandatory Test 5: Presentation Mapping & Real Domain 39/40 Boundary',
      () {
    testWidgets(
        '5a: Presentation Mapping — Domain FAILED (< 40 days) displays Belum Selesai',
        (tester) async {
      final prog = createPendingProgram(targetDays: 40);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2MuhasabahView(
            program: prog,
            onMuhasabahSubmit: ({
              required programId,
              required reasonCode,
              required reasonLabelSnapshot,
              note,
            }) async {
              final updated = ProgramV2Model(
                id: prog.id,
                ibadahId: prog.ibadahId,
                ibadahNameSnapshot: prog.ibadahNameSnapshot,
                targetDays: prog.targetDays,
                startDayKey: prog.startDayKey,
                status: ProgramV2Model.statusFailed,
                createdAt: prog.createdAt,
                updatedAt: DateTime.now(),
              );
              final failureRec = FailureRecordModel(
                id: FailureRecordV2Repository.buildFailureRecordId(
                    prog.pendingMissedDayKey!, prog.id),
                programId: prog.id,
                missedDayKey: prog.pendingMissedDayKey!,
                reasonCode: reasonCode,
                reasonLabelSnapshot: reasonLabelSnapshot,
                note: note,
                createdAt: DateTime.now(),
              );
              return OrchestratedMuhasabahResult.fromOutcome(
                outcome: OrchestratedMuhasabahOutcome.failedCreated,
                programId: programId,
                finalStatus: ProgramV2Model.statusFailed,
                program: updated,
                failureRecord: failureRec,
                completedDays: 39,
              );
            },
            reasonOptions: testReasons,
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sakit / Kurang Sehat'));
      await tester.pumpAndSettle();

      final submitBtn =
          find.byKey(const ValueKey('v2_muhasabah_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('v2_muhasabah_dialog_confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('v2_muhasabah_completed_view')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('v2_muhasabah_terminal_status')),
          findsOneWidget);
      expect(find.text('Belum Selesai'), findsWidgets);
      expect(find.text('Evaluasi Muhasabah Selesai'), findsOneWidget);
    });

    testWidgets(
        '5b: Presentation Mapping — Domain WARNING (>= 40 days, target 60) displays Hampir Selesai',
        (tester) async {
      final prog = createPendingProgram(targetDays: 60);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2MuhasabahView(
            program: prog,
            onMuhasabahSubmit: ({
              required programId,
              required reasonCode,
              required reasonLabelSnapshot,
              note,
            }) async {
              final updated = ProgramV2Model(
                id: prog.id,
                ibadahId: prog.ibadahId,
                ibadahNameSnapshot: prog.ibadahNameSnapshot,
                targetDays: prog.targetDays,
                startDayKey: prog.startDayKey,
                status: ProgramV2Model.statusWarning,
                createdAt: prog.createdAt,
                updatedAt: DateTime.now(),
              );
              final failureRec = FailureRecordModel(
                id: FailureRecordV2Repository.buildFailureRecordId(
                    prog.pendingMissedDayKey!, prog.id),
                programId: prog.id,
                missedDayKey: prog.pendingMissedDayKey!,
                reasonCode: reasonCode,
                reasonLabelSnapshot: reasonLabelSnapshot,
                note: note,
                createdAt: DateTime.now(),
              );
              return OrchestratedMuhasabahResult.fromOutcome(
                outcome: OrchestratedMuhasabahOutcome.warningCreated,
                programId: programId,
                finalStatus: ProgramV2Model.statusWarning,
                program: updated,
                failureRecord: failureRec,
                completedDays: 40,
              );
            },
            reasonOptions: testReasons,
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sakit / Kurang Sehat'));
      await tester.pumpAndSettle();

      final submitBtn =
          find.byKey(const ValueKey('v2_muhasabah_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('v2_muhasabah_dialog_confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('v2_muhasabah_completed_view')),
          findsOneWidget);
      expect(find.text('Hampir Selesai'), findsWidgets);
      expect(find.text('Amal Istiqomah Minimal Tercapai'), findsOneWidget);
    });

    testWidgets(
        '5c: Real Domain E2E — 39 consecutive valid day keys with target 40 results in persisted FAILED (Belum Selesai)',
        (tester) async {
      // 39 consecutive days from 2026-09-12 to 2026-10-20
      final prog = createPendingProgram(
        targetDays: 40,
        startDayKey: '2026-09-12',
        missedDayKey: '2026-10-21',
      );
      await saveProgram(tester, prog);

      // Seed 39 contiguous valid check-in records
      DateTime dayDate = DateTime(2026, 9, 12);
      for (int i = 0; i < 39; i++) {
        final dKey = DateService.formatCalendarDayKey(dayDate);
        final checkinId =
            DailyCheckInV2Repository.buildCheckInId(dKey, prog.id);
        await saveCheckIn(
          tester,
          DailyCheckInModel(
            id: checkinId,
            programId: prog.id,
            dayKey: dKey,
            checkedAt: DateTime(dayDate.year, dayDate.month, dayDate.day, 5, 0),
            createdAt: DateTime(dayDate.year, dayDate.month, dayDate.day, 5, 0),
          ),
        );
        dayDate = dayDate.add(const Duration(days: 1));
      }

      ProgramV2Model? completedProgramReceipt;

      final submitDone = Completer<void>();

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2MuhasabahView(
            program: prog,
            programRepository: programRepo,
            onMuhasabahSubmit: ({
              required programId,
              required reasonCode,
              required reasonLabelSnapshot,
              note,
            }) async {
              final res =
                  await tester.runAsync(() => orchestrator.submitMuhasabah(
                        programId: programId,
                        reasonCode: reasonCode,
                        reasonLabelSnapshot: reasonLabelSnapshot,
                        note: note,
                      ));
              submitDone.complete();
              return res!;
            },
            reasonOptions: testReasons,
            dateService: createDeterministicDateService(),
            onCompleted: (p) => completedProgramReceipt = p,
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select reason 'sakit'
      await tester.tap(find.text('Sakit / Kurang Sehat'));
      await tester.pumpAndSettle();

      // Submit and confirm
      final submitBtn =
          find.byKey(const ValueKey('v2_muhasabah_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('v2_muhasabah_dialog_confirm')));
      await tester.pump();

      // Await real domain submitMuhasabah completion
      await submitDone.future;

      await tester.pumpAndSettle();

      // Verify UI displays Belum Selesai terminal outcome
      expect(find.byKey(const ValueKey('v2_muhasabah_completed_view')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('v2_muhasabah_terminal_status')),
          findsOneWidget);
      expect(find.text('Belum Selesai'), findsWidgets);
      expect(find.text('Evaluasi Muhasabah Selesai'), findsOneWidget);
      expect(find.textContaining('39 hari terselesaikan'), findsOneWidget);

      // Verify callback was invoked with updated terminal model
      expect(completedProgramReceipt, isNotNull);
      expect(completedProgramReceipt!.id, equals(prog.id));
      expect(
          completedProgramReceipt!.status, equals(ProgramV2Model.statusFailed));

      // Verify authoritative domain repository persistence
      final persistedProg = programRepo.getById(prog.id);
      expect(persistedProg, isNotNull);
      expect(persistedProg!.status, equals(ProgramV2Model.statusFailed));
      expect(persistedProg.finalizedAt, isNotNull);

      final failureRecords = failureRepo.getByProgramId(prog.id);
      expect(failureRecords.length, equals(1));
      expect(failureRecords.first.missedDayKey, equals('2026-10-21'));
      expect(failureRecords.first.reasonCode, equals('sakit'));
      expect(failureRecords.first.reasonLabelSnapshot,
          equals('Sakit / Kurang Sehat'));
    });

    testWidgets(
        '5d: Real Domain E2E — 40 consecutive valid day keys with target 60 results in persisted WARNING (Hampir Selesai)',
        (tester) async {
      // 40 consecutive days from 2026-09-11 to 2026-10-20
      final prog = createPendingProgram(
        targetDays: 60,
        startDayKey: '2026-09-11',
        missedDayKey: '2026-10-21',
      );
      await saveProgram(tester, prog);

      // Seed 40 contiguous valid check-in records
      DateTime dayDate = DateTime(2026, 9, 11);
      for (int i = 0; i < 40; i++) {
        final dKey = DateService.formatCalendarDayKey(dayDate);
        final checkinId =
            DailyCheckInV2Repository.buildCheckInId(dKey, prog.id);
        await saveCheckIn(
          tester,
          DailyCheckInModel(
            id: checkinId,
            programId: prog.id,
            dayKey: dKey,
            checkedAt: DateTime(dayDate.year, dayDate.month, dayDate.day, 5, 0),
            createdAt: DateTime(dayDate.year, dayDate.month, dayDate.day, 5, 0),
          ),
        );
        dayDate = dayDate.add(const Duration(days: 1));
      }

      ProgramV2Model? completedProgramReceipt;
      final submitDone = Completer<void>();

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2MuhasabahView(
            program: prog,
            programRepository: programRepo,
            onMuhasabahSubmit: ({
              required programId,
              required reasonCode,
              required reasonLabelSnapshot,
              note,
            }) async {
              final res =
                  await tester.runAsync(() => orchestrator.submitMuhasabah(
                        programId: programId,
                        reasonCode: reasonCode,
                        reasonLabelSnapshot: reasonLabelSnapshot,
                        note: note,
                      ));
              submitDone.complete();
              return res!;
            },
            reasonOptions: testReasons,
            dateService: createDeterministicDateService(),
            onCompleted: (p) => completedProgramReceipt = p,
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select reason 'safar'
      await tester.tap(find.text('Safar / Perjalanan'));
      await tester.pumpAndSettle();

      // Submit and confirm
      final submitBtn =
          find.byKey(const ValueKey('v2_muhasabah_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('v2_muhasabah_dialog_confirm')));
      await tester.pump();

      // Await real domain submitMuhasabah completion
      await submitDone.future;

      await tester.pumpAndSettle();

      // Verify UI displays Hampir Selesai terminal outcome
      expect(find.byKey(const ValueKey('v2_muhasabah_completed_view')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('v2_muhasabah_terminal_status')),
          findsOneWidget);
      expect(find.text('Hampir Selesai'), findsWidgets);
      expect(find.text('Amal Istiqomah Minimal Tercapai'), findsOneWidget);
      expect(find.textContaining('40 hari'), findsOneWidget);

      // Verify callback was invoked with updated terminal model
      expect(completedProgramReceipt, isNotNull);
      expect(completedProgramReceipt!.id, equals(prog.id));
      expect(completedProgramReceipt!.status,
          equals(ProgramV2Model.statusWarning));

      // Verify authoritative domain repository persistence
      final persistedProg = programRepo.getById(prog.id);
      expect(persistedProg, isNotNull);
      expect(persistedProg!.status, equals(ProgramV2Model.statusWarning));
      expect(persistedProg.finalizedAt, isNotNull);

      final failureRecords = failureRepo.getByProgramId(prog.id);
      expect(failureRecords.length, equals(1));
      expect(failureRecords.first.missedDayKey, equals('2026-10-21'));
      expect(failureRecords.first.reasonCode, equals('safar'));
    });
  });

  group('Mandatory Test 6: In-Flight Guard, Conflicts & Error Handling', () {
    testWidgets('In-flight guard prevents multiple dispatches', (tester) async {
      final prog = createPendingProgram();
      int callCount = 0;
      final completer = Completer<OrchestratedMuhasabahResult>();

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2MuhasabahView(
            program: prog,
            reasonOptions: testReasons,
            onMuhasabahSubmit: ({
              required programId,
              required reasonCode,
              required reasonLabelSnapshot,
              note,
            }) {
              callCount++;
              return completer.future;
            },
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sakit / Kurang Sehat'));
      await tester.pumpAndSettle();

      final submitBtn =
          find.byKey(const ValueKey('v2_muhasabah_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('v2_muhasabah_dialog_confirm')));
      await tester.pump(); // Start submission

      expect(callCount, equals(1));

      // Attempt to tap submit again (should be guarded / disabled)
      await tester
          .tap(find.byKey(const ValueKey('v2_muhasabah_submit_button')));
      await tester.pump();
      expect(callCount, equals(1));

      // Complete async
      final updated = ProgramV2Model(
        id: prog.id,
        ibadahId: prog.ibadahId,
        ibadahNameSnapshot: prog.ibadahNameSnapshot,
        targetDays: prog.targetDays,
        startDayKey: prog.startDayKey,
        status: ProgramV2Model.statusFailed,
        createdAt: prog.createdAt,
        updatedAt: DateTime.now(),
      );
      final failureRec = FailureRecordModel(
        id: FailureRecordV2Repository.buildFailureRecordId(
            prog.pendingMissedDayKey!, prog.id),
        programId: prog.id,
        missedDayKey: prog.pendingMissedDayKey!,
        reasonCode: 'sakit',
        reasonLabelSnapshot: 'Sakit / Kurang Sehat',
        createdAt: DateTime.now(),
      );
      completer.complete(OrchestratedMuhasabahResult.fromOutcome(
        outcome: OrchestratedMuhasabahOutcome.failedCreated,
        programId: prog.id,
        finalStatus: ProgramV2Model.statusFailed,
        program: updated,
        failureRecord: failureRec,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('v2_muhasabah_completed_view')),
          findsOneWidget);
    });

    testWidgets('Domain conflict error displays truthful error banner',
        (tester) async {
      final prog = createPendingProgram();

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2MuhasabahView(
            program: prog,
            reasonOptions: testReasons,
            onMuhasabahSubmit: ({
              required programId,
              required reasonCode,
              required reasonLabelSnapshot,
              note,
            }) async {
              return OrchestratedMuhasabahResult.failure(
                outcome: OrchestratedMuhasabahOutcome.reasonConflict,
                programId: programId,
                message: 'Reason conflict detected.',
              );
            },
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sakit / Kurang Sehat'));
      await tester.pumpAndSettle();

      final submitBtn =
          find.byKey(const ValueKey('v2_muhasabah_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('v2_muhasabah_dialog_confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('v2_muhasabah_error_banner')),
          findsOneWidget);
      expect(
        find.textContaining('Alasan yang diajukan berbeda'),
        findsOneWidget,
      );
    });
  });

  group('Mandatory Test 7: App Resume & Stale Program Protection', () {
    testWidgets('App resume detects program state update to terminal',
        (tester) async {
      final prog = createPendingProgram();
      await saveProgram(tester, prog);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2MuhasabahView(
            program: prog,
            programRepository: programRepo,
            reasonOptions: testReasons,
            orchestrator: orchestrator,
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('v2_muhasabah_reasons_list')),
          findsOneWidget);

      // Externally update program to FAILED
      final updatedProg = ProgramV2Model(
        id: prog.id,
        ibadahId: prog.ibadahId,
        ibadahNameSnapshot: prog.ibadahNameSnapshot,
        targetDays: prog.targetDays,
        startDayKey: prog.startDayKey,
        status: ProgramV2Model.statusFailed,
        createdAt: prog.createdAt,
        updatedAt: DateTime.now(),
      );
      await saveProgram(tester, updatedProg);

      // Simulate App Resume
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // UI safely switches to non-pending notice
      expect(find.byKey(const ValueKey('v2_muhasabah_non_pending_notice')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('v2_muhasabah_submit_button')),
          findsNothing);
    });
  });

  group('Mandatory Test 8: Inactive-tab Back Behavior in App Shell', () {
    testWidgets('PopScope does not intercept Back when Program tab is inactive',
        (tester) async {
      final prog = createPendingProgram();
      await saveProgram(tester, prog);

      final navCtrl = V2NavigationController();
      Get.put<V2NavigationController>(navCtrl);

      final hubCtrl = V2ProgramHubController(
        programRepository: programRepo,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2AppShell(
            controller: navCtrl,
            program: V2ProgramHubView(
              controller: hubCtrl,
              navigationController: navCtrl,
              programRepository: programRepo,
              journeyOrchestrator: orchestrator,
              muhasabahService: muhasabahService,
              muhasabahReasonOptions: testReasons,
              dateService: createDeterministicDateService(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Program tab
      navCtrl.selectTab(V2NavigationTab.program);
      await tester.pumpAndSettle();

      // Open detail then muhasabah
      hubCtrl.openProgramDetail(prog);
      await tester.pumpAndSettle();
      hubCtrl.openMuhasabah(prog);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('v2_muhasabah_view')), findsOneWidget);

      // Switch away to Dashboard tab
      navCtrl.selectTab(V2NavigationTab.dashboard);
      await tester.pumpAndSettle();

      // Simulate system Back when on Dashboard tab
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Tab remains dashboard, program back stack didn't intercept incorrectly
      expect(navCtrl.currentTab, equals(V2NavigationTab.dashboard));
    });
  });

  group('Mandatory Test 9: Responsive, Touch Targets & Accessibility', () {
    testWidgets('Renders properly on 320dp width in Dark Mode', (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 600 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final prog = createPendingProgram();
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.darkTheme,
          home: V2MuhasabahView(
            program: prog,
            reasonOptions: testReasons,
            orchestrator: orchestrator,
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dynamic error = tester.takeException();
      expect(error, isNull);
      expect(find.byKey(const ValueKey('v2_muhasabah_view')), findsOneWidget);

      // Verify button min touch target
      final submitFinder =
          find.byKey(const ValueKey('v2_muhasabah_submit_button'));
      final cancelFinder =
          find.byKey(const ValueKey('v2_muhasabah_cancel_button'));
      expect(tester.getSize(submitFinder).height, greaterThanOrEqualTo(48.0));
      expect(tester.getSize(cancelFinder).height, greaterThanOrEqualTo(48.0));
    });
  });

  group('P1-01 Regression: Anti-False-Positive Terminal Verification', () {
    testWidgets(
        'Fake success receipt with unpersisted PENDING_FAILURE in repo is rejected fail-closed',
        (tester) async {
      final prog = createPendingProgram();
      await saveProgram(tester, prog);

      bool onCompletedCalled = false;

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2MuhasabahView(
            program: prog,
            programRepository: programRepo,
            reasonOptions: testReasons,
            onCompleted: (_) => onCompletedCalled = true,
            onMuhasabahSubmit: ({
              required programId,
              required reasonCode,
              required reasonLabelSnapshot,
              note,
            }) async {
              // Deliberately do NOT mutate repo — returns fake success
              return OrchestratedMuhasabahResult.fromOutcome(
                outcome: OrchestratedMuhasabahOutcome.failedCreated,
                programId: programId,
                finalStatus: ProgramV2Model.statusFailed,
                completedDays: 10,
              );
            },
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sakit / Kurang Sehat'));
      await tester.pumpAndSettle();

      final submitBtn =
          find.byKey(const ValueKey('v2_muhasabah_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('v2_muhasabah_dialog_confirm')));
      await tester.pumpAndSettle();

      // Must NOT show completed view and must NOT call onCompleted
      expect(find.byKey(const ValueKey('v2_muhasabah_completed_view')),
          findsNothing);
      expect(onCompletedCalled, isFalse);

      // Must show fail-closed error banner
      expect(find.byKey(const ValueKey('v2_muhasabah_error_banner')),
          findsOneWidget);
      expect(
        find.textContaining(
            'Gagal memverifikasi status terminal program yang tersimpan di penyimpanan lokal'),
        findsOneWidget,
      );
    });

    testWidgets(
        'Contradictory result status vs persisted repo status is rejected fail-closed',
        (tester) async {
      final prog = createPendingProgram();
      await saveProgram(tester, prog);

      final submitDone = Completer<void>();

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2MuhasabahView(
            program: prog,
            programRepository: programRepo,
            reasonOptions: testReasons,
            onMuhasabahSubmit: ({
              required programId,
              required reasonCode,
              required reasonLabelSnapshot,
              note,
            }) async {
              // Persist as FAILED in repo, but return WARNING in result receipt
              final updatedProg = ProgramV2Model(
                id: prog.id,
                ibadahId: prog.ibadahId,
                ibadahNameSnapshot: prog.ibadahNameSnapshot,
                targetDays: prog.targetDays,
                startDayKey: prog.startDayKey,
                status: ProgramV2Model.statusFailed,
                createdAt: prog.createdAt,
                updatedAt: DateTime.now(),
              );
              await tester.runAsync(() async {
                await programRepo.save(updatedProg);
              });
              submitDone.complete();
              return OrchestratedMuhasabahResult.fromOutcome(
                outcome: OrchestratedMuhasabahOutcome.warningCreated,
                programId: programId,
                finalStatus: ProgramV2Model.statusWarning,
                completedDays: 45,
              );
            },
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sakit / Kurang Sehat'));
      await tester.pumpAndSettle();

      final submitBtn =
          find.byKey(const ValueKey('v2_muhasabah_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('v2_muhasabah_dialog_confirm')));
      await tester.pump();

      await submitDone.future;
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('v2_muhasabah_completed_view')),
          findsNothing);
      expect(find.byKey(const ValueKey('v2_muhasabah_error_banner')),
          findsOneWidget);
      expect(
        find.textContaining('Gagal memverifikasi status terminal program'),
        findsOneWidget,
      );
    });

    testWidgets(
        'Callback-only mode without repo rejects incomplete success receipt missing models',
        (tester) async {
      final prog = createPendingProgram();

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2MuhasabahView(
            program: prog,
            // No repository supplied
            reasonOptions: testReasons,
            onMuhasabahSubmit: ({
              required programId,
              required reasonCode,
              required reasonLabelSnapshot,
              note,
            }) async {
              // Return success but missing program and failureRecord
              return OrchestratedMuhasabahResult.fromOutcome(
                outcome: OrchestratedMuhasabahOutcome.failedCreated,
                programId: programId,
                finalStatus: ProgramV2Model.statusFailed,
              );
            },
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sakit / Kurang Sehat'));
      await tester.pumpAndSettle();

      final submitBtn =
          find.byKey(const ValueKey('v2_muhasabah_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('v2_muhasabah_dialog_confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('v2_muhasabah_completed_view')),
          findsNothing);
      expect(find.byKey(const ValueKey('v2_muhasabah_error_banner')),
          findsOneWidget);
      expect(
        find.textContaining(
            'Respon finalisasi tidak memuat data program terminal yang lengkap'),
        findsOneWidget,
      );
    });
  });

  group('P1-02 Regression: Cross-Program Async Submission & State Scoping', () {
    testWidgets(
        'Program switch A -> B mid-flight clears loading and leaves B interactive and unaffected',
        (tester) async {
      final progA = createPendingProgram(id: 'prog-A', ibadahName: 'Tahajud A');
      final progB = createPendingProgram(id: 'prog-B', ibadahName: 'Dhuha B');

      final completerA = Completer<OrchestratedMuhasabahResult>();
      int callCountA = 0;
      int callCountB = 0;

      Widget buildView(ProgramV2Model prog) {
        return GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2MuhasabahView(
            program: prog,
            reasonOptions: testReasons,
            onMuhasabahSubmit: ({
              required programId,
              required reasonCode,
              required reasonLabelSnapshot,
              note,
            }) async {
              if (programId == 'prog-A') {
                callCountA++;
                return completerA.future;
              } else {
                callCountB++;
                final updated = ProgramV2Model(
                  id: progB.id,
                  ibadahId: progB.ibadahId,
                  ibadahNameSnapshot: progB.ibadahNameSnapshot,
                  targetDays: progB.targetDays,
                  startDayKey: progB.startDayKey,
                  status: ProgramV2Model.statusFailed,
                  createdAt: progB.createdAt,
                  updatedAt: DateTime.now(),
                );
                final failureRec = FailureRecordModel(
                  id: FailureRecordV2Repository.buildFailureRecordId(
                      progB.pendingMissedDayKey!, progB.id),
                  programId: progB.id,
                  missedDayKey: progB.pendingMissedDayKey!,
                  reasonCode: reasonCode,
                  reasonLabelSnapshot: reasonLabelSnapshot,
                  createdAt: DateTime.now(),
                );
                return OrchestratedMuhasabahResult.fromOutcome(
                  outcome: OrchestratedMuhasabahOutcome.failedCreated,
                  programId: programId,
                  finalStatus: ProgramV2Model.statusFailed,
                  program: updated,
                  failureRecord: failureRec,
                  completedDays: 5,
                );
              }
            },
            onBack: () {},
          ),
        );
      }

      await tester.pumpWidget(buildView(progA));
      await tester.pumpAndSettle();

      // Select reason for A and start submit
      await tester.tap(find.text('Sakit / Kurang Sehat'));
      await tester.pumpAndSettle();

      final submitBtnA =
          find.byKey(const ValueKey('v2_muhasabah_submit_button'));
      await tester.ensureVisible(submitBtnA);
      await tester.tap(submitBtnA);
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('v2_muhasabah_dialog_confirm')));
      await tester.pump(); // Start submission for A (in flight)

      expect(callCountA, equals(1));

      // Mid-flight switch widget to Program B
      await tester.pumpWidget(buildView(progB));
      await tester.pumpAndSettle();

      // Program B form must NOT be loading, and must be interactive
      expect(find.text('Dhuha B'), findsWidgets);
      expect(find.byKey(const ValueKey('v2_muhasabah_completed_view')),
          findsNothing);

      // Select reason for Program B
      await tester.tap(find.text('Safar / Perjalanan'));
      await tester.pumpAndSettle();

      final submitBtnB = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('v2_muhasabah_submit_button')),
      );
      expect(submitBtnB.onPressed, isNotNull); // Enabled and interactive!

      // Now resolve Program A's in-flight submission
      final progATerminal = ProgramV2Model(
        id: progA.id,
        ibadahId: progA.ibadahId,
        ibadahNameSnapshot: progA.ibadahNameSnapshot,
        targetDays: progA.targetDays,
        startDayKey: progA.startDayKey,
        status: ProgramV2Model.statusFailed,
        createdAt: progA.createdAt,
        updatedAt: DateTime.now(),
      );
      final progAFailure = FailureRecordModel(
        id: FailureRecordV2Repository.buildFailureRecordId(
            progA.pendingMissedDayKey!, progA.id),
        programId: progA.id,
        missedDayKey: progA.pendingMissedDayKey!,
        reasonCode: 'sakit',
        reasonLabelSnapshot: 'Sakit / Kurang Sehat',
        createdAt: DateTime.now(),
      );
      completerA.complete(OrchestratedMuhasabahResult.fromOutcome(
        outcome: OrchestratedMuhasabahOutcome.failedCreated,
        programId: progA.id,
        finalStatus: ProgramV2Model.statusFailed,
        program: progATerminal,
        failureRecord: progAFailure,
        completedDays: 5,
      ));
      await tester.pumpAndSettle();

      // Verify Program B remains on form, not contaminated by Program A's completion
      expect(find.text('Dhuha B'), findsWidgets);
      expect(find.byKey(const ValueKey('v2_muhasabah_completed_view')),
          findsNothing);

      // Program B can submit independently
      final btnBFinder =
          find.byKey(const ValueKey('v2_muhasabah_submit_button'));
      await tester.ensureVisible(btnBFinder);
      await tester.tap(btnBFinder);
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('v2_muhasabah_dialog_confirm')));
      await tester.pumpAndSettle();

      expect(callCountB, equals(1));
      expect(find.byKey(const ValueKey('v2_muhasabah_completed_view')),
          findsOneWidget);
      expect(find.text('Dhuha B'), findsWidgets);
    });
  });

  group('P1-03 Regression: Reason Catalogue Invariant & Dynamic Update', () {
    testWidgets(
        'Replacing reasonOptions with empty/null clears selection and disables submit',
        (tester) async {
      final prog = createPendingProgram();

      Widget buildView(List<MuhasabahReasonOption>? options) {
        return GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2MuhasabahView(
            program: prog,
            reasonOptions: options,
            onMuhasabahSubmit: ({
              required programId,
              required reasonCode,
              required reasonLabelSnapshot,
              note,
            }) async =>
                throw UnimplementedError('Must not be called'),
            onBack: () {},
          ),
        );
      }

      await tester.pumpWidget(buildView(testReasons));
      await tester.pumpAndSettle();

      // Select reason
      await tester.tap(find.text('Sakit / Kurang Sehat'));
      await tester.pumpAndSettle();

      final submitBtn1 = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('v2_muhasabah_submit_button')),
      );
      expect(submitBtn1.onPressed, isNotNull);

      // Parent updates options to empty
      await tester.pumpWidget(buildView([]));
      await tester.pumpAndSettle();

      // Must show fail-closed notice and submit must be disabled
      expect(find.byKey(const ValueKey('v2_muhasabah_no_reasons_notice')),
          findsOneWidget);
      final submitBtn2 = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('v2_muhasabah_submit_button')),
      );
      expect(submitBtn2.onPressed, isNull);
    });

    testWidgets(
        'Replacing reason option with changed label clears selection and disables submit',
        (tester) async {
      final prog = createPendingProgram();

      Widget buildView(List<MuhasabahReasonOption> options) {
        return GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2MuhasabahView(
            program: prog,
            reasonOptions: options,
            onMuhasabahSubmit: ({
              required programId,
              required reasonCode,
              required reasonLabelSnapshot,
              note,
            }) async =>
                throw UnimplementedError('Must not be called'),
            onBack: () {},
          ),
        );
      }

      await tester.pumpWidget(buildView(testReasons));
      await tester.pumpAndSettle();

      // Select 'sakit'
      await tester.tap(find.text('Sakit / Kurang Sehat'));
      await tester.pumpAndSettle();

      final submitBtn1 = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('v2_muhasabah_submit_button')),
      );
      expect(submitBtn1.onPressed, isNotNull);

      // Catalogue updates label for code 'sakit'
      const updatedReasons = [
        MuhasabahReasonOption(
          code: 'sakit',
          label: 'Sakit Keras / Rawat Inap', // changed label
        ),
      ];

      await tester.pumpWidget(buildView(updatedReasons));
      await tester.pumpAndSettle();

      // Previous selection was cleared because label snapshot changed
      final submitBtn2 = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('v2_muhasabah_submit_button')),
      );
      expect(submitBtn2.onPressed, isNull);

      // Selecting new option enables submit
      await tester.tap(find.text('Sakit Keras / Rawat Inap'));
      await tester.pumpAndSettle();

      final submitBtn3 = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('v2_muhasabah_submit_button')),
      );
      expect(submitBtn3.onPressed, isNotNull);
    });
  });

  group(
      'P1-05 Regression: Complete & Consistent Failure Record Receipt Verification',
      () {
    testWidgets(
        'Repository contains terminal FAILED, callback returns failedCreated with missing failureRecord is rejected fail-closed',
        (tester) async {
      final prog = createPendingProgram();
      final terminalProg = ProgramV2Model(
        id: prog.id,
        ibadahId: prog.ibadahId,
        ibadahNameSnapshot: prog.ibadahNameSnapshot,
        targetDays: prog.targetDays,
        startDayKey: prog.startDayKey,
        status: ProgramV2Model.statusFailed,
        pendingMissedDayKey: prog.pendingMissedDayKey,
        createdAt: prog.createdAt,
        updatedAt: DateTime.now(),
        finalizedAt: DateTime.now(),
      );
      await saveProgram(tester, terminalProg);

      bool onCompletedCalled = false;

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2MuhasabahView(
            program: prog,
            programRepository: programRepo,
            reasonOptions: testReasons,
            onCompleted: (_) => onCompletedCalled = true,
            onMuhasabahSubmit: ({
              required programId,
              required reasonCode,
              required reasonLabelSnapshot,
              note,
            }) async {
              return OrchestratedMuhasabahResult.fromOutcome(
                outcome: OrchestratedMuhasabahOutcome.failedCreated,
                programId: programId,
                finalStatus: ProgramV2Model.statusFailed,
                program: terminalProg,
                failureRecord: null, // deliberately missing
                completedDays: 10,
              );
            },
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sakit / Kurang Sehat'));
      await tester.pumpAndSettle();

      final submitBtn =
          find.byKey(const ValueKey('v2_muhasabah_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('v2_muhasabah_dialog_confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('v2_muhasabah_completed_view')),
          findsNothing);
      expect(onCompletedCalled, isFalse);
      expect(find.byKey(const ValueKey('v2_muhasabah_error_banner')),
          findsOneWidget);
      expect(
        find.textContaining(
            'Respon finalisasi tidak memuat bukti pencatatan muhasabah'),
        findsOneWidget,
      );
    });

    testWidgets(
        'Mismatched missedDayKey in failureRecord is rejected fail-closed with repository',
        (tester) async {
      final prog = createPendingProgram(missedDayKey: '2026-10-21');
      final terminalProg = ProgramV2Model(
        id: prog.id,
        ibadahId: prog.ibadahId,
        ibadahNameSnapshot: prog.ibadahNameSnapshot,
        targetDays: prog.targetDays,
        startDayKey: prog.startDayKey,
        status: ProgramV2Model.statusFailed,
        pendingMissedDayKey: prog.pendingMissedDayKey,
        createdAt: prog.createdAt,
        updatedAt: DateTime.now(),
        finalizedAt: DateTime.now(),
      );
      await saveProgram(tester, terminalProg);

      bool onCompletedCalled = false;

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2MuhasabahView(
            program: prog,
            programRepository: programRepo,
            reasonOptions: testReasons,
            onCompleted: (_) => onCompletedCalled = true,
            onMuhasabahSubmit: ({
              required programId,
              required reasonCode,
              required reasonLabelSnapshot,
              note,
            }) async {
              final mismatchedFailure = FailureRecordModel(
                id: 'fail-1',
                programId: programId,
                missedDayKey: '2026-10-15', // mismatched vs 2026-10-21
                reasonCode: reasonCode,
                reasonLabelSnapshot: reasonLabelSnapshot,
                createdAt: DateTime.now(),
              );
              return OrchestratedMuhasabahResult.fromOutcome(
                outcome: OrchestratedMuhasabahOutcome.failedCreated,
                programId: programId,
                finalStatus: ProgramV2Model.statusFailed,
                program: terminalProg,
                failureRecord: mismatchedFailure,
                completedDays: 10,
              );
            },
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sakit / Kurang Sehat'));
      await tester.pumpAndSettle();

      final submitBtn =
          find.byKey(const ValueKey('v2_muhasabah_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('v2_muhasabah_dialog_confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('v2_muhasabah_completed_view')),
          findsNothing);
      expect(onCompletedCalled, isFalse);
      expect(find.byKey(const ValueKey('v2_muhasabah_error_banner')),
          findsOneWidget);
      expect(
        find.textContaining(
            'Respon pencatatan muhasabah tidak sesuai dengan interupsi program'),
        findsOneWidget,
      );
    });

    testWidgets(
        'Mismatched missedDayKey in failureRecord is rejected fail-closed in callback-only mode',
        (tester) async {
      final prog = createPendingProgram(missedDayKey: '2026-10-21');
      bool onCompletedCalled = false;

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2MuhasabahView(
            program: prog,
            reasonOptions: testReasons,
            onCompleted: (_) => onCompletedCalled = true,
            onMuhasabahSubmit: ({
              required programId,
              required reasonCode,
              required reasonLabelSnapshot,
              note,
            }) async {
              final terminalProg = ProgramV2Model(
                id: prog.id,
                ibadahId: prog.ibadahId,
                ibadahNameSnapshot: prog.ibadahNameSnapshot,
                targetDays: prog.targetDays,
                startDayKey: prog.startDayKey,
                status: ProgramV2Model.statusFailed,
                pendingMissedDayKey: prog.pendingMissedDayKey,
                createdAt: prog.createdAt,
                updatedAt: DateTime.now(),
              );
              final mismatchedFailure = FailureRecordModel(
                id: 'fail-1',
                programId: programId,
                missedDayKey: '2026-10-05', // mismatched vs 2026-10-21
                reasonCode: reasonCode,
                reasonLabelSnapshot: reasonLabelSnapshot,
                createdAt: DateTime.now(),
              );
              return OrchestratedMuhasabahResult.fromOutcome(
                outcome: OrchestratedMuhasabahOutcome.failedCreated,
                programId: programId,
                finalStatus: ProgramV2Model.statusFailed,
                program: terminalProg,
                failureRecord: mismatchedFailure,
                completedDays: 10,
              );
            },
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sakit / Kurang Sehat'));
      await tester.pumpAndSettle();

      final submitBtn =
          find.byKey(const ValueKey('v2_muhasabah_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('v2_muhasabah_dialog_confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('v2_muhasabah_completed_view')),
          findsNothing);
      expect(onCompletedCalled, isFalse);
      expect(find.byKey(const ValueKey('v2_muhasabah_error_banner')),
          findsOneWidget);
      expect(
        find.textContaining(
            'Respon pencatatan muhasabah tidak sesuai dengan interupsi program'),
        findsOneWidget,
      );
    });

    testWidgets(
        'Mismatched reason code/label in failureRecord is rejected fail-closed with repository',
        (tester) async {
      final prog = createPendingProgram();
      final terminalProg = ProgramV2Model(
        id: prog.id,
        ibadahId: prog.ibadahId,
        ibadahNameSnapshot: prog.ibadahNameSnapshot,
        targetDays: prog.targetDays,
        startDayKey: prog.startDayKey,
        status: ProgramV2Model.statusFailed,
        pendingMissedDayKey: prog.pendingMissedDayKey,
        createdAt: prog.createdAt,
        updatedAt: DateTime.now(),
        finalizedAt: DateTime.now(),
      );
      await saveProgram(tester, terminalProg);

      bool onCompletedCalled = false;

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2MuhasabahView(
            program: prog,
            programRepository: programRepo,
            reasonOptions: testReasons,
            onCompleted: (_) => onCompletedCalled = true,
            onMuhasabahSubmit: ({
              required programId,
              required reasonCode,
              required reasonLabelSnapshot,
              note,
            }) async {
              final mismatchedFailure = FailureRecordModel(
                id: 'fail-1',
                programId: programId,
                missedDayKey: prog.pendingMissedDayKey!,
                reasonCode: 'safar', // mismatched vs 'sakit'
                reasonLabelSnapshot:
                    'Safar / Perjalanan', // mismatched vs 'Sakit / Kurang Sehat'
                createdAt: DateTime.now(),
              );
              return OrchestratedMuhasabahResult.fromOutcome(
                outcome: OrchestratedMuhasabahOutcome.failedCreated,
                programId: programId,
                finalStatus: ProgramV2Model.statusFailed,
                program: terminalProg,
                failureRecord: mismatchedFailure,
                completedDays: 10,
              );
            },
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sakit / Kurang Sehat'));
      await tester.pumpAndSettle();

      final submitBtn =
          find.byKey(const ValueKey('v2_muhasabah_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('v2_muhasabah_dialog_confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('v2_muhasabah_completed_view')),
          findsNothing);
      expect(onCompletedCalled, isFalse);
      expect(find.byKey(const ValueKey('v2_muhasabah_error_banner')),
          findsOneWidget);
      expect(
        find.textContaining(
            'Respon pencatatan muhasabah tidak sesuai dengan interupsi program atau alasan yang dipilih'),
        findsOneWidget,
      );
    });

    testWidgets(
        'Mismatched reason code/label in failureRecord is rejected fail-closed in callback-only mode',
        (tester) async {
      final prog = createPendingProgram();
      bool onCompletedCalled = false;

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2MuhasabahView(
            program: prog,
            reasonOptions: testReasons,
            onCompleted: (_) => onCompletedCalled = true,
            onMuhasabahSubmit: ({
              required programId,
              required reasonCode,
              required reasonLabelSnapshot,
              note,
            }) async {
              final terminalProg = ProgramV2Model(
                id: prog.id,
                ibadahId: prog.ibadahId,
                ibadahNameSnapshot: prog.ibadahNameSnapshot,
                targetDays: prog.targetDays,
                startDayKey: prog.startDayKey,
                status: ProgramV2Model.statusFailed,
                pendingMissedDayKey: prog.pendingMissedDayKey,
                createdAt: prog.createdAt,
                updatedAt: DateTime.now(),
              );
              final mismatchedFailure = FailureRecordModel(
                id: 'fail-1',
                programId: programId,
                missedDayKey: prog.pendingMissedDayKey!,
                reasonCode: 'safar', // mismatched vs 'sakit'
                reasonLabelSnapshot:
                    'Safar / Perjalanan', // mismatched vs 'Sakit / Kurang Sehat'
                createdAt: DateTime.now(),
              );
              return OrchestratedMuhasabahResult.fromOutcome(
                outcome: OrchestratedMuhasabahOutcome.failedCreated,
                programId: programId,
                finalStatus: ProgramV2Model.statusFailed,
                program: terminalProg,
                failureRecord: mismatchedFailure,
                completedDays: 10,
              );
            },
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sakit / Kurang Sehat'));
      await tester.pumpAndSettle();

      final submitBtn =
          find.byKey(const ValueKey('v2_muhasabah_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('v2_muhasabah_dialog_confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('v2_muhasabah_completed_view')),
          findsNothing);
      expect(onCompletedCalled, isFalse);
      expect(find.byKey(const ValueKey('v2_muhasabah_error_banner')),
          findsOneWidget);
      expect(
        find.textContaining(
            'Respon pencatatan muhasabah tidak sesuai dengan interupsi program atau alasan yang dipilih'),
        findsOneWidget,
      );
    });

    testWidgets(
        'Valid idempotent alreadyFinalized receipt with matching failure record passes',
        (tester) async {
      final prog = createPendingProgram();
      final terminalProg = ProgramV2Model(
        id: prog.id,
        ibadahId: prog.ibadahId,
        ibadahNameSnapshot: prog.ibadahNameSnapshot,
        targetDays: prog.targetDays,
        startDayKey: prog.startDayKey,
        status: ProgramV2Model.statusFailed,
        pendingMissedDayKey: prog.pendingMissedDayKey,
        createdAt: prog.createdAt,
        updatedAt: DateTime.now(),
        finalizedAt: DateTime.now(),
      );
      await saveProgram(tester, terminalProg);

      final matchingFailure = FailureRecordModel(
        id: FailureRecordV2Repository.buildFailureRecordId(
            prog.pendingMissedDayKey!, prog.id),
        programId: prog.id,
        missedDayKey: prog.pendingMissedDayKey!,
        reasonCode: 'sakit',
        reasonLabelSnapshot: 'Sakit / Kurang Sehat',
        createdAt: DateTime.now(),
      );
      await tester.runAsync(() async {
        await failureRepo.save(matchingFailure);
      });

      ProgramV2Model? completedResult;

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2MuhasabahView(
            program: prog,
            programRepository: programRepo,
            reasonOptions: testReasons,
            onCompleted: (p) => completedResult = p,
            onMuhasabahSubmit: ({
              required programId,
              required reasonCode,
              required reasonLabelSnapshot,
              note,
            }) async {
              return OrchestratedMuhasabahResult.fromOutcome(
                outcome: OrchestratedMuhasabahOutcome.alreadyFinalized,
                programId: programId,
                finalStatus: ProgramV2Model.statusFailed,
                program: terminalProg,
                failureRecord: matchingFailure,
                completedDays: 15,
              );
            },
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sakit / Kurang Sehat'));
      await tester.pumpAndSettle();

      final submitBtn =
          find.byKey(const ValueKey('v2_muhasabah_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('v2_muhasabah_dialog_confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('v2_muhasabah_completed_view')),
          findsOneWidget);
      expect(completedResult, isNotNull);
      expect(completedResult!.status, equals(ProgramV2Model.statusFailed));
      expect(find.byKey(const ValueKey('v2_muhasabah_error_banner')),
          findsNothing);
    });
  });

  group('P2-04 Regression: Nonblank Reason Validation & Fail-Closed Guard', () {
    testWidgets(
        'Catalog with empty or whitespace-only code or label keeps submit disabled and prevents confirmation dialog',
        (tester) async {
      final prog = createPendingProgram();
      bool callbackCalled = false;

      const malformedReasons = [
        MuhasabahReasonOption(
          code: '   ',
          label: '   ',
          description: 'Whitespace only',
        ),
        MuhasabahReasonOption(
          code: '',
          label: 'Alasan Tanpa Kode',
        ),
        MuhasabahReasonOption(
          code: 'kode_tanpa_label',
          label: '   ',
        ),
      ];

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2MuhasabahView(
            program: prog,
            reasonOptions: malformedReasons,
            onMuhasabahSubmit: ({
              required programId,
              required reasonCode,
              required reasonLabelSnapshot,
              note,
            }) async {
              callbackCalled = true;
              throw UnimplementedError('Callback must not be invoked');
            },
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Submit must be disabled initially
      final submitBtn1 = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('v2_muhasabah_submit_button')),
      );
      expect(submitBtn1.onPressed, isNull);

      // Tap malformed option
      await tester.tap(find.text('Alasan Tanpa Kode'));
      await tester.pumpAndSettle();

      // Submit must STILL be disabled
      final submitBtn2 = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('v2_muhasabah_submit_button')),
      );
      expect(submitBtn2.onPressed, isNull);

      // Confirm dialog must not exist
      expect(find.byKey(const ValueKey('v2_muhasabah_confirm_dialog')),
          findsNothing);
      expect(callbackCalled, isFalse);
    });

    testWidgets(
        'Mixed catalog allows valid item selection and submission while malformed item remains un-submittable',
        (tester) async {
      final prog = createPendingProgram();
      bool callbackCalled = false;
      String? recordedCode;
      String? recordedLabel;

      const mixedReasons = [
        MuhasabahReasonOption(
          code: '   ',
          label: '   ',
        ),
        MuhasabahReasonOption(
          code: 'valid_reason',
          label: 'Alasan Valid Resmi',
          description: 'Deskripsi alasan valid',
        ),
      ];

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2MuhasabahView(
            program: prog,
            reasonOptions: mixedReasons,
            onMuhasabahSubmit: ({
              required programId,
              required reasonCode,
              required reasonLabelSnapshot,
              note,
            }) async {
              callbackCalled = true;
              recordedCode = reasonCode;
              recordedLabel = reasonLabelSnapshot;
              final terminalProg = ProgramV2Model(
                id: prog.id,
                ibadahId: prog.ibadahId,
                ibadahNameSnapshot: prog.ibadahNameSnapshot,
                targetDays: prog.targetDays,
                startDayKey: prog.startDayKey,
                status: ProgramV2Model.statusFailed,
                pendingMissedDayKey: prog.pendingMissedDayKey,
                createdAt: prog.createdAt,
                updatedAt: DateTime.now(),
              );
              final failureRec = FailureRecordModel(
                id: FailureRecordV2Repository.buildFailureRecordId(
                    prog.pendingMissedDayKey!, prog.id),
                programId: prog.id,
                missedDayKey: prog.pendingMissedDayKey!,
                reasonCode: reasonCode,
                reasonLabelSnapshot: reasonLabelSnapshot,
                createdAt: DateTime.now(),
              );
              return OrchestratedMuhasabahResult.fromOutcome(
                outcome: OrchestratedMuhasabahOutcome.failedCreated,
                programId: programId,
                finalStatus: ProgramV2Model.statusFailed,
                program: terminalProg,
                failureRecord: failureRec,
                completedDays: 5,
              );
            },
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Submit disabled initially
      final submitBtn1 = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('v2_muhasabah_submit_button')),
      );
      expect(submitBtn1.onPressed, isNull);

      // Select valid option
      await tester.tap(find.text('Alasan Valid Resmi'));
      await tester.pumpAndSettle();

      // Submit enabled
      final submitBtn2 = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('v2_muhasabah_submit_button')),
      );
      expect(submitBtn2.onPressed, isNotNull);

      // Submit and confirm
      final submitBtnFinder =
          find.byKey(const ValueKey('v2_muhasabah_submit_button'));
      await tester.ensureVisible(submitBtnFinder);
      await tester.tap(submitBtnFinder);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('v2_muhasabah_confirm_dialog')),
          findsOneWidget);
      await tester
          .tap(find.byKey(const ValueKey('v2_muhasabah_dialog_confirm')));
      await tester.pumpAndSettle();

      expect(callbackCalled, isTrue);
      expect(recordedCode, equals('valid_reason'));
      expect(recordedLabel, equals('Alasan Valid Resmi'));
      expect(find.byKey(const ValueKey('v2_muhasabah_completed_view')),
          findsOneWidget);
    });
  });
}
