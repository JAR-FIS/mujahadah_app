import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mujahadah/core/runtime/v2_startup_coordinator.dart';
import 'package:mujahadah/models/v2_initial_preferences_model.dart';
import 'package:mujahadah/repositories/v2_preferences_repository.dart';
import 'package:mujahadah/views/v2/preferences/v2_initial_preferences_view.dart';

class StubPreferencesRepository implements V2PreferencesRepository {
  V2InitialPreferencesModel current;
  bool shouldThrowOnIsCompleted = false;

  StubPreferencesRepository({V2InitialPreferencesModel? initial})
      : current = initial ?? V2InitialPreferencesModel.initial();

  @override
  Future<V2InitialPreferencesModel> getPreferences() async => current;

  @override
  Future<bool> isCompleted() async {
    if (shouldThrowOnIsCompleted) {
      throw Exception('Simulated storage read error');
    }
    return current.isCompleted;
  }

  @override
  Future<void> savePreferences(V2InitialPreferencesModel preferences) async {
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
  setUp(() {
    Get.reset();
  });

  group('V2StartupCoordinator Unit Tests (P1-01 Fail-Closed)', () {
    test(
        '1. Fresh launch with uncompleted preferences resolves to initialPreferences',
        () async {
      final repo = StubPreferencesRepository();
      final coordinator = V2StartupCoordinator(preferencesRepository: repo);

      final stage = await coordinator.resolveStartupStage();

      expect(stage, equals(V2StartupStage.initialPreferences));
    });

    test(
        '2. Completed preferences with uncompleted onboarding resolves to onboarding',
        () async {
      final repo = StubPreferencesRepository(
        initial: const V2InitialPreferencesModel(isCompleted: true),
      );
      final coordinator = V2StartupCoordinator(
        preferencesRepository: repo,
        isOnboardingCompleted: () async => false,
      );

      final stage = await coordinator.resolveStartupStage();

      expect(stage, equals(V2StartupStage.onboarding));
    });

    test(
        '3. Completed onboarding with uncompleted profile resolves to profileSetup',
        () async {
      final repo = StubPreferencesRepository(
        initial: const V2InitialPreferencesModel(isCompleted: true),
      );
      final coordinator = V2StartupCoordinator(
        preferencesRepository: repo,
        isOnboardingCompleted: () async => true,
        isProfileCompleted: () async => false,
      );

      final stage = await coordinator.resolveStartupStage();

      expect(stage, equals(V2StartupStage.profileSetup));
    });

    test('4. All prerequisite stages completed resolves to mainApp', () async {
      final repo = StubPreferencesRepository(
        initial: const V2InitialPreferencesModel(isCompleted: true),
      );
      final coordinator = V2StartupCoordinator(
        preferencesRepository: repo,
        isOnboardingCompleted: () async => true,
        isProfileCompleted: () async => true,
      );

      final stage = await coordinator.resolveStartupStage();

      expect(stage, equals(V2StartupStage.mainApp));
    });

    test(
        '5. P1-01: Missing onboarding evaluator fails closed to unresolved, never mainApp',
        () async {
      final repo = StubPreferencesRepository(
        initial: const V2InitialPreferencesModel(isCompleted: true),
      );
      // Coordinator without onboarding evaluator
      final coordinator = V2StartupCoordinator(preferencesRepository: repo);

      final stage = await coordinator.resolveStartupStage();

      expect(stage, equals(V2StartupStage.unresolved));
      expect(stage, isNot(equals(V2StartupStage.mainApp)));
    });

    test(
        '5b. P1-01: Completed onboarding with missing profile evaluator fails closed to unresolved, never mainApp',
        () async {
      final repo = StubPreferencesRepository(
        initial: const V2InitialPreferencesModel(isCompleted: true),
      );
      final coordinator = V2StartupCoordinator(
        preferencesRepository: repo,
        isOnboardingCompleted: () async => true,
        // isProfileCompleted is null
      );

      final stage = await coordinator.resolveStartupStage();

      expect(stage, equals(V2StartupStage.unresolved));
      expect(stage, isNot(equals(V2StartupStage.mainApp)));
    });

    test('5c. P1-01: Failed evaluator throws and never resolves to mainApp',
        () async {
      final repo = StubPreferencesRepository(
        initial: const V2InitialPreferencesModel(isCompleted: true),
      );
      final coordinator = V2StartupCoordinator(
        preferencesRepository: repo,
        isOnboardingCompleted: () async =>
            throw Exception('Evaluator network crash'),
        isProfileCompleted: () async => true,
      );

      await expectLater(
          coordinator.resolveStartupStage(), throwsA(isA<Exception>()));
    });
  });

  group('V2StartupGate Widget Tests (P2-01 Recoverable Error & Retry)', () {
    testWidgets(
        '6. Fresh install builds initial preferences and transitions upon completion',
        (tester) async {
      final repo = StubPreferencesRepository();
      final coordinator = V2StartupCoordinator(
        preferencesRepository: repo,
        isOnboardingCompleted: () async => false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: V2StartupGate(
            coordinator: coordinator,
            onboardingBuilder: (_) => const Scaffold(
              body: Center(child: Text('Destination: Onboarding Stage')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially shows Initial Preferences View (S00A)
      expect(find.byType(V2InitialPreferencesView), findsOneWidget);
      expect(find.text('Destination: Onboarding Stage'), findsNothing);

      // Tap Mulai to complete preferences
      await tester.tap(find.byKey(const ValueKey('v2_init_pref_mulai_button')));
      await tester.pumpAndSettle();

      // Automatically transitions to Onboarding
      expect(find.byType(V2InitialPreferencesView), findsNothing);
      expect(find.text('Destination: Onboarding Stage'), findsOneWidget);
      expect(await repo.isCompleted(), isTrue);
    });

    testWidgets(
        '7. Returning user with completed preferences bypasses initial preferences',
        (tester) async {
      final repo = StubPreferencesRepository(
        initial: const V2InitialPreferencesModel(isCompleted: true),
      );
      final coordinator = V2StartupCoordinator(
        preferencesRepository: repo,
        isOnboardingCompleted: () async => true,
        isProfileCompleted: () async => true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: V2StartupGate(
            coordinator: coordinator,
            mainAppBuilder: (_) => const Scaffold(
              body: Center(child: Text('Destination: Main App Shell')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Bypasses Initial Preferences and directly displays destination
      expect(find.byType(V2InitialPreferencesView), findsNothing);
      expect(find.text('Destination: Main App Shell'), findsOneWidget);
    });

    testWidgets(
        '8. P2-01: Startup read failure renders error state with Coba Lagi retry button',
        (tester) async {
      final repo = StubPreferencesRepository();
      repo.shouldThrowOnIsCompleted = true; // Injected failure

      final coordinator = V2StartupCoordinator(
        preferencesRepository: repo,
        isOnboardingCompleted: () async => true,
        isProfileCompleted: () async => true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: V2StartupGate(
            coordinator: coordinator,
            mainAppBuilder: (_) => const Scaffold(
              body: Center(child: Text('Destination: Main App Shell')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Error UI is displayed
      expect(
        find.text(
            'Terjadi kesalahan saat memeriksa status aplikasi. Silakan coba lagi.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('v2_startup_gate_retry_button')),
          findsOneWidget);
      expect(find.text('Destination: Main App Shell'), findsNothing);

      // Clear the failure and tap retry
      repo.shouldThrowOnIsCompleted = false;
      await tester
          .tap(find.byKey(const ValueKey('v2_startup_gate_retry_button')));
      await tester.pumpAndSettle();

      // Successfully resolved after retry (fresh install -> Initial Preferences)
      expect(find.byType(V2InitialPreferencesView), findsOneWidget);
      expect(
        find.text(
            'Terjadi kesalahan saat memeriksa status aplikasi. Silakan coba lagi.'),
        findsNothing,
      );
    });

    testWidgets(
        '9. P1-01: Unresolved stage renders custom builder or fallback safely',
        (tester) async {
      final repo = StubPreferencesRepository(
        initial: const V2InitialPreferencesModel(isCompleted: true),
      );
      // Missing onboarding evaluator -> unresolved
      final coordinator = V2StartupCoordinator(preferencesRepository: repo);

      await tester.pumpWidget(
        MaterialApp(
          home: V2StartupGate(
            coordinator: coordinator,
            unresolvedBuilder: (_) => const Scaffold(
              body: Center(child: Text('Custom Unresolved Screen')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Custom Unresolved Screen'), findsOneWidget);
    });
  });
}
