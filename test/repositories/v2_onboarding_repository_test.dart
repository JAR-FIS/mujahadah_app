import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mujahadah/repositories/v2_onboarding_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box settingsBox;
  late HiveV2OnboardingRepository repository;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('v2_onboarding_repo_test_');
    Hive.init(tempDir.path);
    settingsBox = await Hive.openBox('settings');
    repository = HiveV2OnboardingRepository(box: settingsBox);
  });

  tearDown(() async {
    await settingsBox.close();
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('HiveV2OnboardingRepository Tests', () {
    test('1. Fresh launch returns isCompleted false', () async {
      final completed = await repository.isCompleted();
      expect(completed, isFalse);
    });

    test('2. setCompleted persists true under v2_onboarding_completed key',
        () async {
      await repository.setCompleted(true);

      final completed = await repository.isCompleted();
      expect(completed, isTrue);

      final raw = settingsBox.get('v2_onboarding_completed');
      expect(raw, isTrue);
    });

    test('3. clear() removes onboarding completed marker', () async {
      await repository.setCompleted(true);
      expect(await repository.isCompleted(), isTrue);

      await repository.clear();
      expect(await repository.isCompleted(), isFalse);
      expect(settingsBox.containsKey('v2_onboarding_completed'), isFalse);
    });

    test(
        '4. Onboarding completion is strictly isolated from initial preferences',
        () async {
      // Set initial preferences flag in the same settings box
      await settingsBox.put('v2_initial_preferences_completed', true);

      // Onboarding is still false
      expect(await repository.isCompleted(), isFalse);

      // Complete onboarding
      await repository.setCompleted(true);
      expect(await repository.isCompleted(), isTrue);

      // Initial preferences flag remains unchanged
      expect(settingsBox.get('v2_initial_preferences_completed'), isTrue);
    });

    test(
        '5. Throws StateError when default box is unopened without explicit box',
        () async {
      await settingsBox.close();

      final unopenedRepo = HiveV2OnboardingRepository();
      expect(
        () => unopenedRepo.isCompleted(),
        throwsA(isA<StateError>()),
      );
    });

    test('6. onBeforePut hook can simulate failure during persistence',
        () async {
      final failureRepo = HiveV2OnboardingRepository(
        box: settingsBox,
        onBeforePut: (key, value) async {
          throw Exception('Disk I/O failure');
        },
      );

      expect(
        () => failureRepo.setCompleted(true),
        throwsA(isA<Exception>()),
      );

      // Value remains false
      expect(await repository.isCompleted(), isFalse);
    });
  });
}
