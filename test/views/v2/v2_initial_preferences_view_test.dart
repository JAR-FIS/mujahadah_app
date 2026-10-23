import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mujahadah/controllers/v2_initial_preferences_controller.dart';
import 'package:mujahadah/models/v2_initial_preferences_model.dart';
import 'package:mujahadah/repositories/v2_preferences_repository.dart';
import 'package:mujahadah/theme/v2_theme.dart';
import 'package:mujahadah/views/v2/preferences/v2_initial_preferences_view.dart';

class MockPreferencesRepository implements V2PreferencesRepository {
  V2InitialPreferencesModel current = V2InitialPreferencesModel.initial();
  bool shouldFail = false;
  int saveCount = 0;
  Completer<void>? saveCompleter;
  Completer<V2InitialPreferencesModel>? getPreferencesCompleter;

  @override
  Future<V2InitialPreferencesModel> getPreferences() async {
    if (getPreferencesCompleter != null) {
      return await getPreferencesCompleter!.future;
    }
    return current;
  }

  @override
  Future<bool> isCompleted() async => current.isCompleted;

  @override
  Future<void> savePreferences(V2InitialPreferencesModel preferences) async {
    saveCount++;
    if (saveCompleter != null) {
      await saveCompleter!.future;
    }
    if (shouldFail) {
      throw Exception('Disk I/O error');
    }
    current = preferences;
  }

  @override
  Future<void> setCompleted(bool completed) async {
    current = current.copyWith(isCompleted: completed);
  }

  @override
  Future<void> clear() async {
    current = V2InitialPreferencesModel.initial();
  }
}

void main() {
  setUp(() {
    Get.reset();
  });

  Widget buildTestWidget({
    V2InitialPreferencesController? controller,
    V2PreferencesRepository? repository,
    ThemeData? theme,
    VoidCallback? onContinue,
  }) {
    return GetMaterialApp(
      theme: theme ?? V2Theme.lightTheme,
      home: V2InitialPreferencesView(
        controller: controller,
        repository: repository,
        onContinue: onContinue,
      ),
    );
  }

  group('V2InitialPreferencesView Widget Tests (S00A)', () {
    testWidgets('1. Renders approved hierarchy and initial default selections',
        (tester) async {
      final repo = MockPreferencesRepository();
      final controller = V2InitialPreferencesController(repository: repo);

      await tester.pumpWidget(buildTestWidget(controller: controller));
      await tester.pumpAndSettle();

      // Brand / Logo Area
      expect(find.text('MUJAHADAH'), findsOneWidget);
      expect(find.text('Pengaturan Awal Aplikasi'), findsOneWidget);
      expect(find.byIcon(Icons.mosque_rounded), findsOneWidget);

      // Section 1: Language
      expect(find.text('Pilih Penggunaan Bahasa'), findsOneWidget);
      expect(find.text('Bahasa Indonesia'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);

      // Section 2: Theme
      expect(find.text('Pilih Tema Aplikasi'), findsOneWidget);
      expect(find.text('Mode Terang'), findsOneWidget);
      expect(find.text('Mode Gelap'), findsOneWidget);

      // Bottom CTA
      expect(find.byKey(const ValueKey('v2_init_pref_mulai_button')),
          findsOneWidget);
      expect(find.text('Mulai'), findsOneWidget);

      // Initial defaults
      expect(controller.selectedLanguage.value, equals('id'));
      expect(controller.selectedTheme.value, equals('light'));
    });

    testWidgets('2. Selects English with truthful localization disclosure',
        (tester) async {
      final repo = MockPreferencesRepository();
      final controller = V2InitialPreferencesController(repository: repo);

      await tester.pumpWidget(buildTestWidget(controller: controller));
      await tester.pumpAndSettle();

      // Verify English disclosure notice is clearly visible
      expect(
        find.text(
            'Konten aplikasi saat ini masih tersedia dalam Bahasa Indonesia'),
        findsOneWidget,
      );

      // Tap English tile
      await tester.tap(find.byKey(const ValueKey('v2_pref_lang_en')));
      await tester.pumpAndSettle();

      expect(controller.selectedLanguage.value, equals('en'));

      // Tap back to Indonesian
      await tester.tap(find.byKey(const ValueKey('v2_pref_lang_id')));
      await tester.pumpAndSettle();

      expect(controller.selectedLanguage.value, equals('id'));
    });

    testWidgets('3. Selects Dark Theme and updates reactive controller',
        (tester) async {
      final repo = MockPreferencesRepository();
      final controller = V2InitialPreferencesController(repository: repo);

      await tester.pumpWidget(buildTestWidget(controller: controller));
      await tester.pumpAndSettle();

      // Tap Dark Mode tile
      await tester
          .ensureVisible(find.byKey(const ValueKey('v2_pref_theme_dark')));
      await tester.tap(find.byKey(const ValueKey('v2_pref_theme_dark')));
      await tester.pumpAndSettle();

      expect(controller.selectedTheme.value, equals('dark'));
      expect(controller.isDarkMode, isTrue);

      // Tap back to Light Mode
      await tester
          .ensureVisible(find.byKey(const ValueKey('v2_pref_theme_light')));
      await tester.tap(find.byKey(const ValueKey('v2_pref_theme_light')));
      await tester.pumpAndSettle();

      expect(controller.selectedTheme.value, equals('light'));
      expect(controller.isDarkMode, isFalse);
    });

    testWidgets(
        '4. Accessible touch targets >= 48dp on all interactive elements',
        (tester) async {
      final repo = MockPreferencesRepository();
      final controller = V2InitialPreferencesController(repository: repo);

      await tester.pumpWidget(buildTestWidget(controller: controller));
      await tester.pumpAndSettle();

      // Check minimum height constraints on tiles
      final tileKeys = [
        const ValueKey('v2_pref_lang_id'),
        const ValueKey('v2_pref_lang_en'),
        const ValueKey('v2_pref_theme_light'),
        const ValueKey('v2_pref_theme_dark'),
      ];

      for (final key in tileKeys) {
        final size = tester.getSize(find.byKey(key));
        expect(size.height, greaterThanOrEqualTo(48.0));
      }

      // Mulai CTA button height
      final buttonSize = tester
          .getSize(find.byKey(const ValueKey('v2_init_pref_mulai_button')));
      expect(buttonSize.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets(
        '5. Renders responsively on compact screen (320x480 dp) without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 480 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = MockPreferencesRepository();
      final controller = V2InitialPreferencesController(repository: repo);

      await tester.pumpWidget(buildTestWidget(controller: controller));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(V2InitialPreferencesView), findsOneWidget);
      expect(find.text('MUJAHADAH'), findsOneWidget);
      expect(find.byKey(const ValueKey('v2_init_pref_mulai_button')),
          findsOneWidget);
    });

    testWidgets(
        '6. Renders with Dark Theme without error or visual contrast issues',
        (tester) async {
      final repo = MockPreferencesRepository();
      final controller = V2InitialPreferencesController(repository: repo);
      controller.setTheme('dark');

      await tester.pumpWidget(
        buildTestWidget(
          controller: controller,
          theme: V2Theme.darkTheme,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(V2InitialPreferencesView), findsOneWidget);
    });

    testWidgets(
        '7. Tap Mulai persists selections and invokes onContinue callback',
        (tester) async {
      final repo = MockPreferencesRepository();
      final controller = V2InitialPreferencesController(repository: repo);
      bool continued = false;

      await tester.pumpWidget(
        buildTestWidget(
          controller: controller,
          onContinue: () => continued = true,
        ),
      );
      await tester.pumpAndSettle();

      controller.setLanguage('en');
      controller.setTheme('dark');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('v2_init_pref_mulai_button')));
      await tester.pumpAndSettle();

      expect(repo.saveCount, equals(1));
      expect(repo.current.isCompleted, isTrue);
      expect(repo.current.languageCode, equals('en'));
      expect(repo.current.themeMode, equals('dark'));
      expect(continued, isTrue);
    });

    testWidgets(
        '8. Repeated rapid taps on Mulai triggers single persistence only',
        (tester) async {
      final repo = MockPreferencesRepository();
      repo.saveCompleter = Completer<void>();
      final controller = V2InitialPreferencesController(repository: repo);
      int continueCallCount = 0;

      await tester.pumpWidget(
        buildTestWidget(
          controller: controller,
          onContinue: () => continueCallCount++,
        ),
      );
      await tester.pumpAndSettle();

      // Tap Mulai multiple times rapidly
      await tester.tap(find.byKey(const ValueKey('v2_init_pref_mulai_button')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('v2_init_pref_mulai_button')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('v2_init_pref_mulai_button')));
      await tester.pump();

      // Complete the pending asynchronous save
      repo.saveCompleter!.complete();
      await tester.pumpAndSettle();

      expect(repo.saveCount, equals(1));
      expect(continueCallCount, equals(1));
    });

    testWidgets(
        '9. Persistence failure shows recoverable Indonesian error and does not navigate',
        (tester) async {
      final repo = MockPreferencesRepository();
      repo.shouldFail = true;
      final controller = V2InitialPreferencesController(repository: repo);
      bool continued = false;

      await tester.pumpWidget(
        buildTestWidget(
          controller: controller,
          onContinue: () => continued = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('v2_init_pref_mulai_button')));
      await tester.pumpAndSettle();

      // Did NOT route
      expect(continued, isFalse);
      expect(repo.current.isCompleted, isFalse);

      // Error banner is visible
      expect(
        find.textContaining('Gagal menyimpan preferensi'),
        findsOneWidget,
      );

      // Retry after resolving failure succeeds
      repo.shouldFail = false;
      await tester.tap(find.byKey(const ValueKey('v2_init_pref_mulai_button')));
      await tester.pumpAndSettle();

      expect(continued, isTrue);
      expect(repo.current.isCompleted, isTrue);
      expect(find.textContaining('Gagal menyimpan preferensi'), findsNothing);
    });

    testWidgets(
        '10. P1-02: Default-constructed view automatically loads incomplete stored en/dark choices',
        (tester) async {
      final repo = MockPreferencesRepository();
      // Incomplete saved preferences from an interrupted launch
      repo.current = const V2InitialPreferencesModel(
        isCompleted: false,
        languageCode: 'en',
        themeMode: 'dark',
      );

      // Mount view with repository ONLY (default controller creation internally)
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await tester.pumpAndSettle();

      // English must be marked selected
      final enTile = tester.widget<InkWell>(
        find.byKey(const ValueKey('v2_pref_lang_en')),
      );
      expect(enTile, isNotNull);

      // Semantics for English shows Terpilih
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.label != null &&
            w.properties.label!.contains('English') &&
            w.properties.selected == true),
        findsOneWidget,
      );

      // Semantics for Dark Mode shows Terpilih
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.label != null &&
            w.properties.label!.contains('Mode Gelap') &&
            w.properties.selected == true),
        findsOneWidget,
      );
    });

    testWidgets(
        '11. P2-03: Option tiles are disabled and ignore tap events during in-flight save',
        (tester) async {
      final repo = MockPreferencesRepository();
      repo.saveCompleter = Completer<void>();
      final controller = V2InitialPreferencesController(repository: repo);

      await tester.pumpWidget(buildTestWidget(controller: controller));
      await tester.pumpAndSettle();

      // Initial state is ID / Light
      expect(controller.selectedLanguage.value, equals('id'));
      expect(controller.selectedTheme.value, equals('light'));

      // Tap Mulai to start save
      await tester.tap(find.byKey(const ValueKey('v2_init_pref_mulai_button')));
      await tester.pump();

      // Save is in flight
      expect(controller.isSaving.value, isTrue);

      // Attempt to tap English tile while saving
      await tester.tap(find.byKey(const ValueKey('v2_pref_lang_en')));
      await tester.pump();

      // Selection did NOT change
      expect(controller.selectedLanguage.value, equals('id'));

      // Complete save
      repo.saveCompleter!.complete();
      await tester.pumpAndSettle();

      expect(controller.isSaving.value, isFalse);
      expect(repo.current.languageCode, equals('id'));
    });

    testWidgets(
        '12. P1-02: Delayed preference read does not overwrite user immediate selection',
        (tester) async {
      final repo = MockPreferencesRepository();
      repo.getPreferencesCompleter = Completer<V2InitialPreferencesModel>();

      // Mount view with repository
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await tester.pump();

      // User immediately taps English
      await tester.tap(find.byKey(const ValueKey('v2_pref_lang_en')));
      await tester.pump();

      // Now complete the delayed preference read which returns 'id'
      repo.getPreferencesCompleter!.complete(
        const V2InitialPreferencesModel(
          isCompleted: false,
          languageCode: 'id',
          themeMode: 'light',
        ),
      );
      await tester.pumpAndSettle();

      // English selection was preserved
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.label != null &&
            w.properties.label!.contains('English') &&
            w.properties.selected == true),
        findsOneWidget,
      );
    });

    testWidgets(
        '13. P1-03: Mulai button is disabled during delayed preference load and enabled after restore',
        (tester) async {
      final repo = MockPreferencesRepository();
      repo.getPreferencesCompleter = Completer<V2InitialPreferencesModel>();
      bool continued = false;

      // Mount default-owned view with repository
      await tester.pumpWidget(
        buildTestWidget(
          repository: repo,
          onContinue: () => continued = true,
        ),
      );
      await tester.pump();

      // Mulai button is present but DISABLED (onPressed is null)
      final buttonFinder =
          find.byKey(const ValueKey('v2_init_pref_mulai_button'));
      expect(buttonFinder, findsOneWidget);
      final elevatedButton = tester.widget<ElevatedButton>(buttonFinder);
      expect(elevatedButton.onPressed, isNull);

      // Attempt tapping the disabled Mulai button
      await tester.tap(buttonFinder, warnIfMissed: false);
      await tester.pump();

      // Must not continue and must not persist
      expect(continued, isFalse);
      expect(repo.saveCount, equals(0));

      // Resolve pending read to incomplete 'en' / 'dark'
      repo.getPreferencesCompleter!.complete(
        const V2InitialPreferencesModel(
          isCompleted: false,
          languageCode: 'en',
          themeMode: 'dark',
        ),
      );
      await tester.pumpAndSettle();

      // Verify that choices are now loaded and reflected in selection semantics
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.label != null &&
            w.properties.label!.contains('English') &&
            w.properties.selected == true),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.label != null &&
            w.properties.label!.contains('Mode Gelap') &&
            w.properties.selected == true),
        findsOneWidget,
      );

      // Mulai button is now enabled
      final enabledButton = tester.widget<ElevatedButton>(buttonFinder);
      expect(enabledButton.onPressed, isNotNull);

      // Tap enabled Mulai button
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      // Successfully saved restored choices and continued
      expect(repo.saveCount, equals(1));
      expect(repo.current.isCompleted, isTrue);
      expect(repo.current.languageCode, equals('en'));
      expect(repo.current.themeMode, equals('dark'));
      expect(continued, isTrue);
    });
  });
}
