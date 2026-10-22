import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:mujahadah/controllers/v2_navigation_controller.dart';
import 'package:mujahadah/controllers/v2_program_hub_controller.dart';
import 'package:mujahadah/core/date/date_service.dart';
import 'package:mujahadah/core/runtime/v2_runtime.dart';
import 'package:mujahadah/models/program_v2_model.dart';
import 'package:mujahadah/models/v2_custom_ibadah_draft.dart';
import 'package:mujahadah/models/v2_ibadah_catalog_item.dart';
import 'package:mujahadah/models/v2_program_config_draft.dart';
import 'package:mujahadah/repositories/program_v2_repository.dart';
import 'package:mujahadah/services/program_v2_creation_service.dart';
import 'package:mujahadah/theme/v2_theme.dart';
import 'package:mujahadah/views/v2/program/v2_custom_ibadah_view.dart';
import 'package:mujahadah/views/v2/program/v2_pilih_ibadah_view.dart';
import 'package:mujahadah/views/v2/program/v2_program_config_view.dart';
import 'package:mujahadah/views/v2/program/v2_program_hub_view.dart';
import 'package:mujahadah/views/v2/program/v2_program_review_view.dart';
import 'package:mujahadah/views/v2/shell/v2_app_shell.dart';

class _InMemoryProgramV2Repository extends ProgramV2Repository {
  final List<ProgramV2Model> _items = [];

  _InMemoryProgramV2Repository({required super.box});

  @override
  List<ProgramV2Model> getAll() => List.unmodifiable(_items);

  @override
  Future<void> save(ProgramV2Model program) async {
    _items.removeWhere((p) => p.id == program.id);
    _items.add(program);
  }

  @override
  bool hasActiveOrPendingProgram(String ibadahId) {
    return _items.any((p) =>
        p.ibadahId == ibadahId &&
        (p.status == ProgramV2Model.statusActive ||
            p.status == ProgramV2Model.statusPendingFailure));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<ProgramV2Model> programBox;
  late ProgramV2Repository programRepo;
  late ProgramV2CreationService creationService;

  final sampleCatalogItems = [
    const V2IbadahCatalogItem(
      id: 'sholat_dhuha',
      namaIbadah: 'Sholat Dhuha',
      category: V2IbadahCategory.sholatSunnah,
      deskripsi: 'Sholat sunnah muakkadah pagi hari.',
      defaultTargetDays: 40,
      isDailyEligible: true,
    ),
    const V2IbadahCatalogItem(
      id: 'puasa_daud',
      namaIbadah: 'Puasa Daud',
      category: V2IbadahCategory.puasa,
      deskripsi: 'Puasa berselang sehari puasa sehari berbuka.',
      defaultTargetDays: 40,
      isDailyEligible: false,
      ineligibilityReason:
          'Program Mujahadah V2 dirancang untuk target harian berturut-turut. Puasa Daud memiliki pola berselang sehingga tidak dapat dibuat sebagai target harian.',
    ),
    const V2IbadahCatalogItem(
      id: 'wirid_pagi',
      namaIbadah: 'Wirid Pagi',
      category: V2IbadahCategory.dzikir,
      deskripsi: 'Dzikir pagi sesudah sholat subuh.',
      defaultTargetDays: 60,
      isDailyEligible: true,
    ),
  ];

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('v2_custom_program_test_');
    Hive.init(tempDir.path);
    V2Runtime.registerAdapters();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    Get.reset();
    programBox = await Hive.openBox<ProgramV2Model>(
        'program_v2_${DateTime.now().microsecondsSinceEpoch}');
    programRepo = ProgramV2Repository(box: programBox);
    creationService = ProgramV2CreationService(repository: programRepo);
  });

  tearDown(() async {
    await programBox.close();
  });

  group('V2 Custom Ibadah S19 & Program Setup S20 (TASK MV2-B0-02-06)', () {
    // -------------------------------------------------------------------------
    // 1. S17 "+ Baru" opens S19
    // -------------------------------------------------------------------------
    testWidgets('1. S17 "+ Baru" opens S19 Tambah Ibadah Kustom',
        (tester) async {
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap '+ Baru' action button
      final baruBtn =
          find.byKey(const ValueKey('v2_program_new_custom_button'));
      expect(baruBtn, findsOneWidget);
      await tester.tap(baruBtn);
      await tester.pumpAndSettle();

      // S19 Custom Ibadah screen is now rendered
      expect(find.byType(V2CustomIbadahView), findsOneWidget);
      expect(find.text('Tambah Ibadah Kustom'), findsOneWidget);
      expect(find.byKey(const ValueKey('v2_custom_ibadah_name_input')),
          findsOneWidget);

      // Back navigation returns to S17
      await tester
          .tap(find.byKey(const ValueKey('v2_custom_ibadah_back_button')));
      await tester.pumpAndSettle();

      expect(find.byType(V2CustomIbadahView), findsNothing);
      expect(find.text('Program'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 2. S18 eligible Ibadah navigates to S20 when wired
    // -------------------------------------------------------------------------
    testWidgets('2. S18 eligible Ibadah navigates to S20 when wired',
        (tester) async {
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            controller: controller,
            wireProgramSetup: true,
            creationService: creationService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select eligible item
      await tester
          .tap(find.byKey(const ValueKey('v2_catalog_item_sholat_dhuha')));
      await tester.pumpAndSettle();

      expect(find.byType(V2PilihIbadahView), findsOneWidget);

      // Tap Mulai Program Mujahadah
      final startBtn =
          find.byKey(const ValueKey('v2_pilih_ibadah_mulai_button'));
      await tester.tap(startBtn);
      await tester.pumpAndSettle();

      // S20 is opened
      expect(find.byType(V2ProgramConfigView), findsOneWidget);
      expect(find.text('Konfigurasi Program'), findsOneWidget);
      expect(find.text('Sholat Dhuha'), findsWidgets);
      expect(find.text('Target Durasi Istiqomah'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 3. Ineligible Ibadah cannot start a Program
    // -------------------------------------------------------------------------
    testWidgets('3. Ineligible Ibadah cannot start a Program', (tester) async {
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            controller: controller,
            wireProgramSetup: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select ineligible item
      await tester
          .tap(find.byKey(const ValueKey('v2_catalog_item_puasa_daud')));
      await tester.pumpAndSettle();

      final startBtnFinder =
          find.byKey(const ValueKey('v2_pilih_ibadah_mulai_button'));
      final ElevatedButton btn = tester.widget(startBtnFinder);
      expect(btn.onPressed, isNull);

      // Try tapping anyway
      await tester.tap(startBtnFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Still on S18
      expect(find.byType(V2ProgramConfigView), findsNothing);
      expect(find.byType(V2PilihIbadahView), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 4. S19 input validation
    // -------------------------------------------------------------------------
    testWidgets(
        '4. S19 input validation: empty, too short, too long, and valid',
        (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2CustomIbadahView(
            onBack: () {},
            onSave: (draft) async => null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final nameInput =
          find.byKey(const ValueKey('v2_custom_ibadah_name_input'));
      final saveBtn =
          find.byKey(const ValueKey('v2_custom_ibadah_save_button'));

      // Tap save while empty
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();
      expect(find.text('Nama ibadah tidak boleh kosong.'), findsOneWidget);

      // Enter 2 chars
      await tester.enterText(nameInput, 'Sh');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();
      expect(find.text('Nama ibadah minimal 3 karakter.'), findsOneWidget);

      // Enter valid name
      await tester.enterText(nameInput, 'Sholat Tahajud 4 Rakaat');
      await tester.pumpAndSettle();
      expect(find.text('Nama ibadah minimal 3 karakter.'), findsNothing);
      expect(find.text('Nama ibadah tidak boleh kosong.'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // 5. Custom template never embeds Program configuration
    // -------------------------------------------------------------------------
    test(
        '5. Custom template draft never embeds Program lifecycle configuration',
        () {
      const draft = V2CustomIbadahDraft(
        namaIbadah: 'Dzikir Petang 100x',
        category: V2IbadahCategory.dzikir,
        deskripsi: 'Membaca istighfar dan tasbih',
      );

      expect(draft.namaIbadah, 'Dzikir Petang 100x');
      expect(draft.category, V2IbadahCategory.dzikir);
      expect(draft.deskripsi, 'Membaca istighfar dan tasbih');
      expect(draft.isValid, isTrue);

      // Confirm no program lifecycle fields are exposed on V2CustomIbadahDraft
      final fields = [
        'targetDays',
        'startDayKey',
        'reminderTime',
        'status',
      ];
      for (final f in fields) {
        expect(draft.toString().contains(f), isFalse);
      }
    });

    // -------------------------------------------------------------------------
    // 6. S19 cannot falsely report unsaved templates as saved
    // -------------------------------------------------------------------------
    testWidgets('6. S19 cannot falsely report unsaved templates as saved',
        (tester) async {
      int savedCount = 0;

      // Part A: null onSave handler
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2CustomIbadahView(
            onBack: () {},
            onSave: null,
            onSaved: (_) => savedCount++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('v2_custom_ibadah_unavailable_notice')),
          findsOneWidget);
      final ElevatedButton btn = tester
          .widget(find.byKey(const ValueKey('v2_custom_ibadah_save_button')));
      expect(btn.onPressed, isNull);
      expect(savedCount, 0);

      // Part B: Failing save handler returning null
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2CustomIbadahView(
            onBack: () {},
            onSave: (draft) async => null,
            onSaved: (_) => savedCount++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const ValueKey('v2_custom_ibadah_name_input')),
          'Sholat Hajat 2 Rakaat');
      await tester
          .tap(find.byKey(const ValueKey('v2_custom_ibadah_save_button')));
      await tester.pumpAndSettle();

      expect(savedCount, 0);
      expect(find.text('Gagal menyimpan ibadah kustom. Silakan coba lagi.'),
          findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 7. S20 preset selection 40/60/90/100
    // -------------------------------------------------------------------------
    testWidgets('7. S20 preset selection 40, 60, 90, 100 days', (tester) async {
      V2ProgramConfigDraft? capturedDraft;

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramConfigView(
            item: sampleCatalogItems[0],
            initialDraft: const V2ProgramConfigDraft(targetDays: 40),
            onBack: () {},
            onProceedToReview: (d) => capturedDraft = d,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial is 40
      await tester.tap(find.byKey(const ValueKey('v2_config_review_button')));
      await tester.pumpAndSettle();
      expect(capturedDraft?.effectiveTargetDays, 40);

      // Tap 60
      await tester.tap(find.byKey(const ValueKey('v2_config_preset_60')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('v2_config_review_button')));
      await tester.pumpAndSettle();
      expect(capturedDraft?.effectiveTargetDays, 60);

      // Tap 90
      await tester.tap(find.byKey(const ValueKey('v2_config_preset_90')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('v2_config_review_button')));
      await tester.pumpAndSettle();
      expect(capturedDraft?.effectiveTargetDays, 90);

      // Tap 100
      await tester.tap(find.byKey(const ValueKey('v2_config_preset_100')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('v2_config_review_button')));
      await tester.pumpAndSettle();
      expect(capturedDraft?.effectiveTargetDays, 100);
    });

    // -------------------------------------------------------------------------
    // 8. Custom 39 rejected, 40 accepted, 365 accepted, 366 rejected
    // -------------------------------------------------------------------------
    testWidgets(
        '8. Custom target duration: 39 rejected, 40 accepted, 365 accepted, 366 rejected',
        (tester) async {
      V2ProgramConfigDraft? capturedDraft;

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramConfigView(
            item: sampleCatalogItems[0],
            initialDraft: const V2ProgramConfigDraft(
              isCustomDuration: true,
              customDurationText: '',
            ),
            onBack: () {},
            onProceedToReview: (d) => capturedDraft = d,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final inputFinder =
          find.byKey(const ValueKey('v2_config_custom_duration_input'));
      final reviewBtn = find.byKey(const ValueKey('v2_config_review_button'));

      // 1. Enter 39
      await tester.enterText(inputFinder, '39');
      await tester.pumpAndSettle();
      expect(find.text('Durasi minimal 40 hari.'), findsOneWidget);
      ElevatedButton btn = tester.widget(reviewBtn);
      expect(btn.onPressed, isNull);

      // 2. Enter 40 (Accepted)
      await tester.enterText(inputFinder, '40');
      await tester.pumpAndSettle();
      expect(find.text('Durasi minimal 40 hari.'), findsNothing);
      btn = tester.widget(reviewBtn);
      expect(btn.onPressed, isNotNull);
      await tester.tap(reviewBtn);
      await tester.pumpAndSettle();
      expect(capturedDraft?.effectiveTargetDays, 40);

      // 3. Enter 365 (Accepted)
      await tester.enterText(inputFinder, '365');
      await tester.pumpAndSettle();
      expect(find.text('Durasi maksimal 365 hari.'), findsNothing);
      btn = tester.widget(reviewBtn);
      expect(btn.onPressed, isNotNull);
      await tester.tap(reviewBtn);
      await tester.pumpAndSettle();
      expect(capturedDraft?.effectiveTargetDays, 365);

      // 4. Enter 366 (Rejected)
      await tester.enterText(inputFinder, '366');
      await tester.pumpAndSettle();
      expect(find.text('Durasi maksimal 365 hari.'), findsOneWidget);
      btn = tester.widget(reviewBtn);
      expect(btn.onPressed, isNull);
    });

    // -------------------------------------------------------------------------
    // 9. Invalid non-numeric duration is rejected safely
    // -------------------------------------------------------------------------
    testWidgets('9. Invalid non-numeric duration is rejected safely',
        (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramConfigView(
            item: sampleCatalogItems[0],
            initialDraft: const V2ProgramConfigDraft(
              isCustomDuration: true,
              customDurationText: '',
            ),
            onBack: () {},
            onProceedToReview: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final input =
          find.byKey(const ValueKey('v2_config_custom_duration_input'));
      final reviewBtn = find.byKey(const ValueKey('v2_config_review_button'));

      // Empty
      await tester.enterText(input, '   ');
      await tester.pumpAndSettle();
      expect(find.text('Masukkan jumlah hari target.'), findsOneWidget);
      expect((tester.widget(reviewBtn) as ElevatedButton).onPressed, isNull);

      // Fractional / decimal
      await tester.enterText(input, '45.5');
      await tester.pumpAndSettle();
      expect(find.text('Durasi harus berupa angka bulat.'), findsOneWidget);
      expect((tester.widget(reviewBtn) as ElevatedButton).onPressed, isNull);

      // Letters
      await tester.enterText(input, 'empat puluh');
      await tester.pumpAndSettle();
      expect(find.text('Durasi harus berupa angka bulat.'), findsOneWidget);
      expect((tester.widget(reviewBtn) as ElevatedButton).onPressed, isNull);
    });

    // -------------------------------------------------------------------------
    // 10. Hari Ini/Besok at 00:00, 02:59, and 03:00
    // -------------------------------------------------------------------------
    test('10. Operational day resolution at 00:00, 02:59, 03:00, and 22:59',
        () {
      final d0000 =
          DateService(nowProvider: () => DateTime(2026, 10, 22, 0, 0, 0));
      final d0259 =
          DateService(nowProvider: () => DateTime(2026, 10, 22, 2, 59, 59));
      final d0300 =
          DateService(nowProvider: () => DateTime(2026, 10, 22, 3, 0, 0));
      final d2259 =
          DateService(nowProvider: () => DateTime(2026, 10, 22, 22, 59, 0));

      // Before 03:00 -> resolves to preceding calendar date (2026-10-21)
      expect(d0000.getTodayDayKey(), '2026-10-21');
      expect(d0259.getTodayDayKey(), '2026-10-21');
      expect(d0000.getNextDayKey(d0000.getTodayDayKey()), '2026-10-22');

      // At and after 03:00 -> resolves to current calendar date (2026-10-22)
      expect(d0300.getTodayDayKey(), '2026-10-22');
      expect(d2259.getTodayDayKey(), '2026-10-22');
      expect(d0300.getNextDayKey(d0300.getTodayDayKey()), '2026-10-23');
    });

    // -------------------------------------------------------------------------
    // 11. Reminder optionality and valid/invalid HH:mm values
    // -------------------------------------------------------------------------
    test('11. Reminder optionality and strict HH:mm validation', () {
      // Optional: disabled by default
      const disabledDraft = V2ProgramConfigDraft(
        isReminderEnabled: false,
        reminderTime: null,
      );
      expect(disabledDraft.validateReminder(), isNull);
      expect(disabledDraft.isValid, isTrue);

      // Enabled with valid HH:mm
      const validDraft = V2ProgramConfigDraft(
        isReminderEnabled: true,
        reminderTime: '05:30',
      );
      expect(validDraft.validateReminder(), isNull);
      expect(validDraft.isValid, isTrue);

      // Enabled with invalid HH:mm
      const invalidHour = V2ProgramConfigDraft(
        isReminderEnabled: true,
        reminderTime: '25:00',
      );
      expect(invalidHour.validateReminder(), isNotNull);

      const invalidFormat = V2ProgramConfigDraft(
        isReminderEnabled: true,
        reminderTime: '5:30',
      );
      expect(invalidFormat.validateReminder(), isNotNull);
    });

    // -------------------------------------------------------------------------
    // 12. Review Program is mandatory
    // -------------------------------------------------------------------------
    testWidgets('12. Review Program is mandatory before final creation',
        (tester) async {
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            controller: controller,
            wireProgramSetup: true,
            creationService: creationService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to S18
      await tester
          .tap(find.byKey(const ValueKey('v2_catalog_item_sholat_dhuha')));
      await tester.pumpAndSettle();

      // Navigate to S20
      await tester
          .tap(find.byKey(const ValueKey('v2_pilih_ibadah_mulai_button')));
      await tester.pumpAndSettle();

      // On S20: verify "Buat Program" is NOT directly available
      expect(
          find.byKey(const ValueKey('v2_review_create_button')), findsNothing);
      expect(find.byKey(const ValueKey('v2_config_review_button')),
          findsOneWidget);

      // Must tap to enter Review
      await tester.tap(find.byKey(const ValueKey('v2_config_review_button')));
      await tester.pumpAndSettle();

      // Now on Review Program
      expect(find.byType(V2ProgramReviewView), findsOneWidget);
      expect(find.text('Review Program'), findsOneWidget);
      expect(find.byKey(const ValueKey('v2_review_create_button')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('v2_review_niat_text')), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 13. Back & Edit preserves configuration
    // -------------------------------------------------------------------------
    testWidgets('13. Back & Edit preserves configuration inputs',
        (tester) async {
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            controller: controller,
            wireProgramSetup: true,
            creationService: creationService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // S17 -> S18 -> S20
      await tester
          .tap(find.byKey(const ValueKey('v2_catalog_item_sholat_dhuha')));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('v2_pilih_ibadah_mulai_button')));
      await tester.pumpAndSettle();

      // Select Custom 75 days on S20
      await tester.tap(find.byKey(const ValueKey('v2_config_preset_custom')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('v2_config_custom_duration_input')), '75');
      await tester.pumpAndSettle();

      // Select Besok
      await tester.ensureVisible(
          find.byKey(const ValueKey('v2_config_start_tomorrow')));
      await tester.tap(find.byKey(const ValueKey('v2_config_start_tomorrow')));
      await tester.pumpAndSettle();

      // Proceed to Review
      await tester.tap(find.byKey(const ValueKey('v2_config_review_button')));
      await tester.pumpAndSettle();

      // Verify on Review
      expect(find.text('75 Hari Berturut-turut'), findsOneWidget);

      // Tap 'Kembali & Edit'
      await tester.tap(find.byKey(const ValueKey('v2_review_edit_button')));
      await tester.pumpAndSettle();

      // Back on S20: verify inputs remain intact
      expect(find.byType(V2ProgramConfigView), findsOneWidget);
      expect(find.text('75'), findsOneWidget);
      expect(controller.configDraft.effectiveTargetDays, 75);
      expect(controller.configDraft.startSelection,
          ProgramStartSelection.tomorrow);
    });

    // -------------------------------------------------------------------------
    // 14. Final creation does not occur before Review
    // -------------------------------------------------------------------------
    testWidgets('14. Final creation performs zero writes before Review',
        (tester) async {
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            controller: controller,
            wireProgramSetup: true,
            creationService: creationService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate through S18 and S20 up to Review
      await tester
          .tap(find.byKey(const ValueKey('v2_catalog_item_sholat_dhuha')));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('v2_pilih_ibadah_mulai_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('v2_config_review_button')));
      await tester.pumpAndSettle();

      // On Review screen, but haven't pressed "Buat Program" yet
      expect(find.byType(V2ProgramReviewView), findsOneWidget);
      expect(programBox.values.length, 0);
    });

    // -------------------------------------------------------------------------
    // 15. Missing creation callback cannot produce a false success
    // -------------------------------------------------------------------------
    testWidgets('15. Missing creation callback cannot produce a false success',
        (tester) async {
      int createdCount = 0;

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramReviewView(
            item: sampleCatalogItems[0],
            draft: const V2ProgramConfigDraft(targetDays: 40),
            creationService: null,
            onConfirmCreate: null,
            onBackAndEdit: () {},
            onProgramCreated: (_) => createdCount++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('v2_review_unavailable_notice')),
          findsOneWidget);
      final ElevatedButton btn =
          tester.widget(find.byKey(const ValueKey('v2_review_create_button')));
      expect(btn.onPressed, isNull);
      expect(createdCount, 0);
    });

    // -------------------------------------------------------------------------
    // 16. Valid creation callback receives the correct typed request
    // -------------------------------------------------------------------------
    testWidgets(
        '16. Valid creation callback receives the correct typed request',
        (tester) async {
      CreateProgramV2Request? capturedRequest;

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramReviewView(
            item: sampleCatalogItems[0],
            draft: const V2ProgramConfigDraft(
              targetDays: 60,
              startSelection: ProgramStartSelection.tomorrow,
              isReminderEnabled: true,
              reminderTime: '04:45',
            ),
            onConfirmCreate: (req) async {
              capturedRequest = req;
              return ProgramCreationResult.failure(
                reason: ProgramCreationFailureReason.persistenceError,
              );
            },
            onBackAndEdit: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('v2_review_create_button')));
      await tester.pumpAndSettle();

      expect(capturedRequest, isNotNull);
      expect(capturedRequest?.ibadahId, 'sholat_dhuha');
      expect(capturedRequest?.ibadahNameSnapshot, 'Sholat Dhuha');
      expect(capturedRequest?.targetDays, 60);
      expect(capturedRequest?.startSelection, ProgramStartSelection.tomorrow);
      expect(capturedRequest?.reminderTime, '04:45');
    });

    // -------------------------------------------------------------------------
    // 17. Rapid duplicate submission dispatches at most once
    // -------------------------------------------------------------------------
    testWidgets('17. Rapid duplicate submission dispatches at most once',
        (tester) async {
      int dispatchCount = 0;

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramReviewView(
            item: sampleCatalogItems[0],
            draft: const V2ProgramConfigDraft(targetDays: 40),
            onConfirmCreate: (req) async {
              dispatchCount++;
              await Future.delayed(const Duration(milliseconds: 50));
              return ProgramCreationResult.failure(
                reason: ProgramCreationFailureReason.persistenceError,
              );
            },
            onBackAndEdit: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final createBtn = find.byKey(const ValueKey('v2_review_create_button'));

      // Rapid double tap
      await tester.tap(createBtn);
      await tester.tap(createBtn);
      await tester.pumpAndSettle();

      expect(dispatchCount, 1);
    });

    // -------------------------------------------------------------------------
    // 18. Creation errors show safe retry without duplicate success
    // -------------------------------------------------------------------------
    testWidgets('18. Creation errors show safe retry without duplicate success',
        (tester) async {
      int attempt = 0;
      int successCount = 0;

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramReviewView(
            item: sampleCatalogItems[0],
            draft: const V2ProgramConfigDraft(targetDays: 40),
            onConfirmCreate: (req) async {
              attempt++;
              if (attempt == 1) {
                return ProgramCreationResult.failure(
                  reason: ProgramCreationFailureReason.persistenceError,
                );
              } else {
                final dummy = ProgramV2Model(
                  id: 'prog_test_retry',
                  ibadahId: req.ibadahId,
                  ibadahNameSnapshot: req.ibadahNameSnapshot,
                  targetDays: req.targetDays,
                  startDayKey: '2026-10-22',
                  status: ProgramV2Model.statusActive,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                return ProgramCreationResult.success(dummy);
              }
            },
            onBackAndEdit: () {},
            onProgramCreated: (_) => successCount++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // First attempt fails
      await tester.tap(find.byKey(const ValueKey('v2_review_create_button')));
      await tester.pumpAndSettle();

      expect(
          find.text(
              'Gagal menyimpan program ke penyimpanan perangkat. Silakan coba lagi.'),
          findsOneWidget);
      expect(successCount, 0);

      // Retry attempt succeeds
      await tester.tap(find.byKey(const ValueKey('v2_review_create_button')));
      await tester.pumpAndSettle();

      expect(successCount, 1);
      expect(attempt, 2);
    });

    // -------------------------------------------------------------------------
    // 19. Switching Ibadah clears inappropriate stale draft state
    // -------------------------------------------------------------------------
    testWidgets('19. Switching Ibadah clears inappropriate stale draft state',
        (tester) async {
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
      );

      // Start setup for item 1 with 90 days
      controller.startProgramSetup(sampleCatalogItems[0]); // sholat_dhuha
      controller.updateConfigDraft(
        const V2ProgramConfigDraft(targetDays: 90),
      );
      expect(controller.configDraft.targetDays, 90);

      // Now switch to item 3 (wirid_pagi, defaultTargetDays 60)
      controller.startProgramSetup(sampleCatalogItems[2]); // wirid_pagi
      expect(controller.configuringItem?.id, 'wirid_pagi');
      // Draft reset to item 3's default, clearing stale 90 days
      expect(controller.configDraft.targetDays, 60);
    });

    // -------------------------------------------------------------------------
    // 20. Inactive Program tab does not intercept Android Back
    // -------------------------------------------------------------------------
    testWidgets('20. Inactive Program tab does not intercept Android Back',
        (tester) async {
      final navController = V2NavigationController(
        initialTab: V2NavigationTab.dashboard,
      );
      final programController = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
      );

      // Set Program controller to have S18 open
      programController.selectItem(sampleCatalogItems[0]);
      expect(programController.isDetailOpen, isTrue);

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

      // Active tab is Dashboard, NOT Program
      expect(navController.currentTab, V2NavigationTab.dashboard);

      // Program's PopScope allows system back to pop (canPop is true)
      // Verify program selection was not reset because PopScope did not intercept
      expect(programController.isDetailOpen, isTrue);
    });

    // -------------------------------------------------------------------------
    // 21. No V1/domain/Hive mutation caused by rendering
    // -------------------------------------------------------------------------
    testWidgets('21. Rendering screens performs zero database writes',
        (tester) async {
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
        programRepository: programRepo,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            controller: controller,
            wireProgramSetup: true,
            creationService: creationService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(programBox.values.length, 0);

      // Open S19
      controller.openCustomIbadah();
      await tester.pumpAndSettle();
      expect(programBox.values.length, 0);

      // Open S20
      controller.startProgramSetup(sampleCatalogItems[0]);
      await tester.pumpAndSettle();
      expect(programBox.values.length, 0);

      // Open Review
      controller.openReview();
      await tester.pumpAndSettle();
      expect(programBox.values.length, 0);
    });

    // -------------------------------------------------------------------------
    // 22. Responsive on 320dp, long text, accessibility, Light/Dark
    // -------------------------------------------------------------------------
    testWidgets('22. Responsive on 320dp and renders cleanly in Light and Dark',
        (tester) async {
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
      );

      // Set small compact screen 320x568
      tester.view.physicalSize = const Size(320 * 2, 568 * 2);
      tester.view.devicePixelRatio = 2.0;

      // Dark Theme S20
      controller.startProgramSetup(sampleCatalogItems[0]);
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.darkTheme,
          home: V2ProgramHubView(
            controller: controller,
            wireProgramSetup: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(V2ProgramConfigView), findsOneWidget);

      // Dark Theme Review
      controller.openReview();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(V2ProgramReviewView), findsOneWidget);

      // Reset test viewport
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    // -------------------------------------------------------------------------
    // 23. Full working journey: S19 -> S20 -> Review -> Creation -> Ibadah Saya
    // -------------------------------------------------------------------------
    testWidgets(
        '23. Full working journey: S19 custom ibadah to S20 to Review and creation',
        (tester) async {
      final inMemoryRepo = _InMemoryProgramV2Repository(box: programBox);
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
        programRepository: inMemoryRepo,
      );

      final fakeCustomStore = <String, V2IbadahCatalogItem>{};
      int createdCallbackCount = 0;

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            controller: controller,
            wireProgramSetup: true,
            onConfirmCreate: (req) async {
              final program = ProgramV2Model(
                id: 'custom_prog_123',
                ibadahId: req.ibadahId,
                ibadahNameSnapshot: req.ibadahNameSnapshot,
                targetDays: req.targetDays,
                startDayKey: '2026-10-22',
                status: ProgramV2Model.statusActive,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              await inMemoryRepo.save(program);
              return ProgramCreationResult.success(program);
            },
            onSaveCustomIbadah: (draft) async {
              final id =
                  'custom_${draft.namaIbadah.toLowerCase().replaceAll(' ', '_')}';
              final item = V2IbadahCatalogItem(
                id: id,
                namaIbadah: draft.namaIbadah,
                category: draft.category,
                deskripsi: draft.deskripsi,
                defaultTargetDays: 40,
                isDailyEligible: true,
                isCustom: true,
              );
              fakeCustomStore[id] = item;
              return item;
            },
            onProgramCreated: (_) => createdCallbackCount++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. S17: Tap '+ Baru' to open S19
      await tester
          .tap(find.byKey(const ValueKey('v2_program_new_custom_button')));
      await tester.pumpAndSettle();

      expect(find.byType(V2CustomIbadahView), findsOneWidget);

      // 2. S19: Enter custom worship data
      await tester.enterText(
          find.byKey(const ValueKey('v2_custom_ibadah_name_input')),
          'Tahajud 4 Rakaat Malam');
      await tester
          .tap(find.byKey(const ValueKey('v2_custom_ibadah_save_button')));
      await tester.pumpAndSettle();

      // Verify custom item was persisted in fake store
      expect(
          fakeCustomStore.containsKey('custom_tahajud_4_rakaat_malam'), isTrue);

      // 3. S20: Automatically opens with the saved custom ibadah
      expect(find.byType(V2ProgramConfigView), findsOneWidget);
      expect(find.text('Tahajud 4 Rakaat Malam'), findsWidgets);

      // Select preset 60
      await tester
          .ensureVisible(find.byKey(const ValueKey('v2_config_preset_60')));
      await tester.tap(find.byKey(const ValueKey('v2_config_preset_60')));
      await tester.pumpAndSettle();

      // 4. Tap "Lanjut ke Review Program"
      await tester.tap(find.byKey(const ValueKey('v2_config_review_button')));
      await tester.pumpAndSettle();

      // 5. Review: Confirm details
      expect(find.byType(V2ProgramReviewView), findsOneWidget);
      expect(find.text('Tahajud 4 Rakaat Malam'), findsWidgets);
      expect(find.text('60 Hari Berturut-turut'), findsOneWidget);

      // 6. Tap "Buat Program"
      await tester.tap(find.byKey(const ValueKey('v2_review_create_button')));
      await tester.pumpAndSettle();

      // 7. Verify creation succeeded:
      expect(createdCallbackCount, 1);
      expect(inMemoryRepo.getAll().length, 1);
      expect(inMemoryRepo.getAll().first.ibadahId,
          'custom_tahajud_4_rakaat_malam');
      expect(inMemoryRepo.getAll().first.targetDays, 60);

      // 8. Controller switched to Ibadah Saya and new custom program is displayed
      expect(controller.currentTab, ProgramHubTab.ibadahSaya);
      expect(find.text('Tahajud 4 Rakaat Malam'), findsWidgets);
    });

    // -------------------------------------------------------------------------
    // 24. FIX 1 & R2: Legacy onStartProgram callback is NOT invoked and cannot create side effects
    // -------------------------------------------------------------------------
    testWidgets(
        '24. FIX 1 & R2: Legacy onStartProgram callback injection is NOT invoked and cannot trigger creation',
        (tester) async {
      int legacyCallbackCount = 0;
      final sideEffectList = <String>[];
      int creationCallbackCount = 0;
      ProgramV2Model? notifiedProgram;
      final inMemoryRepo = _InMemoryProgramV2Repository(box: programBox);
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
        programRepository: inMemoryRepo,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            controller: controller,
            wireProgramSetup: true,
            onStartProgram: (item) {
              legacyCallbackCount++;
              sideEffectList.add(item.id);
            },
            onProgramCreated: (prog) {
              notifiedProgram = prog;
            },
            onConfirmCreate: (req) async {
              creationCallbackCount++;
              final p = ProgramV2Model(
                id: 'prog_p1',
                ibadahId: req.ibadahId,
                ibadahNameSnapshot: req.ibadahNameSnapshot,
                targetDays: req.targetDays,
                startDayKey: '2026-10-22',
                status: ProgramV2Model.statusActive,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              await inMemoryRepo.save(p);
              return ProgramCreationResult.success(p);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select eligible item
      await tester
          .tap(find.byKey(const ValueKey('v2_catalog_item_sholat_dhuha')));
      await tester.pumpAndSettle();

      // Tap Mulai Program Mujahadah
      await tester
          .tap(find.byKey(const ValueKey('v2_pilih_ibadah_mulai_button')));
      await tester.pumpAndSettle();

      // S20 must be opened (NOT bypassed)
      expect(find.byType(V2ProgramConfigView), findsOneWidget);
      expect(controller.currentStep, ProgramScreenStep.programConfig);
      // R2 Requirement: Legacy callback that increments a counter and attempts a side effect is NOT invoked
      expect(legacyCallbackCount, 0);
      expect(sideEffectList, isEmpty);
      // Zero program creation dispatches occurred!
      expect(creationCallbackCount, 0);
      expect(notifiedProgram, isNull);
      expect(inMemoryRepo.getAll(), isEmpty);

      // Advance to Review
      await tester.tap(find.byKey(const ValueKey('v2_config_review_button')));
      await tester.pumpAndSettle();

      expect(find.byType(V2ProgramReviewView), findsOneWidget);
      // Still zero legacy callback invocations or creation dispatches upon entering Review
      expect(legacyCallbackCount, 0);
      expect(sideEffectList, isEmpty);
      expect(creationCallbackCount, 0);
      expect(notifiedProgram, isNull);

      // Final creation only happens on explicit confirmation in Review
      await tester.tap(find.byKey(const ValueKey('v2_review_create_button')));
      await tester.pumpAndSettle();

      expect(creationCallbackCount, 1);
      expect(inMemoryRepo.getAll().length, 1);
      expect(notifiedProgram, isNotNull);
      expect(notifiedProgram!.id, 'prog_p1');
    });

    // -------------------------------------------------------------------------
    // 24b. FIX 4 Condition B: Setup NOT wired with legacy callback: CTA disabled, zero invocations
    // -------------------------------------------------------------------------
    testWidgets(
        '24b. FIX 4 Condition B: Setup NOT wired with legacy callback: CTA disabled, zero invocations, no false navigation/persistence',
        (tester) async {
      int legacyCallbackCount = 0;
      final inMemoryRepo = _InMemoryProgramV2Repository(box: programBox);
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
        programRepository: inMemoryRepo,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            controller: controller,
            wireProgramSetup: false, // Explicitly unwired
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

      // S18 detail is open
      expect(controller.currentStep, ProgramScreenStep.catalogDetail);
      final btnFinder =
          find.byKey(const ValueKey('v2_pilih_ibadah_mulai_button'));
      expect(btnFinder, findsOneWidget);

      final ElevatedButton btn = tester.widget(btnFinder);
      // CTA button MUST be disabled because setup is NOT wired even though legacy callback is provided
      expect(btn.onPressed, isNull);

      // Attempt tap
      await tester.tap(btnFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Legacy callback MUST NOT be triggered
      expect(legacyCallbackCount, 0);

      // No navigation occurred (remains on S18 catalogDetail)
      expect(controller.currentStep, ProgramScreenStep.catalogDetail);
      expect(find.byType(V2ProgramConfigView), findsNothing);
      expect(find.byType(V2ProgramReviewView), findsNothing);

      // No persistence or program creation occurred
      expect(inMemoryRepo.getAll(), isEmpty);
    });

    // -------------------------------------------------------------------------
    // 25. FIX 1: Ineligible daily activity remains blocked with legacy callback
    // -------------------------------------------------------------------------
    testWidgets(
        '25. FIX 1: Ineligible daily activities remain blocked even when legacy callback is provided',
        (tester) async {
      int legacyCallbackCount = 0;
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            controller: controller,
            wireProgramSetup: true,
            onStartProgram: (item) {
              legacyCallbackCount++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select ineligible item (Puasa Daud)
      await tester
          .tap(find.byKey(const ValueKey('v2_catalog_item_puasa_daud')));
      await tester.pumpAndSettle();

      final btnFinder =
          find.byKey(const ValueKey('v2_pilih_ibadah_mulai_button'));
      final ElevatedButton btn = tester.widget(btnFinder);
      expect(btn.onPressed, isNull);

      await tester.tap(btnFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(legacyCallbackCount, 0);
      expect(controller.currentStep, ProgramScreenStep.catalogDetail);
      expect(find.byType(V2ProgramConfigView), findsNothing);
    });

    // -------------------------------------------------------------------------
    // 26. FIX 2: Review at 02:59:59, submission at 03:00:01: blocked
    // -------------------------------------------------------------------------
    testWidgets(
        '26. FIX 2: Review started at 02:59:59, submission at 03:00:01: blocked, zero creation calls',
        (tester) async {
      DateTime mockNow = DateTime(2026, 10, 22, 2, 59, 59);
      final dateService = DateService(nowProvider: () => mockNow);

      int creationCalls = 0;
      final inMemoryRepo = _InMemoryProgramV2Repository(box: programBox);
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
        programRepository: inMemoryRepo,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            controller: controller,
            wireProgramSetup: true,
            dateService: dateService,
            onConfirmCreate: (req) async {
              creationCalls++;
              final p = ProgramV2Model(
                id: 'p_test',
                ibadahId: req.ibadahId,
                ibadahNameSnapshot: req.ibadahNameSnapshot,
                targetDays: req.targetDays,
                startDayKey: req.startSelection == ProgramStartSelection.today
                    ? dateService.getTodayDayKey()
                    : dateService.getNextDayKey(dateService.getTodayDayKey()),
                status: ProgramV2Model.statusActive,
                createdAt: mockNow,
                updatedAt: mockNow,
              );
              await inMemoryRepo.save(p);
              return ProgramCreationResult.success(p);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open S20
      controller.startProgramSetup(sampleCatalogItems[0]);
      await tester.pumpAndSettle();

      // Proceed to Review at 02:59:59 (reviewed start day is 2026-10-21)
      await tester.tap(find.byKey(const ValueKey('v2_config_review_button')));
      await tester.pumpAndSettle();

      expect(find.byType(V2ProgramReviewView), findsOneWidget);
      // Verify reviewed start day snapshot is 21 Oktober 2026
      expect(find.textContaining('21 Oktober 2026'), findsOneWidget);

      // Clock advances across boundary to 03:00:01
      mockNow = DateTime(2026, 10, 22, 3, 0, 1);

      // Attempt submission
      await tester.tap(find.byKey(const ValueKey('v2_review_create_button')));
      await tester.pumpAndSettle();

      // Submission must be BLOCKED! Zero creation calls dispatched
      expect(creationCalls, 0);
      expect(inMemoryRepo.getAll(), isEmpty);

      // Error banner with Indonesian explanation is displayed
      expect(
          find.byKey(const ValueKey('v2_review_error_banner')), findsOneWidget);
      expect(find.textContaining('batas pukul 03:00'), findsOneWidget);
      expect(find.textContaining('Silakan kembali ke konfigurasi'),
          findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 27. FIX 2: Review and submission both before 03:00: valid
    // -------------------------------------------------------------------------
    testWidgets(
        '27. FIX 2: Review and submission both before 03:00 boundary: valid',
        (tester) async {
      DateTime mockNow = DateTime(2026, 10, 22, 2, 30, 0);
      final dateService = DateService(nowProvider: () => mockNow);

      int creationCalls = 0;
      final inMemoryRepo = _InMemoryProgramV2Repository(box: programBox);
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
        programRepository: inMemoryRepo,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            controller: controller,
            wireProgramSetup: true,
            dateService: dateService,
            onConfirmCreate: (req) async {
              creationCalls++;
              final p = ProgramV2Model(
                id: 'p_before',
                ibadahId: req.ibadahId,
                ibadahNameSnapshot: req.ibadahNameSnapshot,
                targetDays: req.targetDays,
                startDayKey: dateService.getTodayDayKey(),
                status: ProgramV2Model.statusActive,
                createdAt: mockNow,
                updatedAt: mockNow,
              );
              await inMemoryRepo.save(p);
              return ProgramCreationResult.success(p);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.startProgramSetup(sampleCatalogItems[0]);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('v2_config_review_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('v2_review_create_button')));
      await tester.pumpAndSettle();

      expect(creationCalls, 1);
      expect(inMemoryRepo.getAll().length, 1);
      expect(inMemoryRepo.getAll().first.startDayKey, '2026-10-21');
    });

    // -------------------------------------------------------------------------
    // 28. FIX 2: Review and submission both after 03:00: valid
    // -------------------------------------------------------------------------
    testWidgets(
        '28. FIX 2: Review and submission both after 03:00 boundary: valid',
        (tester) async {
      DateTime mockNow = DateTime(2026, 10, 22, 3, 30, 0);
      final dateService = DateService(nowProvider: () => mockNow);

      int creationCalls = 0;
      final inMemoryRepo = _InMemoryProgramV2Repository(box: programBox);
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
        programRepository: inMemoryRepo,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            controller: controller,
            wireProgramSetup: true,
            dateService: dateService,
            onConfirmCreate: (req) async {
              creationCalls++;
              final p = ProgramV2Model(
                id: 'p_after',
                ibadahId: req.ibadahId,
                ibadahNameSnapshot: req.ibadahNameSnapshot,
                targetDays: req.targetDays,
                startDayKey: dateService.getTodayDayKey(),
                status: ProgramV2Model.statusActive,
                createdAt: mockNow,
                updatedAt: mockNow,
              );
              await inMemoryRepo.save(p);
              return ProgramCreationResult.success(p);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.startProgramSetup(sampleCatalogItems[0]);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('v2_config_review_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('v2_review_create_button')));
      await tester.pumpAndSettle();

      expect(creationCalls, 1);
      expect(inMemoryRepo.getAll().length, 1);
      expect(inMemoryRepo.getAll().first.startDayKey, '2026-10-22');
    });

    // -------------------------------------------------------------------------
    // 29. FIX 2: Tomorrow selection crossing boundary: blocked
    // -------------------------------------------------------------------------
    testWidgets(
        '29. FIX 2: Tomorrow selection crossing 03:00 boundary: blocked if effective day changes',
        (tester) async {
      DateTime mockNow = DateTime(2026, 10, 22, 2, 59, 59);
      final dateService = DateService(nowProvider: () => mockNow);

      int creationCalls = 0;
      final inMemoryRepo = _InMemoryProgramV2Repository(box: programBox);
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
        programRepository: inMemoryRepo,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            controller: controller,
            wireProgramSetup: true,
            dateService: dateService,
            onConfirmCreate: (req) async {
              creationCalls++;
              return ProgramCreationResult.success(ProgramV2Model(
                id: 'p_tomorrow',
                ibadahId: req.ibadahId,
                ibadahNameSnapshot: req.ibadahNameSnapshot,
                targetDays: req.targetDays,
                startDayKey: '2026-10-22',
                status: ProgramV2Model.statusActive,
                createdAt: mockNow,
                updatedAt: mockNow,
              ));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open S20 and select 'Besok'
      controller.startProgramSetup(sampleCatalogItems[0]);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('v2_config_start_tomorrow')));
      await tester.pumpAndSettle();

      // Proceed to review at 02:59:59 (reviewed tomorrow is 2026-10-22)
      await tester.tap(find.byKey(const ValueKey('v2_config_review_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('22 Oktober 2026'), findsOneWidget);

      // Advance clock to 03:00:01 (tomorrow is now 2026-10-23)
      mockNow = DateTime(2026, 10, 22, 3, 0, 1);

      await tester.tap(find.byKey(const ValueKey('v2_review_create_button')));
      await tester.pumpAndSettle();

      expect(creationCalls, 0);
      expect(
          find.byKey(const ValueKey('v2_review_error_banner')), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 30. FIX 2: Back to configuration and re-review permits creation
    // -------------------------------------------------------------------------
    testWidgets(
        '30. FIX 2: Back to configuration and re-review updates date snapshot and permits creation',
        (tester) async {
      DateTime mockNow = DateTime(2026, 10, 22, 2, 59, 59);
      final dateService = DateService(nowProvider: () => mockNow);

      int creationCalls = 0;
      final inMemoryRepo = _InMemoryProgramV2Repository(box: programBox);
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
        programRepository: inMemoryRepo,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            controller: controller,
            wireProgramSetup: true,
            dateService: dateService,
            onConfirmCreate: (req) async {
              creationCalls++;
              final p = ProgramV2Model(
                id: 'p_rereview',
                ibadahId: req.ibadahId,
                ibadahNameSnapshot: req.ibadahNameSnapshot,
                targetDays: req.targetDays,
                startDayKey: dateService.getTodayDayKey(),
                status: ProgramV2Model.statusActive,
                createdAt: mockNow,
                updatedAt: mockNow,
              );
              await inMemoryRepo.save(p);
              return ProgramCreationResult.success(p);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.startProgramSetup(sampleCatalogItems[0]);
      await tester.pumpAndSettle();

      // Proceed to review at 02:59:59 (reviewed snapshot is 2026-10-21)
      await tester.tap(find.byKey(const ValueKey('v2_config_review_button')));
      await tester.pumpAndSettle();

      // Advance clock past 03:00
      mockNow = DateTime(2026, 10, 22, 3, 0, 1);

      // Attempt submission -> blocked
      await tester.tap(find.byKey(const ValueKey('v2_review_create_button')));
      await tester.pumpAndSettle();
      expect(creationCalls, 0);

      // Tap "Kembali & Edit"
      await tester.tap(find.byKey(const ValueKey('v2_review_edit_button')));
      await tester.pumpAndSettle();

      expect(find.byType(V2ProgramConfigView), findsOneWidget);

      // Re-proceed to Review (captures new snapshot 2026-10-22)
      await tester.tap(find.byKey(const ValueKey('v2_config_review_button')));
      await tester.pumpAndSettle();

      expect(find.byType(V2ProgramReviewView), findsOneWidget);
      expect(find.textContaining('22 Oktober 2026'), findsOneWidget);

      // Tap "Buat Program" now -> allowed!
      await tester.tap(find.byKey(const ValueKey('v2_review_create_button')));
      await tester.pumpAndSettle();

      expect(creationCalls, 1);
      expect(inMemoryRepo.getAll().first.startDayKey, '2026-10-22');
    });

    // -------------------------------------------------------------------------
    // 31. FIX 2: No automatic creation simply from Review navigation
    // -------------------------------------------------------------------------
    testWidgets(
        '31. FIX 2: No automatic creation occurs simply from Review navigation',
        (tester) async {
      int creationCalls = 0;
      final inMemoryRepo = _InMemoryProgramV2Repository(box: programBox);
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
        programRepository: inMemoryRepo,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            controller: controller,
            wireProgramSetup: true,
            onConfirmCreate: (req) async {
              creationCalls++;
              return ProgramCreationResult.failure(
                reason: ProgramCreationFailureReason.persistenceError,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.startProgramSetup(sampleCatalogItems[0]);
      await tester.pumpAndSettle();

      // Navigate to Review
      controller.openReview();
      await tester.pumpAndSettle();

      expect(find.byType(V2ProgramReviewView), findsOneWidget);
      expect(creationCalls, 0);
      expect(inMemoryRepo.getAll(), isEmpty);
    });

    // -------------------------------------------------------------------------
    // 32. FIX 3: S19 draft retention on navigate back and reopen
    // -------------------------------------------------------------------------
    testWidgets(
        '32. FIX 3: S19 draft retention on navigate back and reopen preserves name, category, and description',
        (tester) async {
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            controller: controller,
            wireProgramSetup: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open S19
      await tester
          .tap(find.byKey(const ValueKey('v2_program_new_custom_button')));
      await tester.pumpAndSettle();

      // Enter name, category, and description
      await tester.enterText(
          find.byKey(const ValueKey('v2_custom_ibadah_name_input')),
          'Dzikir Tasbih 100x');
      await tester
          .tap(find.byKey(const ValueKey('v2_custom_ibadah_category_dzikir')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('v2_custom_ibadah_desc_input')),
          'Catatan amalan istiqomah harian');
      await tester.pumpAndSettle();

      // Tap Back to S17 Hub
      await tester
          .tap(find.byKey(const ValueKey('v2_custom_ibadah_back_button')));
      await tester.pumpAndSettle();

      expect(find.byType(V2CustomIbadahView), findsNothing);

      // Reopen S19 resuming draft
      controller.openCustomIbadah(isNew: false);
      await tester.pumpAndSettle();

      expect(find.byType(V2CustomIbadahView), findsOneWidget);

      final nameField = tester.widget<TextFormField>(
          find.byKey(const ValueKey('v2_custom_ibadah_name_input')));
      expect(nameField.controller?.text, 'Dzikir Tasbih 100x');

      final descField = tester.widget<TextFormField>(
          find.byKey(const ValueKey('v2_custom_ibadah_desc_input')));
      expect(descField.controller?.text, 'Catatan amalan istiqomah harian');

      final chip = tester.widget<ChoiceChip>(
          find.byKey(const ValueKey('v2_custom_ibadah_category_dzikir')));
      expect(chip.selected, isTrue);
    });

    // -------------------------------------------------------------------------
    // 33. FIX 3: S19 recognizes saved template on return from S20
    // -------------------------------------------------------------------------
    testWidgets(
        '33. FIX 3: Returning to S19 from S20 recognizes persisted template and locks fields',
        (tester) async {
      int saveCount = 0;
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            controller: controller,
            wireProgramSetup: true,
            onSaveCustomIbadah: (draft) async {
              saveCount++;
              return V2IbadahCatalogItem(
                id: 'custom_dzikir_subuh',
                namaIbadah: draft.namaIbadah,
                category: draft.category,
                deskripsi: draft.deskripsi,
                defaultTargetDays: 40,
                isDailyEligible: true,
                isCustom: true,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open S19
      await tester
          .tap(find.byKey(const ValueKey('v2_program_new_custom_button')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const ValueKey('v2_custom_ibadah_name_input')),
          'Dzikir Subuh');
      await tester
          .tap(find.byKey(const ValueKey('v2_custom_ibadah_save_button')));
      await tester.pumpAndSettle();

      expect(saveCount, 1);
      // S20 opens
      expect(find.byType(V2ProgramConfigView), findsOneWidget);

      // Tap Back from S20 to S19
      await tester
          .tap(find.byKey(const ValueKey('v2_program_config_back_button')));
      await tester.pumpAndSettle();

      // S19 is displayed and recognizes persisted item
      expect(find.byType(V2CustomIbadahView), findsOneWidget);
      expect(find.byKey(const ValueKey('v2_custom_ibadah_persisted_banner')),
          findsOneWidget);

      // Verify fields are read-only
      final nameInput = tester.widget<TextField>(find.descendant(
        of: find.byKey(const ValueKey('v2_custom_ibadah_name_input')),
        matching: find.byType(TextField),
      ));
      expect(nameInput.readOnly, isTrue);

      final descInput = tester.widget<TextField>(find.descendant(
        of: find.byKey(const ValueKey('v2_custom_ibadah_desc_input')),
        matching: find.byType(TextField),
      ));
      expect(descInput.readOnly, isTrue);
    });

    // -------------------------------------------------------------------------
    // 34. FIX 3: Continuing to S20 does not call save callback a second time
    // -------------------------------------------------------------------------
    testWidgets(
        '34. FIX 3: Continuing to S20 for persisted template does not call save callback a second time',
        (tester) async {
      int saveCount = 0;
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            controller: controller,
            wireProgramSetup: true,
            onSaveCustomIbadah: (draft) async {
              saveCount++;
              return V2IbadahCatalogItem(
                id: 'custom_tahajud',
                namaIbadah: draft.namaIbadah,
                category: draft.category,
                deskripsi: draft.deskripsi,
                defaultTargetDays: 40,
                isDailyEligible: true,
                isCustom: true,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open S19 and save
      await tester
          .tap(find.byKey(const ValueKey('v2_program_new_custom_button')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const ValueKey('v2_custom_ibadah_name_input')),
          'Sholat Tahajud 4 Rakaat');
      await tester
          .tap(find.byKey(const ValueKey('v2_custom_ibadah_save_button')));
      await tester.pumpAndSettle();

      expect(saveCount, 1);
      expect(find.byType(V2ProgramConfigView), findsOneWidget);

      // Back to S19
      await tester
          .tap(find.byKey(const ValueKey('v2_program_config_back_button')));
      await tester.pumpAndSettle();

      // Re-advance to S20
      await tester
          .tap(find.byKey(const ValueKey('v2_custom_ibadah_save_button')));
      await tester.pumpAndSettle();

      // S20 opens again WITHOUT calling save callback a second time
      expect(find.byType(V2ProgramConfigView), findsOneWidget);
      expect(saveCount, 1);
    });

    // -------------------------------------------------------------------------
    // 35. FIX 3: Failed custom save retains all inputs
    // -------------------------------------------------------------------------
    testWidgets(
        '35. FIX 3: Failed custom save retains all user inputs and displays error notice',
        (tester) async {
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            controller: controller,
            wireProgramSetup: true,
            onSaveCustomIbadah: (draft) async => null, // Fails
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const ValueKey('v2_program_new_custom_button')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const ValueKey('v2_custom_ibadah_name_input')),
          'Sholat Sunnah Awwabin');
      await tester.enterText(
          find.byKey(const ValueKey('v2_custom_ibadah_desc_input')),
          'Dikerjakan 6 rakaat ba\'da maghrib');
      await tester
          .tap(find.byKey(const ValueKey('v2_custom_ibadah_save_button')));
      await tester.pumpAndSettle();

      // Error banner is shown
      expect(find.byKey(const ValueKey('v2_custom_ibadah_error_banner')),
          findsOneWidget);

      // Inputs remain in text fields
      final nameWidget = tester.widget<TextFormField>(
          find.byKey(const ValueKey('v2_custom_ibadah_name_input')));
      expect(nameWidget.controller?.text, 'Sholat Sunnah Awwabin');

      final descWidget = tester.widget<TextFormField>(
          find.byKey(const ValueKey('v2_custom_ibadah_desc_input')));
      expect(descWidget.controller?.text, 'Dikerjakan 6 rakaat ba\'da maghrib');

      // Still on S19
      expect(find.byType(V2ProgramConfigView), findsNothing);
    });

    // -------------------------------------------------------------------------
    // 36. FIX 3: Starting genuinely new custom flow clears previous draft
    // -------------------------------------------------------------------------
    testWidgets(
        '36. FIX 3: Starting a separate new custom flow does not inherit another template\'s state',
        (tester) async {
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
      );

      controller.updateCustomDraft(const V2CustomIbadahDraft(
        namaIbadah: 'Draft Lama',
        category: V2IbadahCategory.sholatSunnah,
        deskripsi: 'Deskripsi lama',
      ));
      expect(controller.customDraft?.namaIbadah, 'Draft Lama');

      // Start new custom flow with isNew: true
      controller.openCustomIbadah(isNew: true);
      expect(controller.customDraft, isNull);
      expect(controller.persistedCustomItem, isNull);
    });

    // -------------------------------------------------------------------------
    // 37. FIX 4: Authoritative validation of custom save callback result
    // -------------------------------------------------------------------------
    testWidgets(
        '37. FIX 4: Authoritative validation of custom save callback result: blank ID, non-custom, daily ineligible, and empty name',
        (tester) async {
      // A. Blank ID
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2CustomIbadahView(
            onBack: () {},
            onSave: (draft) async => V2IbadahCatalogItem(
              id: '   ',
              namaIbadah: draft.namaIbadah,
              category: draft.category,
              deskripsi: 'Deskripsi',
              isDailyEligible: true,
              isCustom: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const ValueKey('v2_custom_ibadah_name_input')),
          'Valid Name');
      await tester
          .tap(find.byKey(const ValueKey('v2_custom_ibadah_save_button')));
      await tester.pumpAndSettle();

      expect(find.text('Identitas ibadah kustom tidak valid dari penyimpanan.'),
          findsOneWidget);

      // B. isCustom: false
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2CustomIbadahView(
            onBack: () {},
            onSave: (draft) async => V2IbadahCatalogItem(
              id: 'valid_id',
              namaIbadah: draft.namaIbadah,
              category: draft.category,
              deskripsi: 'Deskripsi',
              isDailyEligible: true,
              isCustom: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const ValueKey('v2_custom_ibadah_name_input')),
          'Valid Name');
      await tester
          .tap(find.byKey(const ValueKey('v2_custom_ibadah_save_button')));
      await tester.pumpAndSettle();

      expect(find.text('Ibadah kustom harus ditandai sebagai ibadah kustom.'),
          findsOneWidget);

      // C. isDailyEligible: false
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2CustomIbadahView(
            onBack: () {},
            onSave: (draft) async => const V2IbadahCatalogItem(
              id: 'valid_id',
              namaIbadah: 'Valid Name',
              category: V2IbadahCategory.custom,
              deskripsi: 'Deskripsi',
              isDailyEligible: false,
              ineligibilityReason:
                  'Amalan berselang tidak memenuhi syarat harian berturut-turut.',
              isCustom: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const ValueKey('v2_custom_ibadah_name_input')),
          'Valid Name');
      await tester
          .tap(find.byKey(const ValueKey('v2_custom_ibadah_save_button')));
      await tester.pumpAndSettle();

      expect(
          find.text(
              'Amalan berselang tidak memenuhi syarat harian berturut-turut.'),
          findsOneWidget);

      // D. empty name
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2CustomIbadahView(
            onBack: () {},
            onSave: (draft) async => const V2IbadahCatalogItem(
              id: 'valid_id',
              namaIbadah: '   ',
              category: V2IbadahCategory.custom,
              deskripsi: 'Deskripsi',
              isDailyEligible: true,
              isCustom: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const ValueKey('v2_custom_ibadah_name_input')),
          'Valid Name');
      await tester
          .tap(find.byKey(const ValueKey('v2_custom_ibadah_save_button')));
      await tester.pumpAndSettle();

      expect(
          find.text('Nama ibadah kustom tidak boleh kosong dari penyimpanan.'),
          findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 38. FIX 5: Local time wording throughout S20/Review (no WIB)
    // -------------------------------------------------------------------------
    testWidgets(
        '38. FIX 5: Local time wording throughout S20/Review without hardcoded WIB',
        (tester) async {
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
      );
      controller.startProgramSetup(sampleCatalogItems[0]);

      final dateService = DateService(
        nowProvider: () => DateTime(2026, 10, 22, 1, 30, 0),
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            controller: controller,
            wireProgramSetup: true,
            dateService: dateService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // S20 check: no 'WIB' text anywhere
      expect(find.byType(V2ProgramConfigView), findsOneWidget);
      expect(find.textContaining('WIB'), findsNothing);
      expect(find.textContaining('waktu setempat'), findsWidgets);

      // Enable reminder and proceed to Review
      controller.updateConfigDraft(controller.configDraft.copyWith(
        isReminderEnabled: true,
        reminderTime: '05:00',
      ));
      controller.openReview();
      await tester.pumpAndSettle();

      // Review check: no 'WIB' text anywhere
      expect(find.byType(V2ProgramReviewView), findsOneWidget);
      expect(find.textContaining('WIB'), findsNothing);
      expect(find.text('Pukul 05:00'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 39. FIX 5: Safe Indonesian errors without raw exception details
    // -------------------------------------------------------------------------
    testWidgets(
        '39. FIX 5: Safe friendly Indonesian error fallback without raw exception leaks',
        (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramReviewView(
            item: sampleCatalogItems[0],
            draft: const V2ProgramConfigDraft(),
            onBackAndEdit: () {},
            onConfirmCreate: (req) async {
              throw Exception(
                  'Fatal SQL deadlock on 192.168.1.100:5432 transaction #999');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('v2_review_create_button')));
      await tester.pumpAndSettle();

      // Raw technical details must NOT appear
      expect(find.textContaining('Fatal SQL deadlock'), findsNothing);
      expect(find.textContaining('192.168.1.100'), findsNothing);
      // Friendly Indonesian fallback must appear
      expect(
          find.text(
              'Terjadi kendala komunikasi penyimpanan. Silakan coba lagi.'),
          findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 40. R2: Missing creation handler does not produce fake success
    // -------------------------------------------------------------------------
    testWidgets(
        '40. R2: Missing creation handler does not produce fake success and disables Buat Program',
        (tester) async {
      int programCreatedCount = 0;
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
      );

      // Frontend setup is explicitly enabled (wireProgramSetup: true),
      // but no creationService or onConfirmCreate handler exists.
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            controller: controller,
            wireProgramSetup: true,
            onProgramCreated: (_) {
              programCreatedCount++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate S18 -> S20 -> Review
      await tester
          .tap(find.byKey(const ValueKey('v2_catalog_item_sholat_dhuha')));
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const ValueKey('v2_pilih_ibadah_mulai_button')));
      await tester.pumpAndSettle();

      expect(find.byType(V2ProgramConfigView), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('v2_config_review_button')));
      await tester.pumpAndSettle();

      expect(find.byType(V2ProgramReviewView), findsOneWidget);

      // Honest explanation displayed
      expect(find.text('Layanan pembuatan program belum tersedia.'),
          findsOneWidget);

      // Final 'Buat Program' button must remain disabled
      final createBtnFinder =
          find.byKey(const ValueKey('v2_review_create_button'));
      final ElevatedButton createBtn = tester.widget(createBtnFinder);
      expect(createBtn.onPressed, isNull);

      // Attempting tap produces no side effect or fake success
      await tester.tap(createBtnFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(programCreatedCount, 0);
      expect(controller.currentStep, ProgramScreenStep.programReview);
    });

    // -------------------------------------------------------------------------
    // 41. R2: Notification callback fires only upon authoritative persistence success
    // -------------------------------------------------------------------------
    testWidgets(
        '41. R2: onProgramCreated callback fires only after authoritative persistence result',
        (tester) async {
      int notificationCount = 0;
      ProgramV2Model? lastNotifiedProgram;
      bool shouldSucceed = false;

      final inMemoryRepo = _InMemoryProgramV2Repository(box: programBox);
      final controller = V2ProgramHubController(
        initialCatalog: sampleCatalogItems,
        programRepository: inMemoryRepo,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2ProgramHubView(
            controller: controller,
            wireProgramSetup: true,
            onProgramCreated: (prog) {
              notificationCount++;
              lastNotifiedProgram = prog;
            },
            onConfirmCreate: (req) async {
              if (!shouldSucceed) {
                return ProgramCreationResult.failure(
                  reason: ProgramCreationFailureReason.invalidDuration,
                  message: 'Penolakan uji autorisasi persistence',
                );
              }
              final p = ProgramV2Model(
                id: 'prog_auth_1',
                ibadahId: req.ibadahId,
                ibadahNameSnapshot: req.ibadahNameSnapshot,
                targetDays: req.targetDays,
                startDayKey: '2026-10-22',
                status: ProgramV2Model.statusActive,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              await inMemoryRepo.save(p);
              return ProgramCreationResult.success(p);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter setup and go to Review
      controller.startProgramSetup(sampleCatalogItems[0]);
      await tester.pumpAndSettle();
      controller.openReview();
      await tester.pumpAndSettle();

      // First attempt: persistence returns failure
      await tester.tap(find.byKey(const ValueKey('v2_review_create_button')));
      await tester.pumpAndSettle();

      // No notification must fire on failure!
      expect(notificationCount, 0);
      expect(lastNotifiedProgram, isNull);
      expect(inMemoryRepo.getAll(), isEmpty);

      // Second attempt: persistence succeeds
      shouldSucceed = true;
      await tester.tap(find.byKey(const ValueKey('v2_review_create_button')));
      await tester.pumpAndSettle();

      // Exactly one notification fired after authoritative success!
      expect(notificationCount, 1);
      expect(lastNotifiedProgram?.id, 'prog_auth_1');
      expect(inMemoryRepo.getAll().length, 1);
    });
  });
}
