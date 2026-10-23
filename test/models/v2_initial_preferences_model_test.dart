import 'package:flutter_test/flutter_test.dart';
import 'package:mujahadah/models/v2_initial_preferences_model.dart';

void main() {
  group('V2InitialPreferencesModel Tests', () {
    test('1. Initial factory produces default state with isCompleted false',
        () {
      final model = V2InitialPreferencesModel.initial();

      expect(model.isCompleted, isFalse);
      expect(model.languageCode, equals('id'));
      expect(model.themeMode, equals('light'));
      expect(model.isDarkMode, isFalse);
    });

    test('2. Supported languages and themes contain approved values', () {
      expect(V2InitialPreferencesModel.supportedLanguages,
          containsAll(['id', 'en']));
      expect(V2InitialPreferencesModel.supportedThemes,
          containsAll(['light', 'dark']));
    });

    test('3. copyWith creates accurate copies with updated fields', () {
      final initial = V2InitialPreferencesModel.initial();

      final updated = initial.copyWith(
        isCompleted: true,
        languageCode: 'en',
        themeMode: 'dark',
      );

      expect(updated.isCompleted, isTrue);
      expect(updated.languageCode, equals('en'));
      expect(updated.themeMode, equals('dark'));
      expect(updated.isDarkMode, isTrue);

      // Verify immutability of original
      expect(initial.isCompleted, isFalse);
      expect(initial.languageCode, equals('id'));
      expect(initial.themeMode, equals('light'));
    });

    test('4. Value equality and hashCode behavior', () {
      const a = V2InitialPreferencesModel(
        isCompleted: true,
        languageCode: 'id',
        themeMode: 'dark',
      );
      const b = V2InitialPreferencesModel(
        isCompleted: true,
        languageCode: 'id',
        themeMode: 'dark',
      );
      const c = V2InitialPreferencesModel(
        isCompleted: false,
        languageCode: 'id',
        themeMode: 'dark',
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('5. toString representation', () {
      const model = V2InitialPreferencesModel(
        isCompleted: true,
        languageCode: 'id',
        themeMode: 'light',
      );

      expect(
        model.toString(),
        equals(
            'V2InitialPreferencesModel(isCompleted: true, languageCode: id, themeMode: light)'),
      );
    });

    test('6. Validation and normalization helpers', () {
      expect(V2InitialPreferencesModel.isValidLanguage('id'), isTrue);
      expect(V2InitialPreferencesModel.isValidLanguage('en'), isTrue);
      expect(V2InitialPreferencesModel.isValidLanguage('fr'), isFalse);
      expect(V2InitialPreferencesModel.isValidLanguage(null), isFalse);

      expect(V2InitialPreferencesModel.isValidTheme('light'), isTrue);
      expect(V2InitialPreferencesModel.isValidTheme('dark'), isTrue);
      expect(V2InitialPreferencesModel.isValidTheme('system'), isFalse);
      expect(V2InitialPreferencesModel.isValidTheme(null), isFalse);

      expect(V2InitialPreferencesModel.normalizeLanguage('en'), equals('en'));
      expect(
          V2InitialPreferencesModel.normalizeLanguage('invalid'), equals('id'));
      expect(V2InitialPreferencesModel.normalizeLanguage(null), equals('id'));

      expect(V2InitialPreferencesModel.normalizeTheme('dark'), equals('dark'));
      expect(V2InitialPreferencesModel.normalizeTheme('auto'), equals('light'));
      expect(V2InitialPreferencesModel.normalizeTheme(null), equals('light'));
    });
  });
}
