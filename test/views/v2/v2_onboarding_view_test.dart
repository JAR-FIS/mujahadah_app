import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mujahadah/controllers/v2_onboarding_controller.dart';
import 'package:mujahadah/repositories/v2_onboarding_repository.dart';
import 'package:mujahadah/theme/v2_theme.dart';
import 'package:mujahadah/views/v2/onboarding/v2_onboarding_view.dart';

class MockOnboardingRepository implements V2OnboardingRepository {
  bool completed = false;
  int saveCount = 0;
  bool shouldFail = false;
  Completer<void>? saveCompleter;

  @override
  Future<bool> isCompleted() async => completed;

  @override
  Future<void> setCompleted(bool value) async {
    saveCount++;
    if (saveCompleter != null) {
      await saveCompleter!.future;
    }
    if (shouldFail) {
      throw Exception('Simulated disk write error');
    }
    completed = value;
  }

  @override
  Future<void> clear() async {
    completed = false;
  }
}

void main() {
  setUp(() {
    Get.reset();
  });

  Widget buildTestWidget({
    V2OnboardingController? controller,
    V2OnboardingRepository? repository,
    VoidCallback? onCompleted,
    String? languageCode,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return GetMaterialApp(
      theme: V2Theme.lightTheme,
      darkTheme: V2Theme.darkTheme,
      themeMode: themeMode,
      home: V2OnboardingView(
        controller: controller,
        repository: repository,
        onCompleted: onCompleted,
        languageCode: languageCode,
      ),
    );
  }

  group('V2OnboardingView Widget Tests', () {
    testWidgets(
        '1. Screen 1 renders approved title, badge, hero emblem, and CTA hierarchy',
        (tester) async {
      final repo = MockOnboardingRepository();
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await tester.pumpAndSettle();

      // Screen is present
      expect(
          find.byKey(const ValueKey('v2_onboarding_screen')), findsOneWidget);

      // Title & Badge on Screen 1
      expect(find.text('Selamat Datang di Mujahadah'), findsOneWidget);
      expect(find.text('Aplikasi Mujahadah'), findsOneWidget);

      // Progress Indicator
      expect(
        find.byKey(const ValueKey('v2_onboarding_progress_indicator')),
        findsOneWidget,
      );
      expect(find.text('Halaman 1 dari 5'), findsOneWidget);

      // No fallback notice for Indonesian
      expect(
        find.byKey(const ValueKey('v2_onboarding_fallback_notice')),
        findsNothing,
      );

      // Next button is visible, Back button is NOT visible on screen 1
      expect(
        find.byKey(const ValueKey('v2_onboarding_next_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('v2_onboarding_back_button')),
        findsNothing,
      );
    });

    testWidgets(
        '2. Tapping Lanjut transitions to Screen 2 and reveals Kembali button',
        (tester) async {
      final repo = MockOnboardingRepository();
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await tester.pumpAndSettle();

      // Tap Next
      await tester.tap(find.byKey(const ValueKey('v2_onboarding_next_button')));
      await tester.pumpAndSettle();

      // Screen 2 content is displayed
      expect(
        find.text('Bangun Istiqomah dengan Target yang Jelas'),
        findsOneWidget,
      );
      expect(find.text('Target Bertahap'), findsOneWidget);
      expect(find.text('Halaman 2 dari 5'), findsOneWidget);

      // Kembali button is now visible
      expect(
        find.byKey(const ValueKey('v2_onboarding_back_button')),
        findsOneWidget,
      );

      // Tap Back returns to Screen 1
      await tester.tap(find.byKey(const ValueKey('v2_onboarding_back_button')));
      await tester.pumpAndSettle();

      expect(find.text('Selamat Datang di Mujahadah'), findsOneWidget);
      expect(find.text('Halaman 1 dari 5'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('v2_onboarding_back_button')),
        findsNothing,
      );
    });

    testWidgets(
        '3. Step-by-step navigation visits all 5 screens with approved titles and P1-01 Piagam rule',
        (tester) async {
      final repo = MockOnboardingRepository();
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await tester.pumpAndSettle();

      // Screen 1
      expect(find.text('Selamat Datang di Mujahadah'), findsOneWidget);

      // Screen 2
      await tester.tap(find.byKey(const ValueKey('v2_onboarding_next_button')));
      await tester.pumpAndSettle();
      expect(
        find.text('Bangun Istiqomah dengan Target yang Jelas'),
        findsOneWidget,
      );

      // Screen 3
      await tester.tap(find.byKey(const ValueKey('v2_onboarding_next_button')));
      await tester.pumpAndSettle();
      expect(find.text('Check-in, Ingat, dan Jangan Terlewat'), findsOneWidget);
      expect(find.text('Disiplin Waktu'), findsOneWidget);

      // Screen 4
      await tester.tap(find.byKey(const ValueKey('v2_onboarding_next_button')));
      await tester.pumpAndSettle();
      expect(find.text('Muhasabah, Bukan Sekadar Streak'), findsOneWidget);
      expect(find.text('Evaluasi Diri'), findsOneWidget);

      // Screen 5
      await tester.tap(find.byKey(const ValueKey('v2_onboarding_next_button')));
      await tester.pumpAndSettle();
      expect(
        find.text('Lihat Perjalanan dan Rayakan Milestone'),
        findsOneWidget,
      );
      expect(find.text('Apresiasi & Rekam Jejak'), findsOneWidget);
      expect(find.text('Halaman 5 dari 5'), findsOneWidget);

      // Verify P1-01: Piagam promise reflects target completion rule
      expect(
        find.textContaining(
            'raih Piagam Istiqomah saat berhasil menyelesaikan target program'),
        findsOneWidget,
      );
      expect(
        find.textContaining('di setiap pencapaian milestone'),
        findsNothing,
      );

      // On screen 5, Finish button replaces Next button
      expect(
        find.byKey(const ValueKey('v2_onboarding_finish_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('v2_onboarding_next_button')),
        findsNothing,
      );
    });

    testWidgets(
        '4. Tapping Mulai Perjalanan on screen 5 saves completion and invokes callback',
        (tester) async {
      final repo = MockOnboardingRepository();
      bool completedCallbackInvoked = false;

      await tester.pumpWidget(
        buildTestWidget(
          repository: repo,
          onCompleted: () => completedCallbackInvoked = true,
        ),
      );
      await tester.pumpAndSettle();

      // Advance to page 5
      for (int i = 0; i < 4; i++) {
        await tester
            .tap(find.byKey(const ValueKey('v2_onboarding_next_button')));
        await tester.pumpAndSettle();
      }

      expect(
        find.byKey(const ValueKey('v2_onboarding_finish_button')),
        findsOneWidget,
      );
      expect(repo.completed, isFalse);

      // Tap Finish button
      await tester
          .tap(find.byKey(const ValueKey('v2_onboarding_finish_button')));
      await tester.pumpAndSettle();

      expect(repo.saveCount, equals(1));
      expect(repo.completed, isTrue);
      expect(completedCallbackInvoked, isTrue);
    });

    testWidgets(
        '5. Rapid duplicate taps on Mulai Perjalanan trigger only a single persistence call',
        (tester) async {
      final repo = MockOnboardingRepository();
      repo.saveCompleter = Completer<void>();

      await tester.pumpWidget(buildTestWidget(repository: repo));
      await tester.pumpAndSettle();

      // Navigate to screen 5
      for (int i = 0; i < 4; i++) {
        await tester
            .tap(find.byKey(const ValueKey('v2_onboarding_next_button')));
        await tester.pumpAndSettle();
      }

      // Tap finish multiple times rapidly
      await tester
          .tap(find.byKey(const ValueKey('v2_onboarding_finish_button')));
      await tester.pump();
      await tester
          .tap(find.byKey(const ValueKey('v2_onboarding_finish_button')));
      await tester.pump();

      // Only 1 save was triggered
      expect(repo.saveCount, equals(1));

      // Resolve in-flight save
      repo.saveCompleter!.complete();
      await tester.pumpAndSettle();

      expect(repo.saveCount, equals(1));
      expect(repo.completed, isTrue);
    });

    testWidgets(
        '6. Storage failure renders error banner and does not invoke callback',
        (tester) async {
      final repo = MockOnboardingRepository();
      repo.shouldFail = true;
      bool completedCallbackInvoked = false;

      await tester.pumpWidget(
        buildTestWidget(
          repository: repo,
          onCompleted: () => completedCallbackInvoked = true,
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to screen 5
      for (int i = 0; i < 4; i++) {
        await tester
            .tap(find.byKey(const ValueKey('v2_onboarding_next_button')));
        await tester.pumpAndSettle();
      }

      // Tap finish
      await tester
          .tap(find.byKey(const ValueKey('v2_onboarding_finish_button')));
      await tester.pumpAndSettle();

      // Error banner is displayed
      expect(
        find.byKey(const ValueKey('v2_onboarding_error_banner')),
        findsOneWidget,
      );
      expect(
        find.text('Gagal menyimpan status onboarding. Silakan coba lagi.'),
        findsOneWidget,
      );
      expect(repo.completed, isFalse);
      expect(completedCallbackInvoked, isFalse);
    });

    testWidgets('7. Accessible touch targets are at least 48dp on all buttons',
        (tester) async {
      final repo = MockOnboardingRepository();
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await tester.pumpAndSettle();

      // Next button height >= 48dp
      final nextSize = tester.getSize(
        find.byKey(const ValueKey('v2_onboarding_next_button')),
      );
      expect(nextSize.height, greaterThanOrEqualTo(48.0));

      // Advance to screen 2 to check back button
      await tester.tap(find.byKey(const ValueKey('v2_onboarding_next_button')));
      await tester.pumpAndSettle();

      final backSize = tester.getSize(
        find.byKey(const ValueKey('v2_onboarding_back_button')),
      );
      expect(backSize.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('8. Renders responsively on compact screen (320x480 dp)',
        (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = MockOnboardingRepository();
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Selamat Datang di Mujahadah'), findsOneWidget);
    });

    testWidgets('9. Renders cleanly with Dark Theme without error',
        (tester) async {
      final repo = MockOnboardingRepository();
      await tester.pumpWidget(
        buildTestWidget(
          repository: repo,
          themeMode: ThemeMode.dark,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Selamat Datang di Mujahadah'), findsOneWidget);
    });

    testWidgets(
        '10. Arabic language configuration applies RTL directionality and layout',
        (tester) async {
      final repo = MockOnboardingRepository();
      await tester.pumpWidget(
        buildTestWidget(
          repository: repo,
          languageCode: 'ar',
        ),
      );
      await tester.pumpAndSettle();

      // Finds Directionality ancestor with RTL
      final directionalityFinder = find.byWidgetPredicate(
        (w) => w is Directionality && w.textDirection == TextDirection.rtl,
      );
      expect(directionalityFinder, findsWidgets);

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '11. P1-02: Delayed and failing save prevents swipe, keeps PageView & CTA synchronized, and retry succeeds',
        (tester) async {
      final repo = MockOnboardingRepository();
      repo.saveCompleter = Completer<void>();
      repo.shouldFail = true;
      bool completedCallback = false;

      await tester.pumpWidget(
        buildTestWidget(
          repository: repo,
          onCompleted: () => completedCallback = true,
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to screen 5
      for (int i = 0; i < 4; i++) {
        await tester
            .tap(find.byKey(const ValueKey('v2_onboarding_next_button')));
        await tester.pumpAndSettle();
      }

      expect(find.text('Halaman 5 dari 5'), findsOneWidget);
      final finishBtn =
          find.byKey(const ValueKey('v2_onboarding_finish_button'));
      expect(finishBtn, findsOneWidget);

      // Tap Mulai Perjalanan to start save
      await tester.tap(finishBtn);
      await tester.pump();

      // Attempt to drag/swipe back to screen 4 while save is in flight
      await tester.drag(find.byType(PageView), const Offset(300, 0));
      await tester.pump();

      // PageView has NeverScrollableScrollPhysics, so swipe was rejected
      // Complete save with error
      repo.saveCompleter!.complete();
      await tester.pumpAndSettle();

      // Verify that after failure, viewport, progress, and CTA are all on screen 5
      expect(find.text('Halaman 5 dari 5'), findsOneWidget);
      expect(
        find.text('Lihat Perjalanan dan Rayakan Milestone'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('v2_onboarding_finish_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('v2_onboarding_error_banner')),
        findsOneWidget,
      );
      expect(completedCallback, isFalse);

      // Retry save with working repository
      repo.shouldFail = false;
      repo.saveCompleter = null;

      await tester
          .tap(find.byKey(const ValueKey('v2_onboarding_finish_button')));
      await tester.pumpAndSettle();

      expect(repo.saveCount, equals(2));
      expect(repo.completed, isTrue);
      expect(completedCallback, isTrue);
    });

    testWidgets(
        '12. P2-01: Sequential second tap after successful completion is guarded and idempotent',
        (tester) async {
      final repo = MockOnboardingRepository();
      int completedCallbackCount = 0;

      await tester.pumpWidget(
        buildTestWidget(
          repository: repo,
          onCompleted: () => completedCallbackCount++,
        ),
      );
      await tester.pumpAndSettle();

      // Advance to page 5
      for (int i = 0; i < 4; i++) {
        await tester
            .tap(find.byKey(const ValueKey('v2_onboarding_next_button')));
        await tester.pumpAndSettle();
      }

      final finishBtn =
          find.byKey(const ValueKey('v2_onboarding_finish_button'));

      // First tap succeeds
      await tester.tap(finishBtn);
      await tester.pumpAndSettle();

      expect(repo.saveCount, equals(1));
      expect(completedCallbackCount, equals(1));

      // Button is now disabled (onPressed is null)
      final elevatedBtn = tester.widget<ElevatedButton>(finishBtn);
      expect(elevatedBtn.onPressed, isNull);

      // Attempt sequential second tap
      await tester.tap(finishBtn, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Does not persist again and does not trigger callback again
      expect(repo.saveCount, equals(1));
      expect(completedCallbackCount, equals(1));
    });

    testWidgets(
        '13. P2-02: Fallback notice banner is rendered for fallback languages with readable LTR text in RTL mode',
        (tester) async {
      final repo = MockOnboardingRepository();

      // Test English fallback notice
      await tester.pumpWidget(
        buildTestWidget(
          repository: repo,
          languageCode: 'en',
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('v2_onboarding_fallback_notice')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Terjemahan bahasa ini sedang disiapkan. Teks sementara ditampilkan dalam Bahasa Indonesia.',
        ),
        findsOneWidget,
      );

      // Test Arabic fallback notice with LTR text inside RTL shell
      await tester.pumpWidget(
        buildTestWidget(
          repository: repo,
          languageCode: 'ar',
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('v2_onboarding_fallback_notice')),
        findsOneWidget,
      );

      // Fallback Indonesian notice text widget explicitly has TextDirection.ltr
      final noticeTextWidget = tester.widget<Text>(
        find.text(
          'Terjemahan bahasa ini sedang disiapkan. Teks sementara ditampilkan dalam Bahasa Indonesia.',
        ),
      );
      expect(noticeTextWidget.textDirection, equals(TextDirection.ltr));
    });
  });
}
