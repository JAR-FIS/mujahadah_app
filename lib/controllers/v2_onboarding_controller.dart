import 'package:get/get.dart';

import '../models/v2_onboarding_model.dart';
import '../repositories/v2_onboarding_repository.dart';

/// GetX controller managing user progress, translatable copy, and completion
/// persistence across the 5-screen V2 onboarding flow.
class V2OnboardingController extends GetxController {
  final V2OnboardingRepository repository;
  final String languageCode;
  final V2OnboardingStrings strings;

  final RxInt currentIndex = 0.obs;
  final RxBool isSaving = false.obs;
  final RxBool isCompleted = false.obs;
  final RxString errorMessage = ''.obs;

  V2OnboardingController({
    required this.repository,
    String? languageCode,
    V2OnboardingStrings? strings,
  })  : languageCode = V2OnboardingModel.normalizeLanguage(languageCode),
        strings = strings ?? V2OnboardingModel.stringsFor(languageCode);

  /// Total number of approved onboarding pages (5 screens).
  int get totalPages => strings.pages.length;

  /// Whether user is currently on the very first screen.
  bool get isFirstPage => currentIndex.value == 0;

  /// Whether user is currently on the final screen (screen 5).
  bool get isLastPage => currentIndex.value == totalPages - 1;

  /// Whether layout should render with Right-to-Left (RTL) directionality.
  bool get isRtl => strings.isRtl;

  /// Active page content for the current step.
  V2OnboardingPageContent get currentPage => strings.pages[currentIndex.value];

  /// Advances to the next onboarding page if not on the last page.
  void nextPage() {
    if (isSaving.value) return;
    if (currentIndex.value < totalPages - 1) {
      currentIndex.value++;
      errorMessage.value = '';
    }
  }

  /// Returns to the previous onboarding page if not on the first page.
  void previousPage() {
    if (isSaving.value) return;
    if (currentIndex.value > 0) {
      currentIndex.value--;
      errorMessage.value = '';
    }
  }

  /// Sets the active page directly (used for PageView transitions or step indicator taps).
  void goToPage(int page) {
    if (isSaving.value) return;
    if (page >= 0 && page < totalPages) {
      currentIndex.value = page;
      errorMessage.value = '';
    }
  }

  /// Completes onboarding on the final screen and persists state to Hive.
  ///
  /// Protected against duplicate/rapid taps and premature submission before reaching
  /// the final page. Returns `true` only if persistence succeeded completely.
  Future<bool> completeOnboarding() async {
    if (isSaving.value || isCompleted.value) return false;
    if (!isLastPage) return false;

    isSaving.value = true;
    errorMessage.value = '';

    try {
      await repository.setCompleted(true);
      isCompleted.value = true;
      isSaving.value = false;
      return true;
    } catch (_) {
      isSaving.value = false;
      errorMessage.value = strings.saveErrorMessage;
      return false;
    }
  }

  /// Clears any active error banner.
  void clearError() {
    errorMessage.value = '';
  }
}
