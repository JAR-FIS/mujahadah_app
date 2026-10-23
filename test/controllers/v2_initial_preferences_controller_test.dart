import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mujahadah/controllers/v2_initial_preferences_controller.dart';
import 'package:mujahadah/models/v2_initial_preferences_model.dart';
import 'package:mujahadah/repositories/v2_preferences_repository.dart';

class FakePreferencesRepository implements V2PreferencesRepository {
  V2InitialPreferencesModel current = V2InitialPreferencesModel.initial();
  bool shouldThrowOnSave = false;
  int saveCount = 0;
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
    if (shouldThrowOnSave) {
      throw Exception('Simulated disk write failure');
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
  group('V2InitialPreferencesController Tests', () {
    late FakePreferencesRepository fakeRepo;
    late V2InitialPreferencesController controller;

    setUp(() {
      Get.reset();
      fakeRepo = FakePreferencesRepository();
      controller = V2InitialPreferencesController(repository: fakeRepo);
    });

    tearDown(() {
      controller.dispose();
    });

    test('1. Loads initial defaults when repository has no previous choices',
        () async {
      await controller.loadExistingPreferences();

      expect(controller.selectedLanguage.value, equals('id'));
      expect(controller.selectedTheme.value, equals('light'));
      expect(controller.isDarkMode, isFalse);
      expect(controller.isSaving.value, isFalse);
      expect(controller.errorMessage.value, isEmpty);
    });

    test('2. Loads existing preferences when previously stored', () async {
      fakeRepo.current = const V2InitialPreferencesModel(
        isCompleted: true,
        languageCode: 'en',
        themeMode: 'dark',
      );

      await controller.loadExistingPreferences();

      expect(controller.selectedLanguage.value, equals('en'));
      expect(controller.selectedTheme.value, equals('dark'));
      expect(controller.isDarkMode, isTrue);
    });

    test('3. setLanguage updates selection and clears error', () {
      controller.errorMessage.value = 'Some error';

      controller.setLanguage('en');
      expect(controller.selectedLanguage.value, equals('en'));
      expect(controller.errorMessage.value, isEmpty);

      // Unsupported code is ignored
      controller.setLanguage('fr');
      expect(controller.selectedLanguage.value, equals('en'));
    });

    test('4. setTheme updates selection and clears error', () {
      controller.errorMessage.value = 'Some error';

      controller.setTheme('dark');
      expect(controller.selectedTheme.value, equals('dark'));
      expect(controller.isDarkMode, isTrue);
      expect(controller.errorMessage.value, isEmpty);

      // Unsupported theme is ignored
      controller.setTheme('system');
      expect(controller.selectedTheme.value, equals('dark'));
    });

    test('5. confirmAndSave persists preferences and marks completed',
        () async {
      controller.setLanguage('en');
      controller.setTheme('dark');

      final result = await controller.confirmAndSave();

      expect(result, isTrue);
      expect(fakeRepo.saveCount, equals(1));
      expect(fakeRepo.current.isCompleted, isTrue);
      expect(fakeRepo.current.languageCode, equals('en'));
      expect(fakeRepo.current.themeMode, equals('dark'));
      expect(controller.isSaving.value, isFalse);
      expect(controller.errorMessage.value, isEmpty);
    });

    test(
        '6. Single-flight protection prevents concurrent rapid double-tap saves',
        () async {
      controller.isSaving.value = true;

      final result = await controller.confirmAndSave();

      expect(result, isFalse);
      expect(fakeRepo.saveCount, equals(0));
    });

    test(
        '7. Save failure shows recoverable error message and leaves completed flag false',
        () async {
      fakeRepo.shouldThrowOnSave = true;

      final result = await controller.confirmAndSave();

      expect(result, isFalse);
      expect(fakeRepo.current.isCompleted, isFalse);
      expect(controller.isSaving.value, isFalse);
      expect(controller.errorMessage.value,
          contains('Gagal menyimpan preferensi'));

      // Retry after fixing condition works
      fakeRepo.shouldThrowOnSave = false;
      final retryResult = await controller.confirmAndSave();
      expect(retryResult, isTrue);
      expect(fakeRepo.current.isCompleted, isTrue);
      expect(controller.errorMessage.value, isEmpty);
    });

    test(
        '8. P1-02: Pending preference read does not overwrite later user selection',
        () async {
      fakeRepo.getPreferencesCompleter = Completer<V2InitialPreferencesModel>();

      // Create new controller with autoLoad: true (as default)
      final raceController = V2InitialPreferencesController(
        repository: fakeRepo,
        autoLoad: true,
      );

      // User immediately taps 'en' and 'dark' while disk read is pending
      raceController.setLanguage('en');
      raceController.setTheme('dark');

      expect(raceController.userHasSelectedLanguage, isTrue);
      expect(raceController.userHasSelectedTheme, isTrue);

      // Complete the delayed disk read which returns 'id' and 'light'
      fakeRepo.getPreferencesCompleter!.complete(
        const V2InitialPreferencesModel(
          isCompleted: false,
          languageCode: 'id',
          themeMode: 'light',
        ),
      );
      await Future.delayed(const Duration(milliseconds: 10));

      // User's selections remain preserved
      expect(raceController.selectedLanguage.value, equals('en'));
      expect(raceController.selectedTheme.value, equals('dark'));

      raceController.dispose();
    });

    test('9. P2-03: Choices cannot change while save operation is in-flight',
        () async {
      controller.setLanguage('id');
      controller.setTheme('light');

      controller.isSaving.value = true;

      // Attempt to change language and theme while isSaving is true
      controller.setLanguage('en');
      controller.setTheme('dark');

      // Selections remain unchanged
      expect(controller.selectedLanguage.value, equals('id'));
      expect(controller.selectedTheme.value, equals('light'));

      controller.isSaving.value = false;

      // Once isSaving is false, updates succeed
      controller.setLanguage('en');
      controller.setTheme('dark');
      expect(controller.selectedLanguage.value, equals('en'));
      expect(controller.selectedTheme.value, equals('dark'));
    });

    test(
        '10. P1-03: confirmAndSave is rejected while preference load is in-flight',
        () async {
      fakeRepo.getPreferencesCompleter = Completer<V2InitialPreferencesModel>();

      // Incomplete saved preferences from prior session
      fakeRepo.current = const V2InitialPreferencesModel(
        isCompleted: false,
        languageCode: 'en',
        themeMode: 'dark',
      );

      final raceController = V2InitialPreferencesController(
        repository: fakeRepo,
        autoLoad: true,
      );

      // Verify that read is currently in flight
      expect(raceController.isLoadingPreferences.value, isTrue);

      // Attempt to confirm and save prematurely while read is pending
      final earlySaveResult = await raceController.confirmAndSave();

      // Must be rejected immediately
      expect(earlySaveResult, isFalse);
      expect(fakeRepo.saveCount, equals(0));
      expect(fakeRepo.current.isCompleted, isFalse);

      // Resolve the pending disk read to 'en' and 'dark'
      fakeRepo.getPreferencesCompleter!.complete(fakeRepo.current);
      await Future.delayed(const Duration(milliseconds: 10));

      // Read completed, preferences are loaded
      expect(raceController.isLoadingPreferences.value, isFalse);
      expect(raceController.selectedLanguage.value, equals('en'));
      expect(raceController.selectedTheme.value, equals('dark'));

      // Now confirming saves the restored 'en' / 'dark' choices and marks completed
      final saveResult = await raceController.confirmAndSave();
      expect(saveResult, isTrue);
      expect(fakeRepo.saveCount, equals(1));
      expect(fakeRepo.current.isCompleted, isTrue);
      expect(fakeRepo.current.languageCode, equals('en'));
      expect(fakeRepo.current.themeMode, equals('dark'));

      raceController.dispose();
    });
  });
}
