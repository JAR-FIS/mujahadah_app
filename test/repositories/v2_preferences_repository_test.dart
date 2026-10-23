import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:mujahadah/controllers/theme_controller.dart';
import 'package:mujahadah/models/v2_initial_preferences_model.dart';
import 'package:mujahadah/repositories/v2_preferences_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box settingsBox;
  late HiveV2PreferencesRepository repository;

  setUp(() async {
    Get.reset();
    tempDir = Directory.systemTemp.createTempSync('v2_prefs_repo_test_');
    Hive.init(tempDir.path);
    settingsBox = await Hive.openBox('settings');
    repository = HiveV2PreferencesRepository(box: settingsBox);
  });

  tearDown(() async {
    await settingsBox.close();
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('HiveV2PreferencesRepository Tests', () {
    test(
        '1. Fresh install returns initial uncompleted status and default values',
        () async {
      final isCompleted = await repository.isCompleted();
      expect(isCompleted, isFalse);

      final prefs = await repository.getPreferences();
      expect(prefs.isCompleted, isFalse);
      expect(prefs.languageCode, equals('id'));
      expect(prefs.themeMode, equals('light'));
      expect(prefs.isDarkMode, isFalse);
    });

    test(
        '2. Saves preferences durably, marks completed, and syncs legacy isDarkMode',
        () async {
      const model = V2InitialPreferencesModel(
        isCompleted: true,
        languageCode: 'en',
        themeMode: 'dark',
      );

      await repository.savePreferences(model);

      expect(await repository.isCompleted(), isTrue);

      final loaded = await repository.getPreferences();
      expect(loaded.isCompleted, isTrue);
      expect(loaded.languageCode, equals('en'));
      expect(loaded.themeMode, equals('dark'));
      expect(loaded.isDarkMode, isTrue);

      // Verify raw Hive storage keys
      expect(settingsBox.get(HiveV2PreferencesRepository.keyCompleted), isTrue);
      expect(settingsBox.get(HiveV2PreferencesRepository.keyLanguage),
          equals('en'));
      expect(settingsBox.get(HiveV2PreferencesRepository.keyTheme),
          equals('dark'));
      expect(
          settingsBox.get(HiveV2PreferencesRepository.keyV1IsDarkMode), isTrue);
    });

    test('3. Synchronizes theme with ThemeController in GetX on save',
        () async {
      // Register ThemeController
      final themeCtrl = ThemeController();
      Get.put(themeCtrl);

      expect(themeCtrl.isDarkMode.value, isFalse);

      // Save dark mode preference
      const model = V2InitialPreferencesModel(
        isCompleted: true,
        languageCode: 'id',
        themeMode: 'dark',
      );
      await repository.savePreferences(model);

      // Verify ThemeController reactively updated
      expect(themeCtrl.isDarkMode.value, isTrue);
    });

    test('4. Direct setCompleted updates completion flag', () async {
      expect(await repository.isCompleted(), isFalse);

      await repository.setCompleted(true);
      expect(await repository.isCompleted(), isTrue);

      await repository.setCompleted(false);
      expect(await repository.isCompleted(), isFalse);
    });

    test('5. Clear deletes stored keys', () async {
      const model = V2InitialPreferencesModel(
        isCompleted: true,
        languageCode: 'en',
        themeMode: 'dark',
      );
      await repository.savePreferences(model);

      expect(await repository.isCompleted(), isTrue);

      await repository.clear();

      expect(await repository.isCompleted(), isFalse);
      final resetPrefs = await repository.getPreferences();
      expect(resetPrefs.isCompleted, isFalse);
      expect(resetPrefs.languageCode, equals('id'));
      expect(resetPrefs.themeMode, equals('light'));
    });

    test('6. Accessing repository without explicit box uses open default box',
        () async {
      final defaultRepo = HiveV2PreferencesRepository();
      expect(await defaultRepo.isCompleted(), isFalse);
    });

    test(
        '7. P2-02: Partial write failure leaves completion false while preserving written choices',
        () async {
      // Injected failure when attempting to write keyCompleted (final marker)
      final failRepo = HiveV2PreferencesRepository(
        box: settingsBox,
        onBeforePut: (key, value) async {
          if (key == HiveV2PreferencesRepository.keyCompleted) {
            throw Exception('Disk failure before completion flag commit');
          }
        },
      );

      const model = V2InitialPreferencesModel(
        isCompleted: true,
        languageCode: 'en',
        themeMode: 'dark',
      );

      await expectLater(
          failRepo.savePreferences(model), throwsA(isA<Exception>()));

      // Completion flag MUST be false (fail-closed)
      expect(await failRepo.isCompleted(), isFalse);
      expect(settingsBox.get(HiveV2PreferencesRepository.keyCompleted), isNull);

      // Written choices were already committed and can be reloaded safely
      final partialPrefs = await failRepo.getPreferences();
      expect(partialPrefs.isCompleted, isFalse);
      expect(partialPrefs.languageCode, equals('en'));
      expect(partialPrefs.themeMode, equals('dark'));
    });

    test(
        '8. P2-02: Malformed or unapproved persisted values are safely normalized',
        () async {
      // Intentionally insert corrupted/unsupported types and values
      await settingsBox.put(
          HiveV2PreferencesRepository.keyLanguage, 'unsupported_lang');
      await settingsBox.put(
          HiveV2PreferencesRepository.keyTheme, 12345); // wrong type
      await settingsBox.put(
          HiveV2PreferencesRepository.keyCompleted, 'not_a_bool'); // wrong type

      final safePrefs = await repository.getPreferences();

      // Graceful fallback to default values without throwing
      expect(safePrefs.isCompleted, isFalse);
      expect(safePrefs.languageCode, equals('id'));
      expect(safePrefs.themeMode, equals('light'));
    });

    test(
        '9. P2-02: Theme propagation failure does not mask successful storage commit',
        () async {
      const model = V2InitialPreferencesModel(
        isCompleted: true,
        languageCode: 'en',
        themeMode: 'dark',
      );

      // Save without registered ThemeController should not throw
      await repository.savePreferences(model);

      expect(await repository.isCompleted(), isTrue);
      final loaded = await repository.getPreferences();
      expect(loaded.isCompleted, isTrue);
      expect(loaded.themeMode, equals('dark'));
    });

    test('10. Persisted choices survive box close and restart from disk',
        () async {
      const model = V2InitialPreferencesModel(
        isCompleted: true,
        languageCode: 'en',
        themeMode: 'dark',
      );
      await repository.savePreferences(model);

      // Close box simulating app shutdown
      await settingsBox.close();

      // Reopen box simulating fresh app launch
      final reopenedBox = await Hive.openBox('settings');
      final newRepo = HiveV2PreferencesRepository(box: reopenedBox);

      expect(await newRepo.isCompleted(), isTrue);
      final reloaded = await newRepo.getPreferences();
      expect(reloaded.languageCode, equals('en'));
      expect(reloaded.themeMode, equals('dark'));

      settingsBox = reopenedBox; // for tearDown cleanup
    });
  });
}
