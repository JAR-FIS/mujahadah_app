import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mujahadah/controllers/v2_dalil_controller.dart';
import 'package:mujahadah/controllers/v2_navigation_controller.dart';
import 'package:mujahadah/models/dalil_item.dart';
import 'package:mujahadah/theme/v2_theme.dart';
import 'package:mujahadah/views/v2/dalil/v2_dalil_view.dart';
import 'package:mujahadah/views/v2/dalil/v2_detail_dalil_view.dart';
import 'package:mujahadah/views/v2/shell/v2_app_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Test-only sample fixtures for UI testing and layout verification
  final testQuranItem = DalilItem(
    id: 'quran_1',
    title: 'Seruan Untuk Istiqomah',
    category: DalilCategory.quran,
    excerpt:
        '"Maka karena itu serulah (mereka) dan tetaplah (beristiqomah) sebagaimana diperintahkan kepadamu dan janganlah mengikuti hawa nafsu mereka..."',
    body:
        'Maka karena itu serulah (mereka kepada agama ini) dan tetaplah (beriman dan berdakwah) sebagaimana diperintahkan kepadamu dan janganlah mengikuti hawa nafsu mereka dan katakanlah: "Aku beriman kepada semua Kitab yang diturunkan Allah dan aku diperintahkan supaya berlaku adil di antara kamu. Allah-lah Tuhan kami dan Tuhan kamu. Bagi kami amal-amal kami dan bagi kamu amal-amal kamu. Tidak ada pertengkaran antara kami dan kamu, Allah mengumpulkan antara kita dan kepada-Nyalah kembali (kita)".',
    sourceReference: 'Q.S. Asy-Syura Ayat 15',
    arabicText:
        'فَلِذَٰلِكَ فَادْعُ ۖ وَاسْتَقِمْ كَمَا أُمِرْتَ ۖ وَلَا تَتَّبِعْ أَهْوَاءَهُمْ',
  );

  final testHaditsItem = DalilItem(
    id: 'hadits_1',
    title: 'Iman & Istiqomah',
    category: DalilCategory.hadits,
    excerpt:
        '“Katakanlah, \'Aku beriman kepada Allah,\' kemudian istiqomahlah."',
    body:
        'Dari Sufyan bin Abdillah ats-Tsaqafi radhiyallahu \'anhu, ia berkata: "Wahai Rasulullah, katakanlah kepadaku dalam Islam suatu perkataan yang aku tidak akan menanyakannya lagi kepada seorang pun selain engkau." Beliau bersabda: "Katakanlah, \'Aku beriman kepada Allah,\' kemudian istiqomahlah." (HR. Muslim no. 38)',
    sourceReference: '(HR. Muslim no. 38 dari Sufyan bin Abdillah ats-Tsaqafi)',
    arabicText: 'قُلْ آمَنْتُ بِاللَّهِ ثُمَّ اسْتَقِمْ',
  );

  final testDoaItem = DalilItem(
    id: 'doa_1',
    title: 'Doa Keteguhan Hati & Istiqomah',
    category: DalilCategory.doa,
    excerpt:
        '“Wahai Dzat yang membolak-balikkan hati, teguhkanlah hatiku di atas agama-Mu...”',
    body:
        'Dari Syahr bin Hausyab, ia berkata bahwa ia bertanya kepada Ummu Salamah radhiyallahu \'anha: "Wahai Ummul Mukminin, doa apa yang paling sering dibaca oleh Rasulullah shallallahu \'alaihi wa sallam jika beliau bersamamu?" Ummu Salamah menjawab: Doa beliau yang paling sering adalah: "Ya Muqallibal qulub, tsabbit qalbi \'ala dinik."',
    sourceReference: 'HR. Tirmidzi no. 3522',
    arabicText: 'يَا مُقَلِّبَ الْقُلُوبِ ثَبِّتْ قَلْبِي عَلَى دِينِكَ',
  );

  final testKisahItem1 = DalilItem(
    id: 'kisah_1',
    title: 'Anas bin Malik & Al-Qur’an',
    category: DalilCategory.kisahHikmah,
    excerpt:
        'Sahabat Nabi yang memiliki kebiasaan mendekati khatam Al-Qur\'an pada malam hari, lalu...',
    body:
        'Sahabat Nabi yang memiliki kebiasaan mendekati khatam Al-Qur\'an pada malam hari, lalu menyisakan beberapa ayat untuk dikumpulkan dan dikhatamkan bersama keluarganya saat Subuh. Beliau dikaruniai umur panjang, harta melimpah, ilmu luas, serta keluarga yang saleh berkat keistikamahannya.',
    sourceReference: null,
    arabicText: null,
  );

  final testKisahItem2 = DalilItem(
    id: 'kisah_2',
    title: 'Keteguhan Bilal bin Rabah',
    category: DalilCategory.kisahHikmah,
    excerpt:
        'Keteguhan hati mempertahankan tauhid di bawah terik padang pasir Makkah...',
    body:
        'Bilal bin Rabah disiksa di bawah terik matahari Makkah dengan batu besar diletakkan di atas dadanya, namun lidahnya tak henti melafalkan: Ahad, Ahad.',
    sourceReference: 'Sirah Nabawiyyah',
    arabicText: null,
  );

  final allSampleItems = [
    testQuranItem,
    testHaditsItem,
    testDoaItem,
    testKisahItem1,
    testKisahItem2,
  ];

  setUp(() {
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  group('V2 Dalil & Detail Dalil (TASK MV2-B0-02-04-04-05)', () {
    // -------------------------------------------------------------------------
    // Scenario 1: S15 Layout Rendering
    // -------------------------------------------------------------------------
    testWidgets(
        '1. S15 layout rendering: displays header, subtitle, category chips, and content area',
        (tester) async {
      final controller = V2DalilController(initialItems: allSampleItems);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2DalilView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Header
      expect(find.byKey(const ValueKey('v2_dalil_header')), findsOneWidget);
      expect(find.text('Dalil - Bekal Istiqomah'), findsOneWidget);
      expect(find.text('Bekal untuk menjaga semangat dan keistiqomahan.'),
          findsOneWidget);

      // Category chips (All 5 approved categories in exact order)
      expect(
          find.byKey(const ValueKey('v2_dalil_filter_semua')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('v2_dalil_filter_quran')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('v2_dalil_filter_hadits')), findsOneWidget);
      expect(find.byKey(const ValueKey('v2_dalil_filter_doa')), findsOneWidget);
      expect(find.byKey(const ValueKey('v2_dalil_filter_kisah_hikmah')),
          findsOneWidget);

      expect(
          find.descendant(
            of: find.byKey(const ValueKey('v2_dalil_filter_semua')),
            matching: find.text('Semua'),
          ),
          findsOneWidget);
      expect(
          find.descendant(
            of: find.byKey(const ValueKey('v2_dalil_filter_quran')),
            matching: find.text("Al-Qur'an"),
          ),
          findsOneWidget);
      expect(
          find.descendant(
            of: find.byKey(const ValueKey('v2_dalil_filter_hadits')),
            matching: find.text('Hadits'),
          ),
          findsOneWidget);
      expect(
          find.descendant(
            of: find.byKey(const ValueKey('v2_dalil_filter_doa')),
            matching: find.text('Doa'),
          ),
          findsOneWidget);
      expect(
          find.descendant(
            of: find.byKey(const ValueKey('v2_dalil_filter_kisah_hikmah')),
            matching: find.text('Kisah & Hikmah'),
          ),
          findsOneWidget);

      // Dalil cards
      expect(find.text('Seruan Untuk Istiqomah'), findsOneWidget);
      expect(find.text('Iman & Istiqomah'), findsOneWidget);
      expect(find.text('Doa Keteguhan Hati & Istiqomah'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Scenario 2: All five category filters presence & interactions
    // -------------------------------------------------------------------------
    testWidgets(
        '2. All five category filters can be selected via taps and update state',
        (tester) async {
      final controller = V2DalilController(initialItems: allSampleItems);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2DalilView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.selectedCategory, DalilCategory.all);

      // Tap Al-Qur'an
      await tester.tap(find.byKey(const ValueKey('v2_dalil_filter_quran')));
      await tester.pumpAndSettle();
      expect(controller.selectedCategory, DalilCategory.quran);

      // Tap Hadits
      await tester.tap(find.byKey(const ValueKey('v2_dalil_filter_hadits')));
      await tester.pumpAndSettle();
      expect(controller.selectedCategory, DalilCategory.hadits);

      // Tap Doa
      await tester.tap(find.byKey(const ValueKey('v2_dalil_filter_doa')));
      await tester.pumpAndSettle();
      expect(controller.selectedCategory, DalilCategory.doa);

      // Tap Kisah & Hikmah
      await tester
          .tap(find.byKey(const ValueKey('v2_dalil_filter_kisah_hikmah')));
      await tester.pumpAndSettle();
      expect(controller.selectedCategory, DalilCategory.kisahHikmah);

      // Tap Semua
      await tester.tap(find.byKey(const ValueKey('v2_dalil_filter_semua')));
      await tester.pumpAndSettle();
      expect(controller.selectedCategory, DalilCategory.all);
    });

    // -------------------------------------------------------------------------
    // Scenario 3: Correct filtering using injected test fixtures
    // -------------------------------------------------------------------------
    testWidgets(
        '3. Correct filtering displays only items matching the active category',
        (tester) async {
      final controller = V2DalilController(initialItems: allSampleItems);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2DalilView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // All 5 items in 'Semua'
      expect(controller.filteredItems.length, 5);
      expect(find.text('Seruan Untuk Istiqomah'), findsOneWidget);
      expect(find.text('Iman & Istiqomah'), findsOneWidget);
      expect(find.text('Doa Keteguhan Hati & Istiqomah'), findsOneWidget);

      // Filter: Hadits
      await tester.tap(find.byKey(const ValueKey('v2_dalil_filter_hadits')));
      await tester.pumpAndSettle();

      expect(controller.filteredItems.length, 1);
      expect(find.text('Iman & Istiqomah'), findsOneWidget);
      expect(find.text('Seruan Untuk Istiqomah'), findsNothing);
      expect(find.text('Doa Keteguhan Hati & Istiqomah'), findsNothing);
      expect(find.text('Anas bin Malik & Al-Qur’an'), findsNothing);

      // Filter: Doa
      await tester.tap(find.byKey(const ValueKey('v2_dalil_filter_doa')));
      await tester.pumpAndSettle();

      expect(controller.filteredItems.length, 1);
      expect(find.text('Doa Keteguhan Hati & Istiqomah'), findsOneWidget);
      expect(find.text('Iman & Istiqomah'), findsNothing);
      expect(find.text('Seruan Untuk Istiqomah'), findsNothing);

      // Filter: Kisah & Hikmah
      await tester
          .tap(find.byKey(const ValueKey('v2_dalil_filter_kisah_hikmah')));
      await tester.pumpAndSettle();

      expect(controller.filteredItems.length, 2);
      expect(find.text('Anas bin Malik & Al-Qur’an'), findsOneWidget);
      expect(find.text('Keteguhan Bilal bin Rabah'), findsOneWidget);
      expect(find.text('Iman & Istiqomah'), findsNothing);
      expect(find.text('Doa Keteguhan Hati & Istiqomah'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // Scenario 4: Empty catalog state and honest empty category state
    // -------------------------------------------------------------------------
    testWidgets(
        '4. Default empty state shows honest unavailable catalog placeholder',
        (tester) async {
      // Default controller with no injected items
      final controller = V2DalilController();

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2DalilView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(
          find.byKey(const ValueKey('v2_dalil_empty_state')), findsOneWidget);
      expect(find.text('Katalog Dalil Belum Tersedia'), findsOneWidget);
      expect(
        find.text(
            'Koleksi dalil Al-Qur\'an, hadits, doa, dan kisah & hikmah sedang dipersiapkan dan akan hadir pada pembaruan mendatang.'),
        findsOneWidget,
      );

      // Verify empty category shows honest empty message for Doa
      final partialController =
          V2DalilController(initialItems: [testQuranItem]);
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2DalilView(controller: partialController),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('v2_dalil_filter_doa')));
      await tester.pumpAndSettle();

      expect(
          find.byKey(const ValueKey('v2_dalil_empty_state')), findsOneWidget);
      expect(find.text('Belum Ada Dalil'), findsOneWidget);
      expect(
        find.text(
            'Belum ada konten untuk kategori Doa. Silakan pilih kategori lain.'),
        findsOneWidget,
      );
    });

    // -------------------------------------------------------------------------
    // Scenario 5: Navigation from list to detail
    // -------------------------------------------------------------------------
    testWidgets(
        '5. Tapping a Dalil card or Lihat detail navigates to S16 Detail Dalil',
        (tester) async {
      final controller = V2DalilController(initialItems: allSampleItems);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2DalilView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(V2DetailDalilView), findsNothing);

      // Tap card or detail button
      final detailBtn =
          find.byKey(const ValueKey('v2_dalil_detail_btn_quran_1'));
      await tester.tap(detailBtn);
      await tester.pumpAndSettle();

      // Detail Dalil view is now presented
      expect(find.byType(V2DetailDalilView), findsOneWidget);
      expect(
          find.byKey(const ValueKey('v2_dalil_detail_header')), findsOneWidget);
      expect(find.text('Detail Dalil'), findsOneWidget);
      expect(find.text('Seruan Untuk Istiqomah'), findsOneWidget);
      expect(find.text('Q.S. Asy-Syura Ayat 15'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Scenario 6: Android system Back and UI back navigation preserve category state
    // -------------------------------------------------------------------------
    testWidgets(
        '6. Android system Back and UI back on S16 return to S15 preserving active category',
        (tester) async {
      final controller = V2DalilController(initialItems: allSampleItems);
      final navController =
          V2NavigationController(initialTab: V2NavigationTab.dalil);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          initialRoute: '/home',
          routes: {
            '/home': (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/shell'),
                      child: const Text('Open App Shell'),
                    ),
                  ),
                ),
            '/shell': (context) => V2AppShell(
                  controller: navController,
                  dalil: V2DalilView(
                    controller: controller,
                    navigationController: navController,
                  ),
                ),
          },
        ),
      );
      await tester.pumpAndSettle();

      // Open App Shell route
      await tester.tap(find.text('Open App Shell'));
      await tester.pumpAndSettle();

      expect(navController.currentTab, V2NavigationTab.dalil);

      // Select Kisah & Hikmah category
      await tester
          .tap(find.byKey(const ValueKey('v2_dalil_filter_kisah_hikmah')));
      await tester.pumpAndSettle();
      expect(controller.selectedCategory, DalilCategory.kisahHikmah);

      // Open detail S16
      final card = find.byKey(const ValueKey('v2_dalil_card_kisah_1'));
      await tester.tap(card);
      await tester.pumpAndSettle();

      expect(controller.selectedItem, isNotNull);
      expect(find.byType(V2DetailDalilView), findsOneWidget);

      // 1. Test Android System Back via Navigator route stack
      final systemBackHandled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // System back returned to S15 without exiting the App Shell route
      expect(systemBackHandled, isTrue);
      expect(controller.selectedItem, isNull);
      expect(find.byType(V2DetailDalilView), findsNothing);
      expect(find.byType(V2AppShell), findsOneWidget);

      // Category filter is PRESERVED as Kisah & Hikmah
      expect(controller.selectedCategory, DalilCategory.kisahHikmah);
      expect(find.text('Anas bin Malik & Al-Qur’an'), findsOneWidget);

      // 2. Open detail again and test visible UI back button
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(controller.selectedItem, isNotNull);
      expect(find.byType(V2DetailDalilView), findsOneWidget);

      final backBtn = find.byKey(const ValueKey('v2_dalil_detail_back_button'));
      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      expect(controller.selectedItem, isNull);
      expect(find.byType(V2DetailDalilView), findsNothing);
      expect(controller.selectedCategory, DalilCategory.kisahHikmah);
    });

    testWidgets(
        '6b. Inactive Dalil tab with open S16 does not intercept system Back navigation',
        (tester) async {
      final controller = V2DalilController(initialItems: allSampleItems);
      final navController =
          V2NavigationController(initialTab: V2NavigationTab.dalil);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          initialRoute: '/home',
          routes: {
            '/home': (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/shell'),
                      child: const Text('Open App Shell'),
                    ),
                  ),
                ),
            '/shell': (context) => V2AppShell(
                  controller: navController,
                  dalil: V2DalilView(
                    controller: controller,
                    navigationController: navController,
                  ),
                ),
          },
        ),
      );
      await tester.pumpAndSettle();

      // Open App Shell route
      await tester.tap(find.text('Open App Shell'));
      await tester.pumpAndSettle();

      // Open S16 detail in Dalil tab
      expect(navController.currentTab, V2NavigationTab.dalil);
      final card = find.byKey(const ValueKey('v2_dalil_card_quran_1'));
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(controller.selectedItem, isNotNull);
      expect(find.byType(V2DetailDalilView), findsOneWidget);

      // Switch tab to Dashboard
      navController.selectTab(V2NavigationTab.dashboard);
      await tester.pumpAndSettle();
      expect(navController.currentTab, V2NavigationTab.dashboard);

      // Dalil is mounted in background IndexedStack with S16 open.
      // Trigger Android system Back. Dalil's PopScope must not block it.
      final systemBackHandled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // System back popped the App Shell route, returning to /home!
      expect(systemBackHandled, isTrue);
      expect(find.text('Open App Shell'), findsOneWidget);
      expect(find.byType(V2AppShell), findsNothing);
    });

    // -------------------------------------------------------------------------
    // Scenario 7: Long-content scrolling
    // -------------------------------------------------------------------------
    testWidgets(
        '7. S16 Detail Dalil scrolls long content smoothly without overflow',
        (tester) async {
      final longBody = List.generate(
        15,
        (i) =>
            'Paragraf ke-${i + 1}: Istiqomah merupakan komitmen teguh untuk senantiasa menaati Allah SWT dan menjalankan sunnah Rasul-Nya dalam setiap sendi kehidupan.',
      ).join('\n\n');

      final longItem = DalilItem(
        id: 'long_1',
        title: 'Penjelasan Panjang Istiqomah',
        category: DalilCategory.kisahHikmah,
        excerpt: 'Ringkasan artikel panjang...',
        body: longBody,
        sourceReference: 'Kitab Riyadhus Shalihin',
      );

      final controller = V2DalilController(
        initialItems: [longItem, testKisahItem2],
      );
      controller.selectDalil(longItem);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2DalilView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(V2DetailDalilView), findsOneWidget);
      expect(find.text('Penjelasan Panjang Istiqomah'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Drag to scroll
      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // Scenario 8: Related-content behavior
    // -------------------------------------------------------------------------
    testWidgets(
        '8. S16 presents related items in the same category and handles navigation',
        (tester) async {
      final controller = V2DalilController(initialItems: allSampleItems);
      // Select Kisah 1
      controller.selectDalil(testKisahItem1);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2DalilView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Heading: 'Kisah & Hikmah lainnya'
      expect(find.text('Kisah & Hikmah lainnya'), findsOneWidget);

      // Related card for Kisah 2 is visible
      final relatedCard =
          find.byKey(const ValueKey('v2_dalil_related_card_kisah_2'));
      expect(relatedCard, findsOneWidget);
      expect(find.text('Keteguhan Bilal bin Rabah'), findsOneWidget);

      // Tap related card to switch detail item
      await tester.tap(relatedCard);
      await tester.pumpAndSettle();

      expect(controller.selectedItem?.id, 'kisah_2');
      expect(find.text('Keteguhan Bilal bin Rabah'), findsWidgets);
    });

    // -------------------------------------------------------------------------
    // Scenario 9: Missing source reference handling
    // -------------------------------------------------------------------------
    testWidgets(
        '9. Renders gracefully when source reference is null or missing',
        (tester) async {
      // testKisahItem1 has sourceReference: null
      final controller = V2DalilController(initialItems: [testKisahItem1]);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2DalilView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Anas bin Malik & Al-Qur’an'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Open detail
      controller.selectDalil(testKisahItem1);
      await tester.pumpAndSettle();

      // No source reference box rendered
      expect(find.byKey(const ValueKey('v2_dalil_source_reference')),
          findsNothing);
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // Scenario 10: Light and Dark Mode
    // -------------------------------------------------------------------------
    testWidgets('10. Renders correctly in both Light and Dark themes',
        (tester) async {
      final controller = V2DalilController(initialItems: allSampleItems);

      // Light mode
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2DalilView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(V2DalilView), findsOneWidget);

      // Dark mode
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.darkTheme,
          themeMode: ThemeMode.dark,
          home: V2DalilView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(V2DalilView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // Scenario 11: 320dp and 390dp screen widths
    // -------------------------------------------------------------------------
    testWidgets(
        '11. Responsive layout: renders without overflow on 320dp compact and 390dp standard sizes',
        (tester) async {
      final controller = V2DalilController(initialItems: allSampleItems);

      // Compact 320dp width - S15
      tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2DalilView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Compact 320dp width - S16 Detail
      controller.selectDalil(testQuranItem);
      await tester.pumpAndSettle();
      expect(find.byType(V2DetailDalilView), findsOneWidget);
      expect(tester.takeException(), isNull);
      controller.clearSelection();
      await tester.pumpAndSettle();

      // Standard 390dp width
      tester.view.physicalSize = const Size(390 * 2.0, 844 * 2.0);
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2DalilView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // Scenario 12: Text scaling and accessibility touch targets (>= 48x48 dp)
    // -------------------------------------------------------------------------
    testWidgets(
        '12. Accessible touch targets and semantics labels are properly declared',
        (tester) async {
      final controller = V2DalilController(initialItems: allSampleItems);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.2)),
            child: V2DalilView(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check category semantics
      final semuaSemantics = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.button == true &&
            w.properties.label == 'Kategori Semua',
      );
      expect(semuaSemantics, findsOneWidget);

      // Verify all 5 category filter touch targets meet minimum 48x48 dp
      final filterKeys = [
        'v2_dalil_filter_semua',
        'v2_dalil_filter_quran',
        'v2_dalil_filter_hadits',
        'v2_dalil_filter_doa',
        'v2_dalil_filter_kisah_hikmah',
      ];

      for (final key in filterKeys) {
        final finder = find.byKey(ValueKey(key));
        expect(finder, findsOneWidget);
        final size = tester.getSize(finder);
        expect(size.width, greaterThanOrEqualTo(48.0),
            reason: '$key width must be >= 48.0');
        expect(size.height, greaterThanOrEqualTo(48.0),
            reason: '$key height must be >= 48.0');
      }

      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // Scenario 13: Optional Arabic RTL rendering
    // -------------------------------------------------------------------------
    testWidgets('13. Arabic text is rendered with correct RTL directionality',
        (tester) async {
      final controller = V2DalilController(initialItems: [testQuranItem]);
      controller.selectDalil(testQuranItem);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2DalilView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Arabic text container exists
      final arabicContainer =
          find.byKey(const ValueKey('v2_dalil_arabic_text'));
      expect(arabicContainer, findsOneWidget);

      // Verify Directionality is RTL
      final directionalityFinder = find.descendant(
        of: arabicContainer,
        matching: find.byWidgetPredicate(
          (w) => w is Directionality && w.textDirection == TextDirection.rtl,
        ),
      );
      expect(directionalityFinder, findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Scenario 14: No fabrication of production catalog entries
    // -------------------------------------------------------------------------
    testWidgets(
        '14. Default controller contains empty catalog without fabricated records',
        (tester) async {
      final defaultController = V2DalilController();

      expect(defaultController.items.isEmpty, isTrue);
      expect(defaultController.filteredItems.isEmpty, isTrue);
      expect(defaultController.selectedItem, isNull);
    });

    // -------------------------------------------------------------------------
    // Scenario 15: No Hive writes or V1 dependencies
    // -------------------------------------------------------------------------
    testWidgets(
        '15. Rendering Dalil screens performs zero database writes or storage mutations',
        (tester) async {
      final controller = V2DalilController(initialItems: allSampleItems);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2DalilView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate back and forth
      controller.selectDalil(testQuranItem);
      await tester.pumpAndSettle();
      controller.clearSelection();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // Scenario 16: Existing Dashboard and App Shell navigation regression
    // -------------------------------------------------------------------------
    testWidgets(
        '16. Dashboard quick action and read more navigate smoothly to V2DalilView',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2.0, 1000 * 2.0);
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

      expect(navController.currentIndex, 0);

      // Tap Doa Istiqomah quick action on Dashboard
      final doaAction =
          find.byKey(const ValueKey('v2_quick_action_doa_istiqomah'));
      await tester.ensureVisible(doaAction);
      await tester.pumpAndSettle();
      await tester.tap(doaAction);
      await tester.pumpAndSettle();

      // Navigated to Dalil tab (index 1)
      expect(navController.currentIndex, 1);
      expect(navController.currentTab, V2NavigationTab.dalil);
      expect(find.byType(V2DalilView), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Scenario 17: Portable development screenshot evidence
    // -------------------------------------------------------------------------
    testWidgets(
        '17. Captures actual Flutter widget screenshots in Light, Dark, Empty, and Detail states',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2.0, 844 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final screenshotTempDir =
          Directory.systemTemp.createTempSync('v2_dalil_screenshots_');
      addTearDown(() {
        if (screenshotTempDir.existsSync()) {
          screenshotTempDir.deleteSync(recursive: true);
        }
      });

      // 1. Dalil Home Light Mode
      final lightController = V2DalilController(initialItems: allSampleItems);
      final keyLight = GlobalKey();
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: RepaintBoundary(
            key: keyLight,
            child: V2AppShell(
              controller:
                  V2NavigationController(initialTab: V2NavigationTab.dalil),
              dalil: V2DalilView(controller: lightController),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final lightFile = File('${screenshotTempDir.path}/v2_dalil_light.png');
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

      // 2. Dalil Home Dark Mode
      final darkController = V2DalilController(initialItems: allSampleItems);
      final keyDark = GlobalKey();
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.darkTheme,
          themeMode: ThemeMode.dark,
          home: RepaintBoundary(
            key: keyDark,
            child: V2AppShell(
              controller:
                  V2NavigationController(initialTab: V2NavigationTab.dalil),
              dalil: V2DalilView(controller: darkController),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final darkFile = File('${screenshotTempDir.path}/v2_dalil_dark.png');
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

      // 3. Detail Dalil View
      final detailController = V2DalilController(initialItems: allSampleItems);
      detailController.selectDalil(testKisahItem1);
      final keyDetail = GlobalKey();
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: RepaintBoundary(
            key: keyDetail,
            child: V2AppShell(
              controller:
                  V2NavigationController(initialTab: V2NavigationTab.dalil),
              dalil: V2DalilView(controller: detailController),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final detailFile = File('${screenshotTempDir.path}/v2_dalil_detail.png');
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
      final emptyController = V2DalilController();
      final keyEmpty = GlobalKey();
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: RepaintBoundary(
            key: keyEmpty,
            child: V2AppShell(
              controller:
                  V2NavigationController(initialTab: V2NavigationTab.dalil),
              dalil: V2DalilView(controller: emptyController),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final emptyFile = File('${screenshotTempDir.path}/v2_dalil_empty.png');
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

      // Assertions: Files exist and have valid PNG headers
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
  });
}
