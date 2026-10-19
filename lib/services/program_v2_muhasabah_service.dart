import 'dart:async';

import 'package:hive/hive.dart';

import '../core/date/date_service.dart';
import '../models/daily_checkin_model.dart';
import '../models/failure_record_model.dart';
import '../models/program_v2_model.dart';
import '../repositories/daily_checkin_v2_repository.dart';
import '../repositories/failure_record_v2_repository.dart';
import '../repositories/program_v2_repository.dart';

/// Typed outcomes for program Muhasabah failure finalization operations.
enum ProgramMuhasabahOutcome {
  /// Program was successfully finalized with FAILED status.
  failedCreated,

  /// Program was successfully finalized with WARNING status.
  warningCreated,

  /// Program and failure record were already finalized; idempotent return without mutation.
  alreadyFinalized,

  /// Program ID was empty or whitespace.
  invalidProgramId,

  /// Program was not found in storage.
  programNotFound,

  /// Program is not in PENDING_FAILURE status (e.g. ACTIVE, SUCCESS).
  programNotPending,

  /// Reason code or label snapshot is missing, empty, or whitespace.
  invalidReason,

  /// A conflicting reason was submitted for an already recorded failure interruption.
  reasonConflict,

  /// Storage records contain conflicting, corrupt, or inconsistent data.
  dataIntegrityError,

  /// Storage read/write operation failed.
  persistenceError,

  /// An unexpected error occurred during finalization.
  unexpectedError,
}

/// Result of finalizing a program through Muhasabah.
class ProgramMuhasabahResult {
  final ProgramMuhasabahOutcome outcome;
  final String? programId;
  final String? finalStatus;
  final ProgramV2Model? program;
  final FailureRecordModel? failureRecord;
  final int? completedDays;
  final String? errorMessage;

  const ProgramMuhasabahResult._({
    required this.outcome,
    this.programId,
    this.finalStatus,
    this.program,
    this.failureRecord,
    this.completedDays,
    this.errorMessage,
  });

  /// True if the operation completed normally (FAILED, WARNING, or idempotent retry).
  bool get isSuccess =>
      outcome == ProgramMuhasabahOutcome.failedCreated ||
      outcome == ProgramMuhasabahOutcome.warningCreated ||
      outcome == ProgramMuhasabahOutcome.alreadyFinalized;

  /// True if an error occurred.
  bool get isFailure => !isSuccess;

  /// True if a new transition to FAILED was persisted.
  bool get isFailedCreated => outcome == ProgramMuhasabahOutcome.failedCreated;

  /// True if a new transition to WARNING was persisted.
  bool get isWarningCreated =>
      outcome == ProgramMuhasabahOutcome.warningCreated;

  /// True if the program was already finalized prior to this call.
  bool get isAlreadyFinalized =>
      outcome == ProgramMuhasabahOutcome.alreadyFinalized;

  factory ProgramMuhasabahResult.failedCreated({
    required String programId,
    required ProgramV2Model program,
    required FailureRecordModel failureRecord,
    required int completedDays,
  }) =>
      ProgramMuhasabahResult._(
        outcome: ProgramMuhasabahOutcome.failedCreated,
        programId: programId,
        finalStatus: ProgramV2Model.statusFailed,
        program: program,
        failureRecord: failureRecord,
        completedDays: completedDays,
      );

  factory ProgramMuhasabahResult.warningCreated({
    required String programId,
    required ProgramV2Model program,
    required FailureRecordModel failureRecord,
    required int completedDays,
  }) =>
      ProgramMuhasabahResult._(
        outcome: ProgramMuhasabahOutcome.warningCreated,
        programId: programId,
        finalStatus: ProgramV2Model.statusWarning,
        program: program,
        failureRecord: failureRecord,
        completedDays: completedDays,
      );

  factory ProgramMuhasabahResult.alreadyFinalized({
    required String programId,
    required String finalStatus,
    required ProgramV2Model program,
    required FailureRecordModel failureRecord,
    required int completedDays,
  }) =>
      ProgramMuhasabahResult._(
        outcome: ProgramMuhasabahOutcome.alreadyFinalized,
        programId: programId,
        finalStatus: finalStatus,
        program: program,
        failureRecord: failureRecord,
        completedDays: completedDays,
      );

  factory ProgramMuhasabahResult.failure({
    required ProgramMuhasabahOutcome outcome,
    String? programId,
    String? message,
  }) =>
      ProgramMuhasabahResult._(
        outcome: outcome,
        programId: programId,
        errorMessage: message,
      );
}

/// Domain service responsible for safely finalizing PENDING_FAILURE Program V2 instances
/// through Muhasabah submission into terminal FAILED or WARNING states.
///
/// Enforces all Mujahadah V2 Muhasabah finalization invariants:
/// 1. Only PENDING_FAILURE programs are eligible for failure finalization.
/// 2. Requires mandatory, non-blank `reasonCode` and `reasonLabelSnapshot`.
/// 3. Authoritative progress is derived dynamically from valid consecutive DailyCheckIn
///    records strictly before `pendingMissedDayKey`.
/// 4. Authoritative classification: completedDays < 40 => FAILED; 40 <= completedDays < targetDays => WARNING.
/// 5. Completed target programs (e.g. 40/40) are NEVER finalized as FAILED or WARNING.
/// 6. Safe two-box write ordering: immutable FailureRecordModel is written and verified before
///    updating ProgramV2Model to terminal status.
/// 7. Preserves all other 10 program fields and retains `pendingMissedDayKey` for correlation.
/// 8. Fully idempotent on repeat submission or recovery after partial crash.
///
/// Concurrency Scope & Limitations:
/// In-process serialization is strictly scoped to this single [ProgramV2MuhasabahService] instance.
/// It serializes overlapping asynchronous calls to prevent race conditions within the same service instance.
/// It does NOT guarantee cross-instance, cross-isolate, or multi-process synchronization.
class ProgramV2MuhasabahService {
  final ProgramV2Repository _programRepository;
  final DailyCheckInV2Repository _checkInRepository;
  final FailureRecordV2Repository _failureRecordRepository;
  final DateService _dateService;

  // In-process FIFO lock to serialize concurrent calls within this instance.
  Future<void> _lock = Future.value();

  ProgramV2MuhasabahService({
    required ProgramV2Repository programRepository,
    required DailyCheckInV2Repository checkInRepository,
    required FailureRecordV2Repository failureRecordRepository,
    DateService? dateService,
  })  : _programRepository = programRepository,
        _checkInRepository = checkInRepository,
        _failureRecordRepository = failureRecordRepository,
        _dateService = dateService ?? DateService();

  /// In-process synchronization to serialize async finalization operations.
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

  /// Finalizes a PENDING_FAILURE program through Muhasabah reason submission.
  ///
  /// Serialized in-process to guarantee idempotency and crash recovery.
  /// Storage operations that fail return a typed [ProgramMuhasabahOutcome.persistenceError],
  /// while unexpected programming errors propagate for developer diagnostics.
  Future<ProgramMuhasabahResult> finalizeFailure({
    required String programId,
    required String reasonCode,
    required String reasonLabelSnapshot,
    String? note,
    DateTime? capturedNow,
  }) {
    return _synchronized(() async {
      final instant = capturedNow ?? _dateService.now;
      return _finalizeFailureInternal(
        programId: programId,
        reasonCode: reasonCode,
        reasonLabelSnapshot: reasonLabelSnapshot,
        note: note,
        capturedNow: instant,
      );
    });
  }

  /// Validates core persisted invariants and storage identity of a [ProgramV2Model].
  ProgramMuhasabahResult? _validateProgramIntegrity(
    ProgramV2Model program,
    String expectedId,
  ) {
    // 1. Storage key identity match
    if (program.id != expectedId ||
        (program.key != null && program.key != expectedId)) {
      return ProgramMuhasabahResult.failure(
        outcome: ProgramMuhasabahOutcome.dataIntegrityError,
        programId: expectedId,
        message:
            'Program storage key identity mismatch: expected "$expectedId" but record has id "${program.id}" and key "${program.key}".',
      );
    }

    // 2. targetDays invariant (40..365)
    if (program.targetDays < 40 || program.targetDays > 365) {
      return ProgramMuhasabahResult.failure(
        outcome: ProgramMuhasabahOutcome.dataIntegrityError,
        programId: expectedId,
        message:
            'Invalid program targetDays "${program.targetDays}". Expected between 40 and 365.',
      );
    }

    // 3. startDayKey valid date
    if (!DateService.isValidDayKey(program.startDayKey)) {
      return ProgramMuhasabahResult.failure(
        outcome: ProgramMuhasabahOutcome.dataIntegrityError,
        programId: expectedId,
        message:
            'Invalid program startDayKey format or date: "${program.startDayKey}". Expected YYYY-MM-DD.',
      );
    }

    // 4. Valid status check
    if (!ProgramV2Model.validStatuses.contains(program.status)) {
      return ProgramMuhasabahResult.failure(
        outcome: ProgramMuhasabahOutcome.dataIntegrityError,
        programId: expectedId,
        message: 'Unrecognized program status "${program.status}".',
      );
    }

    return null;
  }

  /// Internal un-locked finalization logic for a single program.
  Future<ProgramMuhasabahResult> _finalizeFailureInternal({
    required String programId,
    required String reasonCode,
    required String reasonLabelSnapshot,
    String? note,
    required DateTime capturedNow,
  }) async {
    // 1. Validate program ID
    final cleanId = programId.trim();
    if (cleanId.isEmpty) {
      return ProgramMuhasabahResult.failure(
        outcome: ProgramMuhasabahOutcome.invalidProgramId,
        message: 'Program ID must not be empty or blank.',
      );
    }

    // 2. Validate mandatory failure reason fields
    final cleanReasonCode = reasonCode.trim();
    final cleanLabel = reasonLabelSnapshot.trim();
    final cleanNote = note?.trim();

    if (cleanReasonCode.isEmpty || cleanLabel.isEmpty) {
      return ProgramMuhasabahResult.failure(
        outcome: ProgramMuhasabahOutcome.invalidReason,
        programId: cleanId,
        message:
            'Reason code and label snapshot are mandatory and cannot be empty or whitespace.',
      );
    }

    // 3. Lookup program in repository
    final ProgramV2Model? program;
    try {
      program = _programRepository.getById(cleanId);
    } on HiveError {
      return ProgramMuhasabahResult.failure(
        outcome: ProgramMuhasabahOutcome.persistenceError,
        programId: cleanId,
        message: 'Storage operation failed during program lookup.',
      );
    } on Exception {
      return ProgramMuhasabahResult.failure(
        outcome: ProgramMuhasabahOutcome.persistenceError,
        programId: cleanId,
        message: 'Storage operation failed during program lookup.',
      );
    }

    if (program == null) {
      return ProgramMuhasabahResult.failure(
        outcome: ProgramMuhasabahOutcome.programNotFound,
        programId: cleanId,
        message: 'Program "$cleanId" was not found in storage.',
      );
    }

    // 4. Validate program storage identity & persisted invariants
    final integrityError = _validateProgramIntegrity(program, cleanId);
    if (integrityError != null) {
      return integrityError;
    }

    // 5. Handle already finalized programs (idempotent recovery or conflicting reason)
    if (program.status == ProgramV2Model.statusFailed ||
        program.status == ProgramV2Model.statusWarning) {
      final missedKey = program.pendingMissedDayKey;
      if (missedKey == null || !DateService.isValidDayKey(missedKey)) {
        return ProgramMuhasabahResult.failure(
          outcome: ProgramMuhasabahOutcome.dataIntegrityError,
          programId: cleanId,
          message:
              'Program is in terminal status "${program.status}" but has missing or invalid pendingMissedDayKey.',
        );
      }

      final expectedFailureId =
          FailureRecordV2Repository.buildFailureRecordId(missedKey, cleanId);

      // Inspect all FailureRecord records for this program
      final List<FailureRecordModel> programRecords;
      try {
        programRecords = _failureRecordRepository.getByProgramId(cleanId);
      } on HiveError {
        return ProgramMuhasabahResult.failure(
          outcome: ProgramMuhasabahOutcome.persistenceError,
          programId: cleanId,
          message:
              'Storage operation failed while checking existing failure record.',
        );
      } catch (_) {
        return ProgramMuhasabahResult.failure(
          outcome: ProgramMuhasabahOutcome.persistenceError,
          programId: cleanId,
          message:
              'Storage operation failed while checking existing failure record.',
        );
      }

      if (programRecords.isEmpty) {
        return ProgramMuhasabahResult.failure(
          outcome: ProgramMuhasabahOutcome.dataIntegrityError,
          programId: cleanId,
          message:
              'Program is finalized as "${program.status}" but corresponding FailureRecord "$expectedFailureId" is missing.',
        );
      }

      if (programRecords.length > 1) {
        return ProgramMuhasabahResult.failure(
          outcome: ProgramMuhasabahOutcome.dataIntegrityError,
          programId: cleanId,
          message:
              'Anomalous duplicate FailureRecord records (${programRecords.length}) detected for finalized program "$cleanId".',
        );
      }

      final existingRecord = programRecords.first;

      // Validate storage identity and canonical key of existing failure record
      final bool canonicalOccupied;
      try {
        canonicalOccupied =
            _failureRecordRepository.containsId(expectedFailureId);
      } on HiveError {
        return ProgramMuhasabahResult.failure(
          outcome: ProgramMuhasabahOutcome.persistenceError,
          programId: cleanId,
          message:
              'Storage operation failed while checking canonical failure record key.',
        );
      } catch (_) {
        return ProgramMuhasabahResult.failure(
          outcome: ProgramMuhasabahOutcome.persistenceError,
          programId: cleanId,
          message:
              'Storage operation failed while checking canonical failure record key.',
        );
      }

      if (!canonicalOccupied ||
          existingRecord.id != expectedFailureId ||
          (existingRecord.key != null &&
              existingRecord.key != expectedFailureId) ||
          existingRecord.programId != cleanId ||
          existingRecord.missedDayKey != missedKey) {
        return ProgramMuhasabahResult.failure(
          outcome: ProgramMuhasabahOutcome.dataIntegrityError,
          programId: cleanId,
          message:
              'Failure record identity mismatch for finalized program "$cleanId".',
        );
      }

      // Check for reason conflict on idempotent retry
      if (existingRecord.reasonCode != cleanReasonCode ||
          existingRecord.reasonLabelSnapshot != cleanLabel) {
        return ProgramMuhasabahResult.failure(
          outcome: ProgramMuhasabahOutcome.reasonConflict,
          programId: cleanId,
          message:
              'Conflicting failure reason submitted for already finalized program "$cleanId".',
        );
      }

      // Recompute authoritative completedDays for reporting and consistency check
      final progressResult = _calculateAuthoritativeCompletedDays(
        program: program,
        missedDayKey: missedKey,
      );
      if (progressResult.isStorageError) {
        return ProgramMuhasabahResult.failure(
          outcome: ProgramMuhasabahOutcome.persistenceError,
          programId: cleanId,
          message: progressResult.errorMessage ??
              'Storage operation failed while reading check-ins.',
        );
      }
      if (progressResult.completedDays == null) {
        return ProgramMuhasabahResult.failure(
          outcome: ProgramMuhasabahOutcome.dataIntegrityError,
          programId: cleanId,
          message: progressResult.errorMessage ??
              'Stored check-in records contain integrity anomalies for finalized program "$cleanId".',
        );
      }

      final completedDays = progressResult.completedDays!;

      // Step 6: Inconsistency check if completedDays reached targetDays
      if (completedDays >= program.targetDays) {
        return ProgramMuhasabahResult.failure(
          outcome: ProgramMuhasabahOutcome.dataIntegrityError,
          programId: cleanId,
          message:
              'Target duration (${program.targetDays} days) was completed ($completedDays days). Program cannot be in failure status.',
        );
      }

      // Step 6: Derive expected status from authoritative progress
      final String expectedStatus = completedDays < 40
          ? ProgramV2Model.statusFailed
          : ProgramV2Model.statusWarning;

      if (program.status != expectedStatus) {
        return ProgramMuhasabahResult.failure(
          outcome: ProgramMuhasabahOutcome.dataIntegrityError,
          programId: cleanId,
          message:
              'Persisted terminal status "${program.status}" disagrees with authoritative progress status "$expectedStatus" ($completedDays completed days vs target ${program.targetDays}).',
        );
      }

      return ProgramMuhasabahResult.alreadyFinalized(
        programId: cleanId,
        finalStatus: program.status,
        program: program,
        failureRecord: existingRecord,
        completedDays: completedDays,
      );
    }

    // 6. Enforce PENDING_FAILURE status requirement
    if (program.status != ProgramV2Model.statusPendingFailure) {
      return ProgramMuhasabahResult.failure(
        outcome: ProgramMuhasabahOutcome.programNotPending,
        programId: cleanId,
        message:
            'Program "$cleanId" is not in PENDING_FAILURE status (current: "${program.status}").',
      );
    }

    // 7. Validate PENDING_FAILURE lifecycle invariants & missedDayKey
    final missedDayKey = program.pendingMissedDayKey;
    if (missedDayKey == null || !DateService.isValidDayKey(missedDayKey)) {
      return ProgramMuhasabahResult.failure(
        outcome: ProgramMuhasabahOutcome.dataIntegrityError,
        programId: cleanId,
        message:
            'Program is in PENDING_FAILURE status but has missing or invalid pendingMissedDayKey: "$missedDayKey".',
      );
    }

    if (_dateService.compareDayKeys(missedDayKey, program.startDayKey) < 0) {
      return ProgramMuhasabahResult.failure(
        outcome: ProgramMuhasabahOutcome.dataIntegrityError,
        programId: cleanId,
        message:
            'Program pendingMissedDayKey "$missedDayKey" cannot precede startDayKey "${program.startDayKey}".',
      );
    }

    // Verify missedDayKey represents a legitimate closed operational day relative to capturedNow
    final currentDayKey = _dateService.getMujahadahDayKey(capturedNow);
    if (_dateService.compareDayKeys(missedDayKey, currentDayKey) >= 0) {
      return ProgramMuhasabahResult.failure(
        outcome: ProgramMuhasabahOutcome.dataIntegrityError,
        programId: cleanId,
        message:
            'Pending missed day key "$missedDayKey" is not a closed operational day relative to current "$currentDayKey".',
      );
    }

    // 8. Derive authoritative completedDays from valid check-in records
    final progressResult = _calculateAuthoritativeCompletedDays(
      program: program,
      missedDayKey: missedDayKey,
    );
    if (progressResult.isStorageError) {
      return ProgramMuhasabahResult.failure(
        outcome: ProgramMuhasabahOutcome.persistenceError,
        programId: cleanId,
        message: progressResult.errorMessage ??
            'Storage operation failed while reading check-ins.',
      );
    }
    if (progressResult.completedDays == null) {
      return ProgramMuhasabahResult.failure(
        outcome: ProgramMuhasabahOutcome.dataIntegrityError,
        programId: cleanId,
        message: progressResult.errorMessage ??
            'Stored check-in records contain integrity anomalies or gaps before missed day "$missedDayKey".',
      );
    }

    final completedDays = progressResult.completedDays!;

    // Target completion protection: completed programs (e.g. 40/40) must NEVER become FAILED or WARNING
    if (completedDays >= program.targetDays) {
      return ProgramMuhasabahResult.failure(
        outcome: ProgramMuhasabahOutcome.dataIntegrityError,
        programId: cleanId,
        message:
            'Target duration (${program.targetDays} days) was completed ($completedDays days). Program is not eligible for failure finalization.',
      );
    }

    // 9. Authoritative classification rule:
    // completedDays < 40 => FAILED
    // 40 <= completedDays < targetDays => WARNING
    final String finalStatus;
    if (completedDays < 40) {
      finalStatus = ProgramV2Model.statusFailed;
    } else {
      finalStatus = ProgramV2Model.statusWarning;
    }

    // 10. TWO-BOX WRITE STEP 1: Inspect FailureRecord records for this program and persist/verify
    final expectedFailureId =
        FailureRecordV2Repository.buildFailureRecordId(missedDayKey, cleanId);

    final List<FailureRecordModel> programRecords;
    try {
      programRecords = _failureRecordRepository.getByProgramId(cleanId);
    } on HiveError {
      return ProgramMuhasabahResult.failure(
        outcome: ProgramMuhasabahOutcome.persistenceError,
        programId: cleanId,
        message: 'Storage operation failed while inspecting failure records.',
      );
    } catch (_) {
      return ProgramMuhasabahResult.failure(
        outcome: ProgramMuhasabahOutcome.persistenceError,
        programId: cleanId,
        message: 'Storage operation failed while inspecting failure records.',
      );
    }

    // Mujahadah V2 has one failure interruption per program. If multiple records exist, return dataIntegrityError.
    if (programRecords.length > 1) {
      return ProgramMuhasabahResult.failure(
        outcome: ProgramMuhasabahOutcome.dataIntegrityError,
        programId: cleanId,
        message:
            'Anomalous duplicate FailureRecord records (${programRecords.length}) detected for program "$cleanId".',
      );
    }

    FailureRecordModel? failureRecord;
    if (programRecords.length == 1) {
      final existing = programRecords.first;

      // Verify interruption identity: FailureRecord must match current program interruption
      if (existing.missedDayKey != missedDayKey) {
        return ProgramMuhasabahResult.failure(
          outcome: ProgramMuhasabahOutcome.dataIntegrityError,
          programId: cleanId,
          message:
              'FailureRecord for program "$cleanId" has conflicting missed day "${existing.missedDayKey}" (expected "$missedDayKey").',
        );
      }

      // Verify canonical identity of existing record
      final bool canonicalOccupied;
      try {
        canonicalOccupied =
            _failureRecordRepository.containsId(expectedFailureId);
      } on HiveError {
        return ProgramMuhasabahResult.failure(
          outcome: ProgramMuhasabahOutcome.persistenceError,
          programId: cleanId,
          message:
              'Storage operation failed while checking canonical failure record key.',
        );
      } catch (_) {
        return ProgramMuhasabahResult.failure(
          outcome: ProgramMuhasabahOutcome.persistenceError,
          programId: cleanId,
          message:
              'Storage operation failed while checking canonical failure record key.',
        );
      }

      if (!canonicalOccupied ||
          existing.id != expectedFailureId ||
          (existing.key != null && existing.key != expectedFailureId) ||
          existing.programId != cleanId) {
        return ProgramMuhasabahResult.failure(
          outcome: ProgramMuhasabahOutcome.dataIntegrityError,
          programId: cleanId,
          message:
              'FailureRecord for program "$cleanId" and missed day "$missedDayKey" exists under noncanonical key or identity ("${existing.id}").',
        );
      }

      // Reason immutability check: prevent overwriting a previously saved reason
      if (existing.reasonCode != cleanReasonCode ||
          existing.reasonLabelSnapshot != cleanLabel) {
        return ProgramMuhasabahResult.failure(
          outcome: ProgramMuhasabahOutcome.reasonConflict,
          programId: cleanId,
          message:
              'Conflicting failure reason submitted for already recorded failure interruption "$expectedFailureId".',
        );
      }

      failureRecord = existing;
    } else {
      // programRecords is empty. Check if canonical key is occupied by another record
      final bool canonicalOccupied;
      try {
        canonicalOccupied =
            _failureRecordRepository.containsId(expectedFailureId);
      } on HiveError {
        return ProgramMuhasabahResult.failure(
          outcome: ProgramMuhasabahOutcome.persistenceError,
          programId: cleanId,
          message:
              'Storage operation failed while checking canonical failure record key.',
        );
      } catch (_) {
        return ProgramMuhasabahResult.failure(
          outcome: ProgramMuhasabahOutcome.persistenceError,
          programId: cleanId,
          message:
              'Storage operation failed while checking canonical failure record key.',
        );
      }

      if (canonicalOccupied) {
        return ProgramMuhasabahResult.failure(
          outcome: ProgramMuhasabahOutcome.dataIntegrityError,
          programId: cleanId,
          message:
              'Canonical FailureRecord storage key "$expectedFailureId" is occupied by an unexpected or conflicting record.',
        );
      }

      // Create and persist new FailureRecordModel
      final newRecord = FailureRecordModel(
        id: expectedFailureId,
        programId: cleanId,
        missedDayKey: missedDayKey,
        reasonCode: cleanReasonCode,
        reasonLabelSnapshot: cleanLabel,
        note: cleanNote,
        createdAt: capturedNow,
      );
      try {
        await _failureRecordRepository.save(newRecord);
      } on HiveError {
        return ProgramMuhasabahResult.failure(
          outcome: ProgramMuhasabahOutcome.persistenceError,
          programId: cleanId,
          message: 'Storage operation failed while persisting failure record.',
        );
      } catch (_) {
        return ProgramMuhasabahResult.failure(
          outcome: ProgramMuhasabahOutcome.persistenceError,
          programId: cleanId,
          message: 'Storage operation failed while persisting failure record.',
        );
      }
      failureRecord = newRecord;
    }

    // 11. TWO-BOX WRITE STEP 2: Re-read program & failure record before program mutation
    final ProgramV2Model? latestProgram;
    try {
      latestProgram = _programRepository.getById(cleanId);
    } on HiveError {
      return ProgramMuhasabahResult.failure(
        outcome: ProgramMuhasabahOutcome.persistenceError,
        programId: cleanId,
        message:
            'Storage operation failed while re-reading program before finalization.',
      );
    } on Exception {
      return ProgramMuhasabahResult.failure(
        outcome: ProgramMuhasabahOutcome.persistenceError,
        programId: cleanId,
        message:
            'Storage operation failed while re-reading program before finalization.',
      );
    }

    if (latestProgram == null) {
      return ProgramMuhasabahResult.failure(
        outcome: ProgramMuhasabahOutcome.programNotFound,
        programId: cleanId,
        message: 'Program "$cleanId" was deleted during finalization.',
      );
    }

    final reReadIntegrity = _validateProgramIntegrity(latestProgram, cleanId);
    if (reReadIntegrity != null) {
      return reReadIntegrity;
    }

    // Snapshot consistency guard:
    // Verify that relevant original and latest ProgramV2Model identity and lifecycle fields
    // remain consistent (at minimum id, ibadahId, startDayKey, targetDays, and pendingMissedDayKey).
    if (latestProgram.id != program.id ||
        latestProgram.ibadahId != program.ibadahId ||
        latestProgram.startDayKey != program.startDayKey ||
        latestProgram.targetDays != program.targetDays ||
        latestProgram.pendingMissedDayKey != program.pendingMissedDayKey ||
        latestProgram.restartedFromProgramId !=
            program.restartedFromProgramId) {
      return ProgramMuhasabahResult.failure(
        outcome: ProgramMuhasabahOutcome.dataIntegrityError,
        programId: cleanId,
        message:
            'Program snapshot changed concurrently during Muhasabah finalization.',
      );
    }

    // STEP 3: FULL RE-READ FAILURE RECORD VALIDATION
    // Verify that the authoritative FailureRecord still exists, uses the canonical storage key,
    // matches the same programId and missedDayKey, and has the original reason.
    final FailureRecordModel? reReadFailure;
    final List<FailureRecordModel> reReadProgramRecords;
    try {
      reReadFailure = _failureRecordRepository.getById(expectedFailureId);
      reReadProgramRecords = _failureRecordRepository.getByProgramId(cleanId);
    } on HiveError {
      return ProgramMuhasabahResult.failure(
        outcome: ProgramMuhasabahOutcome.persistenceError,
        programId: cleanId,
        message:
            'Storage operation failed while verifying persisted failure record.',
      );
    } catch (_) {
      return ProgramMuhasabahResult.failure(
        outcome: ProgramMuhasabahOutcome.persistenceError,
        programId: cleanId,
        message:
            'Storage operation failed while verifying persisted failure record.',
      );
    }

    if (reReadFailure == null ||
        reReadFailure.id != expectedFailureId ||
        (reReadFailure.key != null && reReadFailure.key != expectedFailureId) ||
        reReadFailure.programId != cleanId ||
        reReadFailure.missedDayKey != missedDayKey ||
        reReadFailure.reasonCode != cleanReasonCode ||
        reReadFailure.reasonLabelSnapshot != cleanLabel ||
        reReadFailure.note != failureRecord.note ||
        !reReadFailure.createdAt.isAtSameMomentAs(failureRecord.createdAt) ||
        reReadProgramRecords.length != 1 ||
        reReadProgramRecords.first.id != expectedFailureId) {
      return ProgramMuhasabahResult.failure(
        outcome: ProgramMuhasabahOutcome.dataIntegrityError,
        programId: cleanId,
        message:
            'Persisted failure record was corrupted or altered before program finalization.',
      );
    }

    // Ensure re-read Program and FailureRecord refer to the same interruption
    if (latestProgram.pendingMissedDayKey != reReadFailure.missedDayKey ||
        latestProgram.id != reReadFailure.programId) {
      return ProgramMuhasabahResult.failure(
        outcome: ProgramMuhasabahOutcome.dataIntegrityError,
        programId: cleanId,
        message:
            'Program and FailureRecord interruption mismatch before finalization.',
      );
    }

    // Check if concurrently finalized with valid snapshot and failure record
    if (latestProgram.status == ProgramV2Model.statusFailed ||
        latestProgram.status == ProgramV2Model.statusWarning) {
      if (latestProgram.status == finalStatus) {
        return ProgramMuhasabahResult.alreadyFinalized(
          programId: cleanId,
          finalStatus: latestProgram.status,
          program: latestProgram,
          failureRecord: reReadFailure,
          completedDays: completedDays,
        );
      } else {
        return ProgramMuhasabahResult.failure(
          outcome: ProgramMuhasabahOutcome.dataIntegrityError,
          programId: cleanId,
          message:
              'Program was finalized concurrently with conflicting status "${latestProgram.status}".',
        );
      }
    }

    if (latestProgram.status != ProgramV2Model.statusPendingFailure) {
      return ProgramMuhasabahResult.failure(
        outcome: ProgramMuhasabahOutcome.programNotPending,
        programId: cleanId,
        message:
            'Program status changed concurrently to "${latestProgram.status}".',
      );
    }

    // 12. TWO-BOX WRITE STEP 3: Persist terminal ProgramV2Model
    final finalizedProgram = ProgramV2Model(
      id: latestProgram.id,
      ibadahId: latestProgram.ibadahId,
      ibadahNameSnapshot: latestProgram.ibadahNameSnapshot,
      targetDays: latestProgram.targetDays,
      startDayKey: latestProgram.startDayKey,
      status: finalStatus,
      reminderTime: latestProgram.reminderTime,
      restartedFromProgramId: latestProgram.restartedFromProgramId,
      recipientNameSnapshot: latestProgram.recipientNameSnapshot,
      createdAt: latestProgram.createdAt,
      updatedAt: capturedNow,
      finalizedAt: capturedNow,
      pendingMissedDayKey: latestProgram.pendingMissedDayKey,
    );

    try {
      await _programRepository.save(finalizedProgram);
    } on HiveError {
      return ProgramMuhasabahResult.failure(
        outcome: ProgramMuhasabahOutcome.persistenceError,
        programId: cleanId,
        message:
            'Storage operation failed while persisting program finalization status.',
      );
    } on Exception {
      return ProgramMuhasabahResult.failure(
        outcome: ProgramMuhasabahOutcome.persistenceError,
        programId: cleanId,
        message:
            'Storage operation failed while persisting program finalization status.',
      );
    }

    if (finalStatus == ProgramV2Model.statusFailed) {
      return ProgramMuhasabahResult.failedCreated(
        programId: cleanId,
        program: finalizedProgram,
        failureRecord: reReadFailure,
        completedDays: completedDays,
      );
    } else {
      return ProgramMuhasabahResult.warningCreated(
        programId: cleanId,
        program: finalizedProgram,
        failureRecord: reReadFailure,
        completedDays: completedDays,
      );
    }
  }

  /// Calculates authoritative completed days strictly before [missedDayKey].
  ///
  /// Distinguishes storage read failures (yielding [isStorageError: true])
  /// from data continuity, sequence, and identity anomalies.
  _ProgressCalculationResult _calculateAuthoritativeCompletedDays({
    required ProgramV2Model program,
    required String missedDayKey,
  }) {
    // 1. Verify missed day's canonical check-in key is not occupied
    final canonicalMissedCheckInId =
        DailyCheckInV2Repository.buildCheckInId(missedDayKey, program.id);
    try {
      if (_checkInRepository.containsId(canonicalMissedCheckInId)) {
        return _ProgressCalculationResult.integrityError(
          'Canonical check-in storage key "$canonicalMissedCheckInId" for missed day "$missedDayKey" is occupied by an existing check-in record.',
        );
      }
    } on HiveError {
      return const _ProgressCalculationResult.storageError(
        'Storage operation failed while checking canonical missed day check-in key.',
      );
    } catch (_) {
      return const _ProgressCalculationResult.storageError(
        'Storage operation failed while checking canonical missed day check-in key.',
      );
    }

    final List<DailyCheckInModel> allRecords;
    try {
      allRecords = _checkInRepository.getByProgramId(program.id);
    } on HiveError {
      return const _ProgressCalculationResult.storageError(
        'Storage operation failed while reading daily check-in records.',
      );
    } catch (_) {
      return const _ProgressCalculationResult.storageError(
        'Storage operation failed while reading daily check-in records.',
      );
    }

    final validDayMap = <String, DailyCheckInModel>{};

    for (final record in allRecords) {
      if (record.programId != program.id) {
        return _ProgressCalculationResult.integrityError(
          'Check-in record has mismatched programId "${record.programId}". Expected "${program.id}".',
        );
      }

      if (!DateService.isValidDayKey(record.dayKey)) {
        return _ProgressCalculationResult.integrityError(
          'Check-in record has invalid dayKey format "${record.dayKey}".',
        );
      }

      final expectedId =
          DailyCheckInV2Repository.buildCheckInId(record.dayKey, program.id);
      if (record.id != expectedId) {
        return _ProgressCalculationResult.integrityError(
          'Check-in record ID mismatch: "${record.id}". Expected "$expectedId".',
        );
      }

      if (record.key != null && record.key != expectedId) {
        return _ProgressCalculationResult.integrityError(
          'Check-in record noncanonical storage key "${record.key}". Expected "$expectedId".',
        );
      }

      final DailyCheckInModel? storedAtKey;
      try {
        storedAtKey = _checkInRepository.getById(expectedId);
      } on HiveError {
        return const _ProgressCalculationResult.storageError(
          'Storage operation failed while verifying check-in record key.',
        );
      } catch (_) {
        return const _ProgressCalculationResult.storageError(
          'Storage operation failed while verifying check-in record key.',
        );
      }

      if (storedAtKey == null ||
          storedAtKey.id != record.id ||
          storedAtKey.programId != record.programId ||
          storedAtKey.dayKey != record.dayKey ||
          (storedAtKey.key != null && storedAtKey.key != expectedId)) {
        return _ProgressCalculationResult.integrityError(
          'Check-in storage key identity mismatch at "$expectedId".',
        );
      }

      if (_dateService.compareDayKeys(record.dayKey, program.startDayKey) < 0) {
        return _ProgressCalculationResult.integrityError(
          'Check-in day "${record.dayKey}" precedes program start "${program.startDayKey}".',
        );
      }

      // Check-in on or after missedDayKey contradicts the pending missed day
      if (_dateService.compareDayKeys(record.dayKey, missedDayKey) >= 0) {
        return _ProgressCalculationResult.integrityError(
          'Check-in day "${record.dayKey}" is on or after claimed missed day "$missedDayKey".',
        );
      }

      if (validDayMap.containsKey(record.dayKey)) {
        final existing = validDayMap[record.dayKey]!;
        if (existing.id != record.id ||
            !existing.checkedAt.isAtSameMomentAs(record.checkedAt)) {
          return _ProgressCalculationResult.integrityError(
            'Duplicate conflicting check-in records for day "${record.dayKey}".',
          );
        }
        continue;
      }

      validDayMap[record.dayKey] = record;
    }

    // Calculate consecutive valid days starting from startDayKey up to missedDayKey
    int consecutiveDays = 0;
    String checkDay = program.startDayKey;

    while (_dateService.compareDayKeys(checkDay, missedDayKey) < 0 &&
        consecutiveDays < program.targetDays) {
      if (validDayMap.containsKey(checkDay)) {
        consecutiveDays++;
        checkDay = _dateService.getNextDayKey(checkDay);
      } else {
        break; // Streak interrupted before missed day
      }
    }

    // Every day from startDayKey up to missedDayKey must be accounted for without gaps
    if (checkDay != missedDayKey) {
      return _ProgressCalculationResult.integrityError(
        'Stored check-in records contain integrity anomalies or gaps: check-in gap detected at "$checkDay" before missed day "$missedDayKey".',
      );
    }

    if (validDayMap.length != consecutiveDays) {
      return _ProgressCalculationResult.integrityError(
        'Stray check-in records detected outside consecutive streak.',
      );
    }

    return _ProgressCalculationResult.success(consecutiveDays);
  }
}

/// Internal helper for authoritative progress derivation, distinguishing
/// underlying storage failures from data integrity anomalies.
class _ProgressCalculationResult {
  final int? completedDays;
  final bool isStorageError;
  final String? errorMessage;

  const _ProgressCalculationResult.success(int days)
      : completedDays = days,
        isStorageError = false,
        errorMessage = null;

  const _ProgressCalculationResult.integrityError(String message)
      : completedDays = null,
        isStorageError = false,
        errorMessage = message;

  const _ProgressCalculationResult.storageError(String message)
      : completedDays = null,
        isStorageError = true,
        errorMessage = message;
}
