import 'package:get/get.dart';

import '../models/v2_initial_preferences_model.dart';
import '../repositories/v2_preferences_repository.dart';

/// GetX controller managing user selections and persistence on the Initial Preferences screen.
///
/// Features single-flight save protection, isolated error tracking, and immediate theme application.
class V2InitialPreferencesController extends GetxController {
  final V2PreferencesRepository repository;

  final RxString selectedLanguage =
      V2InitialPreferencesModel.defaultLanguage.obs;
  final RxString selectedTheme = V2InitialPreferencesModel.defaultTheme.obs;
  final RxBool isSaving = false.obs;
  final RxBool isLoadingPreferences = false.obs;
  final RxString errorMessage = ''.obs;

  bool _userHasSelectedLanguage = false;
  bool _userHasSelectedTheme = false;
  bool _hasLoadedOnce = false;
  int _loadVersion = 0;

  bool get userHasSelectedLanguage => _userHasSelectedLanguage;
  bool get userHasSelectedTheme => _userHasSelectedTheme;

  V2InitialPreferencesController({
    required this.repository,
    bool autoLoad = true,
  }) {
    if (autoLoad) {
      loadExistingPreferences();
    }
  }

  @override
  void onInit() {
    super.onInit();
    if (!_hasLoadedOnce) {
      loadExistingPreferences();
    }
  }

  /// Loads current preferences or defaults from repository.
  ///
  /// Preserves any explicit user interaction that took place before or during
  /// this asynchronous disk read to prevent race condition overwrites.
  Future<void> loadExistingPreferences() async {
    final version = ++_loadVersion;
    isLoadingPreferences.value = true;
    try {
      final prefs = await repository.getPreferences();
      if (version != _loadVersion) return;
      _hasLoadedOnce = true;
      if (!_userHasSelectedLanguage) {
        selectedLanguage.value = prefs.languageCode;
      }
      if (!_userHasSelectedTheme) {
        selectedTheme.value = prefs.themeMode;
      }
    } catch (_) {
      if (version != _loadVersion) return;
      _hasLoadedOnce = true;
      if (!_userHasSelectedLanguage) {
        selectedLanguage.value = V2InitialPreferencesModel.defaultLanguage;
      }
      if (!_userHasSelectedTheme) {
        selectedTheme.value = V2InitialPreferencesModel.defaultTheme;
      }
    } finally {
      if (version == _loadVersion) {
        isLoadingPreferences.value = false;
      }
    }
  }

  /// Updates selected language code.
  ///
  /// Frozen while a save operation is in-flight.
  void setLanguage(String code) {
    if (isSaving.value) return;
    if (V2InitialPreferencesModel.isValidLanguage(code)) {
      _userHasSelectedLanguage = true;
      selectedLanguage.value = code;
      errorMessage.value = '';
    }
  }

  /// Updates selected theme mode ('light' or 'dark').
  ///
  /// Frozen while a save operation is in-flight.
  void setTheme(String mode) {
    if (isSaving.value) return;
    if (V2InitialPreferencesModel.isValidTheme(mode)) {
      _userHasSelectedTheme = true;
      selectedTheme.value = mode;
      errorMessage.value = '';
    }
  }

  /// Whether current theme selection is Dark.
  bool get isDarkMode =>
      selectedTheme.value == V2InitialPreferencesModel.themeDark;

  /// Durable persistence triggered when user taps 'Mulai'.
  ///
  /// Protected against duplicate/rapid taps.
  /// Returns `true` only if persistence succeeded completely.
  Future<bool> confirmAndSave() async {
    if (isSaving.value || isLoadingPreferences.value) return false;

    isSaving.value = true;
    errorMessage.value = '';

    try {
      final preferences = V2InitialPreferencesModel(
        isCompleted: true,
        languageCode: selectedLanguage.value,
        themeMode: selectedTheme.value,
      );

      await repository.savePreferences(preferences);
      isSaving.value = false;
      return true;
    } catch (e) {
      isSaving.value = false;
      errorMessage.value =
          'Gagal menyimpan preferensi. Silakan periksa penyimpanan dan coba lagi.';
      return false;
    }
  }

  /// Clears any active error message.
  void clearError() {
    errorMessage.value = '';
  }
}
