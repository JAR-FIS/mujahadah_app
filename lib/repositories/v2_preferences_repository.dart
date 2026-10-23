import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../controllers/theme_controller.dart';
import '../models/v2_initial_preferences_model.dart';

/// Abstract contract for managing V2 application launch preferences.
abstract class V2PreferencesRepository {
  /// Loads current initial launch preferences from persistent storage.
  Future<V2InitialPreferencesModel> getPreferences();

  /// Returns whether initial launch preferences have already been completed.
  Future<bool> isCompleted();

  /// Persists the selected launch preferences and marks initial setup as completed.
  Future<void> savePreferences(V2InitialPreferencesModel preferences);

  /// Directly updates the completion flag.
  Future<void> setCompleted(bool completed);

  /// Clears initial launch preferences (useful for testing or profile reset).
  Future<void> clear();
}

/// Hive-backed implementation of [V2PreferencesRepository].
///
/// Stores values under namespaced keys in the settings box to prevent collision
/// with legacy data while maintaining seamless cross-sync with [ThemeController].
class HiveV2PreferencesRepository implements V2PreferencesRepository {
  static const String defaultBoxName = 'settings';

  static const String keyCompleted = 'v2_initial_preferences_completed';
  static const String keyLanguage = 'v2_app_language_code';
  static const String keyTheme = 'v2_app_theme_mode';
  static const String keyV1IsDarkMode = 'isDarkMode';

  final Box? _explicitBox;
  final Future<void> Function(String key, dynamic value)? onBeforePut;

  HiveV2PreferencesRepository({
    Box? box,
    this.onBeforePut,
  }) : _explicitBox = box;

  Box get _box {
    if (_explicitBox != null) return _explicitBox!;
    if (Hive.isBoxOpen(defaultBoxName)) {
      return Hive.box(defaultBoxName);
    }
    throw StateError(
      'Hive box "$defaultBoxName" is not opened. Ensure Hive is initialized '
      'or provide an explicit Box instance.',
    );
  }

  @override
  Future<V2InitialPreferencesModel> getPreferences() async {
    final rawCompleted = _box.get(keyCompleted, defaultValue: false);
    final completed = rawCompleted is bool ? rawCompleted : false;

    final rawLanguage = _box.get(keyLanguage,
        defaultValue: V2InitialPreferencesModel.defaultLanguage);
    final language = V2InitialPreferencesModel.normalizeLanguage(
        rawLanguage is String ? rawLanguage : null);

    final rawTheme = _box.get(keyTheme,
        defaultValue: V2InitialPreferencesModel.defaultTheme);
    final theme = V2InitialPreferencesModel.normalizeTheme(
        rawTheme is String ? rawTheme : null);

    return V2InitialPreferencesModel(
      isCompleted: completed,
      languageCode: language,
      themeMode: theme,
    );
  }

  @override
  Future<bool> isCompleted() async {
    final raw = _box.get(keyCompleted, defaultValue: false);
    return raw is bool ? raw : false;
  }

  @override
  Future<void> savePreferences(V2InitialPreferencesModel preferences) async {
    final validatedLanguage =
        V2InitialPreferencesModel.normalizeLanguage(preferences.languageCode);
    final validatedTheme =
        V2InitialPreferencesModel.normalizeTheme(preferences.themeMode);
    final isDark = validatedTheme == V2InitialPreferencesModel.themeDark;

    // 1. Persist the language and theme values first
    await _putWithHook(keyLanguage, validatedLanguage);
    await _putWithHook(keyTheme, validatedTheme);

    // 2. Cross-sync legacy isDarkMode to keep V1 AppTheme & GetMaterialApp in sync
    await _putWithHook(keyV1IsDarkMode, isDark);

    // 3. Mark completed ONLY AFTER choices are successfully written (final storage marker)
    await _putWithHook(keyCompleted, preferences.isCompleted);

    // 4. Safely propagate theme mode through GetX so UI errors do not mask successful commit
    try {
      _applyThemeChange(isDark);
    } catch (_) {
      // Non-fatal: durable persistence has succeeded even if UI theme transition failed
    }
  }

  Future<void> _putWithHook(String key, dynamic value) async {
    if (onBeforePut != null) {
      await onBeforePut!(key, value);
    }
    await _box.put(key, value);
  }

  @override
  Future<void> setCompleted(bool completed) async {
    await _putWithHook(keyCompleted, completed);
  }

  @override
  Future<void> clear() async {
    await _box.delete(keyCompleted);
    await _box.delete(keyLanguage);
    await _box.delete(keyTheme);
  }

  void _applyThemeChange(bool isDark) {
    if (Get.isRegistered<ThemeController>()) {
      final themeCtrl = Get.find<ThemeController>();
      themeCtrl.isDarkMode.value = isDark;
    }
    Get.changeThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }
}
