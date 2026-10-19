import 'dart:async';

import 'package:hive/hive.dart';

import '../core/date/date_service.dart';
import '../models/daily_checkin_model.dart';
import '../models/program_v2_model.dart';
import '../repositories/daily_checkin_v2_repository.dart';
import '../repositories/program_v2_repository.dart';

/// Typed outcomes for program reconciliation operations.
enum ProgramReconciliationOutcome {
  /// Eligible ACTIVE program has no missed closed operational days.
  noMissedDay,

  /// Program is scheduled to start on a future operational day.
  notStarted,

  /// Program had a missed required day and was transitioned to PENDING_FAILURE.
  pendingCreated,

  /// Program is already in PENDING_FAILURE status.
  alreadyPending,

  /// Program has completed all target days and is awaiting SUCCESS finalization.
  requiresSuccessFinalization,

  /// Program is in a terminal lifecycle state (SUCCESS, FAILED, WARNING).
  terminalProgram,

  /// Program ID was empty or whitespace.
  invalidProgramId,

  /// Program was not found in storage.
  programNotFound,

  /// Check-in or program storage records contain conflicting or corrupt data.
  dataIntegrityError,

  /// An error occurred during Hive read or write operations.
  persistenceError,

  /// An unexpected error occurred during reconciliation.
  unexpectedError,
}

/// Result of reconciling a single program instance.
class ProgramReconciliationResult {
  final ProgramReconciliationOutcome outcome;
  final String? programId;
  final String? missedDayKey;
  final ProgramV2Model? program;
  final String? errorMessage;

  const ProgramReconciliationResult._({
    required this.outcome,
    this.programId,
    this.missedDayKey,
    this.program,
    this.errorMessage,
  });

  /// True if the operation completed normally without validation or storage errors.
  bool get isSuccess =>
      outcome == ProgramReconciliationOutcome.noMissedDay ||
      outcome == ProgramReconciliationOutcome.notStarted ||
      outcome == ProgramReconciliationOutcome.pendingCreated ||
      outcome == ProgramReconciliationOutcome.alreadyPending ||
      outcome == ProgramReconciliationOutcome.requiresSuccessFinalization ||
      outcome == ProgramReconciliationOutcome.terminalProgram;

  /// True if an error occurred (invalid ID, missing program, data corruption, or persistence failure).
  bool get isFailure => !isSuccess;

  /// True if a new transition to PENDING_FAILURE was persisted.
  bool get isPendingCreated =>
      outcome == ProgramReconciliationOutcome.pendingCreated;

  /// True if the program was already PENDING_FAILURE before this reconciliation.
  bool get isAlreadyPending =>
      outcome == ProgramReconciliationOutcome.alreadyPending;

  /// True if the program has a pending missed day requiring Muhasabah.
  bool get hasMissedDay => isPendingCreated || isAlreadyPending;

  factory ProgramReconciliationResult.noMissedDay({
    required String programId,
    required ProgramV2Model program,
  }) =>
      ProgramReconciliationResult._(
        outcome: ProgramReconciliationOutcome.noMissedDay,
        programId: programId,
        program: program,
      );

  factory ProgramReconciliationResult.notStarted({
    required String programId,
    required ProgramV2Model program,
  }) =>
      ProgramReconciliationResult._(
        outcome: ProgramReconciliationOutcome.notStarted,
        programId: programId,
        program: program,
      );

  factory ProgramReconciliationResult.pendingCreated({
    required String programId,
    required String missedDayKey,
    required ProgramV2Model program,
  }) =>
      ProgramReconciliationResult._(
        outcome: ProgramReconciliationOutcome.pendingCreated,
        programId: programId,
        missedDayKey: missedDayKey,
        program: program,
      );

  factory ProgramReconciliationResult.alreadyPending({
    required String programId,
    required String missedDayKey,
    required ProgramV2Model program,
  }) =>
      ProgramReconciliationResult._(
        outcome: ProgramReconciliationOutcome.alreadyPending,
        programId: programId,
        missedDayKey: missedDayKey,
        program: program,
      );

  factory ProgramReconciliationResult.requiresSuccessFinalization({
    required String programId,
    required ProgramV2Model program,
  }) =>
      ProgramReconciliationResult._(
        outcome: ProgramReconciliationOutcome.requiresSuccessFinalization,
        programId: programId,
        program: program,
      );

  factory ProgramReconciliationResult.terminalProgram({
    required String programId,
    required ProgramV2Model program,
  }) =>
      ProgramReconciliationResult._(
        outcome: ProgramReconciliationOutcome.terminalProgram,
        programId: programId,
        program: program,
      );

  factory ProgramReconciliationResult.failure({
    required ProgramReconciliationOutcome outcome,
    String? programId,
    String? message,
  }) =>
      ProgramReconciliationResult._(
        outcome: outcome,
        programId: programId,
        errorMessage: message,
      );
}

/// Result of reconciling a collection or batch of programs.
class BatchReconciliationResult {
  final List<ProgramReconciliationResult> results;
  final DateTime reconciliationInstant;

  const BatchReconciliationResult({
    required this.results,
    required this.reconciliationInstant,
  });

  int get totalInspected => results.length;

  int get pendingCreatedCount => results
      .where((r) => r.outcome == ProgramReconciliationOutcome.pendingCreated)
      .length;

  int get alreadyPendingCount => results
      .where((r) => r.outcome == ProgramReconciliationOutcome.alreadyPending)
      .length;

  int get noMissedDayCount => results
      .where((r) => r.outcome == ProgramReconciliationOutcome.noMissedDay)
      .length;

  int get errorCount => results.where((r) => r.isFailure).length;

  List<ProgramReconciliationResult> get pendingMuhasabahResults =>
      results.where((r) => r.hasMissedDay).toList();
}

/// Domain service responsible for reconciling ACTIVE Program V2 instances against
/// persisted DailyCheckIn records to detect missed operational days.
///
/// Enforces all Mujahadah V2 reconciliation invariants:
/// 1. Operational day runs 03:00 local device time through 02:59:59.999 following day.
/// 2. An operational day is only missed AFTER its window has closed.
/// 3. Earliest missing required day is recorded as [ProgramV2Model.pendingMissedDayKey].
/// 4. Completed programs (e.g. 40/40) take priority and are NEVER transitioned to PENDING_FAILURE.
/// 5. Already PENDING_FAILURE programs are idempotent; no repeated writes or timestamp changes.
/// 6. Corrupt canonical keys or conflicting check-in data result in typed data-integrity errors.
/// 7. Preserves all other 10 program fields without modification.
///
/// Concurrency Scope & Limitations:
/// In-process serialization is strictly scoped to this single [ProgramV2ReconciliationService] instance.
/// It serializes overlapping asynchronous calls to prevent race conditions within the same service instance.
/// It does NOT guarantee cross-instance, cross-isolate, or multi-process synchronization.
class ProgramV2ReconciliationService {
  final ProgramV2Repository _programRepository;
  final DailyCheckInV2Repository _checkInRepository;
  final DateService _dateService;

  // In-process FIFO lock to prevent race conditions during concurrent reconciliation calls.
  Future<void> _lock = Future.value();

  ProgramV2ReconciliationService({
    required ProgramV2Repository programRepository,
    required DailyCheckInV2Repository checkInRepository,
    DateService? dateService,
  })  : _programRepository = programRepository,
        _checkInRepository = checkInRepository,
        _dateService = dateService ?? DateService();

  /// In-process synchronization to serialize async reconciliation operations.
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

  /// Reconciles a single program by its [programId].
  ///
  /// Serialized in-process to guarantee idempotency and avoid duplicate transitions.
  /// Storage operations that fail return a typed [ProgramReconciliationOutcome.persistenceError],
  /// while unexpected programming errors propagate for developer diagnostics.
  Future<ProgramReconciliationResult> reconcileProgram(
    String programId, {
    DateTime? capturedNow,
  }) {
    return _synchronized(() async {
      final instant = capturedNow ?? _dateService.now;
      return _reconcileProgramInternal(programId, instant);
    });
  }

  /// Reconciles all ACTIVE and PENDING_FAILURE programs stored in the repository.
  ///
  /// Designed for future invocation at app bootstrap, resume, or before check-in.
  /// Captures a single current instant consistently across all inspected programs.
  Future<BatchReconciliationResult> reconcileActivePrograms({
    DateTime? capturedNow,
  }) {
    return _synchronized(() async {
      final instant = capturedNow ?? _dateService.now;
      final List<ProgramV2Model> allPrograms;
      try {
        allPrograms = _programRepository.getAll();
      } on HiveError {
        return BatchReconciliationResult(
          results: [
            ProgramReconciliationResult.failure(
              outcome: ProgramReconciliationOutcome.persistenceError,
              message:
                  'Storage operation failed while retrieving programs for batch reconciliation.',
            )
          ],
          reconciliationInstant: instant,
        );
      } on Exception {
        return BatchReconciliationResult(
          results: [
            ProgramReconciliationResult.failure(
              outcome: ProgramReconciliationOutcome.persistenceError,
              message:
                  'Storage operation failed while retrieving programs for batch reconciliation.',
            )
          ],
          reconciliationInstant: instant,
        );
      }

      final results = <ProgramReconciliationResult>[];
      for (final program in allPrograms) {
        if (program.status == ProgramV2Model.statusActive ||
            program.status == ProgramV2Model.statusPendingFailure) {
          // Validate record storage key identity before calling reconciliation by ID
          if (program.key != null && program.key != program.id) {
            results.add(
              ProgramReconciliationResult.failure(
                outcome: ProgramReconciliationOutcome.dataIntegrityError,
                programId: program.id,
                message:
                    'Program storage key identity mismatch: record with id "${program.id}" is stored under key "${program.key}".',
              ),
            );
            continue;
          }

          final cleanId = program.id.trim();
          if (cleanId.isEmpty) {
            results.add(
              ProgramReconciliationResult.failure(
                outcome: ProgramReconciliationOutcome.invalidProgramId,
                programId: program.id,
                message: 'Program ID must not be empty or blank.',
              ),
            );
            continue;
          }

          final integrityError = _validateProgramIntegrity(program, cleanId);
          if (integrityError != null) {
            results.add(integrityError);
            continue;
          }

          try {
            final res = await _reconcileProgramInternal(cleanId, instant);
            results.add(res);
          } on HiveError {
            results.add(
              ProgramReconciliationResult.failure(
                outcome: ProgramReconciliationOutcome.persistenceError,
                programId: cleanId,
                message:
                    'Storage operation failed during reconciliation of program "$cleanId".',
              ),
            );
          } catch (_) {
            results.add(
              ProgramReconciliationResult.failure(
                outcome: ProgramReconciliationOutcome.unexpectedError,
                programId: cleanId,
                message:
                    'An unexpected error occurred during reconciliation of program "$cleanId".',
              ),
            );
          }
        }
      }

      return BatchReconciliationResult(
        results: results,
        reconciliationInstant: instant,
      );
    });
  }

  /// Validates core persisted invariants and storage identity of a [ProgramV2Model].
  ///
  /// Returns a failure [ProgramReconciliationResult] if invalid, or `null` if valid.
  ProgramReconciliationResult? _validateProgramIntegrity(
    ProgramV2Model program,
    String expectedId,
  ) {
    // 1. Storage key identity match
    if (program.id != expectedId ||
        (program.key != null && program.key != expectedId)) {
      return ProgramReconciliationResult.failure(
        outcome: ProgramReconciliationOutcome.dataIntegrityError,
        programId: expectedId,
        message:
            'Program storage key identity mismatch: expected "$expectedId" but record has id "${program.id}" and key "${program.key}".',
      );
    }

    // 2. targetDays invariant (40..365)
    if (program.targetDays < 40 || program.targetDays > 365) {
      return ProgramReconciliationResult.failure(
        outcome: ProgramReconciliationOutcome.dataIntegrityError,
        programId: expectedId,
        message:
            'Invalid program targetDays "${program.targetDays}". Expected between 40 and 365.',
      );
    }

    // 3. startDayKey valid date
    if (!DateService.isValidDayKey(program.startDayKey)) {
      return ProgramReconciliationResult.failure(
        outcome: ProgramReconciliationOutcome.dataIntegrityError,
        programId: expectedId,
        message:
            'Invalid program startDayKey format or date: "${program.startDayKey}". Expected YYYY-MM-DD.',
      );
    }

    // 4. Valid status check
    if (!ProgramV2Model.validStatuses.contains(program.status)) {
      return ProgramReconciliationResult.failure(
        outcome: ProgramReconciliationOutcome.dataIntegrityError,
        programId: expectedId,
        message: 'Unrecognized program status "${program.status}".',
      );
    }

    // 5. PENDING_FAILURE state invariants
    if (program.status == ProgramV2Model.statusPendingFailure) {
      final missedKey = program.pendingMissedDayKey;
      if (missedKey == null || !DateService.isValidDayKey(missedKey)) {
        return ProgramReconciliationResult.failure(
          outcome: ProgramReconciliationOutcome.dataIntegrityError,
          programId: expectedId,
          message:
              'Program is in PENDING_FAILURE status but has missing or invalid pendingMissedDayKey: "$missedKey".',
        );
      }
      if (_dateService.compareDayKeys(missedKey, program.startDayKey) < 0) {
        return ProgramReconciliationResult.failure(
          outcome: ProgramReconciliationOutcome.dataIntegrityError,
          programId: expectedId,
          message:
              'Program pendingMissedDayKey "$missedKey" cannot precede startDayKey "${program.startDayKey}".',
        );
      }
    }

    return null;
  }

  /// Internal un-locked reconciliation logic for a single program.
  Future<ProgramReconciliationResult> _reconcileProgramInternal(
    String programId,
    DateTime capturedNow,
  ) async {
    // 1. Validate program ID
    final cleanId = programId.trim();
    if (cleanId.isEmpty) {
      return ProgramReconciliationResult.failure(
        outcome: ProgramReconciliationOutcome.invalidProgramId,
        message: 'Program ID must not be empty or blank.',
      );
    }

    // 2. Lookup program in repository
    final ProgramV2Model? program;
    try {
      program = _programRepository.getById(cleanId);
    } on HiveError {
      return ProgramReconciliationResult.failure(
        outcome: ProgramReconciliationOutcome.persistenceError,
        programId: cleanId,
        message: 'Storage operation failed during program lookup.',
      );
    } on Exception {
      return ProgramReconciliationResult.failure(
        outcome: ProgramReconciliationOutcome.persistenceError,
        programId: cleanId,
        message: 'Storage operation failed during program lookup.',
      );
    }

    if (program == null) {
      return ProgramReconciliationResult.failure(
        outcome: ProgramReconciliationOutcome.programNotFound,
        programId: cleanId,
        message: 'Program "$cleanId" was not found in storage.',
      );
    }

    // 3. Validate program storage identity & persisted field invariants before date operations
    final integrityError = _validateProgramIntegrity(program, cleanId);
    if (integrityError != null) {
      return integrityError;
    }

    // 4. Handle already PENDING_FAILURE programs (idempotent, no rewrite)
    if (program.status == ProgramV2Model.statusPendingFailure) {
      return ProgramReconciliationResult.alreadyPending(
        programId: cleanId,
        missedDayKey: program.pendingMissedDayKey!,
        program: program,
      );
    }

    // 5. Handle terminal lifecycle states (SUCCESS, FAILED, WARNING)
    if (program.status == ProgramV2Model.statusSuccess ||
        program.status == ProgramV2Model.statusFailed ||
        program.status == ProgramV2Model.statusWarning) {
      return ProgramReconciliationResult.terminalProgram(
        programId: cleanId,
        program: program,
      );
    }

    // 6. Program is guaranteed ACTIVE here
    // Operational-day derivation
    final currentDayKey = _dateService.getMujahadahDayKey(capturedNow);

    // If current operational day is before startDayKey, program has not started
    if (_dateService.compareDayKeys(currentDayKey, program.startDayKey) < 0) {
      return ProgramReconciliationResult.notStarted(
        programId: cleanId,
        program: program,
      );
    }

    // 7. Retrieve and validate all stored check-ins for this program
    final List<DailyCheckInModel> allRecords;
    try {
      allRecords = _checkInRepository.getByProgramId(cleanId);
    } on HiveError {
      return ProgramReconciliationResult.failure(
        outcome: ProgramReconciliationOutcome.persistenceError,
        programId: cleanId,
        message: 'Storage operation failed while retrieving check-in records.',
      );
    } on Exception {
      return ProgramReconciliationResult.failure(
        outcome: ProgramReconciliationOutcome.persistenceError,
        programId: cleanId,
        message: 'Storage operation failed while retrieving check-in records.',
      );
    }

    final validDayMap = <String, DailyCheckInModel>{};
    bool hasAnomaly = false;
    String? anomalyMessage;

    for (final record in allRecords) {
      if (record.programId != cleanId) {
        hasAnomaly = true;
        anomalyMessage ??=
            'Record programId mismatch: "${record.programId}" vs "$cleanId".';
        continue;
      }

      if (!DateService.isValidDayKey(record.dayKey)) {
        hasAnomaly = true;
        anomalyMessage ??= 'Invalid dayKey format: "${record.dayKey}".';
        continue;
      }

      final expectedId =
          DailyCheckInV2Repository.buildCheckInId(record.dayKey, cleanId);
      if (record.id != expectedId) {
        hasAnomaly = true;
        anomalyMessage ??=
            'Mismatched check-in ID "${record.id}" (expected "$expectedId").';
        continue;
      }

      // Check record's actual storage key in Hive box
      if (record.key != null && record.key != expectedId) {
        hasAnomaly = true;
        anomalyMessage ??=
            'Record is stored at noncanonical storage key "${record.key}" (expected "$expectedId").';
        continue;
      }

      try {
        final storedAtKey = _checkInRepository.getById(expectedId);
        if (storedAtKey == null ||
            storedAtKey.id != record.id ||
            storedAtKey.programId != record.programId ||
            storedAtKey.dayKey != record.dayKey ||
            (storedAtKey.key != null && storedAtKey.key != expectedId)) {
          hasAnomaly = true;
          anomalyMessage ??=
              'Storage key "$expectedId" does not match record identity.';
          continue;
        }
      } on HiveError {
        return ProgramReconciliationResult.failure(
          outcome: ProgramReconciliationOutcome.persistenceError,
          programId: cleanId,
          message:
              'Storage operation failed while validating check-in storage keys.',
        );
      } on Exception {
        return ProgramReconciliationResult.failure(
          outcome: ProgramReconciliationOutcome.persistenceError,
          programId: cleanId,
          message:
              'Storage operation failed while validating check-in storage keys.',
        );
      }

      if (_dateService.compareDayKeys(record.dayKey, program.startDayKey) < 0) {
        hasAnomaly = true;
        anomalyMessage ??=
            'Record dayKey "${record.dayKey}" precedes startDayKey "${program.startDayKey}".';
        continue;
      }

      if (_dateService.compareDayKeys(record.dayKey, currentDayKey) > 0) {
        hasAnomaly = true;
        anomalyMessage ??=
            'Record dayKey "${record.dayKey}" is in future relative to "$currentDayKey".';
        continue;
      }

      if (validDayMap.containsKey(record.dayKey)) {
        final existing = validDayMap[record.dayKey]!;
        if (existing.id != record.id ||
            !existing.checkedAt.isAtSameMomentAs(record.checkedAt)) {
          hasAnomaly = true;
          anomalyMessage ??=
              'Duplicate conflicting records found for dayKey "${record.dayKey}".';
        }
        continue;
      }

      validDayMap[record.dayKey] = record;
    }

    // 8. Calculate consecutive completed days starting from startDayKey
    int consecutiveDays = 0;
    String checkDay = program.startDayKey;

    while (_dateService.compareDayKeys(checkDay, currentDayKey) <= 0 &&
        consecutiveDays < program.targetDays) {
      if (validDayMap.containsKey(checkDay)) {
        consecutiveDays++;
        checkDay = _dateService.getNextDayKey(checkDay);
      } else {
        break; // Streak interrupted
      }
    }

    // Flag nonconsecutive stored day keys
    if (validDayMap.length > consecutiveDays) {
      hasAnomaly = true;
      anomalyMessage ??=
          'Nonconsecutive stored day keys detected for program "$cleanId".';
    }

    // 9. Target completion check takes absolute priority over missed-day transition
    if (consecutiveDays >= program.targetDays) {
      if (hasAnomaly) {
        return ProgramReconciliationResult.failure(
          outcome: ProgramReconciliationOutcome.dataIntegrityError,
          programId: cleanId,
          message:
              'Target reached but check-in data contains integrity anomalies: $anomalyMessage',
        );
      }
      return ProgramReconciliationResult.requiresSuccessFinalization(
        programId: cleanId,
        program: program,
      );
    }

    // 10. If not target reached, check for data integrity anomalies before evaluating missed days
    if (hasAnomaly) {
      return ProgramReconciliationResult.failure(
        outcome: ProgramReconciliationOutcome.dataIntegrityError,
        programId: cleanId,
        message:
            'Data integrity anomaly detected in check-in records: $anomalyMessage',
      );
    }

    // 11. If current day is the start day, operational day is still open
    if (_dateService.compareDayKeys(currentDayKey, program.startDayKey) == 0) {
      return ProgramReconciliationResult.noMissedDay(
        programId: cleanId,
        program: program,
      );
    }

    // 12. Chronological check of required closed operational days
    final previousDayKey = _dateService.getPreviousDayKey(currentDayKey);
    final requiredDays = _dateService.getDayKeyRangeInclusive(
      program.startDayKey,
      previousDayKey,
    );

    String? earliestMissedDayKey;

    for (final requiredDay in requiredDays) {
      final canonicalId =
          DailyCheckInV2Repository.buildCheckInId(requiredDay, cleanId);

      try {
        if (_checkInRepository.containsId(canonicalId)) {
          final stored = _checkInRepository.getById(canonicalId);
          if (stored == null ||
              stored.id != canonicalId ||
              stored.programId != cleanId ||
              stored.dayKey != requiredDay ||
              (stored.key != null && stored.key != canonicalId)) {
            return ProgramReconciliationResult.failure(
              outcome: ProgramReconciliationOutcome.dataIntegrityError,
              programId: cleanId,
              message:
                  'Canonical check-in storage key "$canonicalId" is occupied by a conflicting record.',
            );
          }
        } else {
          final anomalous = _checkInRepository.getCheckIn(cleanId, requiredDay);
          if (anomalous != null) {
            return ProgramReconciliationResult.failure(
              outcome: ProgramReconciliationOutcome.dataIntegrityError,
              programId: cleanId,
              message:
                  'Existing check-in for operational day "$requiredDay" has an anomalous or non-canonical key.',
            );
          }
        }
      } on HiveError {
        return ProgramReconciliationResult.failure(
          outcome: ProgramReconciliationOutcome.persistenceError,
          programId: cleanId,
          message: 'Storage operation failed during continuity verification.',
        );
      } on Exception {
        return ProgramReconciliationResult.failure(
          outcome: ProgramReconciliationOutcome.persistenceError,
          programId: cleanId,
          message: 'Storage operation failed during continuity verification.',
        );
      }

      if (!validDayMap.containsKey(requiredDay)) {
        earliestMissedDayKey = requiredDay;
        break; // First missing day found
      }
    }

    if (earliestMissedDayKey == null) {
      return ProgramReconciliationResult.noMissedDay(
        programId: cleanId,
        program: program,
      );
    }

    // 13. Re-read program from storage before write (idempotency guard)
    final ProgramV2Model? latestProgram;
    try {
      latestProgram = _programRepository.getById(cleanId);
    } on HiveError {
      return ProgramReconciliationResult.failure(
        outcome: ProgramReconciliationOutcome.persistenceError,
        programId: cleanId,
        message:
            'Storage operation failed while re-reading program before update.',
      );
    } on Exception {
      return ProgramReconciliationResult.failure(
        outcome: ProgramReconciliationOutcome.persistenceError,
        programId: cleanId,
        message:
            'Storage operation failed while re-reading program before update.',
      );
    }

    if (latestProgram == null) {
      return ProgramReconciliationResult.failure(
        outcome: ProgramReconciliationOutcome.programNotFound,
        programId: cleanId,
        message: 'Program "$cleanId" was deleted during reconciliation.',
      );
    }

    // Validate storage identity and lifecycle invariants on the re-read instance
    final reReadIntegrityError =
        _validateProgramIntegrity(latestProgram, cleanId);
    if (reReadIntegrityError != null) {
      return reReadIntegrityError;
    }

    if (latestProgram.status == ProgramV2Model.statusPendingFailure) {
      return ProgramReconciliationResult.alreadyPending(
        programId: cleanId,
        missedDayKey: latestProgram.pendingMissedDayKey!,
        program: latestProgram,
      );
    }

    if (latestProgram.status == ProgramV2Model.statusSuccess ||
        latestProgram.status == ProgramV2Model.statusFailed ||
        latestProgram.status == ProgramV2Model.statusWarning) {
      return ProgramReconciliationResult.terminalProgram(
        programId: cleanId,
        program: latestProgram,
      );
    }

    if (latestProgram.status != ProgramV2Model.statusActive) {
      return ProgramReconciliationResult.failure(
        outcome: ProgramReconciliationOutcome.dataIntegrityError,
        programId: cleanId,
        message: 'Unrecognized program status "${latestProgram.status}".',
      );
    }

    // Snapshot consistency guard: verify that the lifecycle baseline and reconciliation
    // eligibility fields have not changed concurrently since calculation started.
    if (latestProgram.id != program.id ||
        latestProgram.ibadahId != program.ibadahId ||
        latestProgram.startDayKey != program.startDayKey ||
        latestProgram.targetDays != program.targetDays ||
        latestProgram.status != program.status ||
        latestProgram.pendingMissedDayKey != program.pendingMissedDayKey) {
      return ProgramReconciliationResult.failure(
        outcome: ProgramReconciliationOutcome.dataIntegrityError,
        programId: cleanId,
        message:
            'Program snapshot changed concurrently during reconciliation. Operation aborted to prevent stale transition.',
      );
    }

    // Never persist a pendingMissedDayKey that precedes latestProgram.startDayKey
    if (_dateService.compareDayKeys(
            earliestMissedDayKey, latestProgram.startDayKey) <
        0) {
      return ProgramReconciliationResult.failure(
        outcome: ProgramReconciliationOutcome.dataIntegrityError,
        programId: cleanId,
        message:
            'Pending missed day key "$earliestMissedDayKey" cannot precede startDayKey "${latestProgram.startDayKey}".',
      );
    }

    // 14. Construct replacement ProgramV2Model preserving all 10 unmutated fields
    final updatedProgram = ProgramV2Model(
      id: latestProgram.id,
      ibadahId: latestProgram.ibadahId,
      ibadahNameSnapshot: latestProgram.ibadahNameSnapshot,
      targetDays: latestProgram.targetDays,
      startDayKey: latestProgram.startDayKey,
      status: ProgramV2Model.statusPendingFailure,
      reminderTime: latestProgram.reminderTime,
      restartedFromProgramId: latestProgram.restartedFromProgramId,
      recipientNameSnapshot: latestProgram.recipientNameSnapshot,
      createdAt: latestProgram.createdAt,
      updatedAt: capturedNow,
      finalizedAt: latestProgram.finalizedAt,
      pendingMissedDayKey: earliestMissedDayKey,
    );

    // 15. Persist replacement model into repository
    try {
      await _programRepository.save(updatedProgram);
    } on HiveError {
      return ProgramReconciliationResult.failure(
        outcome: ProgramReconciliationOutcome.persistenceError,
        programId: cleanId,
        message:
            'Storage operation failed while persisting PENDING_FAILURE transition.',
      );
    } on Exception {
      return ProgramReconciliationResult.failure(
        outcome: ProgramReconciliationOutcome.persistenceError,
        programId: cleanId,
        message:
            'Storage operation failed while persisting PENDING_FAILURE transition.',
      );
    }

    return ProgramReconciliationResult.pendingCreated(
      programId: cleanId,
      missedDayKey: earliestMissedDayKey,
      program: updatedProgram,
    );
  }
}
