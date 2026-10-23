import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mujahadah/controllers/v2_onboarding_controller.dart';
import 'package:mujahadah/repositories/v2_onboarding_repository.dart';

class FakeOnboardingRepository implements V2OnboardingRepository {
  bool completed = false;
  int saveCount = 0;
  Completer<void>? setCompletedCompleter;
  bool shouldThrow = false;

  @override
  Future<bool> isCompleted() async => completed;

  @override
  Future<void> setCompleted(bool value) async {
    saveCount++;
    if (setCompletedCompleter != null) {
      await setCompletedCompleter!.future;
    }
    if (shouldThrow) {
      throw Exception('Simulated persistence write error');
    }
    completed = value;
  }

  @override
  Future<void> clear() async {
    completed = false;
  }
}

void main() {
  late FakeOnboardingRepository fakeRepo;
  late V2OnboardingController controller;

  setUp(() {
    fakeRepo = FakeOnboardingRepository();
    controller = V2OnboardingController(repository: fakeRepo);
  });

  group('V2OnboardingController Tests', () {
    test('1. Initial state defaults to page 0, uncompleted, and not saving',
        () {
      expect(controller.currentIndex.value, equals(0));
      expect(controller.isFirstPage, isTrue);
      expect(controller.isLastPage, isFalse);
      expect(controller.isSaving.value, isFalse);
      expect(controller.isCompleted.value, isFalse);
      expect(controller.errorMessage.value, isEmpty);
      expect(controller.totalPages, equals(5));
      expect(controller.currentPage.pageIndex, equals(0));
      expect(controller.isRtl, isFalse);
    });

    test('2. nextPage advances index incrementally up to maximum 4', () {
      expect(controller.currentIndex.value, equals(0));

      controller.nextPage();
      expect(controller.currentIndex.value, equals(1));
      expect(controller.isFirstPage, isFalse);

      controller.nextPage(); // 2
      controller.nextPage(); // 3
      controller.nextPage(); // 4
      expect(controller.currentIndex.value, equals(4));
      expect(controller.isLastPage, isTrue);

      // Attempting to advance beyond last page is ignored
      controller.nextPage();
      expect(controller.currentIndex.value, equals(4));
    });

    test('3. previousPage decrements index down to minimum 0', () {
      controller.goToPage(3);
      expect(controller.currentIndex.value, equals(3));

      controller.previousPage();
      expect(controller.currentIndex.value, equals(2));

      controller.previousPage();
      controller.previousPage();
      expect(controller.currentIndex.value, equals(0));
      expect(controller.isFirstPage, isTrue);

      // Attempting to decrement below 0 is ignored
      controller.previousPage();
      expect(controller.currentIndex.value, equals(0));
    });

    test('4. goToPage updates page safely within valid bounds', () {
      controller.goToPage(3);
      expect(controller.currentIndex.value, equals(3));

      // Out of bounds values are ignored
      controller.goToPage(10);
      expect(controller.currentIndex.value, equals(3));

      controller.goToPage(-1);
      expect(controller.currentIndex.value, equals(3));
    });

    test(
        '5. completeOnboarding is rejected prematurely if called before reaching final page',
        () async {
      controller.goToPage(2);
      expect(controller.isLastPage, isFalse);

      final result = await controller.completeOnboarding();
      expect(result, isFalse);
      expect(fakeRepo.saveCount, equals(0));
      expect(fakeRepo.completed, isFalse);
      expect(controller.isCompleted.value, isFalse);
    });

    test('6. completeOnboarding on final screen persists completion durably',
        () async {
      controller.goToPage(4);
      expect(controller.isLastPage, isTrue);

      final result = await controller.completeOnboarding();
      expect(result, isTrue);
      expect(fakeRepo.saveCount, equals(1));
      expect(fakeRepo.completed, isTrue);
      expect(controller.isCompleted.value, isTrue);
      expect(controller.isSaving.value, isFalse);
    });

    test(
        '7. Rapid duplicate taps during save are guarded against multiple persistence',
        () async {
      fakeRepo.setCompletedCompleter = Completer<void>();
      controller.goToPage(4);

      // Trigger first completion call
      final firstCall = controller.completeOnboarding();
      expect(controller.isSaving.value, isTrue);

      // Immediate second call while in flight
      final secondCall = controller.completeOnboarding();

      // Second call is rejected immediately
      final secondResult = await secondCall;
      expect(secondResult, isFalse);

      // Complete in-flight operation
      fakeRepo.setCompletedCompleter!.complete();
      final firstResult = await firstCall;

      expect(firstResult, isTrue);
      expect(fakeRepo.saveCount, equals(1));
    });

    test(
        '8. Persistence failure surfaces recoverable error message and leaves completed false',
        () async {
      fakeRepo.shouldThrow = true;
      controller.goToPage(4);

      final result = await controller.completeOnboarding();
      expect(result, isFalse);
      expect(controller.isCompleted.value, isFalse);
      expect(controller.isSaving.value, isFalse);
      expect(controller.errorMessage.value, isNotEmpty);
      expect(
        controller.errorMessage.value,
        equals(controller.strings.saveErrorMessage),
      );

      // Clear error resets message
      controller.clearError();
      expect(controller.errorMessage.value, isEmpty);
    });

    test('9. Arabic language code configures RTL directionality metadata', () {
      final arController = V2OnboardingController(
        repository: fakeRepo,
        languageCode: 'ar',
      );

      expect(arController.isRtl, isTrue);
      expect(arController.languageCode, equals('ar'));
      expect(arController.strings.isFullyLocalized, isFalse);
    });

    test(
        '10. P2-01: Sequential second call to completeOnboarding after success is idempotent',
        () async {
      controller.goToPage(4);

      final firstResult = await controller.completeOnboarding();
      expect(firstResult, isTrue);
      expect(fakeRepo.saveCount, equals(1));
      expect(controller.isCompleted.value, isTrue);

      // Sequential second call after save resolved
      final secondResult = await controller.completeOnboarding();
      expect(secondResult, isFalse);
      expect(fakeRepo.saveCount, equals(1)); // Does not persist again
    });
  });
}
