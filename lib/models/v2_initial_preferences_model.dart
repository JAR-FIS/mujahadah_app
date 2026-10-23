import 'package:flutter/foundation.dart';

/// Immutable model capturing initial application launch preferences.
///
/// Tracks completion status, selected language, and selected theme mode.
@immutable
class V2InitialPreferencesModel {
  static const String defaultLanguage = 'id';
  static const String defaultTheme = 'light';

  static const String themeLight = 'light';
  static const String themeDark = 'dark';

  static const String languageId = 'id';
  static const String languageEn = 'en';

  /// Approved language codes.
  static const List<String> supportedLanguages = [languageId, languageEn];

  /// Approved theme modes.
  static const List<String> supportedThemes = [themeLight, themeDark];

  /// Validates whether the language code is supported.
  static bool isValidLanguage(String? code) =>
      code != null && supportedLanguages.contains(code);

  /// Validates whether the theme mode is supported.
  static bool isValidTheme(String? mode) =>
      mode != null && supportedThemes.contains(mode);

  /// Normalizes language code to an approved value or default.
  static String normalizeLanguage(String? code) =>
      isValidLanguage(code) ? code! : defaultLanguage;

  /// Normalizes theme mode to an approved value or default.
  static String normalizeTheme(String? mode) =>
      isValidTheme(mode) ? mode! : defaultTheme;

  final bool isCompleted;
  final String languageCode;
  final String themeMode;

  const V2InitialPreferencesModel({
    this.isCompleted = false,
    this.languageCode = defaultLanguage,
    this.themeMode = defaultTheme,
  });

  /// Factory creating initial fresh state.
  factory V2InitialPreferencesModel.initial() {
    return const V2InitialPreferencesModel(
      isCompleted: false,
      languageCode: defaultLanguage,
      themeMode: defaultTheme,
    );
  }

  /// Creates a copy with the given fields replaced by new values.
  V2InitialPreferencesModel copyWith({
    bool? isCompleted,
    String? languageCode,
    String? themeMode,
  }) {
    return V2InitialPreferencesModel(
      isCompleted: isCompleted ?? this.isCompleted,
      languageCode: languageCode ?? this.languageCode,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  /// Whether dark theme is currently selected.
  bool get isDarkMode => themeMode == themeDark;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is V2InitialPreferencesModel &&
          runtimeType == other.runtimeType &&
          isCompleted == other.isCompleted &&
          languageCode == other.languageCode &&
          themeMode == other.themeMode;

  @override
  int get hashCode => Object.hash(isCompleted, languageCode, themeMode);

  @override
  String toString() {
    return 'V2InitialPreferencesModel('
        'isCompleted: $isCompleted, '
        'languageCode: $languageCode, '
        'themeMode: $themeMode)';
  }
}
