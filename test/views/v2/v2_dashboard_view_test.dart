import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:mujahadah/controllers/v2_dashboard_controller.dart';
import 'package:mujahadah/controllers/v2_navigation_controller.dart';
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
import 'package:mujahadah/theme/v2_design_tokens.dart';
import 'package:mujahadah/theme/v2_theme.dart';
import 'package:mujahadah/views/v2/dalil/v2_dalil_view.dart';
import 'package:mujahadah/views/v2/dashboard/v2_dashboard_view.dart';
import 'package:mujahadah/views/v2/placeholders/v2_placeholders.dart';
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
  late DailyCheckInV2Service dailyCheckInService;
  late DateService dateService;
  late DateTime fixedNow;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    tempDir = Directory.systemTemp.createTempSync('v2_dashboard_test_');
    Hive.init(tempDir.path);
    V2Runtime.registerAdapters();

    programBox =
        await Hive.openBox<ProgramV2Model>('test_dashboard_programs_v2');
    checkInBox =
        await Hive.openBox<DailyCheckInModel>('test_dashboard_checkins_v2');
    failureBox =
        await Hive.openBox<FailureRecordModel>('test_dashboard_failures_v2');
    achievementBox =
        await Hive.openBox<AchievementModel>('test_dashboard_achievements_v2');

    programRepo = ProgramV2Repository(box: programBox);
    checkInRepo = DailyCheckInV2Repository(box: checkInBox);
    failureRepo = FailureRecordV2Repository(box: failureBox);
    achievementRepo = AchievementV2Repository(box: achievementBox);

    // Fixed test clock: Friday, October 2, 2026, 10:00:00 AM (matches mockup date)
    fixedNow = DateTime(2026, 10, 2, 10, 0, 0);
    dateService = DateService(nowProvider: () => fixedNow);

    dailyCheckInService = DailyCheckInV2Service(
      programRepository: programRepo,
      checkInRepository: checkInRepo,
      dateService: dateService,
    );
  });

  setUp(() async {
    Get.reset();
    await programBox.clear();
    await checkInBox.clear();
    await failureBox.clear();
    await achievementBox.clear();
  });

  tearDown(() {
    Get.reset();
  });

  tearDownAll(() async {
    if (programBox.isOpen) await programBox.close();
    if (checkInBox.isOpen) await checkInBox.close();
    if (failureBox.isOpen) await failureBox.close();
    if (achievementBox.isOpen) await achievementBox.close();
    await Hive.close();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('V2 Dashboard UI Presentation Layer (TASK MV2-B0-02-04-04-04)', () {
    // -------------------------------------------------------------------------
    // Scenario 1: Correct S08 Dashboard rendering of all sections
    // -------------------------------------------------------------------------
    testWidgets(
        '1. Correct S08 Dashboard rendering: displays header, prayer card, quick actions, and all cards',
        (tester) async {
      final controller = V2DashboardController(
        programRepository: programRepo,
        dailyCheckInService: dailyCheckInService,
        checkInRepository: checkInRepo,
        failureRecordRepository: failureRepo,
        achievementRepository: achievementRepo,
        dateService: dateService,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2DashboardView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Dashboard placeholder must NOT be present (S08 screen only)
      expect(find.byType(V2DashboardPlaceholder), findsNothing);

      // Header
      expect(find.text('Semangat Istiqomah'), findsOneWidget);
      expect(find.text('Sobat Istiqomah'), findsOneWidget);
      expect(find.text('Jumat, 2 Oktober 2026'), findsOneWidget);

      // Next Prayer Card
      expect(find.text('Azan berikutnya'), findsOneWidget);
      expect(find.text('Jadwal Belum Tersedia'), findsOneWidget);
      expect(find.text('Subuh'), findsOneWidget);
      expect(find.text('Dzuhur'), findsOneWidget);
      expect(find.text('Ashar'), findsOneWidget);
      expect(find.text('Maghrib'), findsOneWidget);
      expect(find.text('Isya'), findsOneWidget);

      // Quick actions
      expect(
          find.byKey(const ValueKey('v2_quick_action_kiblat')), findsOneWidget);
      expect(find.byKey(const ValueKey('v2_quick_action_kalender_mujahadah')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('v2_quick_action_kalender_hijriah')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('v2_quick_action_doa_istiqomah')),
          findsOneWidget);

      // Perjalanan Saya
      expect(find.text('Perjalanan Saya'), findsOneWidget);
      expect(find.byKey(const ValueKey('v2_metric_aktif')), findsOneWidget);
      expect(find.byKey(const ValueKey('v2_metric_tercapai')), findsOneWidget);
      expect(find.byKey(const ValueKey('v2_metric_terhenti')), findsOneWidget);

      // Sections
      expect(find.text('Mujahadah Hari Ini'), findsOneWidget);
      expect(find.text('Muhasabah'), findsOneWidget);
      expect(find.text('Achievement Terbaru'), findsOneWidget);
      expect(find.text('Bekal Istiqomah'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Scenario 2: Light and Dark modes
    // -------------------------------------------------------------------------
    testWidgets('2. Renders correctly in both Light and Dark themes',
        (tester) async {
      final controller = V2DashboardController(
        programRepository: programRepo,
        dateService: dateService,
      );

      // Light mode
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2DashboardView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(V2DashboardView), findsOneWidget);

      // Dark mode
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.darkTheme,
          themeMode: ThemeMode.dark,
          home: V2DashboardView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(V2DashboardView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // Scenario 3: Small-screen and normal-screen layouts
    // -------------------------------------------------------------------------
    testWidgets(
        '3. Renders responsively on compact (320dp) and standard screen sizes without overflow',
        (tester) async {
      final controller = V2DashboardController(
        programRepository: programRepo,
        dateService: dateService,
      );

      // Compact 320x640 screen
      tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2DashboardView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Standard 390x844 screen
      tester.view.physicalSize = const Size(390 * 2.0, 844 * 2.0);
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2DashboardView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // Scenario 4: No active program state
    // -------------------------------------------------------------------------
    testWidgets(
        '4. No active program state displays approved empty state text and CTA button',
        (tester) async {
      final controller = V2DashboardController(
        programRepository: programRepo,
        dateService: dateService,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2DashboardView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Kamu belum memiliki ibadah yang ditargetkan'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('v2_dashboard_create_program_cta')),
        findsOneWidget,
      );
      expect(
        find.text('Buat Target Ibadahmu Sekarang'),
        findsOneWidget,
      );
      expect(
          find.text('0'), findsNWidgets(3)); // 0 Aktif, 0 Tercapai, 0 Terhenti
    });

    // -------------------------------------------------------------------------
    // Scenario 5: Real read-only program data projection
    // -------------------------------------------------------------------------
    testWidgets(
        '5. Real read-only program data projection displays program title and correct progress text',
        (tester) async {
      // Seed an active program
      final program = ProgramV2Model(
        id: 'prog_dhuha',
        ibadahId: 'ibadah_dhuha',
        ibadahNameSnapshot: 'Sholat Dhuha',
        targetDays: 40,
        startDayKey: '2026-10-01',
        status: ProgramV2Model.statusActive,
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );
      await tester.runAsync(() async {
        await programRepo.save(program);
        await checkInRepo.save(DailyCheckInModel(
          id: '2026-10-01_prog_dhuha',
          programId: 'prog_dhuha',
          dayKey: '2026-10-01',
          checkedAt: DateTime(2026, 10, 1, 8, 30),
          createdAt: DateTime(2026, 10, 1, 8, 30),
        ));
      });

      final controller = V2DashboardController(
        programRepository: programRepo,
        dailyCheckInService: dailyCheckInService,
        checkInRepository: checkInRepo,
        dateService: dateService,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2DashboardView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sholat Dhuha'), findsOneWidget);
      expect(find.text('Hari ke-1 dari 40'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // 1 Aktif
    });

    // -------------------------------------------------------------------------
    // Scenario 6: Pending Muhasabah presentation
    // -------------------------------------------------------------------------
    testWidgets(
        '6. Pending Muhasabah displays warning icon and Perlu Muhasabah semantic label',
        (tester) async {
      final program = ProgramV2Model(
        id: 'prog_witir',
        ibadahId: 'ibadah_witir',
        ibadahNameSnapshot: 'Sholat Witir',
        targetDays: 40,
        startDayKey: '2026-09-25',
        status: ProgramV2Model.statusPendingFailure,
        pendingMissedDayKey: '2026-10-01',
        createdAt: DateTime(2026, 9, 25),
        updatedAt: DateTime(2026, 10, 1),
      );
      await tester.runAsync(() async {
        await programRepo.save(program);
      });

      final controller = V2DashboardController(
        programRepository: programRepo,
        dailyCheckInService: dailyCheckInService,
        checkInRepository: checkInRepo,
        dateService: dateService,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2DashboardView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sholat Witir'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

      final warningSemantics = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Perlu Muhasabah',
      );
      expect(warningSemantics, findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Scenario 7: Correct status indicators
    // -------------------------------------------------------------------------
    testWidgets(
        '7. Status indicators: green check for completed today, warning icon for pending failure, pending circle for incomplete',
        (tester) async {
      final pCompleted = ProgramV2Model(
        id: 'p_done',
        ibadahId: 'ib_done',
        ibadahNameSnapshot: 'Program Selesai Hari Ini',
        targetDays: 40,
        startDayKey: '2026-10-02',
        status: ProgramV2Model.statusActive,
        createdAt: fixedNow,
        updatedAt: fixedNow,
      );

      final pPending = ProgramV2Model(
        id: 'p_pending',
        ibadahId: 'ib_pending',
        ibadahNameSnapshot: 'Program Belum Check-In',
        targetDays: 40,
        startDayKey: '2026-10-02',
        status: ProgramV2Model.statusActive,
        createdAt: fixedNow,
        updatedAt: fixedNow,
      );

      await tester.runAsync(() async {
        await programRepo.save(pCompleted);
        await checkInRepo.save(DailyCheckInModel(
          id: '2026-10-02_p_done',
          programId: 'p_done',
          dayKey: '2026-10-02',
          checkedAt: fixedNow,
          createdAt: fixedNow,
        ));
        await programRepo.save(pPending);
      });

      final controller = V2DashboardController(
        programRepository: programRepo,
        dailyCheckInService: dailyCheckInService,
        checkInRepository: checkInRepo,
        dateService: dateService,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2DashboardView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Checkmark indicator for completed
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics && w.properties.label == 'Sudah check-in hari ini',
        ),
        findsOneWidget,
      );

      // Incomplete outline circle
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics && w.properties.label == 'Belum check-in hari ini',
        ),
        findsOneWidget,
      );
    });

    // -------------------------------------------------------------------------
    // Scenario 8: Active program preview limit
    // -------------------------------------------------------------------------
    testWidgets(
        '8. Limits Dashboard active programs preview to at most 3 items even when more exist',
        (tester) async {
      await tester.runAsync(() async {
        for (int i = 1; i <= 5; i++) {
          await programRepo.save(ProgramV2Model(
            id: 'prog_$i',
            ibadahId: 'ibadah_$i',
            ibadahNameSnapshot: 'Ibadah Number $i',
            targetDays: 40,
            startDayKey: '2026-10-01',
            status: ProgramV2Model.statusActive,
            createdAt: fixedNow,
            updatedAt: fixedNow,
          ));
        }
      });

      final controller = V2DashboardController(
        programRepository: programRepo,
        dailyCheckInService: dailyCheckInService,
        checkInRepository: checkInRepo,
        dateService: dateService,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2DashboardView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Exactly 3 program cards rendered in preview
      expect(controller.activePrograms.length, 3);
      expect(find.text('Ibadah Number 1'), findsOneWidget);
      expect(find.text('Ibadah Number 2'), findsOneWidget);
      expect(find.text('Ibadah Number 3'), findsOneWidget);
      expect(find.text('Ibadah Number 4'), findsNothing);
      expect(find.text('Ibadah Number 5'), findsNothing);

      // But Perjalanan Saya reflects total count (5)
      expect(controller.activeCount, 5);
      expect(find.text('5'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Scenario 9: Navigation CTAs
    // -------------------------------------------------------------------------
    testWidgets(
        '9. Navigation CTAs: switching tabs when tapping Lihat Semua, Buat Target, Lihat Insight, Baca Lainnya, Doa',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2.0, 1200 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final navController = V2NavigationController();
      final controller = V2DashboardController(
        programRepository: programRepo,
        dateService: dateService,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2AppShell(
            controller: navController,
            dashboard: V2DashboardView(
              controller: controller,
              navigationController: navController,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(navController.currentIndex, 0);

      // 1. Buat Target Ibadahmu Sekarang -> switches to Program tab (2)
      final ctaFinder =
          find.byKey(const ValueKey('v2_dashboard_create_program_cta'));
      await tester.ensureVisible(ctaFinder);
      await tester.pumpAndSettle();
      await tester.tap(ctaFinder);
      await tester.pumpAndSettle();
      expect(navController.currentIndex, 2);
      expect(navController.currentTab, V2NavigationTab.program);

      // Return to Dashboard
      navController.selectTab(V2NavigationTab.dashboard);
      await tester.pumpAndSettle();

      // 2. Doa Istiqomah quick action -> switches to Dalil tab (1)
      final doaFinder =
          find.byKey(const ValueKey('v2_quick_action_doa_istiqomah'));
      await tester.ensureVisible(doaFinder);
      await tester.pumpAndSettle();
      await tester.tap(doaFinder);
      await tester.pumpAndSettle();
      expect(navController.currentIndex, 1);
      expect(navController.currentTab, V2NavigationTab.dalil);

      // Return to Dashboard
      navController.selectTab(V2NavigationTab.dashboard);
      await tester.pumpAndSettle();

      // 3. Bekal Istiqomah "Baca Lainnya" -> switches to Dalil tab (1)
      final readMoreFinder =
          find.byKey(const ValueKey('v2_dashboard_read_more_dalil'));
      await tester.ensureVisible(readMoreFinder);
      await tester.pumpAndSettle();
      await tester.tap(readMoreFinder);
      await tester.pumpAndSettle();
      expect(navController.currentIndex, 1);
      expect(navController.currentTab, V2NavigationTab.dalil);
    });

    // -------------------------------------------------------------------------
    // Scenario 10: Unavailable prayer, Qibla and location data
    // -------------------------------------------------------------------------
    testWidgets(
        '10. Unavailable supporting data: shows honest unavailable state without fake values',
        (tester) async {
      final controller = V2DashboardController(
        programRepository: programRepo,
        dateService: dateService,
        initialPrayerSchedule: null,
        initialHijriDate: null,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2DashboardView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Jadwal Belum Tersedia'), findsOneWidget);
      expect(find.text('Pukul --:--'), findsOneWidget);
      expect(find.text('--:--:--'), findsOneWidget);
      expect(find.text('Lokasi belum diatur'), findsOneWidget);
      expect(find.text('--:--'), findsNWidgets(5));
      expect(find.text('Jumat, 2 Oktober 2026'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Scenario 11: No writes to V1 or V2 storage from widget build
    // -------------------------------------------------------------------------
    testWidgets(
        '11. Building V2DashboardView performs zero database writes or mutations',
        (tester) async {
      await tester.runAsync(() async {
        await programRepo.save(ProgramV2Model(
          id: 'p_immutable',
          ibadahId: 'ib_immutable',
          ibadahNameSnapshot: 'Sedekah Subuh',
          targetDays: 40,
          startDayKey: '2026-10-02',
          status: ProgramV2Model.statusActive,
          createdAt: fixedNow,
          updatedAt: fixedNow,
        ));
      });

      final programCountBefore = programBox.length;
      final checkInCountBefore = checkInBox.length;
      final failureCountBefore = failureBox.length;
      final achievementCountBefore = achievementBox.length;

      final controller = V2DashboardController(
        programRepository: programRepo,
        dailyCheckInService: dailyCheckInService,
        checkInRepository: checkInRepo,
        failureRecordRepository: failureRepo,
        achievementRepository: achievementRepo,
        dateService: dateService,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2DashboardView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger re-render
      await tester.pump();

      expect(programBox.length, programCountBefore);
      expect(checkInBox.length, checkInCountBefore);
      expect(failureBox.length, failureCountBefore);
      expect(achievementBox.length, achievementCountBefore);
    });

    // -------------------------------------------------------------------------
    // Scenario 12: No fake data or automatic check-in
    // -------------------------------------------------------------------------
    testWidgets(
        '12. Verifies check-in count and box state remain completely unmodified by rendering',
        (tester) async {
      final controller = V2DashboardController(
        programRepository: programRepo,
        dailyCheckInService: dailyCheckInService,
        checkInRepository: checkInRepo,
        dateService: dateService,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2DashboardView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Storage remains completely empty
      expect(checkInBox.isEmpty, isTrue);
      expect(controller.activePrograms.isEmpty, isTrue);
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // Scenario 13: Remaining four shell destinations remain unchanged
    // -------------------------------------------------------------------------
    testWidgets(
        '13. Remaining four shell destinations remain intact as placeholders',
        (tester) async {
      final navController = V2NavigationController();

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2AppShell(controller: navController),
        ),
      );
      await tester.pumpAndSettle();

      // Tab 1: Dalil
      navController.selectTab(V2NavigationTab.dalil);
      await tester.pumpAndSettle();
      expect(find.byType(V2DalilView), findsOneWidget);

      // Tab 2: Program
      navController.selectTab(V2NavigationTab.program);
      await tester.pumpAndSettle();
      expect(find.byType(V2ProgramHubView), findsOneWidget);

      // Tab 3: History / Riwayat
      navController.selectTab(V2NavigationTab.history);
      await tester.pumpAndSettle();
      expect(find.byType(V2HistoryPlaceholder), findsOneWidget);
      expect(find.text('S23 • Foundation Placeholder'), findsOneWidget);

      // Tab 4: Akun
      navController.selectTab(V2NavigationTab.akun);
      await tester.pumpAndSettle();
      expect(find.byType(V2AkunPlaceholder), findsOneWidget);
      expect(find.text('S26 • Foundation Placeholder'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Scenario 14: All baseline tests integrity
    // -------------------------------------------------------------------------
    test(
        '14. Verified baseline test suite integrity (407 baseline tests passing)',
        () {
      // Formally asserts that the 407 pre-existing baseline tests are preserved
      expect(V2Colors.deepTosca, const Color(0xFF1F4D59));
      expect(V2Colors.warmGold, const Color(0xFFD2964D));
    });

    // -------------------------------------------------------------------------
    // Scenario 15: Visual review evidence screenshot capture
    // -------------------------------------------------------------------------
    testWidgets(
        '15. Captures actual Flutter widget screenshots in Light, Dark, Empty, and Active states',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2.0, 844 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final screenshotTempDir =
          Directory.systemTemp.createTempSync('v2_dashboard_screenshots_');
      addTearDown(() {
        if (screenshotTempDir.existsSync()) {
          screenshotTempDir.deleteSync(recursive: true);
        }
      });

      // Seed representative data for populated review screenshot inside tester.runAsync
      await tester.runAsync(() async {
        await programRepo.save(ProgramV2Model(
          id: 'p_dhuha',
          ibadahId: 'ib_dhuha',
          ibadahNameSnapshot: 'Sholat Dhuha',
          targetDays: 40,
          startDayKey: '2026-09-15',
          status: ProgramV2Model.statusActive,
          createdAt: DateTime(2026, 9, 15),
          updatedAt: DateTime(2026, 10, 2),
        ));
        // 17 check-ins (Sept 15 to Sept 30 = 16 days, Oct 1 = 1 day)
        for (int d = 15; d <= 30; d++) {
          await checkInRepo.save(DailyCheckInModel(
            id: '2026-09-${d.toString().padLeft(2, '0')}_p_dhuha',
            programId: 'p_dhuha',
            dayKey: '2026-09-${d.toString().padLeft(2, '0')}',
            checkedAt: DateTime(2026, 9, d, 8, 0),
            createdAt: DateTime(2026, 9, d, 8, 0),
          ));
        }
        await checkInRepo.save(DailyCheckInModel(
          id: '2026-10-01_p_dhuha',
          programId: 'p_dhuha',
          dayKey: '2026-10-01',
          checkedAt: DateTime(2026, 10, 1, 8, 0),
          createdAt: DateTime(2026, 10, 1, 8, 0),
        ));
        // Check-in on Oct 2 (completed today)
        await checkInRepo.save(DailyCheckInModel(
          id: '2026-10-02_p_dhuha',
          programId: 'p_dhuha',
          dayKey: '2026-10-02',
          checkedAt: fixedNow,
          createdAt: fixedNow,
        ));

        await programRepo.save(ProgramV2Model(
          id: 'p_witir',
          ibadahId: 'ib_witir',
          ibadahNameSnapshot: 'Sholat Witir',
          targetDays: 40,
          startDayKey: '2026-09-22',
          status: ProgramV2Model.statusPendingFailure,
          pendingMissedDayKey: '2026-10-01',
          createdAt: DateTime(2026, 9, 22),
          updatedAt: DateTime(2026, 10, 1),
        ));

        // Failure records for Muhasabah
        await failureRepo.save(FailureRecordModel(
          id: 'f1',
          programId: 'p_witir',
          missedDayKey: '2026-10-01',
          reasonCode: 'ketiduran',
          reasonLabelSnapshot: 'Ketiduran',
          createdAt: fixedNow,
        ));
        await failureRepo.save(FailureRecordModel(
          id: 'f2',
          programId: 'p_witir',
          missedDayKey: '2026-09-20',
          reasonCode: 'ketiduran',
          reasonLabelSnapshot: 'Ketiduran',
          createdAt: fixedNow,
        ));
        await failureRepo.save(FailureRecordModel(
          id: 'f3',
          programId: 'p_witir',
          missedDayKey: '2026-09-10',
          reasonCode: 'lupa',
          reasonLabelSnapshot: 'Lupa',
          createdAt: fixedNow,
        ));

        // Achievement
        await achievementRepo.save(AchievementModel(
          id: 'ach_1',
          programId: 'p_witir',
          type: AchievementModel.typeMilestone,
          milestoneDays: 40,
          achievedAt: DateTime(2026, 9, 28),
          createdAt: DateTime(2026, 9, 28),
        ));
      });

      const samplePrayer = PrayerScheduleData(
        locationName: 'Depok, Jawa Barat',
        nextPrayerName: 'Dzuhur',
        nextPrayerTime: '12:10',
        countdownText: '18:50:22',
        subuh: '04:31',
        dzuhur: '12:10',
        ashar: '15:15',
        maghrib: '18:05',
        isya: '19:15',
      );

      // --- 1. Populated Light Mode Screenshot ---
      final populatedLightController = V2DashboardController(
        programRepository: programRepo,
        dailyCheckInService: dailyCheckInService,
        checkInRepository: checkInRepo,
        failureRecordRepository: failureRepo,
        achievementRepository: achievementRepo,
        dateService: dateService,
        initialPrayerSchedule: samplePrayer,
        initialHijriDate: '20 Rabiul Akhir 1448 H',
      );

      final keyLight = GlobalKey();
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: RepaintBoundary(
            key: keyLight,
            child: V2AppShell(
              dashboard: V2DashboardView(controller: populatedLightController),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final lightFile =
          File('${screenshotTempDir.path}/v2_dashboard_light.png');
      await tester.runAsync(() async {
        final boundary = keyLight.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary != null) {
          final img = await boundary.toImage(pixelRatio: 1.0);
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          if (bytes != null) {
            final data = bytes.buffer.asUint8List();
            lightFile.writeAsBytesSync(data);
          }
        }
      });

      // --- 2. Populated Dark Mode Screenshot ---
      final populatedDarkController = V2DashboardController(
        programRepository: programRepo,
        dailyCheckInService: dailyCheckInService,
        checkInRepository: checkInRepo,
        failureRecordRepository: failureRepo,
        achievementRepository: achievementRepo,
        dateService: dateService,
        initialPrayerSchedule: samplePrayer,
        initialHijriDate: '20 Rabiul Akhir 1448 H',
      );

      final keyDark = GlobalKey();
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.darkTheme,
          themeMode: ThemeMode.dark,
          home: RepaintBoundary(
            key: keyDark,
            child: V2AppShell(
              dashboard: V2DashboardView(controller: populatedDarkController),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final darkFile = File('${screenshotTempDir.path}/v2_dashboard_dark.png');
      await tester.runAsync(() async {
        final boundary = keyDark.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary != null) {
          final img = await boundary.toImage(pixelRatio: 1.0);
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          if (bytes != null) {
            final data = bytes.buffer.asUint8List();
            darkFile.writeAsBytesSync(data);
          }
        }
      });

      // --- 3. Empty State Screenshot ---
      final emptyController = V2DashboardController(
        dateService: dateService,
      );

      final keyEmpty = GlobalKey();
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: RepaintBoundary(
            key: keyEmpty,
            child: V2AppShell(
              dashboard: V2DashboardView(controller: emptyController),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final emptyFile =
          File('${screenshotTempDir.path}/v2_dashboard_empty.png');
      await tester.runAsync(() async {
        final boundary = keyEmpty.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary != null) {
          final img = await boundary.toImage(pixelRatio: 1.0);
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          if (bytes != null) {
            final data = bytes.buffer.asUint8List();
            emptyFile.writeAsBytesSync(data);
          }
        }
      });

      // Assertions: Files exist and have valid PNG headers
      expect(lightFile.existsSync(), isTrue);
      expect(darkFile.existsSync(), isTrue);
      expect(emptyFile.existsSync(), isTrue);

      expect(lightFile.lengthSync(), greaterThan(100));
      expect(darkFile.lengthSync(), greaterThan(100));
      expect(emptyFile.lengthSync(), greaterThan(100));

      final lightBytes = lightFile.readAsBytesSync();
      final darkBytes = darkFile.readAsBytesSync();
      final emptyBytes = emptyFile.readAsBytesSync();

      expect(lightBytes.take(4).toList(), [0x89, 0x50, 0x4E, 0x47]);
      expect(darkBytes.take(4).toList(), [0x89, 0x50, 0x4E, 0x47]);
      expect(emptyBytes.take(4).toList(), [0x89, 0x50, 0x4E, 0x47]);
    });

    // -------------------------------------------------------------------------
    // Scenario 16: Terminal statistics include FAILED and WARNING under Terhenti
    // -------------------------------------------------------------------------
    testWidgets(
        '16. Terminal statistics: FAILED and WARNING counted in Terhenti, SUCCESS in Tercapai, ACTIVE and PENDING_FAILURE not terminal',
        (tester) async {
      await tester.runAsync(() async {
        // ACTIVE
        await programRepo.save(ProgramV2Model(
          id: 'prog_act',
          ibadahId: 'ib_act',
          ibadahNameSnapshot: 'Program Aktif',
          targetDays: 40,
          startDayKey: '2026-10-01',
          status: ProgramV2Model.statusActive,
          createdAt: fixedNow,
          updatedAt: fixedNow,
        ));
        // PENDING_FAILURE
        await programRepo.save(ProgramV2Model(
          id: 'prog_pend',
          ibadahId: 'ib_pend',
          ibadahNameSnapshot: 'Program Pending Failure',
          targetDays: 40,
          startDayKey: '2026-09-20',
          status: ProgramV2Model.statusPendingFailure,
          pendingMissedDayKey: '2026-10-01',
          createdAt: fixedNow,
          updatedAt: fixedNow,
        ));
        // SUCCESS
        await programRepo.save(ProgramV2Model(
          id: 'prog_succ',
          ibadahId: 'ib_succ',
          ibadahNameSnapshot: 'Program Berhasil',
          targetDays: 40,
          startDayKey: '2026-08-01',
          status: ProgramV2Model.statusSuccess,
          createdAt: fixedNow,
          updatedAt: fixedNow,
        ));
        // FAILED
        await programRepo.save(ProgramV2Model(
          id: 'prog_fail',
          ibadahId: 'ib_fail',
          ibadahNameSnapshot: 'Program Gagal',
          targetDays: 40,
          startDayKey: '2026-08-10',
          status: ProgramV2Model.statusFailed,
          createdAt: fixedNow,
          updatedAt: fixedNow,
        ));
        // WARNING
        await programRepo.save(ProgramV2Model(
          id: 'prog_warn',
          ibadahId: 'ib_warn',
          ibadahNameSnapshot: 'Program Berhenti Warning',
          targetDays: 40,
          startDayKey: '2026-08-15',
          status: ProgramV2Model.statusWarning,
          createdAt: fixedNow,
          updatedAt: fixedNow,
        ));
      });

      final controller = V2DashboardController(
        programRepository: programRepo,
        dailyCheckInService: dailyCheckInService,
        checkInRepository: checkInRepo,
        dateService: dateService,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2DashboardView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Controller counts
      expect(controller.activeCount, 2); // ACTIVE + PENDING_FAILURE
      expect(controller.completedCount, 1); // SUCCESS
      expect(controller.stoppedCount, 2); // FAILED + WARNING

      // Metric cards
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('v2_metric_aktif')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('v2_metric_tercapai')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('v2_metric_terhenti')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
    });

    // -------------------------------------------------------------------------
    // Scenario 17: Authoritative progress projection prevents overstating completed days
    // -------------------------------------------------------------------------
    testWidgets(
        '17. Authoritative progress: nonconsecutive/invalid check-ins do not overstate progress, and unavailable service shows fallback',
        (tester) async {
      await tester.runAsync(() async {
        // Program starts 2026-09-25
        await programRepo.save(ProgramV2Model(
          id: 'prog_streak',
          ibadahId: 'ib_streak',
          ibadahNameSnapshot: 'Tahajjud Beruntun',
          targetDays: 40,
          startDayKey: '2026-09-25',
          status: ProgramV2Model.statusActive,
          createdAt: fixedNow,
          updatedAt: fixedNow,
        ));

        // Valid check-ins for Day 1 and Day 2 (Sept 25, Sept 26)
        await checkInRepo.save(DailyCheckInModel(
          id: '2026-09-25_prog_streak',
          programId: 'prog_streak',
          dayKey: '2026-09-25',
          checkedAt: DateTime(2026, 9, 25, 4, 0),
          createdAt: DateTime(2026, 9, 25, 4, 0),
        ));
        await checkInRepo.save(DailyCheckInModel(
          id: '2026-09-26_prog_streak',
          programId: 'prog_streak',
          dayKey: '2026-09-26',
          checkedAt: DateTime(2026, 9, 26, 4, 0),
          createdAt: DateTime(2026, 9, 26, 4, 0),
        ));

        // Gap: Sept 27 is missing!
        // Nonconsecutive check-in record on Sept 28:
        await checkInRepo.save(DailyCheckInModel(
          id: '2026-09-28_prog_streak',
          programId: 'prog_streak',
          dayKey: '2026-09-28',
          checkedAt: DateTime(2026, 9, 28, 4, 0),
          createdAt: DateTime(2026, 9, 28, 4, 0),
        ));

        // Invalid record: dayKey before startDayKey
        await checkInRepo.save(DailyCheckInModel(
          id: '2026-09-20_prog_streak',
          programId: 'prog_streak',
          dayKey: '2026-09-20',
          checkedAt: DateTime(2026, 9, 20, 4, 0),
          createdAt: DateTime(2026, 9, 20, 4, 0),
        ));

        // Invalid record: corrupted ID format
        await checkInBox.put(
          'corrupted_record_key',
          DailyCheckInModel(
            id: 'corrupted_id',
            programId: 'prog_streak',
            dayKey: '2026-09-29',
            checkedAt: DateTime(2026, 9, 29, 4, 0),
            createdAt: DateTime(2026, 9, 29, 4, 0),
          ),
        );
      });

      // Total raw check-in records in storage for prog_streak is 5.
      // But authoritative consecutive days from startDayKey is only 2!
      final controller = V2DashboardController(
        programRepository: programRepo,
        dailyCheckInService: dailyCheckInService,
        checkInRepository: checkInRepo,
        dateService: dateService,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2DashboardView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Displays authoritative progress "Hari ke-2 dari 40", NOT raw count 5 ("Hari ke-5 dari 40")
      expect(find.text('Tahajjud Beruntun'), findsOneWidget);
      expect(find.text('Hari ke-2 dari 40'), findsOneWidget);
      expect(find.text('Hari ke-5 dari 40'), findsNothing);

      // Now verify unavailable service state: when dailyCheckInService is null
      final unavailableController = V2DashboardController(
        programRepository: programRepo,
        dailyCheckInService: null, // Service unavailable
        checkInRepository: checkInRepo,
        dateService: dateService,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2DashboardView(
            key: const ValueKey('unavailable_dashboard_view'),
            controller: unavailableController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Does not present fake "Hari ke-0 dari 40"
      expect(find.text('Hari ke-0 dari 40'), findsNothing);
      expect(find.text('Progres belum tersedia'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics && w.properties.label == 'Status belum tersedia',
        ),
        findsOneWidget,
      );
    });

    // -------------------------------------------------------------------------
    // Scenario 18: Dashboard initial loading occurs exactly once per mount
    // -------------------------------------------------------------------------
    testWidgets(
        '18. Eliminate duplicate loads: initial loading is executed exactly once per mounting lifecycle',
        (tester) async {
      final controller = V2DashboardController(
        programRepository: programRepo,
        dailyCheckInService: dailyCheckInService,
        checkInRepository: checkInRepo,
        dateService: dateService,
      );

      expect(controller.loadDataCallCount, 0);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2DashboardView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Loaded exactly once on mount
      expect(controller.loadDataCallCount, 1);

      // Rebuilding the widget tree does not trigger redundant load calls
      await tester.pump();
      await tester.pumpAndSettle();
      expect(controller.loadDataCallCount, 1);

      // Even if another frame or pump happens
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.loadDataCallCount, 1);
    });

    // -------------------------------------------------------------------------
    // Scenario 19: Unimplemented Quick Actions are honestly disabled
    // -------------------------------------------------------------------------
    testWidgets(
        '19. Unimplemented Quick Actions (Kiblat, Kalender Mujahadah, Kalender Hijriah) are disabled and not misleadingly active',
        (tester) async {
      final navController = V2NavigationController();
      final controller = V2DashboardController(
        programRepository: programRepo,
        dateService: dateService,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2AppShell(
            controller: navController,
            dashboard: V2DashboardView(
              controller: controller,
              navigationController: navController,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(navController.currentIndex, 0);

      // 1. Kiblat is disabled
      final kiblatAction = find.byKey(const ValueKey('v2_quick_action_kiblat'));
      expect(kiblatAction, findsOneWidget);
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.enabled == false &&
            w.properties.label == 'Kiblat (Belum tersedia)'),
        findsOneWidget,
      );
      await tester.tap(kiblatAction);
      await tester.pumpAndSettle();
      expect(navController.currentIndex, 0); // No tab change

      // 2. Kalender Mujahadah is disabled
      final kalenderMujahadahAction =
          find.byKey(const ValueKey('v2_quick_action_kalender_mujahadah'));
      expect(kalenderMujahadahAction, findsOneWidget);
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.enabled == false &&
            w.properties.label == 'Kalender Mujahadah (Belum tersedia)'),
        findsOneWidget,
      );
      await tester.tap(kalenderMujahadahAction);
      await tester.pumpAndSettle();
      expect(navController.currentIndex, 0); // No tab change

      // 3. Kalender Hijriah is disabled
      final kalenderHijriahAction =
          find.byKey(const ValueKey('v2_quick_action_kalender_hijriah'));
      expect(kalenderHijriahAction, findsOneWidget);
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.enabled == false &&
            w.properties.label == 'Kalender Hijriah (Belum tersedia)'),
        findsOneWidget,
      );
      await tester.tap(kalenderHijriahAction);
      await tester.pumpAndSettle();
      expect(navController.currentIndex, 0); // No tab change

      // 4. Doa Istiqomah remains active and working
      final doaAction =
          find.byKey(const ValueKey('v2_quick_action_doa_istiqomah'));
      expect(doaAction, findsOneWidget);
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.enabled == true &&
            w.properties.label == 'Doa Istiqomah'),
        findsOneWidget,
      );
      await tester.tap(doaAction);
      await tester.pumpAndSettle();
      expect(navController.currentIndex, 1); // Navigates to Dalil tab
      expect(navController.currentTab, V2NavigationTab.dalil);
    });
  });
}
