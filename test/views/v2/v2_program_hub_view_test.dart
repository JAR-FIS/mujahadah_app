import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:mujahadah/controllers/v2_navigation_controller.dart';
import 'package:mujahadah/controllers/v2_program_hub_controller.dart';
import 'package:mujahadah/core/runtime/v2_runtime.dart';
import 'package:mujahadah/models/program_v2_model.dart';
import 'package:mujahadah/models/v2_ibadah_catalog_item.dart';
import 'package:mujahadah/repositories/program_v2_repository.dart';
import 'package:mujahadah/theme/v2_theme.dart';
import 'package:mujahadah/views/v2/dalil/v2_dalil_view.dart';
import 'package:mujahadah/views/v2/program/v2_pilih_ibadah_view.dart';
import 'package:mujahadah/views/v2/program/v2_program_config_view.dart';
import 'package:mujahadah/views/v2/program/v2_program_hub_view.dart';
import 'package:mujahadah/views/v2/program/widgets/program_active_card.dart';
import 'package:mujahadah/views/v2/program/widgets/program_catalog_card.dart';
import 'package:mujahadah/views/v2/program/widgets/program_search_bar.dart';
import 'package:mujahadah/views/v2/program/widgets/program_segment_selector.dart';
import 'package:mujahadah/views/v2/shell/v2_app_shell.dart';

class _FailingProgramV2Repository extends ProgramV2Repository {
  _FailingProgramV2Repository({required super.box});

  @override
  List<ProgramV2Model> getAll() {
    throw Exception(
        'Simulated Hive storage corruption: fatal disk read error 0xDEADBEEF');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<ProgramV2Model> programBox;
  late ProgramV2Repository programRepo;

  // Sample catalog fixtures for isolated testing
  final sampleCatalogItems = [
    const V2IbadahCatalogItem(
      id: 'sholat_dhuha',
      namaIbadah: 'Sholat Dhuha',
      category: V2IbadahCategory.sholatSunnah,
      deskripsi:
          'Sholat Dhuha adalah ibadah sholat sunnah muakkadah yang dikerjakan pada pagi hari ketika matahari mulai naik hingga menjelang waktu zuhur.',
      tataCaraDanWaktu:
          'Kerjakan minimal dua rakaat dengan tuma\'ninah, setelah matahari naik hingga menjelang waktu zuhur.',
      keutamaan: [
        'Sedekah bagi seluruh persendian: 2 rakaat Dhuha mencukupi sedekah untuk 360 sendi dalam tubuh.',
        'Dicukupi kebutuhan rezeki hingga sore hari.',
        'Dibangunkan rumah di surga bagi yang menunaikan sebanyak 12 rakaat.',
      ],
      dalilDanRujukan: 'HR. Muslim no. 720; HR. Abu Dawud no. 1285.',
      defaultTargetDays: 40,
      isDailyEligible: true,
    ),
    const V2IbadahCatalogItem(
      id: 'sedekah_subuh',
      namaIbadah: 'Sedekah Subuh',
      category: V2IbadahCategory.ibadahHarian,
      deskripsi:
          'Sedekah yang dikeluarkan pada waktu subuh saat malaikat turun mendoakan keberkahan.',
      keutamaan: [
        'Malaikat mendoakan kelapangan rezeki bagi orang yang berinfak di waktu subuh.',
      ],
      defaultTargetDays: 40,
      isDailyEligible: true,
    ),
    const V2IbadahCatalogItem(
      id: 'puasa_daud',
      namaIbadah: 'Puasa Daud',
      category: V2IbadahCategory.puasa,
      deskripsi: 'Puasa sunnah dengan pola sehari berpuasa dan sehari berbuka.',
      keutamaan: [
        'Puasa yang paling disukai Allah SWT adalah puasa Nabi Daud as.',
      ],
      defaultTargetDays: 40,
      isDailyEligible: false,
      ineligibilityReason:
          'Program Mujahadah V2 dirancang untuk target harian berturut-turut. Puasa Daud memiliki pola berselang sehingga tidak dapat dibuat sebagai target harian.',
    ),
    const V2IbadahCatalogItem(
      id: 'wirid_pagi',
      namaIbadah: 'Wirid Pagi',
      category: V2IbadahCategory.dzikir,
      deskripsi:
          'Dzikir dan wirid pagi sesudah menunaikan sholat subuh untuk ketenangan jiwa.',
      defaultTargetDays: 60,
      isDailyEligible: true,
    ),
  ];

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('v2_program_hub_test_');
    Hive.init(tempDir.path);
    V2Runtime.registerAdapters();

    programBox =
        await Hive.openBox<ProgramV2Model>('test_program_hub_programs_v2');
    programRepo = ProgramV2Repository(box: programBox);
  });

  tearDownAll(() async {
    await programBox.close();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    Get.reset();
    await programBox.clear();
  });

  tearDown(() {
    Get.reset();
  });

  group('V2 Program Hub & Pilih Ibadah (TASK MV2-B0-02-05)', () {
    // -------------------------------------------------------------------------
    // Scenario 1: S17 Layout Rendering
    // -------------------------------------------------------------------------
    testWidgets(
        '1. S17 layout rendering: displays header, segment tabs, search bar, and + Baru button',
        (tester) async {
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
        programRepository: programRepo,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Header 'Program'
      expect(find.text('Program'), findsOneWidget);

      // Segment switcher
      expect(find.byType(ProgramSegmentSelector), findsOneWidget);
      expect(find.text('Katalog Ibadah'), findsOneWidget);
      expect(find.text('Ibadah Saya'), findsOneWidget);

      // Search bar and + Baru button
      expect(find.byType(ProgramSearchBar), findsOneWidget);
      expect(find.byKey(const ValueKey('v2_program_search_field')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('v2_program_new_custom_button')),
          findsOneWidget);
      expect(find.text('Baru'), findsOneWidget);

      // Catalog list items rendered
      expect(find.byType(ProgramCatalogCard),
          findsNWidgets(sampleCatalogItems.length));
      expect(find.text('Sholat Dhuha'), findsOneWidget);
      expect(find.text('Sedekah Subuh'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Scenario 2: Program segment switcher updates active tab
    // -------------------------------------------------------------------------
    testWidgets('2. Program segment switcher updates active tab and state',
        (tester) async {
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
        programRepository: programRepo,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.currentTab, ProgramHubTab.katalog);

      // Tap 'Ibadah Saya' segment
      await tester
          .tap(find.byKey(const ValueKey('v2_program_segment_ibadahSaya')));
      await tester.pumpAndSettle();

      expect(controller.currentTab, ProgramHubTab.ibadahSaya);

      // Tap 'Katalog Ibadah' segment
      await tester
          .tap(find.byKey(const ValueKey('v2_program_segment_katalog')));
      await tester.pumpAndSettle();

      expect(controller.currentTab, ProgramHubTab.katalog);
    });

    // -------------------------------------------------------------------------
    // Scenario 3: Empty repository and empty catalog states
    // -------------------------------------------------------------------------
    testWidgets('3. Default empty state shows honest unavailable placeholders',
        (tester) async {
      // Empty controller
      final emptyController = V2ProgramHubController(
        programRepository: programRepo,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(controller: emptyController),
        ),
      );
      await tester.pumpAndSettle();

      // Catalog Tab: Empty
      expect(find.text('Katalog Ibadah Belum Tersedia'), findsOneWidget);

      // Switch to Ibadah Saya Tab
      emptyController.selectTab(ProgramHubTab.ibadahSaya);
      await tester.pumpAndSettle();

      // Ibadah Saya: Empty
      expect(find.text('Belum Ada Program Aktif'), findsOneWidget);
      expect(find.text('Pilih dari Katalog'), findsOneWidget);

      // Tapping 'Pilih dari Katalog' switches back to Katalog tab
      await tester.tap(find.text('Pilih dari Katalog'));
      await tester.pumpAndSettle();

      expect(emptyController.currentTab, ProgramHubTab.katalog);
    });

    // -------------------------------------------------------------------------
    // Scenario 4: Real-time search with matches, no matches, and cleared query
    // -------------------------------------------------------------------------
    testWidgets(
        '4. Search filtering across catalog items with matches, no matches, and clear search',
        (tester) async {
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProgramCatalogCard),
          findsNWidgets(sampleCatalogItems.length));

      // Enter search query 'Dhuha'
      await tester.enterText(
          find.byKey(const ValueKey('v2_program_search_field')), 'Dhuha');
      await tester.pumpAndSettle();

      expect(find.byType(ProgramCatalogCard), findsOneWidget);
      expect(find.text('Sholat Dhuha'), findsOneWidget);
      expect(find.text('Sedekah Subuh'), findsNothing);

      // Enter search query with no matches
      await tester.enterText(
          find.byKey(const ValueKey('v2_program_search_field')), 'TidakAda');
      await tester.pumpAndSettle();

      expect(find.byType(ProgramCatalogCard), findsNothing);
      expect(find.text('Ibadah Tidak Ditemukan'), findsOneWidget);
      expect(find.text('Hapus Pencarian'), findsOneWidget);

      // Tap 'Hapus Pencarian'
      await tester.tap(find.text('Hapus Pencarian'));
      await tester.pumpAndSettle();

      expect(find.byType(ProgramCatalogCard),
          findsNWidgets(sampleCatalogItems.length));
    });

    // -------------------------------------------------------------------------
    // Scenario 5: S17 -> S18 Navigation
    // -------------------------------------------------------------------------
    testWidgets(
        '5. Tapping catalog card navigates to S18 Pilih Ibadah detail screen',
        (tester) async {
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Sholat Dhuha card
      await tester
          .tap(find.byKey(const ValueKey('v2_catalog_item_sholat_dhuha')));
      await tester.pumpAndSettle();

      // S18 View is rendered
      expect(find.byType(V2PilihIbadahView), findsOneWidget);
      expect(controller.isDetailOpen, isTrue);

      // Verify S18 elements
      expect(find.byKey(const ValueKey('v2_pilih_ibadah_back_button')),
          findsOneWidget);
      expect(find.text('Sholat Dhuha'), findsWidgets);
      expect(find.text('Deskripsi'), findsOneWidget);
      expect(find.text('Keutamaan'), findsOneWidget);
      expect(find.byKey(const ValueKey('v2_pilih_ibadah_mulai_button')),
          findsOneWidget);
      expect(find.text('Mulai Program Mujahadah'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Scenario 6: S18 Back Navigation (UI Back & System Back)
    // -------------------------------------------------------------------------
    testWidgets(
        '6. UI Back button and Android system Back on S18 return to S17 Program Hub',
        (tester) async {
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to S18
      await tester
          .tap(find.byKey(const ValueKey('v2_catalog_item_sholat_dhuha')));
      await tester.pumpAndSettle();
      expect(find.byType(V2PilihIbadahView), findsOneWidget);

      // Tap UI Back button
      await tester
          .tap(find.byKey(const ValueKey('v2_pilih_ibadah_back_button')));
      await tester.pumpAndSettle();
      expect(find.byType(V2PilihIbadahView), findsNothing);
      expect(find.text('Program'), findsOneWidget);

      // Re-open S18
      await tester
          .tap(find.byKey(const ValueKey('v2_catalog_item_sholat_dhuha')));
      await tester.pumpAndSettle();
      expect(find.byType(V2PilihIbadahView), findsOneWidget);

      // Simulate Android System Back
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(V2PilihIbadahView), findsNothing);
      expect(find.text('Program'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Scenario 6b: Inactive Program tab does NOT intercept Android system Back
    // -------------------------------------------------------------------------
    testWidgets(
        '6b. Inactive Program tab with open S18 does not intercept Android system Back',
        (tester) async {
      final navController =
          V2NavigationController(initialTab: V2NavigationTab.program);
      final programController = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2AppShell(
            controller: navController,
            program: V2ProgramHubView(
              controller: programController,
              navigationController: navController,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open S18 in Program tab
      await tester
          .tap(find.byKey(const ValueKey('v2_catalog_item_sholat_dhuha')));
      await tester.pumpAndSettle();
      expect(find.byType(V2PilihIbadahView), findsOneWidget);

      // Switch to Dalil tab (1) while S18 is still mounted
      navController.selectTab(V2NavigationTab.dalil);
      await tester.pumpAndSettle();
      expect(find.byType(V2DalilView), findsOneWidget);

      // Trigger system back while on Dalil tab
      final didHandle = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Pop was not consumed by the inactive Program tab
      expect(didHandle, isFalse);
      expect(find.byType(V2DalilView), findsOneWidget);

      // Program's S18 state remains preserved when returning
      navController.selectTab(V2NavigationTab.program);
      await tester.pumpAndSettle();
      expect(find.byType(V2PilihIbadahView), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Scenario 7: Selection by stable Ibadah ID
    // -------------------------------------------------------------------------
    testWidgets('7. Selection by stable Ibadah ID', (tester) async {
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Select by stable ID 'sedekah_subuh'
      final found = controller.selectItemById('sedekah_subuh');
      expect(found, isTrue);
      await tester.pumpAndSettle();

      expect(find.byType(V2PilihIbadahView), findsOneWidget);
      expect(find.text('Sedekah Subuh'), findsWidgets);

      // Non-existent ID returns false
      final notFound = controller.selectItemById('unknown_id');
      expect(notFound, isFalse);
    });

    // -------------------------------------------------------------------------
    // Scenario 8: Active programs projection in Ibadah Saya tab
    // -------------------------------------------------------------------------
    testWidgets('8. Active programs projection in Ibadah Saya tab',
        (tester) async {
      final now = DateTime(2026, 10, 2);
      // Seed programs into repository
      final p1 = ProgramV2Model(
        id: 'prog_1',
        ibadahId: 'sholat_dhuha',
        ibadahNameSnapshot: 'Sholat Dhuha',
        targetDays: 40,
        startDayKey: '2026-10-01',
        status: ProgramV2Model.statusActive,
        createdAt: now,
        updatedAt: now,
      );
      final p2 = ProgramV2Model(
        id: 'prog_2',
        ibadahId: 'sedekah_subuh',
        ibadahNameSnapshot: 'Sedekah Subuh',
        targetDays: 40,
        startDayKey: '2026-10-01',
        status: ProgramV2Model.statusPendingFailure, // Requires Muhasabah
        createdAt: now,
        updatedAt: now,
      );
      final p3 = ProgramV2Model(
        id: 'prog_3',
        ibadahId: 'wirid_pagi',
        ibadahNameSnapshot: 'Wirid Pagi Selesai',
        targetDays: 40,
        startDayKey: '2026-08-01',
        status: ProgramV2Model.statusSuccess, // Terminal - must not be shown
        createdAt: now,
        updatedAt: now,
      );
      final p4 = ProgramV2Model(
        id: 'prog_4',
        ibadahId: 'sholat_tahajud',
        ibadahNameSnapshot: 'Tahajud Gagal',
        targetDays: 40,
        startDayKey: '2026-08-01',
        status: ProgramV2Model.statusFailed, // Terminal - must not be shown
        createdAt: now,
        updatedAt: now,
      );

      await tester.runAsync(() async {
        await programRepo.save(p1);
        await programRepo.save(p2);
        await programRepo.save(p3);
        await programRepo.save(p4);
      });

      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
        programRepository: programRepo,
        initialTab: ProgramHubTab.ibadahSaya,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Only 2 active programs must be rendered (p1 and p2)
      expect(find.byType(ProgramActiveCard), findsNWidgets(2));
      expect(find.text('Sholat Dhuha'), findsOneWidget);
      expect(find.text('Sedekah Subuh'), findsOneWidget);

      // Status labels
      expect(find.text('Aktif'), findsOneWidget);
      expect(find.text('Perlu Muhasabah'), findsOneWidget);

      // Terminal programs must not be shown
      expect(find.text('Wirid Pagi Selesai'), findsNothing);
      expect(find.text('Tahajud Gagal'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // Scenario 9: Program Hub displays all active programs without Dashboard's 3-item limit
    // -------------------------------------------------------------------------
    testWidgets(
        '9. Program Hub displays all active programs without Dashboard 3-item limit',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2.0, 1200 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime(2026, 10, 2);
      await tester.runAsync(() async {
        for (int i = 1; i <= 6; i++) {
          await programRepo.save(
            ProgramV2Model(
              id: 'prog_active_$i',
              ibadahId: 'ibadah_$i',
              ibadahNameSnapshot: 'Target Ibadah $i',
              targetDays: 40,
              startDayKey: '2026-10-01',
              status: ProgramV2Model.statusActive,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      });

      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
        programRepository: programRepo,
        initialTab: ProgramHubTab.ibadahSaya,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // All 6 active programs are loaded and rendered
      expect(controller.userPrograms.length, 6);
      expect(find.byType(ProgramActiveCard), findsNWidgets(6));
    });

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------
    // Scenario 10: Daily-eligibility and S20 setup enforcement in S18
    // -------------------------------------------------------------------------
    testWidgets(
        '10. Daily-eligibility and S20 setup enforcement: blocked when ineligible or unwired, navigates to S20 when wired',
        (tester) async {
      int legacyCallbackCount = 0;
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
      );

      // Part A: View with null callback and no setup wiring
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            controller: controller,
            wireProgramSetup: false,
            onStartProgram: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Select ineligible item (Puasa Daud)
      await tester
          .tap(find.byKey(const ValueKey('v2_catalog_item_puasa_daud')));
      await tester.pumpAndSettle();

      // Ineligibility warning is displayed
      expect(
          find.text(
              'Program Mujahadah V2 dirancang untuk target harian berturut-turut. Puasa Daud memiliki pola berselang sehingga tidak dapat dibuat sebagai target harian.'),
          findsOneWidget);

      // Button is disabled
      final btnFinder =
          find.byKey(const ValueKey('v2_pilih_ibadah_mulai_button'));
      ElevatedButton btn = tester.widget(btnFinder);
      expect(btn.onPressed, isNull);

      // 2. Return and select eligible item (Sholat Dhuha) with no setup wiring
      await tester
          .tap(find.byKey(const ValueKey('v2_pilih_ibadah_back_button')));
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const ValueKey('v2_catalog_item_sholat_dhuha')));
      await tester.pumpAndSettle();

      // CTA remains disabled because setup is not wired, avoiding inert button
      btn = tester.widget(btnFinder);
      expect(btn.onPressed, isNull);
      expect(
          find.text(
              'Pengaturan target dan durasi program (S20) akan segera tersedia.'),
          findsOneWidget);

      // Part B: Re-pump with ONLY deprecated legacy callback and NO setup wiring
      final unwiredController = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
      );
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            controller: unwiredController,
            wireProgramSetup: false,
            onStartProgram: (item) {
              legacyCallbackCount++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select eligible item
      await tester
          .tap(find.byKey(const ValueKey('v2_catalog_item_sholat_dhuha')));
      await tester.pumpAndSettle();

      // Button remains disabled: deprecated legacy callback alone does NOT enable CTA
      btn = tester.widget(btnFinder);
      expect(btn.onPressed, isNull);
      expect(
          find.text(
              'Pengaturan target dan durasi program (S20) akan segera tersedia.'),
          findsOneWidget);

      // Tapping disabled CTA produces zero callback increments
      await tester.tap(btnFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(legacyCallbackCount, 0);

      // Part C: Re-pump with wireProgramSetup: true
      final wiredController = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
      );
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            controller: wiredController,
            wireProgramSetup: true,
            onStartProgram: (item) {
              legacyCallbackCount++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select eligible item
      await tester
          .tap(find.byKey(const ValueKey('v2_catalog_item_sholat_dhuha')));
      await tester.pumpAndSettle();

      // Button is enabled, helper text is not displayed
      btn = tester.widget(btnFinder);
      expect(btn.onPressed, isNotNull);
      expect(
          find.text(
              'Pengaturan target dan durasi program (S20) akan segera tersedia.'),
          findsNothing);

      // Tap CTA once
      await tester.tap(btnFinder);
      await tester.pumpAndSettle();

      // Opens S20
      expect(find.byType(V2ProgramConfigView), findsOneWidget);
      expect(wiredController.currentStep, ProgramScreenStep.programConfig);

      // Crucial: legacy callback was NOT invoked during navigation, zero side effects
      expect(legacyCallbackCount, 0);
    });

    // -------------------------------------------------------------------------
    // Scenario 11: Responsive layout on compact (320dp) and standard (390dp)
    // -------------------------------------------------------------------------
    testWidgets(
        '11. Responsive layout: renders without overflow on 320dp and 390dp',
        (tester) async {
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
      );

      // Compact 320dp width
      tester.view.physicalSize = const Size(320 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Open S18 at 320dp
      await tester
          .tap(find.byKey(const ValueKey('v2_catalog_item_sholat_dhuha')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Standard 390dp width
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Reset test window
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    // -------------------------------------------------------------------------
    // Scenario 12: Long worship names and text scaling
    // -------------------------------------------------------------------------
    testWidgets('12. Long worship names render without overflow',
        (tester) async {
      const longItem = V2IbadahCatalogItem(
        id: 'long_name_ibadah',
        namaIbadah:
            'Sholat Sunnah Tahiyyatul Masjid Sebelum Duduk di Hari Jumat dengan Khusyu',
        category: V2IbadahCategory.sholatSunnah,
        deskripsi:
            'Deskripsi ibadah yang sangat komprehensif dan mendalam untuk menguji ketahanan layout terhadap teks panjang tanpa terjadi overflow pada antarmuka pengguna.',
        keutamaan: [
          'Menghormati rumah Allah SWT ketika pertama kali memasukinya sebelum duduk.',
        ],
        defaultTargetDays: 100,
        isDailyEligible: true,
      );

      final controller = V2ProgramHubController(
        initialCatalog: [longItem],
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester
          .tap(find.byKey(const ValueKey('v2_catalog_item_long_name_ibadah')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // Scenario 13: Light and Dark theme rendering
    // -------------------------------------------------------------------------
    testWidgets('13. Renders correctly in both Light and Dark themes',
        (tester) async {
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
      );

      // Light theme
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(V2ProgramHubView), findsOneWidget);

      // Dark theme
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.darkTheme,
          themeMode: ThemeMode.dark,
          home: V2ProgramHubView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(V2ProgramHubView), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Scenario 14: Accessibility and 48x48dp touch targets
    // -------------------------------------------------------------------------
    testWidgets(
        '14. Accessible touch targets and semantics labels are properly declared',
        (tester) async {
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Check segment touch targets
      final segmentKatalog = tester
          .getSize(find.byKey(const ValueKey('v2_program_segment_katalog')));
      expect(segmentKatalog.height, greaterThanOrEqualTo(48));

      final btnBaru = tester
          .getSize(find.byKey(const ValueKey('v2_program_new_custom_button')));
      expect(btnBaru.height, greaterThanOrEqualTo(48));
      expect(btnBaru.width, greaterThanOrEqualTo(48));

      // Open S18
      await tester
          .tap(find.byKey(const ValueKey('v2_catalog_item_sholat_dhuha')));
      await tester.pumpAndSettle();

      final backBtn = tester
          .getSize(find.byKey(const ValueKey('v2_pilih_ibadah_back_button')));
      expect(backBtn.height, greaterThanOrEqualTo(48));
      expect(backBtn.width, greaterThanOrEqualTo(48));

      final ctaBtn = tester
          .getSize(find.byKey(const ValueKey('v2_pilih_ibadah_mulai_button')));
      expect(ctaBtn.height, greaterThanOrEqualTo(48));
    });

    // -------------------------------------------------------------------------
    // Scenario 15: Default controller contains empty catalog without fabricated records
    // -------------------------------------------------------------------------
    test(
        '15. Default controller contains empty catalog without fabricated records',
        () {
      final controller = V2ProgramHubController();
      expect(controller.catalogItems, isEmpty);
      expect(controller.userPrograms, isEmpty);
      expect(controller.isDetailOpen, isFalse);
    });

    // -------------------------------------------------------------------------
    // Scenario 16: Zero database writes or storage mutations
    // -------------------------------------------------------------------------
    testWidgets('16. Zero database writes or mutations during presentation',
        (tester) async {
      final initialKeys = programBox.keys.toList();

      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
        programRepository: programRepo,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Open S18 and navigate back
      await tester
          .tap(find.byKey(const ValueKey('v2_catalog_item_sholat_dhuha')));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('v2_pilih_ibadah_back_button')));
      await tester.pumpAndSettle();

      expect(programBox.keys.toList(), initialKeys);
    });

    // -------------------------------------------------------------------------
    // Scenario 17: Dashboard's Program CTA navigates to Program Hub S17
    // -------------------------------------------------------------------------
    testWidgets('17. Dashboard CTA navigates to Program Hub S17',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2.0, 1200 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final navController = V2NavigationController();

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2AppShell(controller: navController),
        ),
      );
      await tester.pumpAndSettle();

      expect(navController.currentIndex, 0); // Dashboard

      // Tap Dashboard CTA 'Buat Target Ibadahmu Sekarang'
      final ctaFinder = find.text('Buat Target Ibadahmu Sekarang');
      expect(ctaFinder, findsOneWidget);
      await tester.tap(ctaFinder);
      await tester.pumpAndSettle();

      // Switches to Program Tab (2)
      expect(navController.currentIndex, 2);
      expect(navController.currentTab, V2NavigationTab.program);
      expect(find.byType(V2ProgramHubView), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Scenario 18: Capture actual Flutter widget screenshots
    // -------------------------------------------------------------------------
    testWidgets(
        '18. Captures actual Flutter widget screenshots in Light, Dark, Empty, and S18 Detail states',
        (tester) async {
      final screenshotTempDir =
          Directory.systemTemp.createTempSync('v2_program_hub_screenshots_');
      addTearDown(() {
        try {
          screenshotTempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      // 1. Program Hub Light Mode
      final lightController = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
      );
      final keyLight = GlobalKey();
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: RepaintBoundary(
            key: keyLight,
            child: V2AppShell(
              controller:
                  V2NavigationController(initialTab: V2NavigationTab.program),
              program: V2ProgramHubView(controller: lightController),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final lightFile =
          File('${screenshotTempDir.path}/v2_program_hub_light.png');
      await tester.runAsync(() async {
        final boundary = keyLight.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary != null) {
          final img = await boundary.toImage(pixelRatio: 1.0);
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          if (bytes != null) {
            lightFile.writeAsBytesSync(bytes.buffer.asUint8List());
          }
        }
      });

      // 2. Program Hub Dark Mode
      final darkController = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
      );
      final keyDark = GlobalKey();
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.darkTheme,
          themeMode: ThemeMode.dark,
          home: RepaintBoundary(
            key: keyDark,
            child: V2AppShell(
              controller:
                  V2NavigationController(initialTab: V2NavigationTab.program),
              program: V2ProgramHubView(controller: darkController),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final darkFile =
          File('${screenshotTempDir.path}/v2_program_hub_dark.png');
      await tester.runAsync(() async {
        final boundary = keyDark.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary != null) {
          final img = await boundary.toImage(pixelRatio: 1.0);
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          if (bytes != null) {
            darkFile.writeAsBytesSync(bytes.buffer.asUint8List());
          }
        }
      });

      // 3. S18 Detail Screen
      lightController.selectItem(sampleCatalogItems.first);
      final keyDetail = GlobalKey();
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: RepaintBoundary(
            key: keyDetail,
            child: V2AppShell(
              controller:
                  V2NavigationController(initialTab: V2NavigationTab.program),
              program: V2ProgramHubView(controller: lightController),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final detailFile =
          File('${screenshotTempDir.path}/v2_pilih_ibadah_detail.png');
      await tester.runAsync(() async {
        final boundary = keyDetail.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary != null) {
          final img = await boundary.toImage(pixelRatio: 1.0);
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          if (bytes != null) {
            detailFile.writeAsBytesSync(bytes.buffer.asUint8List());
          }
        }
      });

      // 4. Empty Catalog State
      final emptyController = V2ProgramHubController();
      final keyEmpty = GlobalKey();
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: RepaintBoundary(
            key: keyEmpty,
            child: V2AppShell(
              controller:
                  V2NavigationController(initialTab: V2NavigationTab.program),
              program: V2ProgramHubView(controller: emptyController),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final emptyFile =
          File('${screenshotTempDir.path}/v2_program_hub_empty.png');
      await tester.runAsync(() async {
        final boundary = keyEmpty.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary != null) {
          final img = await boundary.toImage(pixelRatio: 1.0);
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          if (bytes != null) {
            emptyFile.writeAsBytesSync(bytes.buffer.asUint8List());
          }
        }
      });

      // Verify files created and valid PNG headers
      expect(lightFile.existsSync(), isTrue);
      expect(darkFile.existsSync(), isTrue);
      expect(detailFile.existsSync(), isTrue);
      expect(emptyFile.existsSync(), isTrue);

      expect(lightFile.lengthSync(), greaterThan(100));
      expect(darkFile.lengthSync(), greaterThan(100));
      expect(detailFile.lengthSync(), greaterThan(100));
      expect(emptyFile.lengthSync(), greaterThan(100));

      final lightBytes = lightFile.readAsBytesSync();
      final darkBytes = darkFile.readAsBytesSync();
      final detailBytes = detailFile.readAsBytesSync();
      final emptyBytes = emptyFile.readAsBytesSync();

      expect(lightBytes.take(4).toList(), [0x89, 0x50, 0x4E, 0x47]);
      expect(darkBytes.take(4).toList(), [0x89, 0x50, 0x4E, 0x47]);
      expect(detailBytes.take(4).toList(), [0x89, 0x50, 0x4E, 0x47]);
      expect(emptyBytes.take(4).toList(), [0x89, 0x50, 0x4E, 0x47]);
    });

    // -------------------------------------------------------------------------
    // Scenario 19: Priority-based ProgramV2Repository resolution
    // -------------------------------------------------------------------------
    testWidgets(
        '19. Priority-based repository resolution: registered GetX instance resolved, injected repo takes precedence, safe when unregistered',
        (tester) async {
      final now = DateTime(2026, 10, 2);

      // Part A: Registered GetX repository is resolved when no explicit repo is provided
      await tester.runAsync(() async {
        await programRepo.save(
          ProgramV2Model(
            id: 'prog_getx_1',
            ibadahId: 'sholat_dhuha',
            ibadahNameSnapshot: 'Program dari GetX Repo',
            targetDays: 40,
            startDayKey: '2026-10-01',
            status: ProgramV2Model.statusActive,
            createdAt: now,
            updatedAt: now,
          ),
        );
      });

      Get.put<ProgramV2Repository>(programRepo);

      // Pump V2ProgramHubView with NO explicit controller or repository
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: const V2ProgramHubView(
            key: ValueKey('v2_program_hub_part_a'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Ibadah Saya
      await tester
          .tap(find.byKey(const ValueKey('v2_program_segment_ibadahSaya')));
      await tester.pumpAndSettle();

      // Registered repository was resolved and active program is visible
      expect(find.text('Program dari GetX Repo'), findsOneWidget);

      // Part B: Injected repository takes precedence over registered GetX repository
      final customTempDir =
          Directory.systemTemp.createTempSync('v2_program_hub_injected_');
      addTearDown(() {
        try {
          customTempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      late Box<ProgramV2Model> customBox;
      late ProgramV2Repository customInjectedRepo;

      await tester.runAsync(() async {
        customBox = await Hive.openBox<ProgramV2Model>(
          'test_injected_box_v2',
          path: customTempDir.path,
        );
        customInjectedRepo = ProgramV2Repository(box: customBox);
        await customInjectedRepo.save(
          ProgramV2Model(
            id: 'prog_injected_1',
            ibadahId: 'sedekah_subuh',
            ibadahNameSnapshot: 'Program dari Injected Repo',
            targetDays: 60,
            startDayKey: '2026-10-01',
            status: ProgramV2Model.statusActive,
            createdAt: now,
            updatedAt: now,
          ),
        );
      });
      addTearDown(() async {
        await customBox.close();
      });

      // Pump view with explicit injected repo while GetX still has programRepo
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            key: const ValueKey('v2_program_hub_part_b'),
            programRepository: customInjectedRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const ValueKey('v2_program_segment_ibadahSaya')));
      await tester.pumpAndSettle();

      // Injected repo takes precedence
      expect(find.text('Program dari Injected Repo'), findsOneWidget);
      expect(find.text('Program dari GetX Repo'), findsNothing);

      // Part C: Without any registered or injected repository, view remains safe
      Get.reset(); // Clear GetX

      await tester.pumpWidget(
        const GetMaterialApp(
          home: V2ProgramHubView(
            key: ValueKey('v2_program_hub_part_c'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const ValueKey('v2_program_segment_ibadahSaya')));
      await tester.pumpAndSettle();

      expect(find.text('Belum Ada Program Aktif'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // Scenario 20: Safe Indonesian copy and error handling on repository failure
    // -------------------------------------------------------------------------
    testWidgets(
        '20. Repository failure does not expose raw exception details and provides friendly Indonesian copy with retry',
        (tester) async {
      final failingRepo = _FailingProgramV2Repository(box: programBox);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            programRepository: failingRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Ibadah Saya
      await tester
          .tap(find.byKey(const ValueKey('v2_program_segment_ibadahSaya')));
      await tester.pumpAndSettle();

      // Error state displayed
      expect(find.text('Terjadi Kesalahan'), findsOneWidget);
      expect(find.text('Gagal memuat program aktif. Silakan coba lagi.'),
          findsOneWidget);
      expect(find.text('Muat Ulang'), findsOneWidget);

      // Raw technical details are NOT leaked to the user
      expect(find.textContaining('Simulated Hive storage corruption'),
          findsNothing);
      expect(find.textContaining('0xDEADBEEF'), findsNothing);
      expect(find.textContaining('Exception:'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // Scenario 21: Honest card semantics and noninteractive presentation for ProgramActiveCard
    // -------------------------------------------------------------------------
    testWidgets(
        '21. Active program cards are not announced as buttons when noninteractive (onTap is null)',
        (tester) async {
      final now = DateTime(2026, 10, 2);
      final prog = ProgramV2Model(
        id: 'prog_card_semantics',
        ibadahId: 'sholat_dhuha',
        ibadahNameSnapshot: 'Sholat Dhuha Test Semantics',
        targetDays: 40,
        startDayKey: '2026-10-01',
        status: ProgramV2Model.statusActive,
        createdAt: now,
        updatedAt: now,
      );

      // 1. Noninteractive card (onTap == null)
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: Scaffold(
            body: ProgramActiveCard(
              program: prog,
              onTap: null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Has semantics without button flag
      final noninteractiveSemanticsFinder = find.descendant(
        of: find.byType(ProgramActiveCard),
        matching: find.byType(Semantics),
      );
      final Semantics noninteractiveSemantics =
          tester.widget(noninteractiveSemanticsFinder.first);
      expect(noninteractiveSemantics.properties.button, isFalse);

      // No InkWell inside card when noninteractive
      expect(
          find.descendant(
            of: find.byType(ProgramActiveCard),
            matching: find.byType(InkWell),
          ),
          findsNothing);

      // 2. Interactive card (onTap != null)
      bool didTap = false;
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: Scaffold(
            body: ProgramActiveCard(
              program: prog,
              onTap: () => didTap = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final interactiveSemanticsFinder = find.descendant(
        of: find.byType(ProgramActiveCard),
        matching: find.byType(Semantics),
      );
      final Semantics interactiveSemantics =
          tester.widget(interactiveSemanticsFinder.first);
      expect(interactiveSemantics.properties.button, isTrue);

      // InkWell is present and actionable
      final inkWellFinder = find.descendant(
        of: find.byType(ProgramActiveCard),
        matching: find.byType(InkWell),
      );
      expect(inkWellFinder, findsOneWidget);

      await tester.tap(inkWellFinder);
      await tester.pumpAndSettle();
      expect(didTap, isTrue);
    });

    // -------------------------------------------------------------------------
    // Scenario 22: Clear minimum duration label
    // -------------------------------------------------------------------------
    testWidgets(
        '22. Minimum-duration badges do not imply a preselected final target ("Min. 40 hari")',
        (tester) async {
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Catalog card displays minimum duration label
      expect(find.text('Min. 40 hari'), findsWidgets);

      // Open S18
      await tester
          .tap(find.byKey(const ValueKey('v2_catalog_item_sholat_dhuha')));
      await tester.pumpAndSettle();

      // Header card in S18 also displays minimum duration label
      expect(find.text('Min. 40 hari'), findsWidgets);
    });

    // -------------------------------------------------------------------------
    // Scenario 23: Explicit daily eligibility model enforcement
    // -------------------------------------------------------------------------
    test('23. Explicit daily eligibility model enforcement: fail-closed', () {
      const eligibleItem = V2IbadahCatalogItem(
        id: 'test_eligible',
        namaIbadah: 'Ibadah Harian Sahih',
        category: V2IbadahCategory.dzikir,
        deskripsi: 'Deskripsi uji',
        isDailyEligible: true,
      );
      expect(eligibleItem.isDailyEligible, isTrue);

      const ineligibleItem = V2IbadahCatalogItem(
        id: 'test_ineligible',
        namaIbadah: 'Puasa Berselang',
        category: V2IbadahCategory.puasa,
        deskripsi: 'Deskripsi pola selang',
        isDailyEligible: false,
        ineligibilityReason: 'Pola selang-seling',
      );
      expect(ineligibleItem.isDailyEligible, isFalse);
      expect(ineligibleItem.ineligibilityReason, 'Pola selang-seling');

      // copyWith maintains eligibility state
      final copied = ineligibleItem.copyWith(namaIbadah: 'Nama Baru');
      expect(copied.isDailyEligible, isFalse);
    });
  });
}
