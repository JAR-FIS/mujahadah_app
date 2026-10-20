import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../core/runtime/v2_recipient_name_provider.dart';
import '../models/daily_checkin_model.dart';
import '../models/program_v2_model.dart';
import '../repositories/program_v2_repository.dart';
import '../services/program_v2_journey_orchestrator.dart';

/// GetX controller exposing the approved [ProgramV2JourneyOrchestrator] to future V2 screens.
///
/// Responsibilities:
/// 1. Dispatches user-initiated journey actions (confirmed check-in, Muhasabah, SUCCESS finalization).
/// 2. Integrates with the [V2RecipientNameProvider] boundary for SUCCESS certification without hardcoding profile data.
/// 3. Exposes reactive state for UI bindings (processing status, per-program results, pending actions, errors).
/// 4. Serializes concurrent operations to avoid duplicate domain executions from rapid UI taps.
/// 5. Never calculates business metrics, never mutates Hive boxes directly, and never shows UI dialogs.
class ProgramV2JourneyController extends GetxController {
  final ProgramV2JourneyOrchestrator _orchestrator;
  final V2RecipientNameProvider? _recipientNameProvider;
  final ProgramV2Repository? _programRepository;

  // Active operations counter to ensure isProcessing remains true while any operation runs
  int _activeOperationCount = 0;

  // --- Observable State ---

  /// Overall operation progress indicator.
  final RxBool _isProcessing = false.obs;
  bool get isProcessing => _isProcessing.value;

  /// Set of program IDs currently involved in an active asynchronous operation.
  final RxSet<String> _activeProgramsInProgress = <String>{}.obs;

  /// Checks whether an operation is currently running for [programId].
  bool isProgramInProgress(String programId) =>
      _activeProgramsInProgress.contains(programId.trim());

  /// Typed outcome of the most recent check-in attempt.
  final Rxn<OrchestratedCheckInResult> lastCheckInResult =
      Rxn<OrchestratedCheckInResult>();

  /// Typed outcome of the most recent Muhasabah submission attempt.
  final Rxn<OrchestratedMuhasabahResult> lastMuhasabahResult =
      Rxn<OrchestratedMuhasabahResult>();

  /// Typed outcome of the most recent SUCCESS finalization attempt.
  final Rxn<OrchestratedSuccessResult> lastSuccessResult =
      Rxn<OrchestratedSuccessResult>();

  /// Outcome of the most recent app bootstrap/resume batch reconciliation.
  final Rxn<OrchestratedBootstrapResult> lastResumeResult =
      Rxn<OrchestratedBootstrapResult>();

  /// Per-program status reports from startup and resume reconciliation.
  /// Key: `programId`, Value: [ProgramResumeItem].
  final RxMap<String, ProgramResumeItem> reconciliationResults =
      <String, ProgramResumeItem>{}.obs;

  /// Active pending Muhasabah requirements awaiting user reason selection.
  /// Key: `programId`, Value: `missedDayKey`.
  final RxMap<String, String> pendingMuhasabahActions = <String, String>{}.obs;

  /// Programs that completed their target duration but require a recipient name
  /// to complete SUCCESS finalization.
  final RxSet<String> needsRecipientNameActions = <String>{}.obs;

  /// Most recent successful check-in records keyed by `programId`.
  final RxMap<String, DailyCheckInModel> completedCheckIns =
      <String, DailyCheckInModel>{}.obs;

  /// Authoritative final lifecycle status (SUCCESS, FAILED, WARNING) keyed by `programId`.
  final RxMap<String, String> finalizationStatuses = <String, String>{}.obs;

  /// Non-fatal profile lookup diagnostic messages keyed by `programId`.
  /// Populated when reading the profile recipient name encounters an exception,
  /// preserving check-in and batch reconciliation while surfacing nonfatal profile read failures to the UI.
  final RxMap<String, String> profileLookupDiagnostics = <String, String>{}.obs;

  /// Helper to retrieve the profile lookup diagnostic for a given [programId], if any.
  String? profileLookupDiagnostic(String programId) =>
      profileLookupDiagnostics[programId.trim()];

  /// Last user-facing error message received from domain orchestration.
  final Rxn<String> lastErrorMessage = Rxn<String>();

  /// Indicates whether the last operation encountered a recoverable persistence error.
  final RxBool hasPersistenceError = false.obs;

  ProgramV2JourneyController({
    required ProgramV2JourneyOrchestrator orchestrator,
    V2RecipientNameProvider? recipientNameProvider,
    ProgramV2Repository? programRepository,
  })  : _orchestrator = orchestrator,
        _recipientNameProvider = recipientNameProvider,
        _programRepository = programRepository;

  void _beginOperation() {
    _activeOperationCount++;
    _isProcessing.value = true;
  }

  void _endOperation() {
    _activeOperationCount = (_activeOperationCount - 1).clamp(0, 999999);
    _isProcessing.value =
        _activeOperationCount > 0 || _activeProgramsInProgress.isNotEmpty;
  }

  // --- Public Journey Actions ---

  /// Orchestrates a daily check-in for the given [programId].
  ///
  /// Requires explicit [confirmedByUser] confirmation. If false, returns
  /// [OrchestratedCheckInOutcome.confirmationRequired] without mutations and
  /// without invoking the profile recipient provider.
  Future<OrchestratedCheckInResult> checkIn({
    required String programId,
    required bool confirmedByUser,
    String? recipientNameSnapshot,
  }) async {
    final cleanId = programId.trim();
    if (_activeProgramsInProgress.contains(cleanId)) {
      return OrchestratedCheckInResult.failure(
        outcome: OrchestratedCheckInOutcome.unexpectedError,
        programId: cleanId,
        message: 'Operation already in progress for program "$cleanId".',
      );
    }

    // Fix 2: For confirmedByUser == false, do not resolve recipient names unnecessarily.
    // Preserve domain confirmationRequired result and zero-write guarantee.
    if (!confirmedByUser) {
      return _orchestrator.checkIn(
        programId: cleanId,
        confirmedByUser: false,
      );
    }

    _beginOperation();
    _activeProgramsInProgress.add(cleanId);
    try {
      String? effectiveRecipient;
      if (recipientNameSnapshot != null &&
          recipientNameSnapshot.trim().isNotEmpty) {
        effectiveRecipient = recipientNameSnapshot.trim();
        profileLookupDiagnostics.remove(cleanId);
      } else if (_recipientNameProvider != null) {
        try {
          final resolved = await _recipientNameProvider!.getRecipientName();
          if (resolved != null && resolved.trim().isNotEmpty) {
            effectiveRecipient = resolved.trim();
          }
          // Lookup succeeded (or returned null/unconfigured): clear stale diagnostic
          profileLookupDiagnostics.remove(cleanId);
        } on HiveError catch (_) {
          profileLookupDiagnostics[cleanId] =
              'Storage operation failed during profile lookup.';
          effectiveRecipient = null;
        } catch (_) {
          profileLookupDiagnostics[cleanId] =
              'Unexpected error occurred during profile lookup.';
          effectiveRecipient = null;
        }
      }

      final result = await _orchestrator.checkIn(
        programId: cleanId,
        confirmedByUser: true,
        recipientNameSnapshot: effectiveRecipient,
      );

      lastCheckInResult.value = result;

      if (result.outcome == OrchestratedCheckInOutcome.persistenceError) {
        hasPersistenceError.value = true;
        lastErrorMessage.value = result.errorMessage;
      } else {
        hasPersistenceError.value = false;
        if (result.errorMessage != null && !result.isSuccess) {
          lastErrorMessage.value = result.errorMessage;
        } else if (result.isSuccess) {
          lastErrorMessage.value = null;
        }
      }

      if (result.outcome == OrchestratedCheckInOutcome.muhasabahRequired) {
        if (result.missedDayKey != null) {
          pendingMuhasabahActions[cleanId] = result.missedDayKey!;
        }
      } else if (result.isSuccess) {
        pendingMuhasabahActions.remove(cleanId);
        if (result.checkIn != null) {
          completedCheckIns[cleanId] = result.checkIn!;
        }
        if (result.outcome == OrchestratedCheckInOutcome.successFinalized ||
            result.outcome ==
                OrchestratedCheckInOutcome.successAchievementRecovered) {
          finalizationStatuses[cleanId] = ProgramV2Model.statusSuccess;
          needsRecipientNameActions.remove(cleanId);
          profileLookupDiagnostics.remove(cleanId);
        } else if (result.outcome ==
            OrchestratedCheckInOutcome.needsRecipientName) {
          needsRecipientNameActions.add(cleanId);
        }
      }

      return result;
    } finally {
      _activeProgramsInProgress.remove(cleanId);
      _endOperation();
    }
  }

  /// Submits a user-selected Muhasabah reason for a program currently in PENDING_FAILURE.
  Future<OrchestratedMuhasabahResult> submitMuhasabah({
    required String programId,
    required String reasonCode,
    required String reasonLabelSnapshot,
    String? note,
  }) async {
    final cleanId = programId.trim();
    if (_activeProgramsInProgress.contains(cleanId)) {
      return OrchestratedMuhasabahResult.failure(
        outcome: OrchestratedMuhasabahOutcome.unexpectedError,
        programId: cleanId,
        message: 'Operation already in progress for program "$cleanId".',
      );
    }

    _beginOperation();
    _activeProgramsInProgress.add(cleanId);
    try {
      final result = await _orchestrator.submitMuhasabah(
        programId: cleanId,
        reasonCode: reasonCode,
        reasonLabelSnapshot: reasonLabelSnapshot,
        note: note,
      );

      lastMuhasabahResult.value = result;

      if (result.outcome == OrchestratedMuhasabahOutcome.persistenceError) {
        hasPersistenceError.value = true;
        lastErrorMessage.value = result.errorMessage;
      } else {
        hasPersistenceError.value = false;
        if (result.errorMessage != null && !result.isSuccess) {
          lastErrorMessage.value = result.errorMessage;
        } else if (result.isSuccess) {
          lastErrorMessage.value = null;
        }
      }

      if (result.isSuccess) {
        pendingMuhasabahActions.remove(cleanId);
        if (result.finalStatus != null) {
          finalizationStatuses[cleanId] = result.finalStatus!;
        }
      }

      return result;
    } finally {
      _activeProgramsInProgress.remove(cleanId);
      _endOperation();
    }
  }

  /// Explicitly finalizes SUCCESS for a program whose target days were reached.
  Future<OrchestratedSuccessResult> finalizeSuccess({
    required String programId,
    String? recipientNameSnapshot,
  }) async {
    final cleanId = programId.trim();
    if (_activeProgramsInProgress.contains(cleanId)) {
      return OrchestratedSuccessResult.failure(
        outcome: OrchestratedSuccessOutcome.unexpectedError,
        programId: cleanId,
        message: 'Operation already in progress for program "$cleanId".',
      );
    }

    _beginOperation();
    _activeProgramsInProgress.add(cleanId);
    try {
      String? effectiveRecipient;
      if (recipientNameSnapshot != null &&
          recipientNameSnapshot.trim().isNotEmpty) {
        effectiveRecipient = recipientNameSnapshot.trim();
        profileLookupDiagnostics.remove(cleanId);
      } else if (_recipientNameProvider != null) {
        try {
          final resolved = await _recipientNameProvider!.getRecipientName();
          if (resolved != null && resolved.trim().isNotEmpty) {
            effectiveRecipient = resolved.trim();
          }
          profileLookupDiagnostics.remove(cleanId);
        } on HiveError catch (_) {
          profileLookupDiagnostics[cleanId] =
              'Storage operation failed during profile lookup.';
          final errResult = OrchestratedSuccessResult.failure(
            outcome: OrchestratedSuccessOutcome.persistenceError,
            programId: cleanId,
            message: 'Storage operation failed during profile lookup.',
          );
          lastSuccessResult.value = errResult;
          hasPersistenceError.value = true;
          lastErrorMessage.value = errResult.errorMessage;
          return errResult;
        } catch (_) {
          profileLookupDiagnostics[cleanId] =
              'Unexpected error occurred during profile lookup.';
          final errResult = OrchestratedSuccessResult.failure(
            outcome: OrchestratedSuccessOutcome.unexpectedError,
            programId: cleanId,
            message: 'Unexpected error occurred during profile lookup.',
          );
          lastSuccessResult.value = errResult;
          hasPersistenceError.value = false;
          lastErrorMessage.value = errResult.errorMessage;
          return errResult;
        }
      }

      if (effectiveRecipient == null || effectiveRecipient.trim().isEmpty) {
        needsRecipientNameActions.add(cleanId);
        final failureRes = OrchestratedSuccessResult.failure(
          outcome: OrchestratedSuccessOutcome.invalidRecipientName,
          programId: cleanId,
          message: 'Recipient name snapshot is required to finalize SUCCESS.',
        );
        lastSuccessResult.value = failureRes;
        lastErrorMessage.value = failureRes.errorMessage;
        return failureRes;
      }

      final result = await _orchestrator.finalizeSuccess(
        programId: cleanId,
        recipientNameSnapshot: effectiveRecipient.trim(),
      );

      lastSuccessResult.value = result;

      if (result.outcome == OrchestratedSuccessOutcome.persistenceError) {
        hasPersistenceError.value = true;
        lastErrorMessage.value = result.errorMessage;
      } else {
        hasPersistenceError.value = false;
        if (result.errorMessage != null && !result.isSuccess) {
          lastErrorMessage.value = result.errorMessage;
        } else if (result.isSuccess) {
          lastErrorMessage.value = null;
        }
      }

      if (result.isSuccess) {
        needsRecipientNameActions.remove(cleanId);
        finalizationStatuses[cleanId] = ProgramV2Model.statusSuccess;
        profileLookupDiagnostics.remove(cleanId);
      }

      return result;
    } finally {
      _activeProgramsInProgress.remove(cleanId);
      _endOperation();
    }
  }

  /// Performs batch reconciliation for all programs on application startup or resume.
  Future<OrchestratedBootstrapResult> reconcileOnResume({
    DateTime? capturedNow,
    Map<String, String>? recipientNameByProgramId,
  }) async {
    _beginOperation();
    try {
      final effectiveMap = <String, String>{};
      if (recipientNameByProgramId != null) {
        effectiveMap.addAll(recipientNameByProgramId);
      }

      // Fix 1: Resolve available recipient names through the injected provider when preparing batch reconciliation.
      if (_recipientNameProvider != null) {
        List<ProgramV2Model> programs;
        try {
          programs = _programRepository?.getAll() ?? const [];
        } catch (_) {
          programs = const [];
        }

        for (final prog in programs) {
          // Respect explicit caller-provided names
          if (effectiveMap.containsKey(prog.id)) {
            profileLookupDiagnostics.remove(prog.id);
            continue;
          }
          // Do not overwrite existing historical recipient snapshots
          if (prog.recipientNameSnapshot != null &&
              prog.recipientNameSnapshot!.trim().isNotEmpty) {
            profileLookupDiagnostics.remove(prog.id);
            continue;
          }
          try {
            final name =
                await _recipientNameProvider!.getRecipientName(program: prog);
            if (name != null && name.trim().isNotEmpty) {
              effectiveMap[prog.id] = name.trim();
            }
            // Reading profile succeeded (either got a name or verified unconfigured):
            // Clear any stale failure diagnostic for this program
            profileLookupDiagnostics.remove(prog.id);
          } on HiveError catch (_) {
            profileLookupDiagnostics[prog.id] =
                'Storage operation failed during profile lookup.';
          } catch (_) {
            profileLookupDiagnostics[prog.id] =
                'Unexpected error occurred during profile lookup.';
          }
        }
      }

      final result = await _orchestrator.processAppResume(
        capturedNow: capturedNow,
        recipientNameByProgramId: effectiveMap.isNotEmpty ? effectiveMap : null,
      );

      lastResumeResult.value = result;

      for (final item in result.items) {
        if (item.programId.isNotEmpty) {
          reconciliationResults[item.programId] = item;

          if (item.action == ProgramResumeAction.muhasabahRequired) {
            final missedKey = item.program?.pendingMissedDayKey;
            if (missedKey != null) {
              pendingMuhasabahActions[item.programId] = missedKey;
            }
          } else if (item.action == ProgramResumeAction.needsRecipientName) {
            needsRecipientNameActions.add(item.programId);
          } else if (item.action == ProgramResumeAction.successFinalized ||
              item.action == ProgramResumeAction.alreadyFinalized ||
              item.action == ProgramResumeAction.achievementRecovered) {
            final st = item.program?.status ?? ProgramV2Model.statusSuccess;
            finalizationStatuses[item.programId] = st;
            needsRecipientNameActions.remove(item.programId);
            pendingMuhasabahActions.remove(item.programId);
            profileLookupDiagnostics.remove(item.programId);
          }
        }
      }

      if (result.hasErrors) {
        hasPersistenceError.value = true;
        lastErrorMessage.value = result.errors.first.errorMessage;
      } else {
        hasPersistenceError.value = false;
        lastErrorMessage.value = null;
      }

      return result;
    } finally {
      _endOperation();
    }
  }

  @override
  void onClose() {
    // IMPORTANT: Globally owned Hive boxes MUST NOT be closed here.
    // They are managed by the composition root (V2Runtime).
    super.onClose();
  }
}
