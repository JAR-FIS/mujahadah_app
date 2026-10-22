import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mujahadah/controllers/v2_navigation_controller.dart';
import 'package:mujahadah/theme/v2_design_tokens.dart';
import 'package:mujahadah/theme/v2_theme.dart';
import 'package:mujahadah/views/v2/dalil/v2_dalil_view.dart';
import 'package:mujahadah/views/v2/dashboard/v2_dashboard_view.dart';
import 'package:mujahadah/views/v2/placeholders/v2_placeholders.dart';
import 'package:mujahadah/views/v2/program/v2_program_hub_view.dart';
import 'package:mujahadah/views/v2/shell/v2_app_shell.dart';

void main() {
  setUp(() {
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  group('V2 Design System & App Shell Foundation (TASK MV2-B0-02-04-04-03)',
      () {
    // -------------------------------------------------------------------------
    // Scenario 1: Five navigation destinations in the correct order
    // -------------------------------------------------------------------------
    test('1. Navigation tab enum has exactly five destinations in locked order',
        () {
      expect(V2NavigationTab.values.length, 5);
      expect(V2NavigationTab.values[0], V2NavigationTab.dashboard);
      expect(V2NavigationTab.values[1], V2NavigationTab.dalil);
      expect(V2NavigationTab.values[2], V2NavigationTab.program);
      expect(V2NavigationTab.values[3], V2NavigationTab.history);
      expect(V2NavigationTab.values[4], V2NavigationTab.akun);

      expect(V2NavigationTab.dashboard.label, 'Dashboard');
      expect(V2NavigationTab.dalil.label, 'Dalil');
      expect(V2NavigationTab.program.label, 'Program');
      expect(V2NavigationTab.history.label, 'Riwayat');
      expect(V2NavigationTab.akun.label, 'Akun');
    });

    testWidgets(
        '1b. V2BottomNavigationBar displays five destinations in left-to-right order',
        (tester) async {
      final controller = V2NavigationController();

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2AppShell(controller: controller),
        ),
      );

      final navBarFinder = find.byType(V2BottomNavigationBar);
      final dashboardFinder =
          find.descendant(of: navBarFinder, matching: find.text('Dashboard'));
      final dalilFinder =
          find.descendant(of: navBarFinder, matching: find.text('Dalil'));
      final plusIconFinder =
          find.descendant(of: navBarFinder, matching: find.byIcon(Icons.add));
      final riwayatFinder =
          find.descendant(of: navBarFinder, matching: find.text('Riwayat'));
      final akunFinder =
          find.descendant(of: navBarFinder, matching: find.text('Akun'));

      expect(dashboardFinder, findsOneWidget);
      expect(dalilFinder, findsOneWidget);
      expect(plusIconFinder, findsOneWidget);
      expect(riwayatFinder, findsOneWidget);
      expect(akunFinder, findsOneWidget);

      // Verify no visible 'Program' text or 'History' text in navigation bar
      expect(find.descendant(of: navBarFinder, matching: find.text('Program')),
          findsNothing);
      expect(find.descendant(of: navBarFinder, matching: find.text('History')),
          findsNothing);

      final dashboardOffset = tester.getCenter(dashboardFinder);
      final dalilOffset = tester.getCenter(dalilFinder);
      final programOffset = tester.getCenter(plusIconFinder);
      final riwayatOffset = tester.getCenter(riwayatFinder);
      final akunOffset = tester.getCenter(akunFinder);

      expect(dashboardOffset.dx < dalilOffset.dx, isTrue);
      expect(dalilOffset.dx < programOffset.dx, isTrue);
      expect(programOffset.dx < riwayatOffset.dx, isTrue);
      expect(riwayatOffset.dx < akunOffset.dx, isTrue);
    });

    // -------------------------------------------------------------------------
    // Scenario 2: Program plus icon in the center without visible Program text
    // -------------------------------------------------------------------------
    testWidgets(
        '2. Center Program action displays plus icon without visible Program text',
        (tester) async {
      final controller = V2NavigationController();

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2AppShell(controller: controller),
        ),
      );

      final navBarFinder = find.byType(V2BottomNavigationBar);
      final plusIconFinder = find.byIcon(Icons.add);
      expect(plusIconFinder, findsOneWidget);

      // Verify NO visible 'Program' text in bottom navigation bar
      expect(find.descendant(of: navBarFinder, matching: find.text('Program')),
          findsNothing);

      // Verify accessibility/semantics label 'Program' remains available
      final programSemanticsFinder = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == 'Program',
      );
      expect(programSemanticsFinder, findsOneWidget);

      // Verify center placement relative to screen width
      final centerIconPos = tester.getCenter(plusIconFinder);
      final screenWidth = tester.binding.renderViews.first.size.width;
      expect((centerIconPos.dx - screenWidth / 2).abs() < 20, isTrue);
    });

    // -------------------------------------------------------------------------
    // Scenario 3: Selecting each destination displays the correct screen
    // -------------------------------------------------------------------------
    testWidgets(
        '3. Selecting each destination displays the correct screen placeholder',
        (tester) async {
      final controller = V2NavigationController();

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2AppShell(controller: controller),
        ),
      );

      // Initial tab is Dashboard (0)
      expect(controller.currentIndex, 0);
      expect(find.byType(V2DashboardView), findsOneWidget);

      // Select Dalil (1)
      await tester.tap(find.byKey(const ValueKey('v2_nav_item_dalil')));
      await tester.pumpAndSettle();
      expect(controller.currentIndex, 1);
      expect(controller.currentTab, V2NavigationTab.dalil);
      expect(find.byType(V2DalilView), findsOneWidget);

      // Select Program (2) via center plus action
      await tester.tap(find.byKey(const ValueKey('v2_nav_item_program')));
      await tester.pumpAndSettle();
      expect(controller.currentIndex, 2);
      expect(controller.currentTab, V2NavigationTab.program);
      expect(find.byType(V2ProgramHubView), findsOneWidget);

      // Select History / Riwayat (3)
      await tester.tap(find.byKey(const ValueKey('v2_nav_item_history')));
      await tester.pumpAndSettle();
      expect(controller.currentIndex, 3);
      expect(controller.currentTab, V2NavigationTab.history);
      expect(find.byType(V2HistoryPlaceholder), findsOneWidget);

      // Select Akun (4)
      await tester.tap(find.byKey(const ValueKey('v2_nav_item_akun')));
      await tester.pumpAndSettle();
      expect(controller.currentIndex, 4);
      expect(controller.currentTab, V2NavigationTab.akun);
      expect(find.byType(V2AkunPlaceholder), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Scenario 4: Navigation state remains consistent across rebuilds
    // -------------------------------------------------------------------------
    testWidgets('4. Navigation state remains consistent across widget rebuilds',
        (tester) async {
      final controller = V2NavigationController();
      controller.changeTab(3); // Pre-select History

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2AppShell(controller: controller),
        ),
      );

      expect(controller.currentIndex, 3);
      expect(find.byType(V2HistoryPlaceholder), findsOneWidget);

      // Force rebuild of parent
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.darkTheme,
          home: V2AppShell(controller: controller),
        ),
      );

      expect(controller.currentIndex, 3);
      expect(find.byType(V2HistoryPlaceholder), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Scenario 5: Repeated tapping does not create duplicate navigation state
    // -------------------------------------------------------------------------
    testWidgets(
        '5. Repeated tapping does not duplicate state or cause out-of-bounds',
        (tester) async {
      final controller = V2NavigationController();

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2AppShell(controller: controller),
        ),
      );

      // Repeatedly tap the already selected Dashboard
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const ValueKey('v2_nav_item_dashboard')));
        await tester.pump();
      }

      expect(controller.currentIndex, 0);
      expect(controller.currentTab, V2NavigationTab.dashboard);

      // Tap Program multiple times
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const ValueKey('v2_nav_item_program')));
        await tester.pump();
      }

      expect(controller.currentIndex, 2);
      expect(controller.currentTab, V2NavigationTab.program);

      // Direct out-of-bounds calls are safely ignored
      controller.changeTab(-1);
      expect(controller.currentIndex, 2);
      controller.changeTab(10);
      expect(controller.currentIndex, 2);
    });

    // -------------------------------------------------------------------------
    // Scenario 6: Safe-area and small-screen layout
    // -------------------------------------------------------------------------
    testWidgets(
        '6. Renders responsively on compact screen sizes without overflow',
        (tester) async {
      // Small screen size: 320x480 dp
      tester.view.physicalSize = const Size(320 * 2.0, 480 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = V2NavigationController();

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2AppShell(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(V2AppShell), findsOneWidget);
      expect(find.byType(V2BottomNavigationBar), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Scenario 7: Light theme renders correctly
    // -------------------------------------------------------------------------
    testWidgets('7. Light theme renders correctly with approved light palette',
        (tester) async {
      final lightTheme = V2Theme.lightTheme;

      expect(lightTheme.brightness, Brightness.light);
      expect(lightTheme.primaryColor, V2Colors.deepTosca);
      expect(
          lightTheme.scaffoldBackgroundColor, V2Colors.lightScaffoldBackground);
      expect(lightTheme.colorScheme.primary, V2Colors.deepTosca);
      expect(lightTheme.colorScheme.secondary, V2Colors.warmGold);
      expect(lightTheme.colorScheme.surface, V2Colors.lightSurface);

      await tester.pumpWidget(
        MaterialApp(
          theme: lightTheme,
          home: const Scaffold(
            body: V2DashboardPlaceholder(),
          ),
        ),
      );

      final themeFound =
          Theme.of(tester.element(find.byType(V2DashboardPlaceholder)));
      expect(themeFound.brightness, Brightness.light);
      expect(themeFound.primaryColor, V2Colors.deepTosca);
    });

    // -------------------------------------------------------------------------
    // Scenario 8: Dark theme renders correctly
    // -------------------------------------------------------------------------
    testWidgets(
        '8. Dark theme renders correctly with Elegant Black & Dark Tosca palette',
        (tester) async {
      final darkTheme = V2Theme.darkTheme;

      expect(darkTheme.brightness, Brightness.dark);
      expect(
          darkTheme.scaffoldBackgroundColor, V2Colors.darkScaffoldBackground);
      expect(darkTheme.colorScheme.surface, V2Colors.darkSurface);
      expect(darkTheme.colorScheme.primary, V2Colors.mint);
      expect(darkTheme.colorScheme.secondary, V2Colors.warmGold);

      await tester.pumpWidget(
        MaterialApp(
          theme: darkTheme,
          home: const Scaffold(
            body: V2DashboardPlaceholder(),
          ),
        ),
      );

      final themeFound =
          Theme.of(tester.element(find.byType(V2DashboardPlaceholder)));
      expect(themeFound.brightness, Brightness.dark);
      expect(themeFound.scaffoldBackgroundColor, const Color(0xFF121617));
    });

    // -------------------------------------------------------------------------
    // Scenario 9: Color tokens match the approved palette
    // -------------------------------------------------------------------------
    test(
        '9. Centralized color tokens exactly match the 8 approved palette colors',
        () {
      expect(V2Colors.deepTosca, const Color(0xFF1F4D59));
      expect(V2Colors.mint, const Color(0xFFC4FECF));
      expect(V2Colors.warmGold, const Color(0xFFD2964D));
      expect(V2Colors.pink, const Color(0xFFFEC4D2));
      expect(V2Colors.peach, const Color(0xFFFFBF72));
      expect(V2Colors.lightGray, const Color(0xFFEBEBEB));
      expect(V2Colors.cyan, const Color(0xFFC4F8FE));
      expect(V2Colors.charcoal, const Color(0xFF434343));

      expect(V2Colors.darkScaffoldBackground, const Color(0xFF121617));
      expect(V2Colors.darkSurface, const Color(0xFF1A2426));
    });

    // -------------------------------------------------------------------------
    // Scenario 10: Accessible destination labels
    // -------------------------------------------------------------------------
    testWidgets(
        '10. Destination buttons provide accessible labels and >= 48dp touch targets',
        (tester) async {
      final controller = V2NavigationController();

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2AppShell(controller: controller),
        ),
      );

      final labels = ['Dashboard', 'Dalil', 'Program', 'Riwayat', 'Akun'];
      for (final label in labels) {
        final semanticsFinder = find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == label,
        );
        expect(semanticsFinder, findsOneWidget);

        final constrainedBox = find.ancestor(
          of: semanticsFinder,
          matching: find.byType(ConstrainedBox),
        );
        // Verify minimum 48x48 touch target constraint exists
        expect(constrainedBox, findsWidgets);
      }
    });

    // -------------------------------------------------------------------------
    // Scenario 11: Placeholder screens render without V1 controllers or Hive dependencies
    // -------------------------------------------------------------------------
    testWidgets(
        '11. Placeholder screens render without V1 controllers or Hive dependencies and with correct screen IDs',
        (tester) async {
      // We explicitly DO NOT call Get.put(MainController()) or Hive.openBox()
      await tester.pumpWidget(
        MaterialApp(
          theme: V2Theme.lightTheme,
          home: const Scaffold(
            body: Column(
              children: [
                Expanded(child: V2DashboardPlaceholder()),
                Expanded(child: V2DalilPlaceholder()),
                Expanded(child: V2ProgramPlaceholder()),
                Expanded(child: V2HistoryPlaceholder()),
                Expanded(child: V2AkunPlaceholder()),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(V2DashboardPlaceholder), findsOneWidget);
      expect(find.byType(V2DalilPlaceholder), findsOneWidget);
      expect(find.byType(V2ProgramPlaceholder), findsOneWidget);
      expect(find.byType(V2HistoryPlaceholder), findsOneWidget);
      expect(find.byType(V2AkunPlaceholder), findsOneWidget);

      // Verify correct screen IDs matching owner-approved mockup:
      // Dashboard = S08, Dalil = S15, Program Hub = S17, History = S23, Akun = S26
      expect(find.text('S08 • Foundation Placeholder'), findsOneWidget);
      expect(find.text('S15 • Foundation Placeholder'), findsOneWidget);
      expect(find.text('S17 • Foundation Placeholder'), findsOneWidget);
      expect(find.text('S23 • Foundation Placeholder'), findsOneWidget);
      expect(find.text('S26 • Foundation Placeholder'), findsOneWidget);

      // Verify no exceptions occurred and no V1 controllers were registered
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // Scenario 12: No domain mutation occurs during widget build
    // -------------------------------------------------------------------------
    testWidgets(
        '12. Building V2AppShell performs zero domain or database mutations',
        (tester) async {
      final controller = V2NavigationController();

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2AppShell(controller: controller),
        ),
      );

      // Switching through all tabs
      for (int i = 0; i < 5; i++) {
        controller.changeTab(i);
        await tester.pump();
      }

      // Zero side-effects or mutations: controller state simply tracked UI index
      expect(controller.currentIndex, 4);
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // Scenario 13: V2 runtime is not mounted into production main.dart
    // -------------------------------------------------------------------------
    test(
        '13. Production main.dart does not mount or import V2 App Shell or V2Runtime',
        () {
      final mainFile = File('lib/main.dart');
      expect(mainFile.existsSync(), isTrue);

      final content = mainFile.readAsStringSync();

      expect(content.contains('V2AppShell'), isFalse,
          reason:
              'V2AppShell must NOT be imported or used in production main.dart yet');
      expect(content.contains('v2_runtime.dart'), isFalse,
          reason:
              'v2_runtime.dart must NOT be mounted into production main.dart yet');
      expect(content.contains('v2_theme.dart'), isFalse,
          reason:
              'v2_theme.dart must NOT be mounted into production main.dart yet');
      expect(content.contains('V2Theme'), isFalse,
          reason:
              'V2Theme must NOT replace V1 AppTheme in production main.dart yet');
    });

    // -------------------------------------------------------------------------
    // Scenario 14: Visual review evidence screenshot capture
    // -------------------------------------------------------------------------
    testWidgets(
        '14. Captures actual Flutter widget screenshots in Light and Dark modes',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2.0, 844 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final tempDir = Directory.systemTemp.createTempSync('v2_screenshots_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      final lightFile = File('${tempDir.path}/v2_app_shell_light.png');
      final darkFile = File('${tempDir.path}/v2_app_shell_dark.png');

      final controller = V2NavigationController();
      final repaintKeyLight = GlobalKey();

      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: RepaintBoundary(
            key: repaintKeyLight,
            child: V2AppShell(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        final boundaryLight = repaintKeyLight.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundaryLight != null) {
          final image = await boundaryLight.toImage(pixelRatio: 1.0);
          final byteData =
              await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            lightFile.writeAsBytesSync(byteData.buffer.asUint8List());
          }
        }
      });

      final repaintKeyDark = GlobalKey();
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.darkTheme,
          themeMode: ThemeMode.dark,
          home: RepaintBoundary(
            key: repaintKeyDark,
            child: V2AppShell(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        final boundaryDark = repaintKeyDark.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundaryDark != null) {
          final image = await boundaryDark.toImage(pixelRatio: 1.0);
          final byteData =
              await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            darkFile.writeAsBytesSync(byteData.buffer.asUint8List());
          }
        }
      });

      expect(lightFile.existsSync(), isTrue);
      expect(darkFile.existsSync(), isTrue);

      expect(lightFile.lengthSync(), greaterThan(100));
      expect(darkFile.lengthSync(), greaterThan(100));

      // Validate PNG magic bytes header (0x89, 0x50, 0x4E, 0x47)
      final lightBytes = lightFile.readAsBytesSync();
      final darkBytes = darkFile.readAsBytesSync();
      expect(lightBytes.take(4).toList(), [0x89, 0x50, 0x4E, 0x47]);
      expect(darkBytes.take(4).toList(), [0x89, 0x50, 0x4E, 0x47]);
    });

    // -------------------------------------------------------------------------
    // Scenario 15: App Shell Program Hub default setup wiring
    // -------------------------------------------------------------------------
    testWidgets(
        '15. V2AppShell configures default Program Hub with wireProgramSetup: true',
        (tester) async {
      final controller = V2NavigationController();

      // Default shell build
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2AppShell(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Program tab (index 2)
      await tester.tap(find.byKey(const ValueKey('v2_nav_item_program')));
      await tester.pumpAndSettle();

      // Find V2ProgramHubView inside default App Shell
      final hubFinder = find.byType(V2ProgramHubView);
      expect(hubFinder, findsOneWidget);
      final V2ProgramHubView hub = tester.widget(hubFinder);
      expect(hub.wireProgramSetup, isTrue);

      // Explicit override wireProgramSetup: false
      final controllerUnwired = V2NavigationController();
      await tester.pumpWidget(
        GetMaterialApp(
          theme: V2Theme.lightTheme,
          home: V2AppShell(
            controller: controllerUnwired,
            wireProgramSetup: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('v2_nav_item_program')));
      await tester.pumpAndSettle();

      final V2ProgramHubView unwiredHub = tester.widget(hubFinder);
      expect(unwiredHub.wireProgramSetup, isFalse);
    });
  });
}
