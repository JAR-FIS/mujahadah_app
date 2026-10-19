import 'dart:async';

import 'package:hive/hive.dart';

import '../core/date/date_service.dart';
import '../models/achievement_model.dart';
import '../models/daily_checkin_model.dart';
import '../models/failure_record_model.dart';
import '../models/program_v2_model.dart';
import '../repositories/achievement_v2_repository.dart';
import '../repositories/daily_checkin_v2_repository.dart';
import '../repositories/failure_record_v2_repository.dart';
import '../repositories/program_v2_repository.dart';

/// Typed outcomes for program success finalization operations.
enum ProgramSuccessOutcome {
  /// Program was successfully finalized to SUCCESS and FINAL_SUCCESS achievement was created.
  finalizedSuccess,

  /// Program and achievement were already validly finalized; idempotent return without mutation.
  alreadyFinalized,

  /// Program was already in SUCCESS but was missing achievement; achievement was safely recovered.
  recoveredAchievement,

  /// Program target has not yet been reached (completedDays < targetDays).
  notYetEligible,

  /// Recipient name snapshot was empty or whitespace.
  invalidRecipientName,

  /// Program ID was empty or whitespace.
  invalidProgramId,

  /// Program was not found in storage.
  programNotFound,

  /// Program is not in ACTIVE status (e.g. PENDING_FAILURE, FAILED, WARNING).
  programNotActive,

  /// Storage records contain conflicting, corrupt, or inconsistent data.
  dataIntegrityError,

  /// Storage read/write operation failed.
  persistenceError,

  /// An unexpected error occurred during finalization.
  unexpectedError,
}

/// Result of finalizing a program to SUCCESS.
class ProgramSuccessResult {
  final ProgramSuccessOutcome outcome;
  final String? programId;
  final String? finalStatus;
  final ProgramV2Model? program;
  final AchievementModel? achievement;
  final int? completedDays;
  final String? errorMessage;

  const ProgramSuccessResult._({
    required this.outcome,
    this.programId,
    this.finalStatus,
    this.program,
    this.achievement,
    this.completedDays,
    this.errorMessage,
  });

  /// True if the operation completed successfully (new success, idempotent retry, or recovery).
  bool get isSuccess =>
      outcome == ProgramSuccessOutcome.finalizedSuccess ||
      outcome == ProgramSuccessOutcome.alreadyFinalized ||
      outcome == ProgramSuccessOutcome.recoveredAchievement;

  /// True if an error or ineligibility occurred.
  bool get isFailure => !isSuccess;

  /// True if a new transition to SUCCESS was persisted.
  bool get isFinalizedSuccess =>
      outcome == ProgramSuccessOutcome.finalizedSuccess;

  /// True if the program and achievement were already finalized.
  bool get isAlreadyFinalized =>
      outcome == ProgramSuccessOutcome.alreadyFinalized;

  /// True if a missing achievement was safely recovered for an already SUCCESS program.
  bool get isRecoveredAchievement =>
      outcome == ProgramSuccessOutcome.recoveredAchievement;

  /// True if the program is not yet eligible for SUCCESS finalization.
  bool get isNotYetEligible => outcome == ProgramSuccessOutcome.notYetEligible;

  factory ProgramSuccessResult.finalizedSuccess({
    required String programId,
    required ProgramV2Model program,
    required AchievementModel achievement,
    required int completedDays,
  }) =>
      ProgramSuccessResult._(
        outcome: ProgramSuccessOutcome.finalizedSuccess,
        programId: programId,
        finalStatus: ProgramV2Model.statusSuccess,
        program: program,
        achievement: achievement,
        completedDays: completedDays,
      );

  factory ProgramSuccessResult.alreadyFinalized({
    required String programId,
    required ProgramV2Model program,
    required AchievementModel achievement,
    required int completedDays,
  }) =>
      ProgramSuccessResult._(
        outcome: ProgramSuccessOutcome.alreadyFinalized,
        programId: programId,
        finalStatus: ProgramV2Model.statusSuccess,
        program: program,
        achievement: achievement,
        completedDays: completedDays,
      );

  factory ProgramSuccessResult.recoveredAchievement({
    required String programId,
    required ProgramV2Model program,
    required AchievementModel achievement,
    required int completedDays,
  }) =>
      ProgramSuccessResult._(
        outcome: ProgramSuccessOutcome.recoveredAchievement,
        programId: programId,
        finalStatus: ProgramV2Model.statusSuccess,
        program: program,
        achievement: achievement,
        completedDays: completedDays,
      );

  factory ProgramSuccessResult.notYetEligible({
    required String programId,
    required ProgramV2Model program,
    required int completedDays,
    required int targetDays,
  }) =>
      ProgramSuccessResult._(
        outcome: ProgramSuccessOutcome.notYetEligible,
        programId: programId,
        program: program,
        completedDays: completedDays,
        errorMessage:
            'Program has completed $completedDays of $targetDays required operational days.',
      );

  factory ProgramSuccessResult.failure({
    required ProgramSuccessOutcome outcome,
    String? programId,
    required String message,
  }) =>
      ProgramSuccessResult._(
        outcome: outcome,
        programId: programId,
        errorMessage: message,
      );
}

/// Service implementing safe, offline-first finalization of an ACTIVE Mujahadah program
/// to SUCCESS after all required operational-day check-ins have been completed.
///
/// Business Invariants:
/// 1. Lifecycle transition: ACTIVE -> SUCCESS.
/// 2. Already SUCCESS programs are handled idempotently; missing achievements are recovered safely.
/// 3. Ineligible states (PENDING_FAILURE, FAILED, WARNING) cannot be finalized to SUCCESS.
/// 4. Completed days are derived directly and authoritatively from consecutive [DailyCheckInModel] records.
/// 5. Operational day boundaries respect the approved 03:00 local cutoff via [DateService].
/// 6. Exactly one immutable [AchievementModel] of type [AchievementModel.typeFinalSuccess]
///    is persisted with canonical ID `ach_final_<programId>`.
/// 7. A two-box write sequence (Program first, Achievement second) prevents orphan achievements.
/// 8. In-process serialization guarantees single-instance idempotency and prevents race conditions.
///
/// Concurrency Scope & Limitations:
/// In-process serialization is strictly scoped to this single [ProgramV2SuccessService] instance.
/// It serializes overlapping asynchronous calls to prevent race conditions within the same service instance.
/// It does NOT guarantee cross-instance, cross-isolate, or multi-process synchronization.
class ProgramV2SuccessService {
  final ProgramV2Repository _programRepository;
  final DailyCheckInV2Repository _checkInRepository;
  final AchievementV2Repository _achievementRepository;
  final FailureRecordV2Repository _failureRecordRepository;
  final DateService _dateService;

  // In-process FIFO lock to serialize operations within this service instance.
  Future<void> _lock = Future.value();

  ProgramV2SuccessService({
    required ProgramV2Repository programRepository,
    required DailyCheckInV2Repository checkInRepository,
    required AchievementV2Repository achievementRepository,
    required FailureRecordV2Repository failureRecordRepository,
    DateService? dateService,
  })  : _programRepository = programRepository,
        _checkInRepository = checkInRepository,
        _achievementRepository = achievementRepository,
        _failureRecordRepository = failureRecordRepository,
        _dateService = dateService ?? DateService();

  /// In-process serialization to serialize async finalization operations.
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

  /// Finalizes an ACTIVE program to SUCCESS after verifying all required check-ins.
  ///
  /// Serialized in-process to guarantee idempotency and crash recovery.
  Future<ProgramSuccessResult> finalizeSuccess({
    required String programId,
    required String recipientNameSnapshot,
    DateTime? capturedNow,
  }) {
    return _synchronized(() async {
      final now = capturedNow ?? _dateService.now;
      return _finalizeSuccessInternal(
        programId: programId,
        recipientNameSnapshot: recipientNameSnapshot,
        capturedNow: now,
      );
    });
  }

  Future<ProgramSuccessResult> _finalizeSuccessInternal({
    required String programId,
    required String recipientNameSnapshot,
    required DateTime capturedNow,
  }) async {
    // 1. Validate programId input
    if (programId.trim().isEmpty) {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.invalidProgramId,
        programId: programId,
        message: 'Program ID cannot be empty or whitespace.',
      );
    }
    final cleanId = programId.trim();

    // 2. Retrieve Program from repository
    final ProgramV2Model? program;
    try {
      program = _programRepository.getById(cleanId);
    } on HiveError {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.persistenceError,
        programId: cleanId,
        message: 'Storage operation failed during program lookup.',
      );
    } on Exception {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.persistenceError,
        programId: cleanId,
        message: 'Storage operation failed during program lookup.',
      );
    }

    if (program == null) {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.programNotFound,
        programId: cleanId,
        message: 'Program "$cleanId" was not found in storage.',
      );
    }

    // 3. Validate Program storage identity and field invariants
    final integrityError = _validateProgramIntegrity(program, cleanId);
    if (integrityError != null) {
      return integrityError;
    }

    // 4. Validate Program lifecycle eligibility
    if (program.status == ProgramV2Model.statusPendingFailure) {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.programNotActive,
        programId: cleanId,
        message:
            'Program "$cleanId" is in PENDING_FAILURE status and cannot be finalized to SUCCESS.',
      );
    }
    if (program.status == ProgramV2Model.statusFailed) {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.programNotActive,
        programId: cleanId,
        message:
            'Program "$cleanId" is in FAILED status and cannot be finalized to SUCCESS.',
      );
    }
    if (program.status == ProgramV2Model.statusWarning) {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.programNotActive,
        programId: cleanId,
        message:
            'Program "$cleanId" is in WARNING status and cannot be finalized to SUCCESS.',
      );
    }
    if (program.status != ProgramV2Model.statusActive &&
        program.status != ProgramV2Model.statusSuccess) {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.programNotActive,
        programId: cleanId,
        message:
            'Program "$cleanId" has invalid status "${program.status}" for success finalization.',
      );
    }

    // 5. Lifecycle-specific field checks
    if (program.status == ProgramV2Model.statusActive) {
      if (program.finalizedAt != null) {
        return ProgramSuccessResult.failure(
          outcome: ProgramSuccessOutcome.dataIntegrityError,
          programId: cleanId,
          message:
              'ACTIVE program "$cleanId" has inconsistent finalizedAt timestamp.',
        );
      }
      if (program.pendingMissedDayKey != null) {
        return ProgramSuccessResult.failure(
          outcome: ProgramSuccessOutcome.dataIntegrityError,
          programId: cleanId,
          message:
              'ACTIVE program "$cleanId" has inconsistent pendingMissedDayKey.',
        );
      }
      if (recipientNameSnapshot.trim().isEmpty) {
        return ProgramSuccessResult.failure(
          outcome: ProgramSuccessOutcome.invalidRecipientName,
          programId: cleanId,
          message:
              'Recipient name snapshot cannot be empty or whitespace for success finalization.',
        );
      }
    } else {
      // program.status == statusSuccess
      if (program.finalizedAt == null) {
        return ProgramSuccessResult.failure(
          outcome: ProgramSuccessOutcome.dataIntegrityError,
          programId: cleanId,
          message:
              'SUCCESS program "$cleanId" is missing finalizedAt timestamp.',
        );
      }
      if (program.pendingMissedDayKey != null) {
        return ProgramSuccessResult.failure(
          outcome: ProgramSuccessOutcome.dataIntegrityError,
          programId: cleanId,
          message:
              'SUCCESS program "$cleanId" has inconsistent pendingMissedDayKey.',
        );
      }
      if (program.recipientNameSnapshot == null ||
          program.recipientNameSnapshot!.trim().isEmpty) {
        return ProgramSuccessResult.failure(
          outcome: ProgramSuccessOutcome.dataIntegrityError,
          programId: cleanId,
          message:
              'SUCCESS program "$cleanId" is missing or has empty recipientNameSnapshot.',
        );
      }
    }

    // 6. Verify program contains NO conflicting FailureRecord history
    final List<FailureRecordModel> failureRecords;
    try {
      failureRecords = _failureRecordRepository.getByProgramId(cleanId);
    } on HiveError {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.persistenceError,
        programId: cleanId,
        message:
            'Storage operation failed while inspecting failure records for program.',
      );
    } catch (_) {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.persistenceError,
        programId: cleanId,
        message:
            'Storage operation failed while inspecting failure records for program.',
      );
    }

    if (failureRecords.isNotEmpty) {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.dataIntegrityError,
        programId: cleanId,
        message:
            'Program "$cleanId" contains conflicting FailureRecord history (${failureRecords.length} records) and cannot be SUCCESS.',
      );
    }

    // 7. Authoritative DailyCheckIn progress calculation
    final currentDayKey = _dateService.getMujahadahDayKey(capturedNow);
    final progressResult =
        _calculateAuthoritativeCheckIns(program, currentDayKey);
    if (progressResult.isStorageError) {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.persistenceError,
        programId: cleanId,
        message: progressResult.errorMessage ??
            'Storage operation failed while reading check-in records.',
      );
    }
    if (progressResult.isIntegrityError) {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.dataIntegrityError,
        programId: cleanId,
        message: progressResult.errorMessage ??
            'Integrity anomaly detected in daily check-in records.',
      );
    }
    if (progressResult.isNotYetEligible) {
      return ProgramSuccessResult.notYetEligible(
        programId: cleanId,
        program: program,
        completedDays: progressResult.completedDays!,
        targetDays: program.targetDays,
      );
    }

    final int completedDays = progressResult.completedDays!;
    final DailyCheckInModel finalCheckIn = progressResult.finalCheckIn!;
    final expectedAchievementId =
        AchievementV2Repository.buildFinalSuccessId(cleanId);

    // 8. Retrieve existing achievements for this program
    final List<AchievementModel> allAchievements;
    try {
      allAchievements = _achievementRepository.getByProgramId(cleanId);
    } on HiveError {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.persistenceError,
        programId: cleanId,
        message:
            'Storage operation failed while inspecting achievements for program.',
      );
    } catch (_) {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.persistenceError,
        programId: cleanId,
        message:
            'Storage operation failed while inspecting achievements for program.',
      );
    }

    final finalSuccessAchievements = allAchievements
        .where((a) => a.type == AchievementModel.typeFinalSuccess)
        .toList();

    // Check for anomalous duplicate FINAL_SUCCESS records
    if (finalSuccessAchievements.length > 1) {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.dataIntegrityError,
        programId: cleanId,
        message:
            'Anomalous multiple FINAL_SUCCESS achievement records (${finalSuccessAchievements.length}) detected for program "$cleanId".',
      );
    }

    // 9. Handle already SUCCESS program (Idempotent retry or partial-write recovery)
    if (program.status == ProgramV2Model.statusSuccess) {
      final storedRecipient = program.recipientNameSnapshot!.trim();

      if (finalSuccessAchievements.isEmpty) {
        // Recovery scenario: Program was persisted as SUCCESS, but achievement was not yet persisted.
        final bool canonicalOccupied;
        try {
          canonicalOccupied =
              _achievementRepository.containsId(expectedAchievementId);
        } on HiveError {
          return ProgramSuccessResult.failure(
            outcome: ProgramSuccessOutcome.persistenceError,
            programId: cleanId,
            message:
                'Storage operation failed while checking canonical achievement key.',
          );
        } catch (_) {
          return ProgramSuccessResult.failure(
            outcome: ProgramSuccessOutcome.persistenceError,
            programId: cleanId,
            message:
                'Storage operation failed while checking canonical achievement key.',
          );
        }

        if (canonicalOccupied) {
          return ProgramSuccessResult.failure(
            outcome: ProgramSuccessOutcome.dataIntegrityError,
            programId: cleanId,
            message:
                'Canonical achievement storage key "$expectedAchievementId" is occupied by an unexpected record.',
          );
        }

        // Pre-write snapshot guard for achievement recovery
        final ProgramV2Model? latestProgram;
        try {
          latestProgram = _programRepository.getById(cleanId);
        } on HiveError {
          return ProgramSuccessResult.failure(
            outcome: ProgramSuccessOutcome.persistenceError,
            programId: cleanId,
            message:
                'Storage operation failed while re-reading program before achievement recovery.',
          );
        } catch (_) {
          return ProgramSuccessResult.failure(
            outcome: ProgramSuccessOutcome.persistenceError,
            programId: cleanId,
            message:
                'Storage operation failed while re-reading program before achievement recovery.',
          );
        }

        if (latestProgram == null) {
          return ProgramSuccessResult.failure(
            outcome: ProgramSuccessOutcome.programNotFound,
            programId: cleanId,
            message:
                'Program "$cleanId" was deleted during achievement recovery.',
          );
        }

        if (latestProgram.status != ProgramV2Model.statusSuccess ||
            latestProgram.pendingMissedDayKey != null ||
            latestProgram.finalizedAt == null ||
            latestProgram.recipientNameSnapshot !=
                program.recipientNameSnapshot) {
          return ProgramSuccessResult.failure(
            outcome: ProgramSuccessOutcome.dataIntegrityError,
            programId: cleanId,
            message:
                'Program snapshot changed or became inconsistent during achievement recovery.',
          );
        }

        final recoveredAchievement = AchievementModel(
          id: expectedAchievementId,
          programId: cleanId,
          type: AchievementModel.typeFinalSuccess,
          milestoneDays: program.targetDays,
          achievedAt: finalCheckIn.checkedAt,
          recipientNameSnapshot: storedRecipient,
          createdAt: capturedNow,
        );

        try {
          await _achievementRepository.save(recoveredAchievement);
        } on HiveError {
          return ProgramSuccessResult.failure(
            outcome: ProgramSuccessOutcome.persistenceError,
            programId: cleanId,
            message:
                'Storage operation failed while recovering FINAL_SUCCESS achievement.',
          );
        } catch (_) {
          return ProgramSuccessResult.failure(
            outcome: ProgramSuccessOutcome.persistenceError,
            programId: cleanId,
            message:
                'Storage operation failed while recovering FINAL_SUCCESS achievement.',
          );
        }

        return ProgramSuccessResult.recoveredAchievement(
          programId: cleanId,
          program: program,
          achievement: recoveredAchievement,
          completedDays: completedDays,
        );
      }

      // Exactly one FINAL_SUCCESS achievement exists
      final existingAchievement = finalSuccessAchievements.first;
      final bool canonicalOccupied;
      try {
        canonicalOccupied =
            _achievementRepository.containsId(expectedAchievementId);
      } on HiveError {
        return ProgramSuccessResult.failure(
          outcome: ProgramSuccessOutcome.persistenceError,
          programId: cleanId,
          message:
              'Storage operation failed while checking canonical achievement key.',
        );
      } catch (_) {
        return ProgramSuccessResult.failure(
          outcome: ProgramSuccessOutcome.persistenceError,
          programId: cleanId,
          message:
              'Storage operation failed while checking canonical achievement key.',
        );
      }

      if (!canonicalOccupied ||
          existingAchievement.id != expectedAchievementId ||
          (existingAchievement.key != null &&
              existingAchievement.key != expectedAchievementId) ||
          existingAchievement.programId != cleanId ||
          existingAchievement.type != AchievementModel.typeFinalSuccess ||
          existingAchievement.milestoneDays != program.targetDays ||
          !existingAchievement.achievedAt
              .isAtSameMomentAs(finalCheckIn.checkedAt) ||
          existingAchievement.recipientNameSnapshot != storedRecipient) {
        return ProgramSuccessResult.failure(
          outcome: ProgramSuccessOutcome.dataIntegrityError,
          programId: cleanId,
          message:
              'FINAL_SUCCESS achievement record identity or field mismatch for program "$cleanId".',
        );
      }

      return ProgramSuccessResult.alreadyFinalized(
        programId: cleanId,
        program: program,
        achievement: existingAchievement,
        completedDays: completedDays,
      );
    }

    // 10. ACTIVE Program Initial Finalization (Two-Box Write)
    // Pre-write guard: verify no FINAL_SUCCESS achievement exists before program mutation
    if (finalSuccessAchievements.isNotEmpty) {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.dataIntegrityError,
        programId: cleanId,
        message:
            'Conflicting FINAL_SUCCESS achievement already exists before program finalization.',
      );
    }

    final bool canonicalOccupied;
    try {
      canonicalOccupied =
          _achievementRepository.containsId(expectedAchievementId);
    } on HiveError {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.persistenceError,
        programId: cleanId,
        message:
            'Storage operation failed while checking canonical achievement key.',
      );
    } catch (_) {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.persistenceError,
        programId: cleanId,
        message:
            'Storage operation failed while checking canonical achievement key.',
      );
    }

    if (canonicalOccupied) {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.dataIntegrityError,
        programId: cleanId,
        message:
            'Canonical achievement storage key "$expectedAchievementId" is occupied by an unexpected record.',
      );
    }

    // TWO-BOX WRITE STEP 1: Re-read Program to prevent stale writes
    final ProgramV2Model? latestProgram;
    try {
      latestProgram = _programRepository.getById(cleanId);
    } on HiveError {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.persistenceError,
        programId: cleanId,
        message:
            'Storage operation failed while re-reading program before finalization.',
      );
    } on Exception {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.persistenceError,
        programId: cleanId,
        message:
            'Storage operation failed while re-reading program before finalization.',
      );
    }

    if (latestProgram == null) {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.programNotFound,
        programId: cleanId,
        message: 'Program "$cleanId" was deleted during finalization.',
      );
    }

    final reReadIntegrity = _validateProgramIntegrity(latestProgram, cleanId);
    if (reReadIntegrity != null) {
      return reReadIntegrity;
    }

    // Snapshot consistency guard
    if (latestProgram.id != program.id ||
        latestProgram.ibadahId != program.ibadahId ||
        latestProgram.ibadahNameSnapshot != program.ibadahNameSnapshot ||
        latestProgram.startDayKey != program.startDayKey ||
        latestProgram.targetDays != program.targetDays ||
        latestProgram.createdAt != program.createdAt ||
        latestProgram.restartedFromProgramId !=
            program.restartedFromProgramId ||
        latestProgram.recipientNameSnapshot != program.recipientNameSnapshot ||
        latestProgram.pendingMissedDayKey != program.pendingMissedDayKey ||
        latestProgram.finalizedAt != program.finalizedAt) {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.dataIntegrityError,
        programId: cleanId,
        message:
            'Program snapshot changed concurrently during success finalization.',
      );
    }

    if (latestProgram.status != ProgramV2Model.statusActive) {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.dataIntegrityError,
        programId: cleanId,
        message:
            'Program status changed concurrently to "${latestProgram.status}".',
      );
    }

    if (latestProgram.pendingMissedDayKey != null) {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.dataIntegrityError,
        programId: cleanId,
        message:
            'ACTIVE program "$cleanId" acquired pendingMissedDayKey concurrently before success finalization.',
      );
    }

    if (latestProgram.finalizedAt != null) {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.dataIntegrityError,
        programId: cleanId,
        message:
            'ACTIVE program "$cleanId" acquired finalizedAt timestamp concurrently before success finalization.',
      );
    }

    final cleanRecipient = recipientNameSnapshot.trim();

    // TWO-BOX WRITE STEP 2: Persist ProgramV2Model as SUCCESS
    final finalizedProgram = ProgramV2Model(
      id: latestProgram.id,
      ibadahId: latestProgram.ibadahId,
      ibadahNameSnapshot: latestProgram.ibadahNameSnapshot,
      targetDays: latestProgram.targetDays,
      startDayKey: latestProgram.startDayKey,
      status: ProgramV2Model.statusSuccess,
      reminderTime: latestProgram.reminderTime,
      restartedFromProgramId: latestProgram.restartedFromProgramId,
      recipientNameSnapshot: cleanRecipient,
      createdAt: latestProgram.createdAt,
      updatedAt: capturedNow,
      finalizedAt: capturedNow,
      pendingMissedDayKey: null,
    );

    try {
      await _programRepository.save(finalizedProgram);
    } on HiveError {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.persistenceError,
        programId: cleanId,
        message:
            'Storage operation failed while persisting SUCCESS program status.',
      );
    } on Exception {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.persistenceError,
        programId: cleanId,
        message:
            'Storage operation failed while persisting SUCCESS program status.',
      );
    }

    // TWO-BOX WRITE STEP 3: Persist FINAL_SUCCESS AchievementModel
    final newAchievement = AchievementModel(
      id: expectedAchievementId,
      programId: cleanId,
      type: AchievementModel.typeFinalSuccess,
      milestoneDays: latestProgram.targetDays,
      achievedAt: finalCheckIn.checkedAt,
      recipientNameSnapshot: cleanRecipient,
      createdAt: capturedNow,
    );

    try {
      await _achievementRepository.save(newAchievement);
    } on HiveError {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.persistenceError,
        programId: cleanId,
        message:
            'Storage operation failed while persisting FINAL_SUCCESS achievement.',
      );
    } catch (_) {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.persistenceError,
        programId: cleanId,
        message:
            'Storage operation failed while persisting FINAL_SUCCESS achievement.',
      );
    }

    // Durable confirmation
    return ProgramSuccessResult.finalizedSuccess(
      programId: cleanId,
      program: finalizedProgram,
      achievement: newAchievement,
      completedDays: completedDays,
    );
  }

  /// Validates [program] invariants and identity.
  ProgramSuccessResult? _validateProgramIntegrity(
    ProgramV2Model program,
    String expectedId,
  ) {
    if (program.id != expectedId) {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.dataIntegrityError,
        programId: expectedId,
        message:
            'Program internal ID "${program.id}" does not match requested ID "$expectedId".',
      );
    }

    if (program.key != null && program.key != expectedId) {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.dataIntegrityError,
        programId: expectedId,
        message:
            'Program storage key "${program.key}" does not match internal ID "$expectedId".',
      );
    }

    if (program.ibadahId.trim().isEmpty) {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.dataIntegrityError,
        programId: expectedId,
        message: 'Program "$expectedId" has empty or whitespace ibadahId.',
      );
    }

    if (!DateService.isValidDayKey(program.startDayKey)) {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.dataIntegrityError,
        programId: expectedId,
        message:
            'Program "$expectedId" has invalid startDayKey format "${program.startDayKey}".',
      );
    }

    if (program.targetDays < 40 || program.targetDays > 365) {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.dataIntegrityError,
        programId: expectedId,
        message:
            'Program "$expectedId" targetDays (${program.targetDays}) is outside approved bounds [40, 365].',
      );
    }

    if (!ProgramV2Model.validStatuses.contains(program.status)) {
      return ProgramSuccessResult.failure(
        outcome: ProgramSuccessOutcome.dataIntegrityError,
        programId: expectedId,
        message:
            'Program "$expectedId" has unrecognized status "${program.status}".',
      );
    }

    return null;
  }

  /// Calculates authoritative consecutive completed days for [program] up to its target.
  _CheckInProgress _calculateAuthoritativeCheckIns(
    ProgramV2Model program,
    String currentDayKey,
  ) {
    final List<DailyCheckInModel> allRecords;
    try {
      allRecords = _checkInRepository.getByProgramId(program.id);
    } on HiveError {
      return const _CheckInProgress.storageError(
        'Storage operation failed while reading daily check-in records.',
      );
    } catch (_) {
      return const _CheckInProgress.storageError(
        'Storage operation failed while reading daily check-in records.',
      );
    }

    final startDt = DateService.parseDayKey(program.startDayKey);
    final finalDt = DateTime.utc(
      startDt.year,
      startDt.month,
      startDt.day + program.targetDays - 1,
    );
    final targetFinalDayKey = DateService.formatCalendarDayKey(finalDt);

    final validDayMap = <String, DailyCheckInModel>{};

    for (final record in allRecords) {
      if (record.programId != program.id) {
        return _CheckInProgress.integrityError(
          'Check-in record has mismatched programId "${record.programId}". Expected "${program.id}".',
        );
      }

      if (!DateService.isValidDayKey(record.dayKey)) {
        return _CheckInProgress.integrityError(
          'Check-in record has invalid dayKey format "${record.dayKey}".',
        );
      }

      if (validDayMap.containsKey(record.dayKey)) {
        final existing = validDayMap[record.dayKey]!;
        if (existing.id != record.id ||
            !existing.checkedAt.isAtSameMomentAs(record.checkedAt)) {
          return _CheckInProgress.integrityError(
            'Duplicate conflicting check-in records for day "${record.dayKey}".',
          );
        }
        return _CheckInProgress.integrityError(
          'Duplicate check-in records found for day "${record.dayKey}".',
        );
      }

      final expectedId =
          DailyCheckInV2Repository.buildCheckInId(record.dayKey, program.id);
      if (record.id != expectedId) {
        return _CheckInProgress.integrityError(
          'Check-in record ID mismatch: "${record.id}". Expected "$expectedId".',
        );
      }

      if (record.key != null && record.key != expectedId) {
        return _CheckInProgress.integrityError(
          'Check-in record noncanonical storage key "${record.key}". Expected "$expectedId".',
        );
      }

      final DailyCheckInModel? storedAtKey;
      try {
        storedAtKey = _checkInRepository.getById(expectedId);
      } on HiveError {
        return const _CheckInProgress.storageError(
          'Storage operation failed while verifying check-in record key.',
        );
      } catch (_) {
        return const _CheckInProgress.storageError(
          'Storage operation failed while verifying check-in record key.',
        );
      }

      if (storedAtKey == null ||
          storedAtKey.id != record.id ||
          storedAtKey.programId != record.programId ||
          storedAtKey.dayKey != record.dayKey ||
          (storedAtKey.key != null && storedAtKey.key != expectedId)) {
        return _CheckInProgress.integrityError(
          'Check-in storage key identity mismatch at "$expectedId".',
        );
      }

      // Operational day verification: checkedAt must belong to the operational day of dayKey
      final checkedAtDayKey = _dateService.getMujahadahDayKey(record.checkedAt);
      if (checkedAtDayKey != record.dayKey) {
        return _CheckInProgress.integrityError(
          'Check-in record for day "${record.dayKey}" was recorded at "${record.checkedAt}", which falls on operational day "$checkedAtDayKey".',
        );
      }

      if (_dateService.compareDayKeys(record.dayKey, program.startDayKey) < 0) {
        return _CheckInProgress.integrityError(
          'Check-in day "${record.dayKey}" precedes program start "${program.startDayKey}".',
        );
      }

      if (_dateService.compareDayKeys(record.dayKey, currentDayKey) > 0) {
        return _CheckInProgress.integrityError(
          'Check-in day "${record.dayKey}" is in the future relative to current operational day "$currentDayKey".',
        );
      }

      // Check-ins beyond the allowed target duration are anomalies
      if (_dateService.compareDayKeys(record.dayKey, targetFinalDayKey) > 0) {
        return _CheckInProgress.integrityError(
          'Check-in day "${record.dayKey}" extends beyond program target final day "$targetFinalDayKey".',
        );
      }

      validDayMap[record.dayKey] = record;
    }

    // Calculate consecutive completed days starting from startDayKey
    int consecutiveDays = 0;
    String checkDay = program.startDayKey;
    DailyCheckInModel? finalCheckIn;

    while (_dateService.compareDayKeys(checkDay, currentDayKey) <= 0 &&
        consecutiveDays < program.targetDays) {
      if (validDayMap.containsKey(checkDay)) {
        consecutiveDays++;
        finalCheckIn = validDayMap[checkDay];
        checkDay = _dateService.getNextDayKey(checkDay);
      } else {
        break; // Sequence broken
      }
    }

    // Flag nonconsecutive stored day keys or gaps
    if (validDayMap.length > consecutiveDays) {
      return _CheckInProgress.integrityError(
        'Check-in records contain gaps or nonconsecutive dates: found ${validDayMap.length} check-ins but only $consecutiveDays consecutive days.',
      );
    }

    if (consecutiveDays < program.targetDays) {
      return _CheckInProgress.notYetEligible(consecutiveDays);
    }

    return _CheckInProgress.eligible(
      consecutiveDays: consecutiveDays,
      finalCheckIn: finalCheckIn!,
    );
  }
}

/// Helper representing progress evaluation for success finalization.
class _CheckInProgress {
  final int? completedDays;
  final DailyCheckInModel? finalCheckIn;
  final bool isStorageError;
  final bool isIntegrityError;
  final bool isNotYetEligible;
  final String? errorMessage;

  const _CheckInProgress.eligible({
    required int consecutiveDays,
    required this.finalCheckIn,
  })  : completedDays = consecutiveDays,
        isStorageError = false,
        isIntegrityError = false,
        isNotYetEligible = false,
        errorMessage = null;

  const _CheckInProgress.notYetEligible(int days)
      : completedDays = days,
        finalCheckIn = null,
        isStorageError = false,
        isIntegrityError = false,
        isNotYetEligible = true,
        errorMessage = null;

  const _CheckInProgress.integrityError(String message)
      : completedDays = null,
        finalCheckIn = null,
        isStorageError = false,
        isIntegrityError = true,
        isNotYetEligible = false,
        errorMessage = message;

  const _CheckInProgress.storageError(String message)
      : completedDays = null,
        finalCheckIn = null,
        isStorageError = true,
        isIntegrityError = false,
        isNotYetEligible = false,
        errorMessage = message;
}
