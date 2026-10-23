import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:mujahadah/controllers/v2_history_controller.dart';
import 'package:mujahadah/controllers/v2_navigation_controller.dart';
import 'package:mujahadah/controllers/v2_program_hub_controller.dart';
import 'package:mujahadah/core/runtime/v2_runtime.dart';
import 'package:mujahadah/models/daily_checkin_model.dart';
import 'package:mujahadah/models/failure_record_model.dart';
import 'package:mujahadah/models/program_v2_model.dart';
import 'package:mujahadah/models/v2_ibadah_catalog_item.dart';
import 'package:mujahadah/repositories/daily_checkin_v2_repository.dart';
import 'package:mujahadah/repositories/failure_record_v2_repository.dart';
import 'package:mujahadah/repositories/program_v2_repository.dart';
import 'package:mujahadah/services/daily_checkin_v2_service.dart';
import 'package:mujahadah/theme/v2_theme.dart';
import 'package:mujahadah/views/v2/history/v2_history_detail_view.dart';
import 'package:mujahadah/views/v2/history/v2_history_view.dart';
import 'package:mujahadah/views/v2/history/widgets/history_card.dart';

void main() {
  late Directory tempDir;
  late Box<ProgramV2Model> programBox;
  late Box<FailureRecordModel> failureBox;
  late Box<DailyCheckInModel> checkInBox;

  late ProgramV2Repository programRepo;
  late FailureRecordV2Repository failureRepo;
  late DailyCheckInV2Repository checkInRepo;
  late DailyCheckInV2Service checkInService;

  final sampleCatalog = [
    const V2IbadahCatalogItem(
      id: 'ibd-tahajjud',
      namaIbadah: 'Shalat Tahajjud',
      category: V2IbadahCategory.sholatSunnah,
      deskripsi: 'Shalat sunnah malam hari.',
      defaultTargetDays: 40,
      isDailyEligible: true,
    ),
    const V2IbadahCatalogItem(
      id: 'ibd-dhuha',
      namaIbadah: 'Shalat Dhuha',
      category: V2IbadahCategory.sholatSunnah,
      deskripsi: 'Shalat sunnah pagi hari.',
      defaultTargetDays: 40,
      isDailyEligible: true,
    ),
    const V2IbadahCatalogItem(
      id: 'ibd-witir',
      namaIbadah: 'Shalat Witir',
      category: V2IbadahCategory.sholatSunnah,
      deskripsi: 'Shalat penutup malam.',
      defaultTargetDays: 40,
      isDailyEligible: true,
    ),
    const V2IbadahCatalogItem(
      id: 'ibd-senin-kamis',
      namaIbadah: 'Puasa Senin Kamis',
      category: V2IbadahCategory.puasa,
      deskripsi: 'Puasa sunnah mingguan.',
      defaultTargetDays: 40,
      isDailyEligible: false, // Ineligible for daily mujahadah
      ineligibilityReason: 'Hanya dikerjakan hari Senin dan Kamis.',
    ),
  ];

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('v2_history_test_');
    Hive.init(tempDir.path);

    V2Runtime.registerAdapters();

    programBox = await Hive.openBox<ProgramV2Model>('test_history_prog_box');
    failureBox =
        await Hive.openBox<FailureRecordModel>('test_history_fail_box');
    checkInBox =
        await Hive.openBox<DailyCheckInModel>('test_history_checkin_box');

    programRepo = ProgramV2Repository(box: programBox);
    failureRepo = FailureRecordV2Repository(box: failureBox);
    checkInRepo = DailyCheckInV2Repository(box: checkInBox);
    checkInService = DailyCheckInV2Service(
      programRepository: programRepo,
      checkInRepository: checkInRepo,
    );
  });

  tearDownAll(() async {
    await programBox.close();
    await failureBox.close();
    await checkInBox.close();
    await Hive.close();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  setUp(() async {
    Get.reset();
    await programBox.clear();
    await failureBox.clear();
    await checkInBox.clear();
  });

  Widget buildTestHost({
    V2HistoryController? controller,
    V2NavigationController? navigationController,
    V2ProgramHubController? programHubController,
    ValueChanged<ProgramV2Model>? onRestartProgram,
    ThemeData? theme,
  }) {
    return GetMaterialApp(
      theme: theme ?? V2Theme.lightTheme,
      home: Scaffold(
        body: V2HistoryView(
          controller: controller,
          navigationController: navigationController,
          programRepository: programRepo,
          failureRecordRepository: failureRepo,
          dailyCheckInService: checkInService,
          programHubController: programHubController,
          onRestartProgram: onRestartProgram,
        ),
      ),
    );
  }

  group('V2 History & Restart Program (TASK MV2-B0-02-09)', () {
    testWidgets('1. Displays empty state when no programs exist',
        (tester) async {
      final controller = V2HistoryController(programRepository: programRepo);

      await tester.pumpWidget(buildTestHost(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Belum Ada Riwayat'), findsOneWidget);
      expect(
        find.text(
            'Program mujahadah yang telah selesai atau telah dievaluasi akan dicatat dan muncul di sini.'),
        findsOneWidget,
      );
      expect(find.byType(HistoryCard), findsNothing);
    });

    testWidgets(
        '2. Filters OUT active and pending-failure programs, projecting only terminal ones',
        (tester) async {
      await tester.runAsync(() async {
        await programRepo.save(ProgramV2Model(
          id: 'prog_act',
          ibadahId: 'ibd-tahajjud',
          ibadahNameSnapshot: 'Tahajjud Aktif',
          targetDays: 40,
          startDayKey: '2026-10-01',
          status: ProgramV2Model.statusActive,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));

        await programRepo.save(ProgramV2Model(
          id: 'prog_pend',
          ibadahId: 'ibd-witir',
          ibadahNameSnapshot: 'Witir Pending',
          targetDays: 40,
          startDayKey: '2026-10-01',
          status: ProgramV2Model.statusPendingFailure,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));

        await programRepo.save(ProgramV2Model(
          id: 'prog_succ',
          ibadahId: 'ibd-dhuha',
          ibadahNameSnapshot: 'Dhuha Selesai',
          targetDays: 40,
          startDayKey: '2026-08-01',
          status: ProgramV2Model.statusSuccess,
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 9, 10),
          finalizedAt: DateTime(2026, 9, 10),
        ));

        await programRepo.save(ProgramV2Model(
          id: 'prog_fail',
          ibadahId: 'ibd-tahajjud',
          ibadahNameSnapshot: 'Tahajjud Gagal',
          targetDays: 40,
          startDayKey: '2026-09-01',
          status: ProgramV2Model.statusFailed,
          createdAt: DateTime(2026, 9, 1),
          updatedAt: DateTime(2026, 9, 15),
          finalizedAt: DateTime(2026, 9, 15),
        ));

        await programRepo.save(ProgramV2Model(
          id: 'prog_warn',
          ibadahId: 'ibd-quran',
          ibadahNameSnapshot: 'Quran Hampir',
          targetDays: 60,
          startDayKey: '2026-07-01',
          status: ProgramV2Model.statusWarning,
          createdAt: DateTime(2026, 7, 1),
          updatedAt: DateTime(2026, 8, 15),
          finalizedAt: DateTime(2026, 8, 15),
        ));
      });

      final controller = V2HistoryController(programRepository: programRepo);

      await tester.pumpWidget(buildTestHost(controller: controller));
      await tester.pumpAndSettle();

      // Active and Pending must never appear in history
      expect(find.text('Tahajjud Aktif'), findsNothing);
      expect(find.text('Witir Pending'), findsNothing);

      // Terminal items must appear
      expect(find.text('Dhuha Selesai'), findsOneWidget);
      expect(find.text('Tahajjud Gagal'), findsOneWidget);
      expect(find.text('Quran Hampir'), findsOneWidget);
      expect(find.byType(HistoryCard), findsNWidgets(3));

      // Badge counts: Semua (3), Selesai (1), Hampir Selesai (1), Belum Selesai (1)
      expect(find.text('Semua (3)'), findsOneWidget);
      expect(find.text('Selesai (1)'), findsOneWidget);
      expect(find.text('Hampir Selesai (1)'), findsOneWidget);
      expect(find.text('Belum Selesai (1)'), findsOneWidget);
    });

    testWidgets(
        '3. Two episodes of the same ibadah are both visible with distinct IDs',
        (tester) async {
      await tester.runAsync(() async {
        await programRepo.save(ProgramV2Model(
          id: 'prog_episode_1',
          ibadahId: 'ibd-tahajjud',
          ibadahNameSnapshot: 'Shalat Tahajjud',
          targetDays: 40,
          startDayKey: '2026-06-01',
          status: ProgramV2Model.statusFailed,
          createdAt: DateTime(2026, 6, 1),
          updatedAt: DateTime(2026, 6, 10),
          finalizedAt: DateTime(2026, 6, 10),
        ));

        await programRepo.save(ProgramV2Model(
          id: 'prog_episode_2',
          ibadahId: 'ibd-tahajjud',
          ibadahNameSnapshot: 'Shalat Tahajjud',
          targetDays: 40,
          startDayKey: '2026-07-01',
          status: ProgramV2Model.statusSuccess,
          createdAt: DateTime(2026, 7, 1),
          updatedAt: DateTime(2026, 8, 10),
          finalizedAt: DateTime(2026, 8, 10),
        ));
      });

      final controller = V2HistoryController(programRepository: programRepo);

      await tester.pumpWidget(buildTestHost(controller: controller));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('v2_history_card_prog_episode_1')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('v2_history_card_prog_episode_2')),
          findsOneWidget);
      expect(find.byType(HistoryCard), findsNWidgets(2));
    });

    testWidgets(
        '4. Filter chips filter accurately and empty filter shows contextual notice',
        (tester) async {
      await tester.runAsync(() async {
        await programRepo.save(ProgramV2Model(
          id: 'prog_only_success',
          ibadahId: 'ibd-dhuha',
          ibadahNameSnapshot: 'Shalat Dhuha',
          targetDays: 40,
          startDayKey: '2026-08-01',
          status: ProgramV2Model.statusSuccess,
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 9, 10),
          finalizedAt: DateTime(2026, 9, 10),
        ));
      });

      final controller = V2HistoryController(programRepository: programRepo);

      await tester.pumpWidget(buildTestHost(controller: controller));
      await tester.pumpAndSettle();

      // Initial tab: Semua -> 1 card
      expect(find.byType(HistoryCard), findsOneWidget);

      // Select "Belum Selesai" (count 0)
      await tester.tap(find.byKey(const ValueKey('v2_history_filter_failed')));
      await tester.pumpAndSettle();

      expect(find.byType(HistoryCard), findsNothing);
      expect(find.text('Tidak Ada Riwayat'), findsOneWidget);
      expect(
          find.text(
              'Tidak ada program dengan status "Belum Selesai" dalam riwayatmu.'),
          findsOneWidget);

      // Tap "Lihat Semua" button
      await tester.tap(find.text('Lihat Semua'));
      await tester.pumpAndSettle();

      expect(find.byType(HistoryCard), findsOneWidget);
    });

    testWidgets(
        '5. Detail view opens and displays saved failure record snapshot',
        (tester) async {
      final failedProg = ProgramV2Model(
        id: 'prog_with_failure',
        ibadahId: 'ibd-tahajjud',
        ibadahNameSnapshot: 'Shalat Tahajjud',
        targetDays: 40,
        startDayKey: '2026-10-01',
        status: ProgramV2Model.statusFailed,
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 12),
        finalizedAt: DateTime(2026, 10, 12),
        pendingMissedDayKey: '2026-10-12',
      );

      final record = FailureRecordModel(
        id: FailureRecordV2Repository.buildFailureRecordId(
            '2026-10-12', failedProg.id),
        programId: failedProg.id,
        missedDayKey: '2026-10-12',
        reasonCode: 'sakit',
        reasonLabelSnapshot: 'Sakit berat yang membatasi aktivitas',
        note: 'Demam tinggi selama dua hari',
        createdAt: DateTime(2026, 10, 12, 10, 0),
      );

      await tester.runAsync(() async {
        await programRepo.save(failedProg);
        await failureRepo.save(record);
      });

      final controller = V2HistoryController(
        programRepository: programRepo,
        failureRecordRepository: failureRepo,
        dailyCheckInService: checkInService,
      );

      await tester.pumpWidget(buildTestHost(controller: controller));
      await tester.pumpAndSettle();

      // Tap card to open detail
      await tester
          .tap(find.byKey(ValueKey('v2_history_card_${failedProg.id}')));
      await tester.pumpAndSettle();

      expect(find.byType(V2HistoryDetailView), findsOneWidget);
      expect(find.text('Detail Riwayat'), findsOneWidget);
      expect(find.text('Sakit berat yang membatasi aktivitas'), findsOneWidget);
      expect(find.text('Demam tinggi selama dua hari'), findsOneWidget);
      expect(find.byKey(const ValueKey('v2_history_detail_restart_button')),
          findsOneWidget);

      // Tap Back button to return to list
      await tester
          .tap(find.byKey(const ValueKey('v2_history_detail_back_button')));
      await tester.pumpAndSettle();

      expect(find.byType(V2HistoryDetailView), findsNothing);
      expect(find.byType(HistoryCard), findsOneWidget);
    });

    testWidgets('6. Restart CTA initiates S20 setup via V2ProgramHubController',
        (tester) async {
      final oldProg = ProgramV2Model(
        id: 'prog_to_restart',
        ibadahId: 'ibd-tahajjud',
        ibadahNameSnapshot: 'Shalat Tahajjud',
        targetDays: 40,
        startDayKey: '2026-08-01',
        status: ProgramV2Model.statusSuccess,
        reminderTime: '03:30',
        createdAt: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 9, 10),
        finalizedAt: DateTime(2026, 9, 10),
      );

      await tester.runAsync(() async {
        await programRepo.save(oldProg);
      });

      final navCtrl =
          V2NavigationController(initialTab: V2NavigationTab.history);
      final hubCtrl = V2ProgramHubController(
        initialCatalog: sampleCatalog,
        programRepository: programRepo,
      );
      final histCtrl = V2HistoryController(
        programRepository: programRepo,
      );

      await tester.pumpWidget(buildTestHost(
        controller: histCtrl,
        navigationController: navCtrl,
        programHubController: hubCtrl,
      ));
      await tester.pumpAndSettle();

      // Open detail
      await tester.tap(find.byKey(ValueKey('v2_history_card_${oldProg.id}')));
      await tester.pumpAndSettle();

      // Tap "Mulai Lagi Program Ini"
      await tester
          .tap(find.byKey(const ValueKey('v2_history_detail_restart_button')));
      await tester.pumpAndSettle();

      // Must have switched navigation tab to Program (2)
      expect(navCtrl.currentTab, equals(V2NavigationTab.program));

      // Hub controller must have stepped to programConfig with prefilled draft
      expect(hubCtrl.currentStep, equals(ProgramScreenStep.programConfig));
      expect(hubCtrl.configuringItem?.id, equals('ibd-tahajjud'));
      expect(hubCtrl.configDraft.restartedFromProgramId, equals(oldProg.id));
      expect(hubCtrl.configDraft.targetDays, equals(40));
      expect(hubCtrl.configDraft.reminderTime, equals('03:30'));
    });

    testWidgets(
        '7. Restart fails closed when active program already exists for the ibadah',
        (tester) async {
      final oldTerminal = ProgramV2Model(
        id: 'prog_old_terminal',
        ibadahId: 'ibd-dhuha',
        ibadahNameSnapshot: 'Shalat Dhuha',
        targetDays: 40,
        startDayKey: '2026-08-01',
        status: ProgramV2Model.statusSuccess,
        createdAt: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 9, 10),
        finalizedAt: DateTime(2026, 9, 10),
      );

      final activeProg = ProgramV2Model(
        id: 'prog_active_dhuha',
        ibadahId: 'ibd-dhuha',
        ibadahNameSnapshot: 'Shalat Dhuha',
        targetDays: 40,
        startDayKey: '2026-10-20',
        status: ProgramV2Model.statusActive,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.runAsync(() async {
        await programRepo.save(oldTerminal);
        await programRepo.save(activeProg);
      });

      final navCtrl =
          V2NavigationController(initialTab: V2NavigationTab.history);
      final hubCtrl = V2ProgramHubController(
        initialCatalog: sampleCatalog,
        programRepository: programRepo,
      );
      final histCtrl = V2HistoryController(programRepository: programRepo);

      await tester.pumpWidget(buildTestHost(
        controller: histCtrl,
        navigationController: navCtrl,
        programHubController: hubCtrl,
      ));
      await tester.pumpAndSettle();

      // Open detail
      await tester
          .tap(find.byKey(ValueKey('v2_history_card_${oldTerminal.id}')));
      await tester.pumpAndSettle();

      // Tap Mulai Lagi
      await tester
          .tap(find.byKey(const ValueKey('v2_history_detail_restart_button')));
      await tester.pumpAndSettle();

      // Shows modal dialog: Program Masih Aktif
      expect(find.text('Program Masih Aktif'), findsOneWidget);
      expect(navCtrl.currentTab, equals(V2NavigationTab.history));
      expect(hubCtrl.currentStep, equals(ProgramScreenStep.hub));
    });

    testWidgets(
        '8. Restart fails closed when catalog item is not daily eligible',
        (tester) async {
      final oldPuasa = ProgramV2Model(
        id: 'prog_ineligible_terminal',
        ibadahId: 'ibd-senin-kamis',
        ibadahNameSnapshot: 'Puasa Senin Kamis',
        targetDays: 40,
        startDayKey: '2026-08-01',
        status: ProgramV2Model.statusSuccess,
        createdAt: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 9, 10),
        finalizedAt: DateTime(2026, 9, 10),
      );

      await tester.runAsync(() async {
        await programRepo.save(oldPuasa);
      });

      final navCtrl =
          V2NavigationController(initialTab: V2NavigationTab.history);
      final hubCtrl = V2ProgramHubController(
        initialCatalog: sampleCatalog,
        programRepository: programRepo,
      );
      final histCtrl = V2HistoryController(programRepository: programRepo);

      await tester.pumpWidget(buildTestHost(
        controller: histCtrl,
        navigationController: navCtrl,
        programHubController: hubCtrl,
      ));
      await tester.pumpAndSettle();

      // Open detail
      await tester.tap(find.byKey(ValueKey('v2_history_card_${oldPuasa.id}')));
      await tester.pumpAndSettle();

      // Tap Mulai Lagi
      await tester
          .tap(find.byKey(const ValueKey('v2_history_detail_restart_button')));
      await tester.pumpAndSettle();

      // Shows modal dialog: Template Tidak Tersedia
      expect(find.text('Template Tidak Tersedia'), findsOneWidget);
      expect(navCtrl.currentTab, equals(V2NavigationTab.history));
    });

    testWidgets(
        '9. Responsive rendering on 320dp and in Dark Mode without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 568 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.runAsync(() async {
        await programRepo.save(ProgramV2Model(
          id: 'prog_dark_responsive',
          ibadahId: 'ibd-tahajjud',
          ibadahNameSnapshot: 'Shalat Tahajjud Bersama Keluarga',
          targetDays: 100,
          startDayKey: '2026-05-01',
          status: ProgramV2Model.statusSuccess,
          createdAt: DateTime(2026, 5, 1),
          updatedAt: DateTime(2026, 8, 10),
          finalizedAt: DateTime(2026, 8, 10),
        ));
      });

      final controller = V2HistoryController(programRepository: programRepo);

      await tester.pumpWidget(buildTestHost(
        controller: controller,
        theme: V2Theme.darkTheme,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(HistoryCard), findsOneWidget);
    });

    testWidgets(
        '10. External callback override onRestartProgram still enforces terminal status and duplicate active guards (P2-01)',
        (tester) async {
      final terminalProg = ProgramV2Model(
        id: 'prog_terminal_test',
        ibadahId: 'ibd-witir',
        ibadahNameSnapshot: 'Shalat Witir',
        targetDays: 40,
        startDayKey: '2026-08-01',
        status: ProgramV2Model.statusSuccess,
        createdAt: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 9, 10),
        finalizedAt: DateTime(2026, 9, 10),
      );

      final activeProg = ProgramV2Model(
        id: 'prog_active_witir',
        ibadahId: 'ibd-witir',
        ibadahNameSnapshot: 'Shalat Witir',
        targetDays: 40,
        startDayKey: '2026-10-01',
        status: ProgramV2Model.statusActive,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.runAsync(() async {
        await programRepo.save(terminalProg);
        await programRepo.save(activeProg);
      });

      ProgramV2Model? restartedProgramReceived;
      final controller = V2HistoryController(programRepository: programRepo);

      await tester.pumpWidget(buildTestHost(
        controller: controller,
        onRestartProgram: (p) => restartedProgramReceived = p,
      ));
      await tester.pumpAndSettle();

      // Open detail for terminalProg
      await tester
          .tap(find.byKey(ValueKey('v2_history_card_${terminalProg.id}')));
      await tester.pumpAndSettle();

      // Tap Mulai Lagi
      await tester
          .tap(find.byKey(const ValueKey('v2_history_detail_restart_button')));
      await tester.pumpAndSettle();

      // P2-01 Verification: Duplicate active guard blocks restart even when onRestartProgram callback is passed
      expect(find.text('Program Masih Aktif'), findsOneWidget);
      expect(restartedProgramReceived, isNull);

      // Dismiss dialog
      await tester
          .tap(find.byKey(const ValueKey('v2_history_notice_ok_button')));
      await tester.pumpAndSettle();

      // Delete active program so it is no longer duplicate
      await tester.runAsync(() async {
        await programBox.delete(activeProg.id);
      });

      // Tap Mulai Lagi again
      await tester
          .tap(find.byKey(const ValueKey('v2_history_detail_restart_button')));
      await tester.pumpAndSettle();

      // Now callback is invoked with the validated terminal program
      expect(restartedProgramReceived, isNotNull);
      expect(restartedProgramReceived!.id, equals(terminalProg.id));
    });
  });
}
