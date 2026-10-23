import 'package:flutter/material.dart';

import '../../repositories/v2_preferences_repository.dart';
import '../../views/v2/preferences/v2_initial_preferences_view.dart';

/// Enumeration of distinct stages during application launch.
enum V2StartupStage {
  /// First launch initial preferences setup (Language & Theme, S00A).
  initialPreferences,

  /// Five-screen introductory onboarding (S01–S06).
  onboarding,

  /// User profile and recipient setup (S07).
  profileSetup,

  /// Main application shell / dashboard.
  mainApp,

  /// Mandatory subsequent stage is unconfigured or unavailable (Fail-Closed).
  unresolved,
}

/// Decoupled coordinator resolving startup stage based on independent completion flags.
///
/// Ensures initial preferences is presented exactly once on fresh installs
/// without interfering with separate onboarding or profile completion states.
/// Enforces fail-closed gating: never defaults or falls through to [V2StartupStage.mainApp]
/// unless all preceding mandatory stages have been affirmatively confirmed completed.
class V2StartupCoordinator {
  final V2PreferencesRepository preferencesRepository;
  final Future<bool> Function()? isOnboardingCompleted;
  final Future<bool> Function()? isProfileCompleted;

  const V2StartupCoordinator({
    required this.preferencesRepository,
    this.isOnboardingCompleted,
    this.isProfileCompleted,
  });

  /// Resolves which launch stage the application should enter.
  ///
  /// Guarantees fail-closed gating:
  /// 1. Uncompleted initial preferences returns [V2StartupStage.initialPreferences].
  /// 2. Missing onboarding evaluator returns [V2StartupStage.unresolved] (never mainApp).
  /// 3. Incomplete onboarding returns [V2StartupStage.onboarding].
  /// 4. Missing profile evaluator returns [V2StartupStage.unresolved] (never mainApp).
  /// 5. Incomplete profile returns [V2StartupStage.profileSetup].
  /// 6. Only returns [V2StartupStage.mainApp] when both stages are affirmatively confirmed.
  Future<V2StartupStage> resolveStartupStage() async {
    // 1. Initial preferences must be completed first
    final prefCompleted = await preferencesRepository.isCompleted();
    if (!prefCompleted) {
      return V2StartupStage.initialPreferences;
    }

    // 2. Mandatory onboarding evaluation (Fail-closed)
    if (isOnboardingCompleted == null) {
      return V2StartupStage.unresolved;
    }
    final onboardingDone = await isOnboardingCompleted!();
    if (!onboardingDone) {
      return V2StartupStage.onboarding;
    }

    // 3. Mandatory profile evaluation (Fail-closed)
    if (isProfileCompleted == null) {
      return V2StartupStage.unresolved;
    }
    final profileDone = await isProfileCompleted!();
    if (!profileDone) {
      return V2StartupStage.profileSetup;
    }

    // 4. All prerequisites affirmatively satisfied -> launch main app
    return V2StartupStage.mainApp;
  }
}

/// Standalone testable widget gate rendering the appropriate screen for the current startup stage.
class V2StartupGate extends StatefulWidget {
  final V2StartupCoordinator coordinator;
  final Widget Function(BuildContext context, VoidCallback onCompleted)?
      initialPreferencesBuilder;
  final WidgetBuilder? onboardingBuilder;
  final WidgetBuilder? profileSetupBuilder;
  final WidgetBuilder? mainAppBuilder;
  final WidgetBuilder? unresolvedBuilder;
  final WidgetBuilder? loadingBuilder;

  const V2StartupGate({
    super.key,
    required this.coordinator,
    this.initialPreferencesBuilder,
    this.onboardingBuilder,
    this.profileSetupBuilder,
    this.mainAppBuilder,
    this.unresolvedBuilder,
    this.loadingBuilder,
  });

  @override
  State<V2StartupGate> createState() => _V2StartupGateState();
}

class _V2StartupGateState extends State<V2StartupGate> {
  V2StartupStage? _resolvedStage;
  bool _isLoading = true;
  String? _errorMessage;
  int _activeRequestId = 0;

  @override
  void initState() {
    super.initState();
    _resolveStage();
  }

  Future<void> _resolveStage() async {
    final currentRequestId = ++_activeRequestId;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final stage = await widget.coordinator.resolveStartupStage();
      if (!mounted || currentRequestId != _activeRequestId) return;
      setState(() {
        _resolvedStage = stage;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted || currentRequestId != _activeRequestId) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Terjadi kesalahan saat memeriksa status aplikasi. Silakan coba lagi.';
      });
    }
  }

  void _onPreferencesCompleted() {
    _resolveStage();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.loadingBuilder?.call(context) ??
          const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: Color(0xFFC53030),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    key: const ValueKey('v2_startup_gate_retry_button'),
                    onPressed: _resolveStage,
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    switch (_resolvedStage) {
      case V2StartupStage.initialPreferences:
        if (widget.initialPreferencesBuilder != null) {
          return widget.initialPreferencesBuilder!(
            context,
            _onPreferencesCompleted,
          );
        }
        return V2InitialPreferencesView(
          repository: widget.coordinator.preferencesRepository,
          onContinue: _onPreferencesCompleted,
        );

      case V2StartupStage.onboarding:
        return widget.onboardingBuilder?.call(context) ??
            const Scaffold(
              body: Center(
                child: Text('Onboarding Stage Placeholder'),
              ),
            );

      case V2StartupStage.profileSetup:
        return widget.profileSetupBuilder?.call(context) ??
            const Scaffold(
              body: Center(
                child: Text('Profile Setup Stage Placeholder'),
              ),
            );

      case V2StartupStage.unresolved:
        return widget.unresolvedBuilder?.call(context) ??
            const Scaffold(
              body: Center(
                child: Text('Tahap berikutnya belum tersedia.'),
              ),
            );

      case V2StartupStage.mainApp:
      default:
        return widget.mainAppBuilder?.call(context) ??
            const Scaffold(
              body: Center(
                child: Text('Main App Placeholder'),
              ),
            );
    }
  }
}
