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
import 'package:mujahadah/models/daily_checkin_model.dart';
import 'package:mujahadah/models/program_v2_model.dart';
import 'package:mujahadah/repositories/daily_checkin_v2_repository.dart';
import 'package:mujahadah/repositories/program_v2_repository.dart';
import 'package:mujahadah/services/daily_checkin_v2_service.dart';
import 'package:mujahadah/theme/v2_theme.dart';
import 'package:mujahadah/views/v2/program/v2_program_detail_view.dart';
import 'package:mujahadah/views/v2/program/v2_program_hub_view.dart';
import 'package:mujahadah/views/v2/shell/v2_app_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<ProgramV2Model> programBox;
  late Box<DailyCheckInModel> checkInBox;
  late ProgramV2Repository programRepo;
  late DailyCheckInV2Repository checkInRepo;

  DateTime simulatedNow = DateTime(2026, 10, 22, 17, 0);
  DateService createDeterministicDateService() {
    return DateService(nowProvider: () => simulatedNow);
  }

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('v2_program_detail_test_');
    Hive.init(tempDir.path);
    V2Runtime.registerAdapters();

    programBox =
        await Hive.openBox<ProgramV2Model>('test_program_detail_programs_v2');
    checkInBox = await Hive.openBox<DailyCheckInModel>(
        'test_program_detail_checkins_v2');
    programRepo = ProgramV2Repository(box: programBox);
    checkInRepo = DailyCheckInV2Repository(box: checkInBox);
  });

  tearDownAll(() async {});

  setUp(() async {
    Get.reset();
    await programBox.deleteAll(programBox.keys.toList());
    await checkInBox.deleteAll(checkInBox.keys.toList());
    simulatedNow = DateTime(2026, 10, 22, 17, 0);
  });

  tearDown(() {
    Get.reset();
  });

  ProgramV2Model createTestProgram({
    String id = 'prog_dhuha_1',
    String ibadahId = 'sholat_dhuha',
    String ibadahNameSnapshot = 'Sholat Dhuha',
    int targetDays = 40,
    String startDayKey = '2026-10-22',
    String status = ProgramV2Model.statusActive,
    String? reminderTime = '08:30',
    String? recipientNameSnapshot,
  }) {
    final now = DateTime.now();
    return ProgramV2Model(
      id: id,
      ibadahId: ibadahId,
      ibadahNameSnapshot: ibadahNameSnapshot,
      targetDays: targetDays,
      startDayKey: startDayKey,
      status: status,
      reminderTime: reminderTime,
      recipientNameSnapshot: recipientNameSnapshot,
      createdAt: now,
      updatedAt: now,
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

  group('V2 Screen S21 Program Detail & Daily Check-in UI (TASK MV2-B0-02-07)',
      () {
    // -------------------------------------------------------------------------
    // Scenario 1: S17 -> S21 Navigation by Stable Program ID
    // -------------------------------------------------------------------------
    testWidgets('1. S17 -> S21 navigation by stable Program ID',
        (tester) async {
      final prog = createTestProgram(
        id: 'prog_active_01',
        ibadahNameSnapshot: 'Sholat Dhuha 40 Hari',
      );
      await saveProgram(tester, prog);

      final dateService = createDeterministicDateService();
      final checkInService = DailyCheckInV2Service(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: dateService,
      );

      final controller = V2ProgramHubController(
        programRepository: programRepo,
      );
      controller.selectTab(ProgramHubTab.ibadahSaya);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            controller: controller,
            programRepository: programRepo,
            dailyCheckInService: checkInService,
            dateService: dateService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify card exists in Ibadah Saya
      expect(find.byKey(const ValueKey('v2_active_program_prog_active_01')),
          findsOneWidget);

      // Tap card
      await tester
          .tap(find.byKey(const ValueKey('v2_active_program_prog_active_01')));
      await tester.pumpAndSettle();

      // S21 Program Detail is now visible
      expect(find.byType(V2ProgramDetailView), findsOneWidget);
      expect(find.text('Sholat Dhuha 40 Hari'), findsOneWidget);
      expect(find.byKey(const ValueKey('v2_program_detail_back_button')),
          findsOneWidget);
      expect(controller.currentStep, ProgramScreenStep.programDetail);
      expect(controller.selectedProgram?.id, 'prog_active_01');
    });

    // -------------------------------------------------------------------------
    // Scenario 2: Return navigation preserves Program Hub state
    // -------------------------------------------------------------------------
    testWidgets('2. Return navigation preserves Program Hub state',
        (tester) async {
      final prog1 = createTestProgram(
        id: 'prog_active_01',
        ibadahNameSnapshot: 'Sholat Tahajjud',
      );
      final prog2 = createTestProgram(
        id: 'prog_active_02',
        ibadahNameSnapshot: 'Sholat Dhuha',
      );
      await saveProgram(tester, prog1);
      await saveProgram(tester, prog2);

      final dateService = createDeterministicDateService();
      final controller = V2ProgramHubController(
        programRepository: programRepo,
      );
      controller.selectTab(ProgramHubTab.ibadahSaya);
      controller.setSearchQuery('Dhuha');

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            controller: controller,
            programRepository: programRepo,
            dateService: dateService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Only prog2 is visible due to search filter
      expect(find.byKey(const ValueKey('v2_active_program_prog_active_02')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('v2_active_program_prog_active_01')),
          findsNothing);

      // Open detail
      await tester
          .tap(find.byKey(const ValueKey('v2_active_program_prog_active_02')));
      await tester.pumpAndSettle();
      expect(find.byType(V2ProgramDetailView), findsOneWidget);

      // Tap Back button on S21
      await tester
          .tap(find.byKey(const ValueKey('v2_program_detail_back_button')));
      await tester.pumpAndSettle();

      // Restores Hub state: Ibadah Saya tab and search query intact
      expect(find.byType(V2ProgramDetailView), findsNothing);
      expect(controller.currentStep, ProgramScreenStep.hub);
      expect(controller.currentTab, ProgramHubTab.ibadahSaya);
      expect(controller.searchQuery, 'Dhuha');
      expect(controller.selectedProgram, isNull);
    });

    // -------------------------------------------------------------------------
    // Scenario 3: ACTIVE Program Presentation
    // -------------------------------------------------------------------------
    testWidgets(
        '3. ACTIVE program presentation: accessible labels, icons, metadata',
        (tester) async {
      final prog = createTestProgram(
        id: 'prog_active_dhuha',
        ibadahNameSnapshot: 'Sholat Dhuha',
        targetDays: 40,
        startDayKey: '2026-10-22',
        status: ProgramV2Model.statusActive,
        reminderTime: '08:30',
      );
      await saveProgram(tester, prog);

      final dateService = createDeterministicDateService();

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramDetailView(
            program: prog,
            onBack: () {},
            dateService: dateService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Program name
      expect(find.text('Sholat Dhuha'), findsWidgets);
      // Status badge contains label 'Aktif'
      expect(find.text('Aktif'), findsOneWidget);
      // Target days info
      expect(find.text('40 Hari Berturut-turut'), findsOneWidget);
      // Reminder time
      expect(find.text('Pukul 08:30'), findsOneWidget);
      // Starting date info
      expect(find.text('22 Oktober 2026'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Scenario 4: PENDING_FAILURE Presentation
    // -------------------------------------------------------------------------
    testWidgets(
        '4. PENDING_FAILURE presentation: surfaces Perlu Muhasabah, blocks checkin, provides S22 hook',
        (tester) async {
      final prog = createTestProgram(
        id: 'prog_pending_fail',
        ibadahNameSnapshot: 'Sholat Witir',
        status: ProgramV2Model.statusPendingFailure,
      );
      await saveProgram(tester, prog);

      bool muhasabahTapped = false;
      final dateService = createDeterministicDateService();

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramDetailView(
            program: prog,
            onBack: () {},
            dateService: dateService,
            onMuhasabahTap: () {
              muhasabahTapped = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Shows 'Perlu Muhasabah' badge and banner
      expect(find.text('Perlu Muhasabah'), findsWidgets);
      expect(find.byKey(const ValueKey('v2_program_detail_muhasabah_banner')),
          findsOneWidget);

      // Check-in CTA button is replaced by Muhasabah card
      expect(find.byKey(const ValueKey('v2_program_detail_checkin_button')),
          findsNothing);

      // Tap Muhasabah CTA button in banner
      await tester.tap(
          find.byKey(const ValueKey('v2_program_detail_muhasabah_button')));
      await tester.pumpAndSettle();
      expect(muhasabahTapped, isTrue);

      // Verify program model in Hive is untouched (zero failure mutations from UI)
      final storedProg = programRepo.getById('prog_pending_fail');
      expect(storedProg?.status, ProgramV2Model.statusPendingFailure);
    });

    // -------------------------------------------------------------------------
    // Scenario 5: SUCCESS / FAILED / WARNING read-only presentation
    // -------------------------------------------------------------------------
    testWidgets(
        '5. SUCCESS / FAILED / WARNING read-only presentation: checkin CTA disabled',
        (tester) async {
      for (final status in [
        ProgramV2Model.statusSuccess,
        ProgramV2Model.statusFailed,
        ProgramV2Model.statusWarning,
      ]) {
        final prog = createTestProgram(
          id: 'prog_term_$status',
          status: status,
        );
        await saveProgram(tester, prog);

        await tester.pumpWidget(
          GetMaterialApp(
            theme: V2Theme.lightTheme,
            home: V2ProgramDetailView(
              program: prog,
              onBack: () {},
              dateService: createDeterministicDateService(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check-in CTA is replaced by terminal banner
        expect(find.byKey(const ValueKey('v2_program_detail_checkin_button')),
            findsNothing);

        // Terminal banner is displayed
        expect(find.byKey(const ValueKey('v2_program_detail_terminal_banner')),
            findsOneWidget);
      }
    });

    // -------------------------------------------------------------------------
    // Scenario 6: Actual recorded progress vs elapsed days
    // -------------------------------------------------------------------------
    testWidgets(
        '6. Actual recorded progress vs elapsed days: derives strictly from checkin records',
        (tester) async {
      // Program started 10 days ago: 2026-10-12
      final prog = createTestProgram(
        id: 'prog_progress_test',
        targetDays: 40,
        startDayKey: '2026-10-12',
      );
      await saveProgram(tester, prog);

      // But only 2 records exist: 2026-10-12 and 2026-10-13
      final checkin1 = DailyCheckInModel(
        id: '2026-10-12_prog_progress_test',
        programId: prog.id,
        dayKey: '2026-10-12',
        checkedAt: DateTime(2026, 10, 12, 10, 0),
        createdAt: DateTime(2026, 10, 12, 10, 0),
      );
      final checkin2 = DailyCheckInModel(
        id: '2026-10-13_prog_progress_test',
        programId: prog.id,
        dayKey: '2026-10-13',
        checkedAt: DateTime(2026, 10, 13, 10, 0),
        createdAt: DateTime(2026, 10, 13, 10, 0),
      );
      await saveCheckIn(tester, checkin1);
      await saveCheckIn(tester, checkin2);

      final dateService = createDeterministicDateService();
      final checkInService = DailyCheckInV2Service(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: dateService,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramDetailView(
            program: prog,
            onBack: () {},
            dailyCheckInService: checkInService,
            dateService: dateService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Authoritative completed days is 2, remaining is 38 (NOT 10 days)
      expect(find.text('2 dari 40 Hari Selesai'), findsOneWidget);
      expect(find.text('Sisa 38 hari lagi'), findsOneWidget);
      // Progress percentage: 2 / 40 = 5%
      expect(find.text('5%'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Scenario 7: No false milestone or achievement
    // -------------------------------------------------------------------------
    testWidgets(
        '7. No false milestone or achievement: milestones highlight only when reached',
        (tester) async {
      final prog = createTestProgram(
        id: 'prog_milestone_test',
        targetDays: 100,
        startDayKey: '2026-10-22',
      );
      await saveProgram(tester, prog);

      final dateService = createDeterministicDateService();
      final checkInService = DailyCheckInV2Service(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: dateService,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramDetailView(
            program: prog,
            onBack: () {},
            dailyCheckInService: checkInService,
            dateService: dateService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Milestones 40, 60, 90, 100 days are rendered
      expect(find.text('40 Hari'), findsWidgets);
      expect(find.text('60 Hari'), findsOneWidget);
      expect(find.text('90 Hari'), findsOneWidget);
      expect(find.text('100 Hari'), findsOneWidget);

      // Since completed is 0, none are reached
      expect(find.text('Target Utama Tercapai'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // Scenario 8: Missing Program ID or unavailable record
    // -------------------------------------------------------------------------
    testWidgets('8. Missing Program ID or unavailable record fails gracefully',
        (tester) async {
      final controller = V2ProgramHubController(
        programRepository: programRepo,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            controller: controller,
            programRepository: programRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Attempt to open nonexistent ID
      controller.openProgramDetailById('nonexistent_id_xyz');
      await tester.pumpAndSettle();

      // Fails gracefully: remains on Hub without crash or error dialog
      expect(find.byType(V2ProgramDetailView), findsNothing);
      expect(controller.currentStep, ProgramScreenStep.hub);
    });

    // -------------------------------------------------------------------------
    // Scenario 9: Check-in confirmation displayed before dispatch
    // -------------------------------------------------------------------------
    testWidgets('9. Check-in confirmation displayed before dispatch',
        (tester) async {
      final prog = createTestProgram(
        id: 'prog_confirm_test',
        targetDays: 40,
        startDayKey: '2026-10-22',
      );
      await saveProgram(tester, prog);

      int dispatchCount = 0;
      final dateService = createDeterministicDateService();

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramDetailView(
            program: prog,
            onBack: () {},
            dateService: dateService,
            onDailyCheckIn: (id, confirmed) async {
              dispatchCount++;
              return DailyCheckInResult.failure(
                reason: DailyCheckInFailureReason.alreadyCheckedIn,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Check-in CTA
      await tester
          .tap(find.byKey(const ValueKey('v2_program_detail_checkin_button')));
      await tester.pumpAndSettle();

      // Modal dialog is shown
      expect(find.byKey(const ValueKey('v2_checkin_confirmation_dialog')),
          findsOneWidget);
      expect(find.text('Konfirmasi Check-in'), findsOneWidget);

      // Prior to confirming, dispatchCount MUST be 0!
      expect(dispatchCount, 0);
    });

    // -------------------------------------------------------------------------
    // Scenario 10: Cancel confirmation results in zero writes
    // -------------------------------------------------------------------------
    testWidgets('10. Cancel confirmation results in zero writes',
        (tester) async {
      final prog = createTestProgram(
        id: 'prog_cancel_test',
        targetDays: 40,
        startDayKey: '2026-10-22',
      );
      await saveProgram(tester, prog);

      int dispatchCount = 0;
      final dateService = createDeterministicDateService();

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramDetailView(
            program: prog,
            onBack: () {},
            dateService: dateService,
            onDailyCheckIn: (id, confirmed) async {
              dispatchCount++;
              return DailyCheckInResult.failure(
                reason: DailyCheckInFailureReason.alreadyCheckedIn,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap CTA to open modal
      await tester
          .tap(find.byKey(const ValueKey('v2_program_detail_checkin_button')));
      await tester.pumpAndSettle();

      // Tap 'Batal' button
      await tester.tap(find.byKey(const ValueKey('v2_checkin_cancel_button')));
      await tester.pumpAndSettle();

      // Modal is dismissed, zero dispatches and zero checkin records created
      expect(find.byKey(const ValueKey('v2_checkin_confirmation_dialog')),
          findsNothing);
      expect(dispatchCount, 0);
      expect(checkInBox.isEmpty, isTrue);
    });

    // -------------------------------------------------------------------------
    // Scenario 11: Missing check-in handler remains fail-closed
    // -------------------------------------------------------------------------
    testWidgets(
        '11. Missing check-in handler remains fail-closed with honest guidance',
        (tester) async {
      final prog = createTestProgram(
        id: 'prog_no_handler',
        targetDays: 40,
        startDayKey: '2026-10-22',
      );
      await saveProgram(tester, prog);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramDetailView(
            program: prog,
            onBack: () {},
            dailyCheckInService: null,
            onDailyCheckIn: null,
            dateService: createDeterministicDateService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // CTA button is disabled and displays honest user message
      final checkinButton = tester.widget<ElevatedButton>(
          find.byKey(const ValueKey('v2_program_detail_checkin_button')));
      expect(checkinButton.onPressed, isNull);
      expect(find.text('Layanan check-in belum tersedia.'), findsOneWidget);
      expect(checkInBox.isEmpty, isTrue);
    });

    // -------------------------------------------------------------------------
    // Scenario 12: Successful injected check-in reflects authoritative result
    // -------------------------------------------------------------------------
    testWidgets(
        '12. Successful injected check-in reflects authoritative result',
        (tester) async {
      final prog = createTestProgram(
        id: 'prog_success_test',
        targetDays: 40,
        startDayKey: '2026-10-22',
      );
      await saveProgram(tester, prog);

      final dateService = createDeterministicDateService();
      bool programUpdatedCalled = false;

      final authoritativeSnapshot = ProgramProgressSnapshot(
        programId: prog.id,
        targetDays: 40,
        completedDays: 1,
        remainingDays: 39,
        isCompletedToday: true,
        isTargetReached: false,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramDetailView(
            program: prog,
            onBack: () {},
            dateService: dateService,
            onProgramUpdated: () {
              programUpdatedCalled = true;
            },
            onDailyCheckIn: (id, confirmed) async {
              return DailyCheckInResult.success(
                checkIn: DailyCheckInModel(
                  id: '2026-10-22_$id',
                  programId: id,
                  dayKey: '2026-10-22',
                  checkedAt: DateTime(2026, 10, 22, 10, 0),
                  createdAt: DateTime(2026, 10, 22, 10, 0),
                ),
                targetReached: false,
                progress: authoritativeSnapshot,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Check-in CTA
      await tester
          .tap(find.byKey(const ValueKey('v2_program_detail_checkin_button')));
      await tester.pumpAndSettle();

      // Tap confirm button
      await tester.tap(find.byKey(const ValueKey('v2_checkin_confirm_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // Success message displayed
      expect(find.text('Alhamdulillah! Check-in hari ini berhasil dicatat.'),
          findsOneWidget);
      expect(programUpdatedCalled, isTrue);

      // Check-in button becomes disabled with "Ibadah Hari Ini Selesai"
      expect(find.text('Ibadah Hari Ini Selesai'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(
          find.byKey(const ValueKey('v2_program_detail_checkin_button')));
      expect(button.onPressed, isNull);
    });

    // -------------------------------------------------------------------------
    // Scenario 13: Failed check-in preserves correct previous state
    // -------------------------------------------------------------------------
    testWidgets(
        '13. Failed check-in preserves correct previous state and shows error',
        (tester) async {
      final prog = createTestProgram(
        id: 'prog_fail_state_test',
        targetDays: 40,
        startDayKey: '2026-10-22',
      );
      await saveProgram(tester, prog);

      final dateService = createDeterministicDateService();

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramDetailView(
            program: prog,
            onBack: () {},
            dateService: dateService,
            onDailyCheckIn: (id, confirmed) async {
              return DailyCheckInResult.failure(
                reason: DailyCheckInFailureReason.persistenceError,
                message:
                    'Gagal menyimpan check-in ke penyimpanan. Silakan coba lagi.',
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger check-in
      await tester
          .tap(find.byKey(const ValueKey('v2_program_detail_checkin_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('v2_checkin_confirm_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // Error banner displayed
      expect(
          find.text(
              'Gagal menyimpan check-in ke penyimpanan. Silakan coba lagi.'),
          findsOneWidget);
      // Zero writes
      expect(checkInBox.isEmpty, isTrue);
    });

    // -------------------------------------------------------------------------
    // Scenario 14: Duplicate check-in is not counted
    // -------------------------------------------------------------------------
    testWidgets(
        '14. Duplicate check-in is not counted and displays approved message',
        (tester) async {
      final prog = createTestProgram(
        id: 'prog_dup_test',
        targetDays: 40,
        startDayKey: '2026-10-22',
      );
      await saveProgram(tester, prog);

      // Seed an existing check-in for today
      final existingCheckIn = DailyCheckInModel(
        id: '2026-10-22_prog_dup_test',
        programId: prog.id,
        dayKey: '2026-10-22',
        checkedAt: DateTime(2026, 10, 22, 10, 0),
        createdAt: DateTime(2026, 10, 22, 10, 0),
      );
      await saveCheckIn(tester, existingCheckIn);

      final dateService = createDeterministicDateService();
      final checkInService = DailyCheckInV2Service(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: dateService,
      );

      // Attempting check-in via service directly should return alreadyCheckedIn
      final directResult = await tester.runAsync(() => checkInService.checkIn(
            programId: prog.id,
            confirmedByUser: true,
          ));
      expect(directResult?.failureReason,
          DailyCheckInFailureReason.alreadyCheckedIn);

      // Test UI handling when already checked in
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramDetailView(
            program: prog,
            onBack: () {},
            dailyCheckInService: checkInService,
            dateService: dateService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Button is disabled with "Ibadah Hari Ini Selesai"
      expect(find.text('Ibadah Hari Ini Selesai'), findsOneWidget);
      expect(find.text('Anda sudah menyelesaikan ibadahnya hari ini.'),
          findsOneWidget);
      final button = tester.widget<ElevatedButton>(
          find.byKey(const ValueKey('v2_program_detail_checkin_button')));
      expect(button.onPressed, isNull);
      expect(checkInBox.length, 1);
    });

    // -------------------------------------------------------------------------
    // Scenario 15: Operational day: 22:59 and 00:30 resolve to the same day
    // -------------------------------------------------------------------------
    testWidgets('15. 22:59 and 00:30 resolve to the same operational day',
        (tester) async {
      // 22:59 local civil time on 2026-10-22
      final timeNight = DateTime(2026, 10, 22, 22, 59);
      final dsNight = DateService(nowProvider: () => timeNight);
      final dayKeyNight = dsNight.getTodayDayKey();

      // 00:30 local civil time on 2026-10-23
      final timeAfterMidnight = DateTime(2026, 10, 23, 0, 30);
      final dsAfterMidnight = DateService(nowProvider: () => timeAfterMidnight);
      final dayKeyAfterMidnight = dsAfterMidnight.getTodayDayKey();

      // Because 00:30 is before 03:00 boundary, it belongs to the previous day (2026-10-22)
      expect(dayKeyNight, '2026-10-22');
      expect(dayKeyAfterMidnight, '2026-10-22');
      expect(dayKeyNight, equals(dayKeyAfterMidnight));

      // End-to-end checkin rejection at 00:30 after checking in at 22:59
      final prog = createTestProgram(
        id: 'prog_op_day_test',
        startDayKey: '2026-10-22',
      );
      await saveProgram(tester, prog);

      final serviceNight = DailyCheckInV2Service(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: dsNight,
      );
      final res1 = await tester.runAsync(() => serviceNight.checkIn(
            programId: prog.id,
            confirmedByUser: true,
          ));
      expect(res1?.isSuccess, isTrue);

      final serviceAfterMidnight = DailyCheckInV2Service(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: dsAfterMidnight,
      );
      final res2 = await tester.runAsync(() => serviceAfterMidnight.checkIn(
            programId: prog.id,
            confirmedByUser: true,
          ));
      expect(res2?.isSuccess, isFalse);
      expect(res2?.failureReason, DailyCheckInFailureReason.alreadyCheckedIn);
    });

    // -------------------------------------------------------------------------
    // Scenario 16: Operational day: 02:59:59 and 03:00:00 resolve to different days
    // -------------------------------------------------------------------------
    testWidgets(
        '16. 02:59:59 and 03:00:00 resolve to different operational days',
        (tester) async {
      // 02:59:59 local civil time on 2026-10-23
      final timeBefore3 = DateTime(2026, 10, 23, 2, 59, 59);
      final dsBefore3 = DateService(nowProvider: () => timeBefore3);

      // 03:00:00 local civil time on 2026-10-23
      final timeAt3 = DateTime(2026, 10, 23, 3, 0, 0);
      final dsAt3 = DateService(nowProvider: () => timeAt3);

      expect(dsBefore3.getTodayDayKey(), '2026-10-22');
      expect(dsAt3.getTodayDayKey(), '2026-10-23');
      expect(dsBefore3.getTodayDayKey(), isNot(equals(dsAt3.getTodayDayKey())));
    });

    // -------------------------------------------------------------------------
    // Scenario 17: Date rollover while confirmation modal is open
    // -------------------------------------------------------------------------
    testWidgets(
        '17. Date rollover while confirmation is open: submission blocked safely',
        (tester) async {
      final prog = createTestProgram(
        id: 'prog_rollover_test',
        targetDays: 40,
        startDayKey: '2026-10-22',
      );
      await saveProgram(tester, prog);

      // User opens modal at 02:59:59
      DateTime mutableClock = DateTime(2026, 10, 23, 2, 59, 59);
      final dateService = DateService(nowProvider: () => mutableClock);

      int dispatchCalls = 0;

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramDetailView(
            program: prog,
            onBack: () {},
            dateService: dateService,
            onDailyCheckIn: (id, confirmed) async {
              dispatchCalls++;
              return DailyCheckInResult.failure(
                reason: DailyCheckInFailureReason.alreadyCheckedIn,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open confirmation dialog
      await tester
          .tap(find.byKey(const ValueKey('v2_program_detail_checkin_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('v2_checkin_confirmation_dialog')),
          findsOneWidget);

      // While modal is open, clock rolls over past 03:00 (to 03:00:01 local)
      mutableClock = DateTime(2026, 10, 23, 3, 0, 1);

      // User taps confirm
      await tester.tap(find.byKey(const ValueKey('v2_checkin_confirm_button')));
      await tester.pumpAndSettle();

      // Modal closed, submission blocked, zero dispatch calls, friendly notice shown
      expect(dispatchCalls, 0);
      expect(
        find.text(
            'Hari operasional telah berganti melewati batas pukul 03:00. Silakan periksa kembali dan lakukan konfirmasi ulang.'),
        findsOneWidget,
      );
    });

    // -------------------------------------------------------------------------
    // Scenario 18: Rapid double tap invokes at most one submission
    // -------------------------------------------------------------------------
    testWidgets('18. Rapid double tap invokes at most one submission',
        (tester) async {
      final prog = createTestProgram(
        id: 'prog_double_tap',
        targetDays: 40,
        startDayKey: '2026-10-22',
      );
      await saveProgram(tester, prog);

      int callCount = 0;
      final completer = Completer<DailyCheckInResult>();

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramDetailView(
            program: prog,
            onBack: () {},
            dateService: createDeterministicDateService(),
            onDailyCheckIn: (id, confirmed) async {
              callCount++;
              return completer.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open confirmation dialog
      await tester
          .tap(find.byKey(const ValueKey('v2_program_detail_checkin_button')));
      await tester.pumpAndSettle();

      // Tap confirm button twice rapidly
      await tester.tap(find.byKey(const ValueKey('v2_checkin_confirm_button')));
      await tester.tap(find.byKey(const ValueKey('v2_checkin_confirm_button')),
          warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(callCount, 1);

      // Complete future
      completer.complete(
        DailyCheckInResult.failure(
          reason: DailyCheckInFailureReason.alreadyCheckedIn,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(callCount, 1);
    });

    // -------------------------------------------------------------------------
    // Scenario 19: PENDING_FAILURE cannot check in
    // -------------------------------------------------------------------------
    testWidgets('19. PENDING_FAILURE cannot check in', (tester) async {
      final prog = createTestProgram(
        id: 'prog_pf_nocheckin',
        status: ProgramV2Model.statusPendingFailure,
      );
      await saveProgram(tester, prog);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramDetailView(
            program: prog,
            onBack: () {},
            dateService: createDeterministicDateService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check-in button replaced by Muhasabah card
      expect(find.byKey(const ValueKey('v2_program_detail_checkin_button')),
          findsNothing);
    });

    // -------------------------------------------------------------------------
    // Scenario 20: Terminal programs cannot check in
    // -------------------------------------------------------------------------
    testWidgets('20. Terminal programs cannot check in', (tester) async {
      final prog = createTestProgram(
        id: 'prog_terminal',
        status: ProgramV2Model.statusSuccess,
      );
      await saveProgram(tester, prog);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramDetailView(
            program: prog,
            onBack: () {},
            dateService: createDeterministicDateService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check-in button replaced by Terminal card
      expect(find.byKey(const ValueKey('v2_program_detail_checkin_button')),
          findsNothing);
    });

    // -------------------------------------------------------------------------
    // Scenario 21: Inactive Program tab in AppShell does not intercept Back
    // -------------------------------------------------------------------------
    testWidgets('21. Inactive Program tab in AppShell does not intercept Back',
        (tester) async {
      final prog = createTestProgram(id: 'prog_shell_test');
      await saveProgram(tester, prog);

      final navCtrl = V2NavigationController();
      final hubCtrl = V2ProgramHubController(programRepository: programRepo);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2AppShell(
            controller: navCtrl,
            program: V2ProgramHubView(
              controller: hubCtrl,
              navigationController: navCtrl,
              programRepository: programRepo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Program tab (index 2)
      navCtrl.selectTab(V2NavigationTab.program);
      await tester.pumpAndSettle();

      // Open detail
      hubCtrl.openProgramDetail(prog);
      await tester.pumpAndSettle();
      expect(find.byType(V2ProgramDetailView), findsOneWidget);

      // Now switch away to Dashboard tab (index 0)
      navCtrl.selectTab(V2NavigationTab.dashboard);
      await tester.pumpAndSettle();
      expect(navCtrl.currentTab, V2NavigationTab.dashboard);

      // Program tab is NOT active now. System back should not be intercepted by S21/ProgramHub
      final didHandleInactive = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Inactive tab did not consume system Back; user remains on Dashboard
      expect(didHandleInactive, isFalse);
      expect(navCtrl.currentTab, V2NavigationTab.dashboard);

      // Switch back to Program tab: S21 detail state remains preserved
      navCtrl.selectTab(V2NavigationTab.program);
      await tester.pumpAndSettle();
      expect(find.byType(V2ProgramDetailView), findsOneWidget);

      // When Program tab IS active, system Back pops S21 back to Hub
      final didHandleActive = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(didHandleActive, isTrue);
      expect(find.byType(V2ProgramDetailView), findsNothing);
      expect(hubCtrl.currentStep, ProgramScreenStep.hub);
    });

    // -------------------------------------------------------------------------
    // Scenario 22: Responsive layout (320dp), Light/Dark, accessibility
    // -------------------------------------------------------------------------
    testWidgets(
        '22. Responsive layout (320dp), Light/Dark mode, minimum 48dp touch targets',
        (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final prog = createTestProgram(id: 'prog_a11y');
      await saveProgram(tester, prog);

      // Light mode
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramDetailView(
            program: prog,
            onBack: () {},
            dateService: createDeterministicDateService(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Touch target for back button >= 48x48
      final backButtonSize = tester
          .getSize(find.byKey(const ValueKey('v2_program_detail_back_button')));
      expect(backButtonSize.width, greaterThanOrEqualTo(48.0));
      expect(backButtonSize.height, greaterThanOrEqualTo(48.0));

      // Dark mode
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.darkTheme,
          home: V2ProgramDetailView(
            program: prog,
            onBack: () {},
            dateService: createDeterministicDateService(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // Scenario 23: Zero unintended mutations during viewing
    // -------------------------------------------------------------------------
    testWidgets('23. Zero unintended mutations during viewing or navigation',
        (tester) async {
      final prog = createTestProgram(id: 'prog_immutability');
      await saveProgram(tester, prog);

      final initialProgBoxCount = programBox.length;
      final initialCheckInBoxCount = checkInBox.length;

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramDetailView(
            program: prog,
            onBack: () {},
            dateService: createDeterministicDateService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify zero storage writes
      expect(programBox.length, initialProgBoxCount);
      expect(checkInBox.length, initialCheckInBoxCount);
    });

    // -------------------------------------------------------------------------
    // Scenario 24: S18 Program Setup Journey integration preserved
    // -------------------------------------------------------------------------
    testWidgets(
        '24. Program Active Card tapping from Ibadah Saya navigates to S21',
        (tester) async {
      final prog = createTestProgram(
        id: 'prog_active_tap_test',
        ibadahNameSnapshot: 'Sedekah Subuh',
      );
      await saveProgram(tester, prog);

      final controller = V2ProgramHubController(
        programRepository: programRepo,
      );
      controller.selectTab(ProgramHubTab.ibadahSaya);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            controller: controller,
            programRepository: programRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap card
      await tester.tap(
          find.byKey(const ValueKey('v2_active_program_prog_active_tap_test')));
      await tester.pumpAndSettle();

      expect(controller.currentStep, ProgramScreenStep.programDetail);
      expect(find.byType(V2ProgramDetailView), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Scenario 25: Operational-day rollover at 03:00 local updates check-in button in idle foreground
    // -------------------------------------------------------------------------
    testWidgets(
        '25. Operational-day rollover at 03:00 local updates check-in button safely in idle foreground',
        (tester) async {
      final prog = createTestProgram(
        id: 'prog_rollover_button_test',
        startDayKey: '2026-10-22',
      );
      await saveProgram(tester, prog);

      // Save check-in for 2026-10-22
      final checkinDay1 = DailyCheckInModel(
        id: DailyCheckInV2Repository.buildCheckInId('2026-10-22', prog.id),
        programId: prog.id,
        dayKey: '2026-10-22',
        checkedAt: DateTime(2026, 10, 22, 23, 0),
        createdAt: DateTime(2026, 10, 22, 23, 0),
      );
      await saveCheckIn(tester, checkinDay1);

      // Foreground page opened at 02:59:59 on 2026-10-23 (still operational day 2026-10-22)
      DateTime mutableClock = DateTime(2026, 10, 23, 2, 59, 59);
      final dateService = DateService(nowProvider: () => mutableClock);
      final checkInService = DailyCheckInV2Service(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: dateService,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramDetailView(
            program: prog,
            onBack: () {},
            dateService: dateService,
            dailyCheckInService: checkInService,
            programRepository: programRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // At 02:59:59 on 2026-10-23, check-in for 2026-10-22 is already completed
      expect(find.text('Sudah Check-in Hari Ini'), findsOneWidget);
      expect(find.text('Ibadah Hari Ini Selesai'), findsOneWidget);
      final btnBefore = tester.widget<ElevatedButton>(
          find.byKey(const ValueKey('v2_program_detail_checkin_button')));
      expect(btnBefore.onPressed, isNull);

      // Clock advances past 03:00 boundary to next operational day (2026-10-23 03:00:01)
      // Page stays idle in foreground: zero lifecycle resume, zero parent pumpWidget, zero tab switch
      mutableClock = DateTime(2026, 10, 23, 3, 0, 1);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Timer fired automatically! Button is now enabled for the new operational day!
      expect(find.text('Check-in Ibadah Hari Ini'), findsOneWidget);
      final btnAfter = tester.widget<ElevatedButton>(
          find.byKey(const ValueKey('v2_program_detail_checkin_button')));
      expect(btnAfter.onPressed, isNotNull);
    });

    // -------------------------------------------------------------------------
    // Scenario 26: App resume and repository status update (ACTIVE -> PENDING_FAILURE)
    // -------------------------------------------------------------------------
    testWidgets(
        '26. App resume safely refreshes program status from repository',
        (tester) async {
      final prog = createTestProgram(
        id: 'prog_status_refresh_test',
        status: ProgramV2Model.statusActive,
      );
      await saveProgram(tester, prog);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramDetailView(
            program: prog,
            onBack: () {},
            dateService: createDeterministicDateService(),
            programRepository: programRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially active with check-in button available
      expect(find.byKey(const ValueKey('v2_program_detail_muhasabah_banner')),
          findsNothing);

      // External reconciliation sets program status to PENDING_FAILURE in repository
      final updatedProg = ProgramV2Model(
        id: prog.id,
        ibadahId: prog.ibadahId,
        ibadahNameSnapshot: prog.ibadahNameSnapshot,
        targetDays: prog.targetDays,
        startDayKey: prog.startDayKey,
        status: ProgramV2Model.statusPendingFailure,
        createdAt: prog.createdAt,
        updatedAt: DateTime.now(),
      );
      await saveProgram(tester, updatedProg);

      // Simulate app resume
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // UI safely refreshed from repository: Muhasabah card is now shown
      expect(find.byKey(const ValueKey('v2_program_detail_muhasabah_banner')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('v2_program_detail_checkin_button')),
          findsNothing);
    });

    // -------------------------------------------------------------------------
    // Scenario 27: Out-of-order getProgress responses are ignored
    // -------------------------------------------------------------------------
    testWidgets(
        '27. Out-of-order getProgress responses are ignored on program switch',
        (tester) async {
      final progA = createTestProgram(
        id: 'prog_a',
        targetDays: 40,
        ibadahNameSnapshot: 'Ibadah A',
        startDayKey: '2026-10-01',
      );
      final progB = createTestProgram(
        id: 'prog_b',
        targetDays: 40,
        ibadahNameSnapshot: 'Ibadah B',
        startDayKey: '2026-10-01',
      );
      await saveProgram(tester, progA);
      await saveProgram(tester, progB);

      final completerA = Completer<ProgramProgressSnapshot?>();
      final snapshotB = ProgramProgressSnapshot(
        programId: progB.id,
        targetDays: 40,
        completedDays: 10,
        remainingDays: 30,
        isCompletedToday: false,
        isTargetReached: false,
      );
      final snapshotA = ProgramProgressSnapshot(
        programId: progA.id,
        targetDays: 40,
        completedDays: 2,
        remainingDays: 38,
        isCompletedToday: false,
        isTargetReached: false,
      );

      final delayedService = _DelayedProgCheckInService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: createDeterministicDateService(),
        completerA: completerA,
        snapshotB: snapshotB,
      );

      // Render with progA
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramDetailView(
            program: progA,
            onBack: () {},
            dateService: createDeterministicDateService(),
            dailyCheckInService: delayedService,
            programRepository: programRepo,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('2 dari 40 Hari Selesai'), findsNothing);

      // Switch widget to progB while progA is still waiting
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramDetailView(
            program: progB,
            onBack: () {},
            dateService: createDeterministicDateService(),
            dailyCheckInService: delayedService,
            programRepository: programRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('10 dari 40 Hari Selesai'), findsOneWidget);

      // Now resolve progA late
      completerA.complete(snapshotA);
      await tester.pumpAndSettle();

      // progB is NOT overwritten by the stale progA response!
      expect(find.text('10 dari 40 Hari Selesai'), findsOneWidget);
      expect(find.text('2 dari 40 Hari Selesai'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // Scenario 28: Async disposal safety during check-in in-flight
    // -------------------------------------------------------------------------
    testWidgets('28. Async disposal safety during check-in in-flight',
        (tester) async {
      final prog = createTestProgram(id: 'prog_async_dispose');
      await saveProgram(tester, prog);

      final completer = Completer<DailyCheckInResult>();

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramDetailView(
            program: prog,
            onBack: () {},
            dateService: createDeterministicDateService(),
            onDailyCheckIn: (id, confirmed) => completer.future,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open confirmation dialog
      await tester
          .tap(find.byKey(const ValueKey('v2_program_detail_checkin_button')));
      await tester.pumpAndSettle();

      // Tap confirm to start submission
      await tester.tap(find.byKey(const ValueKey('v2_checkin_confirm_button')));
      await tester.pump(const Duration(milliseconds: 300));

      // Widget unmounted while check-in future is unresolved
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Navigated Away'))),
      );

      // Now resolve future after dispose
      completer.complete(
        DailyCheckInResult.failure(
          reason: DailyCheckInFailureReason.alreadyCheckedIn,
        ),
      );
      await tester.pumpAndSettle();

      // No crash, zero unhandled exceptions
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // Scenario 29: Product Guard - targetReached does not falsely show final SUCCESS
    // -------------------------------------------------------------------------
    testWidgets(
        '29. Product Guard: targetReached does not falsely claim SUCCESS or Piagam',
        (tester) async {
      final prog = createTestProgram(
        id: 'prog_product_guard',
        targetDays: 40,
        status: ProgramV2Model.statusActive,
      );
      await saveProgram(tester, prog);

      final snapshot40 = ProgramProgressSnapshot(
        programId: prog.id,
        targetDays: 40,
        completedDays: 40,
        remainingDays: 0,
        isCompletedToday: true,
        isTargetReached: true,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramDetailView(
            program: prog,
            onBack: () {},
            dateService: createDeterministicDateService(),
            onDailyCheckIn: (id, confirmed) async {
              return DailyCheckInResult.success(
                checkIn: DailyCheckInModel(
                  id: DailyCheckInV2Repository.buildCheckInId(
                      '2026-10-22', prog.id),
                  programId: prog.id,
                  dayKey: '2026-10-22',
                  checkedAt: DateTime.now(),
                  createdAt: DateTime.now(),
                ),
                targetReached: true,
                progress: snapshot40,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap check-in
      await tester
          .tap(find.byKey(const ValueKey('v2_program_detail_checkin_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('v2_checkin_confirm_button')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Message states check-in recorded, does NOT claim whole program success/completion
      expect(
        find.text('Alhamdulillah! Check-in hari ini berhasil dicatat.'),
        findsOneWidget,
      );
      expect(
        find.text(
            'Alhamdulillah! Target ibadah telah berhasil dicapai sepenuhnya!'),
        findsNothing,
      );

      // Terminal banner is NOT shown because program.status is still ACTIVE
      expect(find.byKey(const ValueKey('v2_program_detail_terminal_banner')),
          findsNothing);
    });

    // -------------------------------------------------------------------------
    // Scenario 30: Delayed getProgress crossing 03:00 boundary discards old snapshot
    // -------------------------------------------------------------------------
    testWidgets(
        '30. Delayed getProgress initiated before 03:00 and resolved after 03:00 does not mark new day completed',
        (tester) async {
      final prog = createTestProgram(
        id: 'prog_delayed_get_progress',
        startDayKey: '2026-10-22',
      );
      await saveProgram(tester, prog);

      DateTime mutableClock = DateTime(2026, 10, 23, 2, 59, 59);
      final dateService = DateService(nowProvider: () => mutableClock);

      final progressCompleter = Completer<ProgramProgressSnapshot?>();

      final service = _LateProgressService(
        programRepository: programRepo,
        checkInRepository: checkInRepo,
        dateService: dateService,
        lateCompleter: progressCompleter,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramDetailView(
            program: prog,
            onBack: () {},
            dateService: dateService,
            dailyCheckInService: service,
            programRepository: programRepo,
          ),
        ),
      );
      // First frame pumped, getProgress is awaiting progressCompleter.future
      await tester.pump(const Duration(milliseconds: 100));

      // Boundary rolls over while getProgress is still in flight!
      mutableClock = DateTime(2026, 10, 23, 3, 0, 1);

      // Now complete the delayed Future with Day A's snapshot (isCompletedToday: true)
      progressCompleter.complete(
        ProgramProgressSnapshot(
          programId: prog.id,
          targetDays: 40,
          completedDays: 1,
          remainingDays: 39,
          isCompletedToday: true,
          isTargetReached: false,
        ),
      );

      // Settle UI (boundary check discards Day A snapshot and re-fetches for Day B)
      await tester.pumpAndSettle();

      // On Day B, check-in must NOT be marked completed today
      expect(find.text('Sudah Check-in Hari Ini'), findsNothing);
      expect(find.text('Ibadah Hari Ini Selesai'), findsNothing);
      expect(find.text('Check-in Ibadah Hari Ini'), findsOneWidget);

      final ctaBtn = tester.widget<ElevatedButton>(
          find.byKey(const ValueKey('v2_program_detail_checkin_button')));
      expect(ctaBtn.onPressed, isNotNull);
    });

    // -------------------------------------------------------------------------
    // Scenario 31: Delayed check-in crossing 03:00 boundary records Day A without marking Day B done
    // -------------------------------------------------------------------------
    testWidgets(
        '31. Delayed check-in crossing boundary records day A but does not mark day B completed',
        (tester) async {
      final prog = createTestProgram(
        id: 'prog_delayed_checkin_boundary',
        startDayKey: '2026-10-22',
      );
      await saveProgram(tester, prog);

      DateTime mutableClock = DateTime(2026, 10, 23, 2, 59, 59);
      final dateService = DateService(nowProvider: () => mutableClock);
      final checkInCompleter = Completer<DailyCheckInResult>();

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramDetailView(
            program: prog,
            onBack: () {},
            dateService: dateService,
            programRepository: programRepo,
            onDailyCheckIn: (id, confirmed) => checkInCompleter.future,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap check-in CTA button
      await tester
          .tap(find.byKey(const ValueKey('v2_program_detail_checkin_button')));
      await tester.pumpAndSettle();

      // Tap confirm button in dialog (started at 02:59:59 on Day A)
      await tester.tap(find.byKey(const ValueKey('v2_checkin_confirm_button')));
      await tester.pump(const Duration(milliseconds: 100));

      // Boundary rolls over to Day B while check-in callback is awaiting
      mutableClock = DateTime(2026, 10, 23, 3, 0, 1);

      // Callback completes for Day A (2026-10-22)
      final recordDayA = DailyCheckInModel(
        id: DailyCheckInV2Repository.buildCheckInId('2026-10-22', prog.id),
        programId: prog.id,
        dayKey: '2026-10-22',
        checkedAt: DateTime(2026, 10, 22, 23, 59),
        createdAt: DateTime(2026, 10, 22, 23, 59),
      );
      await saveCheckIn(tester, recordDayA);

      checkInCompleter.complete(
        DailyCheckInResult.success(
          checkIn: recordDayA,
          targetReached: false,
          progress: ProgramProgressSnapshot(
            programId: prog.id,
            targetDays: 40,
            completedDays: 1,
            remainingDays: 39,
            isCompletedToday: true,
            isTargetReached: false,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Notice message specifically mentions yesterday's date
      expect(
        find.text(
            'Alhamdulillah! Check-in untuk hari 22 Oktober 2026 berhasil dicatat.'),
        findsOneWidget,
      );

      // On Day B, check-in is NOT marked completed!
      expect(find.text('Ibadah Hari Ini Selesai'), findsNothing);
      expect(find.text('Check-in Ibadah Hari Ini'), findsOneWidget);
      final ctaBtn = tester.widget<ElevatedButton>(
          find.byKey(const ValueKey('v2_program_detail_checkin_button')));
      expect(ctaBtn.onPressed, isNotNull);
    });

    // -------------------------------------------------------------------------
    // Scenario 32: Program A submission in flight while Program B is selected
    // -------------------------------------------------------------------------
    testWidgets(
        '32. Program A check-in in flight does not freeze or mutate Program B submission state',
        (tester) async {
      final progA = createTestProgram(
        id: 'prog_A_concurrent',
        ibadahNameSnapshot: 'Program A',
        startDayKey: '2026-10-20',
      );
      final progB = createTestProgram(
        id: 'prog_B_concurrent',
        ibadahNameSnapshot: 'Program B',
        startDayKey: '2026-10-20',
      );
      await saveProgram(tester, progA);
      await saveProgram(tester, progB);

      final dateService = createDeterministicDateService();
      final checkInCompleterA = Completer<DailyCheckInResult>();

      final dummyCheckIn = DailyCheckInModel(
        id: 'dummy_checkin',
        programId: 'dummy',
        dayKey: '2026-10-22',
        checkedAt: DateTime(2026, 10, 22, 10, 0),
        createdAt: DateTime(2026, 10, 22, 10, 0),
      );
      final dummyProgress = ProgramProgressSnapshot(
        programId: 'dummy',
        targetDays: 40,
        completedDays: 1,
        remainingDays: 39,
        isCompletedToday: true,
        isTargetReached: false,
      );

      // Render Program A
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramDetailView(
            program: progA,
            onBack: () {},
            dateService: dateService,
            programRepository: programRepo,
            onDailyCheckIn: (id, confirmed) {
              if (id == progA.id) {
                return checkInCompleterA.future;
              }
              return Future.value(DailyCheckInResult.success(
                checkIn: dummyCheckIn,
                targetReached: false,
                progress: dummyProgress,
              ));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Start check-in on Program A
      await tester
          .tap(find.byKey(const ValueKey('v2_program_detail_checkin_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('v2_checkin_confirm_button')));
      await tester.pump(const Duration(milliseconds: 100));

      // Program A is now submitting (shows loading indicator)
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Now switch to Program B while Program A submission is still unresolved
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramDetailView(
            program: progB,
            onBack: () {},
            dateService: dateService,
            programRepository: programRepo,
            onDailyCheckIn: (id, confirmed) {
              if (id == progA.id) {
                return checkInCompleterA.future;
              }
              return Future.value(DailyCheckInResult.success(
                checkIn: dummyCheckIn,
                targetReached: false,
                progress: dummyProgress,
              ));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Program B must NOT be stuck in loading state or disabled!
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Check-in Ibadah Hari Ini'), findsOneWidget);
      final btnB = tester.widget<ElevatedButton>(
          find.byKey(const ValueKey('v2_program_detail_checkin_button')));
      expect(btnB.onPressed, isNotNull);

      // Now resolve Program A's delayed check-in
      checkInCompleterA.complete(DailyCheckInResult.success(
        checkIn: dummyCheckIn,
        targetReached: false,
        progress: dummyProgress,
      ));
      await tester.pumpAndSettle();

      // Program B's screen is unchanged, not corrupted by Program A's finally block
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Check-in Ibadah Hari Ini'), findsOneWidget);
      final btnBAfter = tester.widget<ElevatedButton>(
          find.byKey(const ValueKey('v2_program_detail_checkin_button')));
      expect(btnBAfter.onPressed, isNotNull);
    });

    // -------------------------------------------------------------------------
    // Scenario 33: Callback-only mode rollover without service enables CTA at 03:00
    // -------------------------------------------------------------------------
    testWidgets(
        '33. Callback-only mode without service automatically enables future-start program at 03:00 rollover',
        (tester) async {
      final prog = createTestProgram(
        id: 'prog_cb_only_start_tomorrow',
        ibadahNameSnapshot: 'Tahajjud Rutin',
        startDayKey: '2026-10-23',
        status: ProgramV2Model.statusActive,
      );
      await saveProgram(tester, prog);

      // Local clock at 02:59:59 on 2026-10-23 (operational day is still 2026-10-22)
      DateTime mutableClock = DateTime(2026, 10, 23, 2, 59, 59);
      final dateService = DateService(nowProvider: () => mutableClock);
      int callbackCallCount = 0;

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramDetailView(
            program: prog,
            onBack: () {},
            dateService: dateService,
            dailyCheckInService: null, // Callback-only configuration!
            programRepository: programRepo,
            onDailyCheckIn: (id, confirmed) async {
              callbackCallCount++;
              return DailyCheckInResult.success(
                checkIn: DailyCheckInModel(
                  id: DailyCheckInV2Repository.buildCheckInId(
                      '2026-10-23', prog.id),
                  programId: prog.id,
                  dayKey: '2026-10-23',
                  checkedAt: DateTime.now(),
                  createdAt: DateTime.now(),
                ),
                targetReached: false,
                progress: ProgramProgressSnapshot(
                  programId: prog.id,
                  targetDays: 40,
                  completedDays: 1,
                  remainingDays: 39,
                  isCompletedToday: true,
                  isTargetReached: false,
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Before 03:00 (operational day 2026-10-22): program starts tomorrow, button is disabled
      expect(find.text('Program Belum Dimulai'), findsOneWidget);
      final btnBefore = tester.widget<ElevatedButton>(
          find.byKey(const ValueKey('v2_program_detail_checkin_button')));
      expect(btnBefore.onPressed, isNull);
      expect(callbackCallCount, 0);

      // Advance clock past 03:00 boundary to 03:00:01 while idle in foreground
      mutableClock = DateTime(2026, 10, 23, 3, 0, 1);
      // Advance virtual timer without lifecycle events, parent pumpWidget, or tab switch
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Rollover timer fired! Even without DailyCheckInV2Service, UI safely redrew
      expect(find.text('Check-in Ibadah Hari Ini'), findsOneWidget);
      expect(find.text('Program Belum Dimulai'), findsNothing);
      final btnAfter = tester.widget<ElevatedButton>(
          find.byKey(const ValueKey('v2_program_detail_checkin_button')));
      expect(btnAfter.onPressed, isNotNull);

      // Verify callback was NOT invoked automatically on rollover
      expect(callbackCallCount, 0);
    });

    // -------------------------------------------------------------------------
    // Scenario 34: Callback-only mode clears yesterday's checked-in state at 03:00
    // -------------------------------------------------------------------------
    testWidgets(
        '34. Callback-only mode clears yesterday completed state at 03:00 rollover without synthetic check-in',
        (tester) async {
      final prog = createTestProgram(
        id: 'prog_cb_only_yesterday_done',
        ibadahNameSnapshot: 'Sholat Dhuha',
        startDayKey: '2026-10-22',
        status: ProgramV2Model.statusActive,
      );
      await saveProgram(tester, prog);

      // Opened at 02:59:59 on 2026-10-23 (active operational day is 2026-10-22)
      DateTime mutableClock = DateTime(2026, 10, 23, 2, 59, 59);
      final dateService = DateService(nowProvider: () => mutableClock);
      int callbackCallCount = 0;

      final recordDayA = DailyCheckInModel(
        id: DailyCheckInV2Repository.buildCheckInId('2026-10-22', prog.id),
        programId: prog.id,
        dayKey: '2026-10-22',
        checkedAt: DateTime(2026, 10, 23, 2, 59),
        createdAt: DateTime(2026, 10, 23, 2, 59),
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramDetailView(
            program: prog,
            onBack: () {},
            dateService: dateService,
            dailyCheckInService: null, // Callback-only configuration!
            programRepository: programRepo,
            onDailyCheckIn: (id, confirmed) async {
              callbackCallCount++;
              return DailyCheckInResult.success(
                checkIn: recordDayA,
                targetReached: false,
                progress: ProgramProgressSnapshot(
                  programId: prog.id,
                  targetDays: 40,
                  completedDays: 1,
                  remainingDays: 39,
                  isCompletedToday: true,
                  isTargetReached: false,
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Perform check-in on Day A (2026-10-22)
      await tester
          .tap(find.byKey(const ValueKey('v2_program_detail_checkin_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('v2_checkin_confirm_button')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // At 02:59:59, check-in for Day A is completed
      expect(callbackCallCount, 1);
      expect(
          find.byKey(const ValueKey('v2_program_detail_already_checked_card')),
          findsOneWidget);
      expect(find.text('Sudah Check-in Hari Ini'), findsOneWidget);
      expect(find.text('Ibadah Hari Ini Selesai'), findsOneWidget);
      final btnBefore = tester.widget<ElevatedButton>(
          find.byKey(const ValueKey('v2_program_detail_checkin_button')));
      expect(btnBefore.onPressed, isNull);

      // Local clock crosses past 03:00 boundary to 03:00:01 (operational day is now 2026-10-23)
      mutableClock = DateTime(2026, 10, 23, 3, 0, 1);

      // Advance virtual timer without lifecycle events, parent pumpWidget, or tab switch
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Yesterday's completed indicator cleared visually
      expect(
          find.byKey(const ValueKey('v2_program_detail_already_checked_card')),
          findsNothing);
      expect(find.text('Sudah Check-in Hari Ini'), findsNothing);
      expect(find.text('Ibadah Hari Ini Selesai'), findsNothing);

      // Check-in button is enabled for the new day
      expect(find.text('Check-in Ibadah Hari Ini'), findsOneWidget);
      final btnAfter = tester.widget<ElevatedButton>(
          find.byKey(const ValueKey('v2_program_detail_checkin_button')));
      expect(btnAfter.onPressed, isNotNull);

      // Verify callback call count remains exactly 1 (no synthetic or automatic new-day check-in)
      expect(callbackCallCount, 1);
    });
  });
}

class _DelayedProgCheckInService extends DailyCheckInV2Service {
  final Completer<ProgramProgressSnapshot?> completerA;
  final ProgramProgressSnapshot snapshotB;

  _DelayedProgCheckInService({
    required super.programRepository,
    required super.checkInRepository,
    required super.dateService,
    required this.completerA,
    required this.snapshotB,
  });

  @override
  Future<ProgramProgressSnapshot?> getProgress(String programId) {
    if (programId == 'prog_a') {
      return completerA.future;
    } else {
      return Future.value(snapshotB);
    }
  }
}

class _LateProgressService extends DailyCheckInV2Service {
  final Completer<ProgramProgressSnapshot?> lateCompleter;

  _LateProgressService({
    required super.programRepository,
    required super.checkInRepository,
    required super.dateService,
    required this.lateCompleter,
  });

  @override
  Future<ProgramProgressSnapshot?> getProgress(String programId) {
    if (!lateCompleter.isCompleted) {
      return lateCompleter.future;
    }
    return super.getProgress(programId);
  }
}
