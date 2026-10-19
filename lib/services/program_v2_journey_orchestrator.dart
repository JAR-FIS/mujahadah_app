import 'dart:async';

import 'package:hive/hive.dart';

import '../core/date/date_service.dart';
import '../models/achievement_model.dart';
import '../models/daily_checkin_model.dart';
import '../models/failure_record_model.dart';
import '../models/program_v2_model.dart';
import '../repositories/program_v2_repository.dart';
import 'daily_checkin_v2_service.dart';
import 'program_v2_muhasabah_service.dart';
import 'program_v2_reconciliation_service.dart';
import 'program_v2_success_service.dart';

/// Typed outcomes for orchestrated daily check-in operations.
enum OrchestratedCheckInOutcome {
  /// Confirmed check-in was successfully recorded (target not yet reached).
  checkInCompleted,

  /// Program has already checked in for today's operational day.
  alreadyCheckedIn,

  /// Program start date has not yet arrived.
  programNotStarted,

  /// Missed operational day detected; program requires Muhasabah.
  muhasabahRequired,

  /// Check-in reached the final target and SUCCESS was finalized with achievement.
  successFinalized,

  /// Missing achievement was safely recovered for an already SUCCESS program.
  successAchievementRecovered,

  /// Check-in succeeded and reached target, but recipient name is unavailable for SUCCESS finalization.
  needsRecipientName,

  /// Program reached SUCCESS, but achievement persistence failed (incomplete finalization).
  successIncompleteFinalization,

  /// Program is in a terminal lifecycle state (SUCCESS, FAILED, WARNING).
  terminalProgram,

  /// User did not confirm the check-in modal.
  confirmationRequired,

  /// Program ID was empty or whitespace.
  invalidProgramId,

  /// Program was not found in storage.
  programNotFound,

  /// Data integrity anomaly detected in records.
  dataIntegrityError,

  /// Storage read/write error occurred.
  persistenceError,

  /// Boundary race detected: retry recommended.
  boundaryRaceRetry,

  /// Unexpected error during orchestration.
  unexpectedError,
}

/// Result of an orchestrated check-in attempt.
class OrchestratedCheckInResult {
  final OrchestratedCheckInOutcome outcome;
  final String? programId;
  final DailyCheckInModel? checkIn;
  final ProgramProgressSnapshot? progress;
  final ProgramV2Model? program;
  final AchievementModel? achievement;
  final String? missedDayKey;
  final String? errorMessage;

  const OrchestratedCheckInResult._({
    required this.outcome,
    this.programId,
    this.checkIn,
    this.progress,
    this.program,
    this.achievement,
    this.missedDayKey,
    this.errorMessage,
  });

  bool get isSuccess =>
      outcome == OrchestratedCheckInOutcome.checkInCompleted ||
      outcome == OrchestratedCheckInOutcome.successFinalized ||
      outcome == OrchestratedCheckInOutcome.successAchievementRecovered ||
      outcome == OrchestratedCheckInOutcome.needsRecipientName;

  bool get isAlreadyCheckedIn =>
      outcome == OrchestratedCheckInOutcome.alreadyCheckedIn;

  bool get isMuhasabahRequired =>
      outcome == OrchestratedCheckInOutcome.muhasabahRequired;

  bool get isNeedsRecipientName =>
      outcome == OrchestratedCheckInOutcome.needsRecipientName;

  bool get isSuccessFinalized =>
      outcome == OrchestratedCheckInOutcome.successFinalized;

  bool get isFailure =>
      !isSuccess &&
      outcome != OrchestratedCheckInOutcome.alreadyCheckedIn &&
      outcome != OrchestratedCheckInOutcome.muhasabahRequired;

  factory OrchestratedCheckInResult.checkInCompleted({
    required String programId,
    required DailyCheckInModel checkIn,
    required ProgramProgressSnapshot progress,
    ProgramV2Model? program,
  }) =>
      OrchestratedCheckInResult._(
        outcome: OrchestratedCheckInOutcome.checkInCompleted,
        programId: programId,
        checkIn: checkIn,
        progress: progress,
        program: program,
      );

  factory OrchestratedCheckInResult.successFinalized({
    required String programId,
    DailyCheckInModel? checkIn,
    ProgramProgressSnapshot? progress,
    required ProgramV2Model program,
    required AchievementModel achievement,
  }) =>
      OrchestratedCheckInResult._(
        outcome: OrchestratedCheckInOutcome.successFinalized,
        programId: programId,
        checkIn: checkIn,
        progress: progress,
        program: program,
        achievement: achievement,
      );

  factory OrchestratedCheckInResult.successAchievementRecovered({
    required String programId,
    DailyCheckInModel? checkIn,
    ProgramProgressSnapshot? progress,
    required ProgramV2Model program,
    required AchievementModel achievement,
  }) =>
      OrchestratedCheckInResult._(
        outcome: OrchestratedCheckInOutcome.successAchievementRecovered,
        programId: programId,
        checkIn: checkIn,
        progress: progress,
        program: program,
        achievement: achievement,
      );

  factory OrchestratedCheckInResult.needsRecipientName({
    required String programId,
    DailyCheckInModel? checkIn,
    ProgramProgressSnapshot? progress,
    ProgramV2Model? program,
    String? message,
  }) =>
      OrchestratedCheckInResult._(
        outcome: OrchestratedCheckInOutcome.needsRecipientName,
        programId: programId,
        checkIn: checkIn,
        progress: progress,
        program: program,
        errorMessage: message,
      );

  factory OrchestratedCheckInResult.successIncompleteFinalization({
    required String programId,
    DailyCheckInModel? checkIn,
    ProgramProgressSnapshot? progress,
    required ProgramV2Model program,
    String? message,
  }) =>
      OrchestratedCheckInResult._(
        outcome: OrchestratedCheckInOutcome.successIncompleteFinalization,
        programId: programId,
        checkIn: checkIn,
        progress: progress,
        program: program,
        errorMessage: message,
      );

  factory OrchestratedCheckInResult.muhasabahRequired({
    required String programId,
    ProgramV2Model? program,
    String? missedDayKey,
    String? message,
  }) =>
      OrchestratedCheckInResult._(
        outcome: OrchestratedCheckInOutcome.muhasabahRequired,
        programId: programId,
        program: program,
        missedDayKey: missedDayKey,
        errorMessage: message,
      );

  factory OrchestratedCheckInResult.failure({
    required OrchestratedCheckInOutcome outcome,
    String? programId,
    ProgramV2Model? program,
    String? message,
  }) =>
      OrchestratedCheckInResult._(
        outcome: outcome,
        programId: programId,
        program: program,
        errorMessage: message,
      );
}

/// Typed outcomes for orchestrated Muhasabah failure finalization.
enum OrchestratedMuhasabahOutcome {
  /// Program finalized with FAILED status (< 40 days completed).
  failedCreated,

  /// Program finalized with WARNING status (>= 40 days completed before target).
  warningCreated,

  /// Program and failure record were already finalized; idempotent return without mutation.
  alreadyFinalized,

  /// Program is not in PENDING_FAILURE status.
  programNotPending,

  /// Missing or invalid reason code or reason label snapshot.
  invalidReason,

  /// Submitted reason conflicts with existing failure record for interruption.
  reasonConflict,

  /// Program ID was empty or whitespace.
  invalidProgramId,

  /// Program was not found in storage.
  programNotFound,

  /// Storage records contain conflicting or corrupt data.
  dataIntegrityError,

  /// Storage read/write operation failed.
  persistenceError,

  /// An unexpected error occurred.
  unexpectedError,
}

/// Result of an orchestrated Muhasabah failure submission.
class OrchestratedMuhasabahResult {
  final OrchestratedMuhasabahOutcome outcome;
  final String? programId;
  final String? finalStatus;
  final ProgramV2Model? program;
  final FailureRecordModel? failureRecord;
  final int? completedDays;
  final String? errorMessage;

  const OrchestratedMuhasabahResult._({
    required this.outcome,
    this.programId,
    this.finalStatus,
    this.program,
    this.failureRecord,
    this.completedDays,
    this.errorMessage,
  });

  bool get isSuccess =>
      outcome == OrchestratedMuhasabahOutcome.failedCreated ||
      outcome == OrchestratedMuhasabahOutcome.warningCreated ||
      outcome == OrchestratedMuhasabahOutcome.alreadyFinalized;

  bool get isFailure => !isSuccess;

  bool get isFailedCreated =>
      outcome == OrchestratedMuhasabahOutcome.failedCreated;

  bool get isWarningCreated =>
      outcome == OrchestratedMuhasabahOutcome.warningCreated;

  bool get isAlreadyFinalized =>
      outcome == OrchestratedMuhasabahOutcome.alreadyFinalized;

  factory OrchestratedMuhasabahResult.fromOutcome({
    required OrchestratedMuhasabahOutcome outcome,
    required String programId,
    String? finalStatus,
    ProgramV2Model? program,
    FailureRecordModel? failureRecord,
    int? completedDays,
    String? message,
  }) =>
      OrchestratedMuhasabahResult._(
        outcome: outcome,
        programId: programId,
        finalStatus: finalStatus,
        program: program,
        failureRecord: failureRecord,
        completedDays: completedDays,
        errorMessage: message,
      );

  factory OrchestratedMuhasabahResult.failure({
    required OrchestratedMuhasabahOutcome outcome,
    String? programId,
    String? message,
  }) =>
      OrchestratedMuhasabahResult._(
        outcome: outcome,
        programId: programId,
        errorMessage: message,
      );
}

/// Typed outcomes for orchestrated SUCCESS finalization and recovery.
enum OrchestratedSuccessOutcome {
  /// Program was successfully finalized to SUCCESS and FINAL_SUCCESS achievement was created.
  successFinalized,

  /// Program and achievement were already validly finalized; idempotent return without mutation.
  alreadyFinalized,

  /// Missing achievement was safely recovered for an already SUCCESS program.
  achievementRecovered,

  /// Program target has not yet been reached.
  notYetEligible,

  /// Recipient name snapshot was empty or whitespace.
  invalidRecipientName,

  /// Program ID was empty or whitespace.
  invalidProgramId,

  /// Program was not found in storage.
  programNotFound,

  /// Program is not in eligible status for success finalization.
  programNotActive,

  /// Incomplete finalization: program became SUCCESS but achievement persistence failed.
  incompleteFinalization,

  /// Storage records contain conflicting or corrupt data.
  dataIntegrityError,

  /// Storage read/write operation failed.
  persistenceError,

  /// An unexpected error occurred.
  unexpectedError,
}

/// Result of an orchestrated SUCCESS finalization attempt.
class OrchestratedSuccessResult {
  final OrchestratedSuccessOutcome outcome;
  final String? programId;
  final ProgramV2Model? program;
  final AchievementModel? achievement;
  final int? completedDays;
  final String? errorMessage;

  const OrchestratedSuccessResult._({
    required this.outcome,
    this.programId,
    this.program,
    this.achievement,
    this.completedDays,
    this.errorMessage,
  });

  bool get isSuccess =>
      outcome == OrchestratedSuccessOutcome.successFinalized ||
      outcome == OrchestratedSuccessOutcome.alreadyFinalized ||
      outcome == OrchestratedSuccessOutcome.achievementRecovered;

  bool get isFailure => !isSuccess;

  bool get isSuccessFinalized =>
      outcome == OrchestratedSuccessOutcome.successFinalized;

  bool get isAlreadyFinalized =>
      outcome == OrchestratedSuccessOutcome.alreadyFinalized;

  bool get isAchievementRecovered =>
      outcome == OrchestratedSuccessOutcome.achievementRecovered;

  factory OrchestratedSuccessResult.fromOutcome({
    required OrchestratedSuccessOutcome outcome,
    required String programId,
    ProgramV2Model? program,
    AchievementModel? achievement,
    int? completedDays,
    String? message,
  }) =>
      OrchestratedSuccessResult._(
        outcome: outcome,
        programId: programId,
        program: program,
        achievement: achievement,
        completedDays: completedDays,
        errorMessage: message,
      );

  factory OrchestratedSuccessResult.failure({
    required OrchestratedSuccessOutcome outcome,
    String? programId,
    String? message,
  }) =>
      OrchestratedSuccessResult._(
        outcome: outcome,
        programId: programId,
        errorMessage: message,
      );
}

/// Action indicator for programs inspected during bootstrap/resume reconciliation.
enum ProgramResumeAction {
  /// Program is ACTIVE and on track without missed operational days.
  onTrack,

  /// Program is scheduled to start on a future operational day.
  notStarted,

  /// Missed operational day detected; program requires Muhasabah.
  muhasabahRequired,

  /// Program completed target days; finalized to SUCCESS with achievement.
  successFinalized,

  /// Program is already SUCCESS; missing achievement was safely recovered.
  achievementRecovered,

  /// Program completed target days, but recipient name is needed to finalize SUCCESS.
  needsRecipientName,

  /// Program was already validly finalized (SUCCESS, FAILED, WARNING).
  alreadyFinalized,

  /// An error occurred while inspecting this program.
  error,
}

/// Per-program status report item during app bootstrap/resume.
class ProgramResumeItem {
  final String programId;
  final ProgramResumeAction action;
  final ProgramV2Model? program;
  final String? missedDayKey;
  final AchievementModel? achievement;
  final String? errorMessage;

  const ProgramResumeItem({
    required this.programId,
    required this.action,
    this.program,
    this.missedDayKey,
    this.achievement,
    this.errorMessage,
  });

  bool get isMuhasabahRequired =>
      action == ProgramResumeAction.muhasabahRequired;

  bool get isNeedsRecipientName =>
      action == ProgramResumeAction.needsRecipientName;

  bool get isSuccessFinalized => action == ProgramResumeAction.successFinalized;

  bool get isAchievementRecovered =>
      action == ProgramResumeAction.achievementRecovered;

  bool get isError => action == ProgramResumeAction.error;
}

/// Aggregate report of batch reconciliation during app bootstrap or resume.
class OrchestratedBootstrapResult {
  final List<ProgramResumeItem> items;
  final DateTime inspectedAt;

  const OrchestratedBootstrapResult({
    required this.items,
    required this.inspectedAt,
  });

  int get totalInspected => items.length;

  List<ProgramResumeItem> get programsNeedingMuhasabah =>
      items.where((i) => i.isMuhasabahRequired).toList();

  List<ProgramResumeItem> get programsNeedingRecipientName =>
      items.where((i) => i.isNeedsRecipientName).toList();

  List<ProgramResumeItem> get programsFinalizedSuccess =>
      items.where((i) => i.isSuccessFinalized).toList();

  List<ProgramResumeItem> get achievementsRecovered =>
      items.where((i) => i.isAchievementRecovered).toList();

  List<ProgramResumeItem> get errors => items.where((i) => i.isError).toList();

  bool get hasErrors => errors.isNotEmpty;
}

/// Core domain orchestrator connecting DailyCheckInV2Service,
/// ProgramV2ReconciliationService, ProgramV2MuhasabahService, and ProgramV2SuccessService.
///
/// Responsibilities:
/// 1. Preflight check-in reconciliation before any write.
/// 2. Safe 03:00 operational-day boundary race handling.
/// 3. Immediate SUCCESS finalization when check-in completes the target duration.
/// 4. Graceful retention of completed journeys when recipient name is temporarily unavailable.
/// 5. Safe recovery of missing FINAL_SUCCESS achievements for SUCCESS programs.
/// 6. Orchestrated Muhasabah reason submission with reason validation.
/// 7. App bootstrap/resume batch reconciliation without collapsing per-program errors.
/// 8. In-process FIFO serialization for double-tap and concurrency protection.
///
/// Concurrency Scope & Limitations:
/// In-process serialization is strictly scoped to this single [ProgramV2JourneyOrchestrator] instance.
/// It serializes overlapping asynchronous calls to prevent race conditions within the same service instance.
/// It does NOT guarantee cross-instance, cross-isolate, or multi-process synchronization.
class ProgramV2JourneyOrchestrator {
  final ProgramV2Repository _programRepository;
  final DailyCheckInV2Service _dailyCheckInService;
  final ProgramV2ReconciliationService _reconciliationService;
  final ProgramV2MuhasabahService _muhasabahService;
  final ProgramV2SuccessService _successService;
  final DateService _dateService;

  // In-process FIFO lock to prevent race conditions during rapid taps / concurrent calls
  Future<void> _lock = Future.value();

  ProgramV2JourneyOrchestrator({
    required ProgramV2Repository programRepository,
    required DailyCheckInV2Service dailyCheckInService,
    required ProgramV2ReconciliationService reconciliationService,
    required ProgramV2MuhasabahService muhasabahService,
    required ProgramV2SuccessService successService,
    DateService? dateService,
  })  : _programRepository = programRepository,
        _dailyCheckInService = dailyCheckInService,
        _reconciliationService = reconciliationService,
        _muhasabahService = muhasabahService,
        _successService = successService,
        _dateService = dateService ?? DateService();

  /// In-process serialization to serialize async orchestration operations.
  Future<T> _synchronized<T>(Future<T> Function() criticalSection) {
    final completer = Completer<T>();
    _lock = _lock.catchError((_) {}).then((_) async {
      try {
        final result = await criticalSection();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  /// Orchestrates a confirmed daily check-in.
  ///
  /// Flow:
  /// 1. Validates program ID and user confirmation.
  /// 2. If not confirmed, returns immediately without reconciliation or writes.
  /// 3. Reconciles program BEFORE check-in attempt.
  /// 4. Dispatches reconciliation outcome (rejects if notStarted, blocks if missed day).
  /// 5. Invokes DailyCheckInV2Service.checkIn().
  /// 6. If target reached, immediately attempts SUCCESS finalization.
  /// 7. Safely handles 03:00 boundary race if clock advances during orchestration.
  Future<OrchestratedCheckInResult> checkIn({
    required String programId,
    required bool confirmedByUser,
    String? recipientNameSnapshot,
  }) {
    return _synchronized(() async {
      final cleanId = programId.trim();
      if (cleanId.isEmpty) {
        return OrchestratedCheckInResult.failure(
          outcome: OrchestratedCheckInOutcome.invalidProgramId,
          programId: programId,
          message: 'Program ID must not be empty or blank.',
        );
      }

      // Step 4.1: If not confirmed, return without performing reconciliation or writing records.
      if (!confirmedByUser) {
        return OrchestratedCheckInResult.failure(
          outcome: OrchestratedCheckInOutcome.confirmationRequired,
          programId: cleanId,
          message: 'Check-in requires user confirmation.',
        );
      }

      // Step 4.3: Reconcile the program BEFORE attempting check-in.
      final ProgramReconciliationResult reconResult;
      try {
        reconResult = await _reconciliationService.reconcileProgram(cleanId);
      } on HiveError catch (_) {
        return OrchestratedCheckInResult.failure(
          outcome: OrchestratedCheckInOutcome.persistenceError,
          programId: cleanId,
          message: 'Storage operation failed during reconciliation.',
        );
      } catch (_) {
        return OrchestratedCheckInResult.failure(
          outcome: OrchestratedCheckInOutcome.unexpectedError,
          programId: cleanId,
          message: 'Unexpected error occurred during reconciliation.',
        );
      }

      // Step 4.4: Handle reconciliation outcomes explicitly:
      switch (reconResult.outcome) {
        case ProgramReconciliationOutcome.notStarted:
          return OrchestratedCheckInResult.failure(
            outcome: OrchestratedCheckInOutcome.programNotStarted,
            programId: cleanId,
            program: reconResult.program,
            message: reconResult.errorMessage ??
                'Program is scheduled for a future operational day.',
          );

        case ProgramReconciliationOutcome.pendingCreated:
        case ProgramReconciliationOutcome.alreadyPending:
          return OrchestratedCheckInResult.muhasabahRequired(
            programId: cleanId,
            program: reconResult.program,
            missedDayKey: reconResult.missedDayKey,
            message: reconResult.errorMessage ??
                'Missed required check-in. Muhasabah required.',
          );

        case ProgramReconciliationOutcome.requiresSuccessFinalization:
          // Target duration was already completed in earlier check-ins! Finalize SUCCESS.
          return _finalizeSuccessForCheckIn(
            cleanId: cleanId,
            reconciledProgram: reconResult.program,
            callerRecipientName: recipientNameSnapshot,
            existingCheckIn: null,
            progress: null,
          );

        case ProgramReconciliationOutcome.terminalProgram:
          // Terminal program: do not create check-in; handle SUCCESS recovery only when applicable.
          final termProgram = reconResult.program ?? _safeGetProgram(cleanId);
          if (termProgram != null &&
              termProgram.status == ProgramV2Model.statusSuccess) {
            final effectiveName = _resolveRecipientName(
              callerName: recipientNameSnapshot,
              program: termProgram,
            );
            if (effectiveName == null || effectiveName.isEmpty) {
              return OrchestratedCheckInResult.needsRecipientName(
                programId: cleanId,
                program: termProgram,
                message:
                    'SUCCESS program is missing recipient name for achievement recovery.',
              );
            }
            final succRes = await _successService.finalizeSuccess(
              programId: cleanId,
              recipientNameSnapshot: effectiveName,
            );
            return _mapSuccessResultToCheckInResult(
              cleanId: cleanId,
              successResult: succRes,
              checkIn: null,
              progress: null,
            );
          }
          return OrchestratedCheckInResult.failure(
            outcome: OrchestratedCheckInOutcome.terminalProgram,
            programId: cleanId,
            program: termProgram,
            message: reconResult.errorMessage ??
                'Program is in a terminal lifecycle state.',
          );

        case ProgramReconciliationOutcome.invalidProgramId:
          return OrchestratedCheckInResult.failure(
            outcome: OrchestratedCheckInOutcome.invalidProgramId,
            programId: cleanId,
            message: reconResult.errorMessage ?? 'Invalid program ID.',
          );

        case ProgramReconciliationOutcome.programNotFound:
          return OrchestratedCheckInResult.failure(
            outcome: OrchestratedCheckInOutcome.programNotFound,
            programId: cleanId,
            message: reconResult.errorMessage ?? 'Program not found.',
          );

        case ProgramReconciliationOutcome.dataIntegrityError:
          return OrchestratedCheckInResult.failure(
            outcome: OrchestratedCheckInOutcome.dataIntegrityError,
            programId: cleanId,
            message:
                reconResult.errorMessage ?? 'Data integrity error detected.',
          );

        case ProgramReconciliationOutcome.persistenceError:
          return OrchestratedCheckInResult.failure(
            outcome: OrchestratedCheckInOutcome.persistenceError,
            programId: cleanId,
            message: reconResult.errorMessage ??
                'Storage operation failed during reconciliation.',
          );

        case ProgramReconciliationOutcome.unexpectedError:
          return OrchestratedCheckInResult.failure(
            outcome: OrchestratedCheckInOutcome.unexpectedError,
            programId: cleanId,
            message: reconResult.errorMessage ??
                'Unexpected error during reconciliation.',
          );

        case ProgramReconciliationOutcome.noMissedDay:
          // Eligible to proceed to check-in.
          break;
      }

      // Step 4.5: Invoke existing DailyCheckInV2Service.checkIn()
      final DailyCheckInResult checkInResult;
      try {
        checkInResult = await _dailyCheckInService.checkIn(
          programId: cleanId,
          confirmedByUser: true,
        );
      } on HiveError catch (_) {
        return OrchestratedCheckInResult.failure(
          outcome: OrchestratedCheckInOutcome.persistenceError,
          programId: cleanId,
          message: 'Storage operation failed during check-in.',
        );
      } catch (_) {
        return OrchestratedCheckInResult.failure(
          outcome: OrchestratedCheckInOutcome.unexpectedError,
          programId: cleanId,
          message: 'Unexpected error occurred during check-in.',
        );
      }

      // Handle check-in result
      if (checkInResult.isSuccess) {
        // Step 4.6: If check-in succeeds but target is not reached: return normal completion.
        if (!checkInResult.targetReached) {
          return OrchestratedCheckInResult.checkInCompleted(
            programId: cleanId,
            checkIn: checkInResult.checkIn!,
            progress: checkInResult.progress!,
            program: _safeGetProgram(cleanId),
          );
        }

        // Step 4.7: If check-in succeeds and targetReached is true:
        // invoke ProgramV2SuccessService.finalizeSuccess().
        return _finalizeSuccessForCheckIn(
          cleanId: cleanId,
          reconciledProgram: _safeGetProgram(cleanId),
          callerRecipientName: recipientNameSnapshot,
          existingCheckIn: checkInResult.checkIn,
          progress: checkInResult.progress,
        );
      }

      // Step 4.8 / Step 5: Check-in failure handling
      switch (checkInResult.failureReason!) {
        case DailyCheckInFailureReason.alreadyCheckedIn:
          return OrchestratedCheckInResult.failure(
            outcome: OrchestratedCheckInOutcome.alreadyCheckedIn,
            programId: cleanId,
            message:
                checkInResult.errorMessage ?? 'Already checked in for today.',
          );

        case DailyCheckInFailureReason.programNotStarted:
          return OrchestratedCheckInResult.failure(
            outcome: OrchestratedCheckInOutcome.programNotStarted,
            programId: cleanId,
            message:
                checkInResult.errorMessage ?? 'Program has not started yet.',
          );

        case DailyCheckInFailureReason.requiresMuhasabah:
          // STEP 5: 03:00 BOUNDARY RACE!
          // DailyCheckInService detected that an operational day closed between preflight
          // and check-in attempt. Re-run reconciliation against the current time.
          final ProgramReconciliationResult postRaceRecon;
          try {
            postRaceRecon =
                await _reconciliationService.reconcileProgram(cleanId);
          } on HiveError catch (_) {
            return OrchestratedCheckInResult.failure(
              outcome: OrchestratedCheckInOutcome.persistenceError,
              programId: cleanId,
              message:
                  'Storage operation failed during boundary reconciliation.',
            );
          } catch (_) {
            return OrchestratedCheckInResult.failure(
              outcome: OrchestratedCheckInOutcome.unexpectedError,
              programId: cleanId,
              message:
                  'Unexpected error occurred during boundary reconciliation.',
            );
          }

          if (postRaceRecon.outcome ==
                  ProgramReconciliationOutcome.pendingCreated ||
              postRaceRecon.outcome ==
                  ProgramReconciliationOutcome.alreadyPending) {
            return OrchestratedCheckInResult.muhasabahRequired(
              programId: cleanId,
              program: postRaceRecon.program,
              missedDayKey: postRaceRecon.missedDayKey,
              message: postRaceRecon.errorMessage ??
                  'Missed required check-in at operational boundary. Muhasabah required.',
            );
          } else if (postRaceRecon.isFailure) {
            return OrchestratedCheckInResult.failure(
              outcome: _mapReconFailureOutcome(postRaceRecon.outcome),
              programId: cleanId,
              message: postRaceRecon.errorMessage,
            );
          } else {
            // Ambiguity remains across boundary: safe retryable outcome
            return OrchestratedCheckInResult.failure(
              outcome: OrchestratedCheckInOutcome.boundaryRaceRetry,
              programId: cleanId,
              message:
                  'Operational day boundary transition detected during check-in. Please retry.',
            );
          }

        case DailyCheckInFailureReason.targetAlreadyReached:
          // Target was reached; finalize SUCCESS.
          return _finalizeSuccessForCheckIn(
            cleanId: cleanId,
            reconciledProgram: _safeGetProgram(cleanId),
            callerRecipientName: recipientNameSnapshot,
            existingCheckIn: null,
            progress: null,
          );

        case DailyCheckInFailureReason.programNotActive:
          final prog = _safeGetProgram(cleanId);
          if (prog?.status == ProgramV2Model.statusPendingFailure) {
            return OrchestratedCheckInResult.muhasabahRequired(
              programId: cleanId,
              program: prog,
              missedDayKey: prog?.pendingMissedDayKey,
              message:
                  'Program is in PENDING_FAILURE status. Muhasabah required.',
            );
          }
          return OrchestratedCheckInResult.failure(
            outcome: OrchestratedCheckInOutcome.terminalProgram,
            programId: cleanId,
            program: prog,
            message: checkInResult.errorMessage ?? 'Program is not ACTIVE.',
          );

        case DailyCheckInFailureReason.dataIntegrityError:
          return OrchestratedCheckInResult.failure(
            outcome: OrchestratedCheckInOutcome.dataIntegrityError,
            programId: cleanId,
            message: checkInResult.errorMessage ??
                'Data integrity error during check-in.',
          );

        case DailyCheckInFailureReason.persistenceError:
          return OrchestratedCheckInResult.failure(
            outcome: OrchestratedCheckInOutcome.persistenceError,
            programId: cleanId,
            message: checkInResult.errorMessage ??
                'Persistence error during check-in.',
          );

        case DailyCheckInFailureReason.invalidProgramId:
          return OrchestratedCheckInResult.failure(
            outcome: OrchestratedCheckInOutcome.invalidProgramId,
            programId: cleanId,
            message: checkInResult.errorMessage ?? 'Invalid program ID.',
          );

        case DailyCheckInFailureReason.programNotFound:
          return OrchestratedCheckInResult.failure(
            outcome: OrchestratedCheckInOutcome.programNotFound,
            programId: cleanId,
            message: checkInResult.errorMessage ?? 'Program not found.',
          );

        case DailyCheckInFailureReason.confirmationRequired:
          return OrchestratedCheckInResult.failure(
            outcome: OrchestratedCheckInOutcome.confirmationRequired,
            programId: cleanId,
            message: checkInResult.errorMessage ?? 'Confirmation required.',
          );
      }
    });
  }

  /// Orchestrated helper to finalize SUCCESS when target duration is completed.
  Future<OrchestratedCheckInResult> _finalizeSuccessForCheckIn({
    required String cleanId,
    required ProgramV2Model? reconciledProgram,
    required String? callerRecipientName,
    required DailyCheckInModel? existingCheckIn,
    required ProgramProgressSnapshot? progress,
  }) async {
    final effectiveName = _resolveRecipientName(
      callerName: callerRecipientName,
      program: reconciledProgram ?? _safeGetProgram(cleanId),
    );

    // If valid name is unavailable, preserve check-ins and return needsRecipientName
    if (effectiveName == null || effectiveName.isEmpty) {
      return OrchestratedCheckInResult.needsRecipientName(
        programId: cleanId,
        checkIn: existingCheckIn,
        progress: progress,
        program: reconciledProgram ?? _safeGetProgram(cleanId),
        message:
            'Program reached target duration, but recipient name is required to finalize SUCCESS.',
      );
    }

    final ProgramSuccessResult succResult;
    try {
      succResult = await _successService.finalizeSuccess(
        programId: cleanId,
        recipientNameSnapshot: effectiveName,
      );
    } on HiveError catch (_) {
      return OrchestratedCheckInResult.failure(
        outcome: OrchestratedCheckInOutcome.persistenceError,
        programId: cleanId,
        message: 'Storage operation failed during success finalization.',
      );
    } catch (_) {
      return OrchestratedCheckInResult.failure(
        outcome: OrchestratedCheckInOutcome.unexpectedError,
        programId: cleanId,
        message: 'Unexpected error occurred during success finalization.',
      );
    }

    return _mapSuccessResultToCheckInResult(
      cleanId: cleanId,
      successResult: succResult,
      checkIn: existingCheckIn,
      progress: progress,
    );
  }

  /// Maps [ProgramSuccessResult] into [OrchestratedCheckInResult].
  OrchestratedCheckInResult _mapSuccessResultToCheckInResult({
    required String cleanId,
    required ProgramSuccessResult successResult,
    required DailyCheckInModel? checkIn,
    required ProgramProgressSnapshot? progress,
  }) {
    switch (successResult.outcome) {
      case ProgramSuccessOutcome.finalizedSuccess:
      case ProgramSuccessOutcome.alreadyFinalized:
        return OrchestratedCheckInResult.successFinalized(
          programId: cleanId,
          checkIn: checkIn,
          progress: progress,
          program: successResult.program!,
          achievement: successResult.achievement!,
        );

      case ProgramSuccessOutcome.recoveredAchievement:
        return OrchestratedCheckInResult.successAchievementRecovered(
          programId: cleanId,
          checkIn: checkIn,
          progress: progress,
          program: successResult.program!,
          achievement: successResult.achievement!,
        );

      case ProgramSuccessOutcome.invalidRecipientName:
        return OrchestratedCheckInResult.needsRecipientName(
          programId: cleanId,
          checkIn: checkIn,
          progress: progress,
          program: successResult.program ?? _safeGetProgram(cleanId),
          message: successResult.errorMessage,
        );

      case ProgramSuccessOutcome.persistenceError:
        // Incomplete finalization check: if program was persisted as SUCCESS but achievement write failed
        final currentProg = _safeGetProgram(cleanId);
        if (currentProg != null &&
            currentProg.status == ProgramV2Model.statusSuccess) {
          return OrchestratedCheckInResult.successIncompleteFinalization(
            programId: cleanId,
            checkIn: checkIn,
            progress: progress,
            program: currentProg,
            message:
                'Program was finalized to SUCCESS, but achievement persistence failed. Recovery required.',
          );
        }
        return OrchestratedCheckInResult.failure(
          outcome: OrchestratedCheckInOutcome.persistenceError,
          programId: cleanId,
          message: successResult.errorMessage,
        );

      case ProgramSuccessOutcome.dataIntegrityError:
        return OrchestratedCheckInResult.failure(
          outcome: OrchestratedCheckInOutcome.dataIntegrityError,
          programId: cleanId,
          message: successResult.errorMessage,
        );

      case ProgramSuccessOutcome.invalidProgramId:
        return OrchestratedCheckInResult.failure(
          outcome: OrchestratedCheckInOutcome.invalidProgramId,
          programId: cleanId,
          message: successResult.errorMessage,
        );

      case ProgramSuccessOutcome.programNotFound:
        return OrchestratedCheckInResult.failure(
          outcome: OrchestratedCheckInOutcome.programNotFound,
          programId: cleanId,
          message: successResult.errorMessage,
        );

      case ProgramSuccessOutcome.notYetEligible:
      case ProgramSuccessOutcome.programNotActive:
        return OrchestratedCheckInResult.failure(
          outcome: OrchestratedCheckInOutcome.terminalProgram,
          programId: cleanId,
          message: successResult.errorMessage,
        );

      case ProgramSuccessOutcome.unexpectedError:
        return OrchestratedCheckInResult.failure(
          outcome: OrchestratedCheckInOutcome.unexpectedError,
          programId: cleanId,
          message: successResult.errorMessage,
        );
    }
  }

  /// Finalizes or recovers a SUCCESS program once recipient name is available.
  Future<OrchestratedSuccessResult> finalizeSuccess({
    required String programId,
    required String recipientNameSnapshot,
  }) {
    return _synchronized(() async {
      final cleanId = programId.trim();
      if (cleanId.isEmpty) {
        return OrchestratedSuccessResult.failure(
          outcome: OrchestratedSuccessOutcome.invalidProgramId,
          programId: programId,
          message: 'Program ID must not be empty or blank.',
        );
      }

      final cleanRecipient = recipientNameSnapshot.trim();
      if (cleanRecipient.isEmpty) {
        return OrchestratedSuccessResult.failure(
          outcome: OrchestratedSuccessOutcome.invalidRecipientName,
          programId: cleanId,
          message: 'Recipient name snapshot cannot be empty or whitespace.',
        );
      }

      final ProgramSuccessResult succResult;
      try {
        succResult = await _successService.finalizeSuccess(
          programId: cleanId,
          recipientNameSnapshot: cleanRecipient,
        );
      } on HiveError catch (_) {
        return OrchestratedSuccessResult.failure(
          outcome: OrchestratedSuccessOutcome.persistenceError,
          programId: cleanId,
          message: 'Storage operation failed during success finalization.',
        );
      } catch (_) {
        return OrchestratedSuccessResult.failure(
          outcome: OrchestratedSuccessOutcome.unexpectedError,
          programId: cleanId,
          message: 'Unexpected error occurred during success finalization.',
        );
      }

      return _mapProgramSuccessResult(cleanId, succResult);
    });
  }

  /// Maps [ProgramSuccessResult] into [OrchestratedSuccessResult].
  OrchestratedSuccessResult _mapProgramSuccessResult(
    String cleanId,
    ProgramSuccessResult succResult,
  ) {
    switch (succResult.outcome) {
      case ProgramSuccessOutcome.finalizedSuccess:
        return OrchestratedSuccessResult.fromOutcome(
          outcome: OrchestratedSuccessOutcome.successFinalized,
          programId: cleanId,
          program: succResult.program,
          achievement: succResult.achievement,
          completedDays: succResult.completedDays,
        );

      case ProgramSuccessOutcome.alreadyFinalized:
        return OrchestratedSuccessResult.fromOutcome(
          outcome: OrchestratedSuccessOutcome.alreadyFinalized,
          programId: cleanId,
          program: succResult.program,
          achievement: succResult.achievement,
          completedDays: succResult.completedDays,
        );

      case ProgramSuccessOutcome.recoveredAchievement:
        return OrchestratedSuccessResult.fromOutcome(
          outcome: OrchestratedSuccessOutcome.achievementRecovered,
          programId: cleanId,
          program: succResult.program,
          achievement: succResult.achievement,
          completedDays: succResult.completedDays,
        );

      case ProgramSuccessOutcome.notYetEligible:
        return OrchestratedSuccessResult.fromOutcome(
          outcome: OrchestratedSuccessOutcome.notYetEligible,
          programId: cleanId,
          program: succResult.program,
          completedDays: succResult.completedDays,
          message: succResult.errorMessage,
        );

      case ProgramSuccessOutcome.invalidRecipientName:
        return OrchestratedSuccessResult.fromOutcome(
          outcome: OrchestratedSuccessOutcome.invalidRecipientName,
          programId: cleanId,
          message: succResult.errorMessage,
        );

      case ProgramSuccessOutcome.invalidProgramId:
        return OrchestratedSuccessResult.fromOutcome(
          outcome: OrchestratedSuccessOutcome.invalidProgramId,
          programId: cleanId,
          message: succResult.errorMessage,
        );

      case ProgramSuccessOutcome.programNotFound:
        return OrchestratedSuccessResult.fromOutcome(
          outcome: OrchestratedSuccessOutcome.programNotFound,
          programId: cleanId,
          message: succResult.errorMessage,
        );

      case ProgramSuccessOutcome.programNotActive:
        return OrchestratedSuccessResult.fromOutcome(
          outcome: OrchestratedSuccessOutcome.programNotActive,
          programId: cleanId,
          message: succResult.errorMessage,
        );

      case ProgramSuccessOutcome.dataIntegrityError:
        return OrchestratedSuccessResult.fromOutcome(
          outcome: OrchestratedSuccessOutcome.dataIntegrityError,
          programId: cleanId,
          message: succResult.errorMessage,
        );

      case ProgramSuccessOutcome.persistenceError:
        final currentProg = _safeGetProgram(cleanId);
        if (currentProg != null &&
            currentProg.status == ProgramV2Model.statusSuccess) {
          return OrchestratedSuccessResult.fromOutcome(
            outcome: OrchestratedSuccessOutcome.incompleteFinalization,
            programId: cleanId,
            program: currentProg,
            message:
                'Program was finalized to SUCCESS, but achievement persistence failed. Recovery required.',
          );
        }
        return OrchestratedSuccessResult.fromOutcome(
          outcome: OrchestratedSuccessOutcome.persistenceError,
          programId: cleanId,
          message: succResult.errorMessage,
        );

      case ProgramSuccessOutcome.unexpectedError:
        return OrchestratedSuccessResult.fromOutcome(
          outcome: OrchestratedSuccessOutcome.unexpectedError,
          programId: cleanId,
          message: succResult.errorMessage,
        );
    }
  }

  /// Orchestrated reason-submission for a program in PENDING_FAILURE status.
  ///
  /// Enforces:
  /// 1. Explicit reasonCode and reasonLabelSnapshot (never auto-generated).
  /// 2. Delegates terminal failure classification (FAILED vs WARNING) to ProgramV2MuhasabahService.
  /// 3. Idempotent retries and reason conflict detection.
  /// 4. Preserves all history and check-ins without creating separate tables.
  Future<OrchestratedMuhasabahResult> submitMuhasabah({
    required String programId,
    required String reasonCode,
    required String reasonLabelSnapshot,
    String? note,
  }) {
    return _synchronized(() async {
      final cleanId = programId.trim();
      if (cleanId.isEmpty) {
        return OrchestratedMuhasabahResult.failure(
          outcome: OrchestratedMuhasabahOutcome.invalidProgramId,
          programId: programId,
          message: 'Program ID must not be empty or blank.',
        );
      }

      final cleanReasonCode = reasonCode.trim();
      final cleanReasonLabel = reasonLabelSnapshot.trim();
      if (cleanReasonCode.isEmpty || cleanReasonLabel.isEmpty) {
        return OrchestratedMuhasabahResult.failure(
          outcome: OrchestratedMuhasabahOutcome.invalidReason,
          programId: cleanId,
          message:
              'Reason code and reason label snapshot must not be empty or whitespace.',
        );
      }

      final ProgramMuhasabahResult muhasabahResult;
      try {
        muhasabahResult = await _muhasabahService.finalizeFailure(
          programId: cleanId,
          reasonCode: cleanReasonCode,
          reasonLabelSnapshot: cleanReasonLabel,
          note: note,
        );
      } on HiveError catch (_) {
        return OrchestratedMuhasabahResult.failure(
          outcome: OrchestratedMuhasabahOutcome.persistenceError,
          programId: cleanId,
          message: 'Storage operation failed during Muhasabah submission.',
        );
      } catch (_) {
        return OrchestratedMuhasabahResult.failure(
          outcome: OrchestratedMuhasabahOutcome.unexpectedError,
          programId: cleanId,
          message: 'Unexpected error occurred during Muhasabah submission.',
        );
      }

      return _mapMuhasabahResult(cleanId, muhasabahResult);
    });
  }

  /// Maps [ProgramMuhasabahResult] to [OrchestratedMuhasabahResult].
  OrchestratedMuhasabahResult _mapMuhasabahResult(
    String cleanId,
    ProgramMuhasabahResult res,
  ) {
    switch (res.outcome) {
      case ProgramMuhasabahOutcome.failedCreated:
        return OrchestratedMuhasabahResult.fromOutcome(
          outcome: OrchestratedMuhasabahOutcome.failedCreated,
          programId: cleanId,
          finalStatus: res.finalStatus,
          program: res.program,
          failureRecord: res.failureRecord,
          completedDays: res.completedDays,
        );

      case ProgramMuhasabahOutcome.warningCreated:
        return OrchestratedMuhasabahResult.fromOutcome(
          outcome: OrchestratedMuhasabahOutcome.warningCreated,
          programId: cleanId,
          finalStatus: res.finalStatus,
          program: res.program,
          failureRecord: res.failureRecord,
          completedDays: res.completedDays,
        );

      case ProgramMuhasabahOutcome.alreadyFinalized:
        return OrchestratedMuhasabahResult.fromOutcome(
          outcome: OrchestratedMuhasabahOutcome.alreadyFinalized,
          programId: cleanId,
          finalStatus: res.finalStatus,
          program: res.program,
          failureRecord: res.failureRecord,
          completedDays: res.completedDays,
        );

      case ProgramMuhasabahOutcome.programNotPending:
        return OrchestratedMuhasabahResult.fromOutcome(
          outcome: OrchestratedMuhasabahOutcome.programNotPending,
          programId: cleanId,
          message: res.errorMessage,
        );

      case ProgramMuhasabahOutcome.invalidReason:
        return OrchestratedMuhasabahResult.fromOutcome(
          outcome: OrchestratedMuhasabahOutcome.invalidReason,
          programId: cleanId,
          message: res.errorMessage,
        );

      case ProgramMuhasabahOutcome.reasonConflict:
        return OrchestratedMuhasabahResult.fromOutcome(
          outcome: OrchestratedMuhasabahOutcome.reasonConflict,
          programId: cleanId,
          message: res.errorMessage,
        );

      case ProgramMuhasabahOutcome.invalidProgramId:
        return OrchestratedMuhasabahResult.fromOutcome(
          outcome: OrchestratedMuhasabahOutcome.invalidProgramId,
          programId: cleanId,
          message: res.errorMessage,
        );

      case ProgramMuhasabahOutcome.programNotFound:
        return OrchestratedMuhasabahResult.fromOutcome(
          outcome: OrchestratedMuhasabahOutcome.programNotFound,
          programId: cleanId,
          message: res.errorMessage,
        );

      case ProgramMuhasabahOutcome.dataIntegrityError:
        return OrchestratedMuhasabahResult.fromOutcome(
          outcome: OrchestratedMuhasabahOutcome.dataIntegrityError,
          programId: cleanId,
          message: res.errorMessage,
        );

      case ProgramMuhasabahOutcome.persistenceError:
        return OrchestratedMuhasabahResult.fromOutcome(
          outcome: OrchestratedMuhasabahOutcome.persistenceError,
          programId: cleanId,
          message: res.errorMessage,
        );

      case ProgramMuhasabahOutcome.unexpectedError:
        return OrchestratedMuhasabahResult.fromOutcome(
          outcome: OrchestratedMuhasabahOutcome.unexpectedError,
          programId: cleanId,
          message: res.errorMessage,
        );
    }
  }

  /// Domain entry point suitable for future invocation at app bootstrap or resume.
  ///
  /// Flow:
  /// 1. Reconciles ACTIVE and PENDING_FAILURE programs using the batch reconciliation service.
  /// 2. Returns pending Muhasabah actions for programs with missed operational days.
  /// 3. Attempts SUCCESS finalization for completed journeys where recipient name is available.
  /// 4. Reports needsRecipientName for completed journeys where recipient name is unavailable.
  /// 5. Inspects existing SUCCESS programs for missing FINAL_SUCCESS achievements (recovery).
  /// 6. Never modifies FAILED or WARNING records.
  /// 7. Preserves each per-program result without collapsing failures into a false global success.
  Future<OrchestratedBootstrapResult> processAppResume({
    DateTime? capturedNow,
    Map<String, String>? recipientNameByProgramId,
  }) {
    return _synchronized(() async {
      final now = capturedNow ?? _dateService.now;
      final items = <ProgramResumeItem>[];

      // 1. Reconcile ACTIVE and PENDING_FAILURE programs using existing batch reconciliation
      final BatchReconciliationResult batchRecon;
      try {
        batchRecon = await _reconciliationService.reconcileActivePrograms(
            capturedNow: now);
      } on HiveError catch (_) {
        return OrchestratedBootstrapResult(
          items: [
            ProgramResumeItem(
              programId: '',
              action: ProgramResumeAction.error,
              errorMessage:
                  'Storage operation failed during batch reconciliation.',
            ),
          ],
          inspectedAt: now,
        );
      } catch (_) {
        return OrchestratedBootstrapResult(
          items: [
            ProgramResumeItem(
              programId: '',
              action: ProgramResumeAction.error,
              errorMessage:
                  'Unexpected error occurred during batch reconciliation.',
            ),
          ],
          inspectedAt: now,
        );
      }

      final processedProgramIds = <String>{};

      for (final reconRes in batchRecon.results) {
        final progId = reconRes.programId ?? '';
        if (progId.isNotEmpty) {
          processedProgramIds.add(progId);
        }

        switch (reconRes.outcome) {
          case ProgramReconciliationOutcome.noMissedDay:
            items.add(ProgramResumeItem(
              programId: progId,
              action: ProgramResumeAction.onTrack,
              program: reconRes.program,
            ));
            break;

          case ProgramReconciliationOutcome.notStarted:
            items.add(ProgramResumeItem(
              programId: progId,
              action: ProgramResumeAction.notStarted,
              program: reconRes.program,
            ));
            break;

          case ProgramReconciliationOutcome.pendingCreated:
          case ProgramReconciliationOutcome.alreadyPending:
            items.add(ProgramResumeItem(
              programId: progId,
              action: ProgramResumeAction.muhasabahRequired,
              program: reconRes.program,
              missedDayKey: reconRes.missedDayKey,
              errorMessage: reconRes.errorMessage,
            ));
            break;

          case ProgramReconciliationOutcome.requiresSuccessFinalization:
            // Check if recipient name is available
            final recipientName = _resolveRecipientName(
              callerName: recipientNameByProgramId?[progId],
              program: reconRes.program,
            );
            if (recipientName != null && recipientName.isNotEmpty) {
              try {
                final succRes = await _successService.finalizeSuccess(
                  programId: progId,
                  recipientNameSnapshot: recipientName,
                  capturedNow: now,
                );
                if (succRes.isSuccess) {
                  items.add(ProgramResumeItem(
                    programId: progId,
                    action: ProgramResumeAction.successFinalized,
                    program: succRes.program,
                    achievement: succRes.achievement,
                  ));
                } else {
                  items.add(ProgramResumeItem(
                    programId: progId,
                    action: ProgramResumeAction.error,
                    program: reconRes.program,
                    errorMessage: succRes.errorMessage ??
                        'Failed to finalize SUCCESS during resume.',
                  ));
                }
              } on HiveError catch (_) {
                items.add(ProgramResumeItem(
                  programId: progId,
                  action: ProgramResumeAction.error,
                  program: reconRes.program,
                  errorMessage:
                      'Storage operation failed while finalizing SUCCESS during resume.',
                ));
              } catch (_) {
                items.add(ProgramResumeItem(
                  programId: progId,
                  action: ProgramResumeAction.error,
                  program: reconRes.program,
                  errorMessage:
                      'Unexpected error occurred while finalizing SUCCESS during resume.',
                ));
              }
            } else {
              items.add(ProgramResumeItem(
                programId: progId,
                action: ProgramResumeAction.needsRecipientName,
                program: reconRes.program,
                errorMessage:
                    'Completed target duration, but recipient name is needed for finalization.',
              ));
            }
            break;

          case ProgramReconciliationOutcome.terminalProgram:
            items.add(ProgramResumeItem(
              programId: progId,
              action: ProgramResumeAction.alreadyFinalized,
              program: reconRes.program,
            ));
            break;

          case ProgramReconciliationOutcome.invalidProgramId:
          case ProgramReconciliationOutcome.programNotFound:
          case ProgramReconciliationOutcome.dataIntegrityError:
          case ProgramReconciliationOutcome.persistenceError:
          case ProgramReconciliationOutcome.unexpectedError:
            items.add(ProgramResumeItem(
              programId: progId,
              action: ProgramResumeAction.error,
              errorMessage: reconRes.errorMessage ??
                  'Reconciliation failure for program "$progId".',
            ));
            break;
        }
      }

      // 5. Inspect already SUCCESS programs for missing FINAL_SUCCESS achievements
      // and invoke the existing recovery flow.
      List<ProgramV2Model> allPrograms;
      try {
        allPrograms = _programRepository.getAll();
      } on HiveError catch (_) {
        items.add(ProgramResumeItem(
          programId: '',
          action: ProgramResumeAction.error,
          errorMessage:
              'Storage operation failed while retrieving programs for recovery check.',
        ));
        allPrograms = [];
      } catch (_) {
        items.add(ProgramResumeItem(
          programId: '',
          action: ProgramResumeAction.error,
          errorMessage:
              'Unexpected error occurred while retrieving programs for recovery check.',
        ));
        allPrograms = [];
      }

      for (final program in allPrograms) {
        if (program.status == ProgramV2Model.statusSuccess &&
            !processedProgramIds.contains(program.id)) {
          final recipientName = program.recipientNameSnapshot?.trim();
          if (recipientName == null || recipientName.isEmpty) {
            items.add(ProgramResumeItem(
              programId: program.id,
              action: ProgramResumeAction.error,
              program: program,
              errorMessage: 'SUCCESS program is missing recipientNameSnapshot.',
            ));
            continue;
          }

          try {
            final succRes = await _successService.finalizeSuccess(
              programId: program.id,
              recipientNameSnapshot: recipientName,
              capturedNow: now,
            );
            if (succRes.outcome == ProgramSuccessOutcome.recoveredAchievement) {
              items.add(ProgramResumeItem(
                programId: program.id,
                action: ProgramResumeAction.achievementRecovered,
                program: succRes.program,
                achievement: succRes.achievement,
              ));
            } else if (succRes.outcome ==
                ProgramSuccessOutcome.alreadyFinalized) {
              items.add(ProgramResumeItem(
                programId: program.id,
                action: ProgramResumeAction.alreadyFinalized,
                program: succRes.program,
                achievement: succRes.achievement,
              ));
            } else {
              items.add(ProgramResumeItem(
                programId: program.id,
                action: ProgramResumeAction.error,
                program: program,
                errorMessage: succRes.errorMessage ??
                    'Failed recovery check on SUCCESS program.',
              ));
            }
          } on HiveError catch (_) {
            items.add(ProgramResumeItem(
              programId: program.id,
              action: ProgramResumeAction.error,
              program: program,
              errorMessage:
                  'Storage operation failed during achievement recovery check.',
            ));
          } catch (_) {
            items.add(ProgramResumeItem(
              programId: program.id,
              action: ProgramResumeAction.error,
              program: program,
              errorMessage:
                  'Unexpected error occurred during achievement recovery check.',
            ));
          }
        }
      }

      return OrchestratedBootstrapResult(
        items: items,
        inspectedAt: now,
      );
    });
  }

  /// Helper to safely retrieve a program from repository.
  ProgramV2Model? _safeGetProgram(String id) {
    try {
      return _programRepository.getById(id);
    } catch (_) {
      return null;
    }
  }

  /// Helper to resolve recipient name from caller override or stored program snapshot.
  String? _resolveRecipientName({
    String? callerName,
    ProgramV2Model? program,
  }) {
    if (callerName != null && callerName.trim().isNotEmpty) {
      return callerName.trim();
    }
    if (program?.recipientNameSnapshot != null &&
        program!.recipientNameSnapshot!.trim().isNotEmpty) {
      return program.recipientNameSnapshot!.trim();
    }
    return null;
  }

  /// Helper to map reconciliation failures to check-in outcomes.
  OrchestratedCheckInOutcome _mapReconFailureOutcome(
      ProgramReconciliationOutcome outcome) {
    switch (outcome) {
      case ProgramReconciliationOutcome.persistenceError:
        return OrchestratedCheckInOutcome.persistenceError;
      case ProgramReconciliationOutcome.dataIntegrityError:
        return OrchestratedCheckInOutcome.dataIntegrityError;
      case ProgramReconciliationOutcome.invalidProgramId:
        return OrchestratedCheckInOutcome.invalidProgramId;
      case ProgramReconciliationOutcome.programNotFound:
        return OrchestratedCheckInOutcome.programNotFound;
      default:
        return OrchestratedCheckInOutcome.unexpectedError;
    }
  }
}
