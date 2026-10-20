import 'dart:async';
import 'package:flutter/widgets.dart';

import '../../controllers/program_v2_journey_controller.dart';
import '../../services/program_v2_journey_orchestrator.dart';

/// Coordinates Flutter application lifecycle events (startup and resume)
/// with the V2 domain journey reconciliation engine.
///
/// Follows Flutter's official [WidgetsBindingObserver] contract.
///
/// Architectural Guarantees:
/// 1. Initial reconciliation entry point is explicit ([handleStartup]).
/// 2. Entering [AppLifecycleState.resumed] triggers the same domain resume flow ([handleResume]).
/// 3. In-flight synchronization prevents duplicate overlapping runs from rapid resume notifications.
/// 4. Lifecycle callbacks are strictly non-fatal: storage/unexpected errors are captured gracefully.
/// 5. Never mutates domain state from widget build() methods.
/// 6. Safely attaches and detaches from the Flutter observer pipeline without leaks.
///
/// App Shell Integration Guide:
/// ```dart
/// // In future V2 App Shell (e.g. State.initState or GetX onInit):
/// _coordinator = runtime.createLifecycleCoordinator(controller: journeyController);
/// _coordinator.attach();
/// await _coordinator.handleStartup();
///
/// // In State.dispose or GetX onClose:
/// _coordinator.dispose();
/// ```
class ProgramV2LifecycleCoordinator with WidgetsBindingObserver {
  final ProgramV2JourneyOrchestrator _orchestrator;
  final ProgramV2JourneyController? _controller;
  final WidgetsBinding? _injectedBinding;

  bool _isAttached = false;
  bool get isAttached => _isAttached;

  bool _isReconciling = false;
  bool get isReconciling => _isReconciling;

  Future<OrchestratedBootstrapResult>? _ongoingReconciliation;

  ProgramV2LifecycleCoordinator({
    required ProgramV2JourneyOrchestrator orchestrator,
    ProgramV2JourneyController? controller,
    WidgetsBinding? binding,
  })  : _orchestrator = orchestrator,
        _controller = controller,
        _injectedBinding = binding;

  WidgetsBinding get _effectiveBinding =>
      _injectedBinding ?? WidgetsBinding.instance;

  /// Attaches this coordinator to the Flutter [WidgetsBinding] observer pipeline.
  ///
  /// Safe to call multiple times; attaches exactly once.
  void attach() {
    if (_isAttached) return;
    _effectiveBinding.addObserver(this);
    _isAttached = true;
  }

  /// Removes this coordinator from the [WidgetsBinding] observer pipeline.
  ///
  /// Safe to call multiple times; detaches cleanly.
  void dispose() {
    if (!_isAttached) return;
    _effectiveBinding.removeObserver(this);
    _isAttached = false;
  }

  /// Explicit initial reconciliation entry point for application startup.
  ///
  /// Serializes execution to prevent overlapping startup/resume invocations.
  Future<OrchestratedBootstrapResult> handleStartup({
    DateTime? capturedNow,
    Map<String, String>? recipientNameByProgramId,
  }) async {
    return _runReconciliationGuarded(
      capturedNow: capturedNow,
      recipientNameByProgramId: recipientNameByProgramId,
    );
  }

  /// Explicit reconciliation entry point for application resume.
  ///
  /// Serializes execution to prevent overlapping invocations.
  Future<OrchestratedBootstrapResult> handleResume({
    DateTime? capturedNow,
    Map<String, String>? recipientNameByProgramId,
  }) async {
    return _runReconciliationGuarded(
      capturedNow: capturedNow,
      recipientNameByProgramId: recipientNameByProgramId,
    );
  }

  /// Flutter lifecycle observer callback.
  ///
  /// Triggers domain reconciliation when entering [AppLifecycleState.resumed].
  /// Storage errors or unexpected exceptions are caught internally to ensure
  /// the Flutter lifecycle callback never crashes the engine.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(handleResume().catchError((_) {
        return OrchestratedBootstrapResult(
          items: const [],
          inspectedAt: DateTime.now(),
        );
      }));
    }
  }

  /// Serialized, exception-safe reconciliation executor.
  Future<OrchestratedBootstrapResult> _runReconciliationGuarded({
    DateTime? capturedNow,
    Map<String, String>? recipientNameByProgramId,
  }) async {
    if (_isReconciling && _ongoingReconciliation != null) {
      return _ongoingReconciliation!;
    }

    _isReconciling = true;
    final completer = Completer<OrchestratedBootstrapResult>();
    _ongoingReconciliation = completer.future;

    try {
      final result = _controller != null
          ? await _controller!.reconcileOnResume(
              capturedNow: capturedNow,
              recipientNameByProgramId: recipientNameByProgramId,
            )
          : await _orchestrator.processAppResume(
              capturedNow: capturedNow,
              recipientNameByProgramId: recipientNameByProgramId,
            );

      completer.complete(result);
      return result;
    } catch (e) {
      final fallback = OrchestratedBootstrapResult(
        items: [
          ProgramResumeItem(
            programId: '',
            action: ProgramResumeAction.error,
            errorMessage:
                'Storage operation failed during lifecycle reconciliation.',
          ),
        ],
        inspectedAt: capturedNow ?? DateTime.now(),
      );
      completer.complete(fallback);
      return fallback;
    } finally {
      _isReconciling = false;
      _ongoingReconciliation = null;
    }
  }
}
