import 'dart:async';

import 'package:hive/hive.dart';

import '../core/date/date_service.dart';
import '../models/daily_checkin_model.dart';
import '../models/program_v2_model.dart';
import '../repositories/daily_checkin_v2_repository.dart';
import '../repositories/program_v2_repository.dart';

/// Enumeration of typed failure reasons for daily check-in operations.
enum DailyCheckInFailureReason {
  invalidProgramId,
  programNotFound,
  confirmationRequired,
  programNotActive,
  programNotStarted,
  alreadyCheckedIn,
  requiresMuhasabah,
  targetAlreadyReached,
  dataIntegrityError,
  persistenceError,
}

/// Immutable snapshot representing authoritative progress for a Program V2 instance.
///
/// Progress is calculated dynamically from valid, distinct [DailyCheckInModel] records
/// rather than a mutable counter on the program model.
class ProgramProgressSnapshot {
  final String programId;
  final int targetDays;
  final int completedDays;
  final int remainingDays;
  final bool isCompletedToday;
  final bool isTargetReached;

  const ProgramProgressSnapshot({
    required this.programId,
    required this.targetDays,
    required this.completedDays,
    required this.remainingDays,
    required this.isCompletedToday,
    required this.isTargetReached,
  });
}

/// Result object for daily check-in attempts.
class DailyCheckInResult {
  final bool isSuccess;
  final DailyCheckInModel? checkIn;
  final DailyCheckInFailureReason? failureReason;
  final String? errorMessage;
  final bool targetReached;
  final ProgramProgressSnapshot? progress;

  const DailyCheckInResult._({
    required this.isSuccess,
    this.checkIn,
    this.failureReason,
    this.errorMessage,
    this.targetReached = false,
    this.progress,
  });

  /// Successful check-in outcome with persisted record, target signal, and progress snapshot.
  factory DailyCheckInResult.success({
    required DailyCheckInModel checkIn,
    required bool targetReached,
    required ProgramProgressSnapshot progress,
  }) =>
      DailyCheckInResult._(
        isSuccess: true,
        checkIn: checkIn,
        targetReached: targetReached,
        progress: progress,
      );

  /// Failed check-in outcome with typed reason and user-safe explanation.
  factory DailyCheckInResult.failure({
    required DailyCheckInFailureReason reason,
    String? message,
  }) =>
      DailyCheckInResult._(
        isSuccess: false,
        failureReason: reason,
        errorMessage: message,
        targetReached: false,
      );

  bool get isFailure => !isSuccess;
}

/// Domain service responsible for validating, persisting daily check-ins,
/// and computing authoritative progress for Program V2 journeys.
///
/// Enforces all Mujahadah V2 check-in invariants:
/// 1. At most one check-in per Mujahadah operational day (03:00 local boundary).
/// 2. Check-ins cannot be backdated or future-dated; date and timestamps derive
///    internally from an injected [DateService].
/// 3. Programs cannot check in before their operational `startDayKey`.
/// 4. Only ACTIVE programs can check in; terminal or pending failure programs are rejected.
/// 5. Historical continuity: Any un-reconciled missed day blocks check-in with `requiresMuhasabah`.
/// 6. Authoritative progress is calculated from distinct, valid check-in records.
/// 7. Additional check-ins cannot exceed the target duration.
/// 8. Target-day check-in provides an explicit `targetReached` signal.
///
/// Concurrency Scope & Limitations:
/// In-process serialization is strictly scoped to this single [DailyCheckInV2Service] instance.
/// It serializes overlapping asynchronous calls to prevent race conditions within the same service instance.
/// It does NOT guarantee cross-instance, cross-isolate, or multi-process synchronization.
class DailyCheckInV2Service {
  final ProgramV2Repository _programRepository;
  final DailyCheckInV2Repository _checkInRepository;
  final DateService _dateService;

  // In-process FIFO lock to prevent race conditions during rapid repeated check-in taps.
  Future<void> _lock = Future.value();

  DailyCheckInV2Service({
    required ProgramV2Repository programRepository,
    required DailyCheckInV2Repository checkInRepository,
    DateService? dateService,
  })  : _programRepository = programRepository,
        _checkInRepository = checkInRepository,
        _dateService = dateService ?? DateService();

  /// In-process synchronization to serialize async check-in validation and writes.
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

  /// Calculates authoritative progress for a given [programId].
  ///
  /// Returns `null` if the program is not found or the ID is blank, or if storage cannot be read.
  Future<ProgramProgressSnapshot?> getProgress(String programId) async {
    final cleanId = programId.trim();
    if (cleanId.isEmpty) {
      return null;
    }

    final ProgramV2Model? program;
    try {
      program = _programRepository.getById(cleanId);
    } on HiveError {
      return null;
    } on Exception {
      return null;
    }

    if (program == null) {
      return null;
    }

    final currentDayKey = _dateService.getTodayDayKey();
    try {
      final calcResult = _calculateProgress(program, currentDayKey);
      return calcResult.snapshot;
    } on HiveError {
      return null;
    } on Exception {
      return null;
    }
  }

  /// Internal helper to calculate progress from valid, distinct check-in records.
  _ProgressCalculationResult _calculateProgress(
      ProgramV2Model program, String currentDayKey) {
    final allRecords = _checkInRepository.getByProgramId(program.id);
    final validDayMap = <String, DailyCheckInModel>{};
    bool hasAnomaly = false;
    String? anomalyMessage;

    for (final record in allRecords) {
      // 1. Must belong to the exact program ID
      if (record.programId != program.id) {
        hasAnomaly = true;
        anomalyMessage ??=
            'Record programId mismatch: "${record.programId}" vs "${program.id}".';
        continue;
      }

      // 2. Must be a valid YYYY-MM-DD dayKey
      if (!DateService.isValidDayKey(record.dayKey)) {
        hasAnomaly = true;
        anomalyMessage ??= 'Invalid dayKey format: "${record.dayKey}".';
        continue;
      }

      // 3. Must match canonical composite ID format: <dayKey>_<programId>
      final expectedId = DailyCheckInV2Repository.buildCheckInId(
          record.dayKey, record.programId);
      if (record.id != expectedId) {
        hasAnomaly = true;
        anomalyMessage ??=
            'Mismatched check-in ID "${record.id}" (expected "$expectedId").';
        continue;
      }

      // 4. Storage relationship check: key in box must map to this record
      final storedAtKey = _checkInRepository.getById(expectedId);
      if (storedAtKey == null ||
          storedAtKey.id != record.id ||
          storedAtKey.programId != record.programId ||
          storedAtKey.dayKey != record.dayKey) {
        hasAnomaly = true;
        anomalyMessage ??=
            'Storage key "$expectedId" does not match record identity.';
        continue;
      }

      // 5. Must not precede the program's start day
      if (_dateService.compareDayKeys(record.dayKey, program.startDayKey) < 0) {
        hasAnomaly = true;
        anomalyMessage ??=
            'Record dayKey "${record.dayKey}" precedes startDayKey "${program.startDayKey}".';
        continue;
      }

      // 6. Must not be in the future relative to current operational day
      if (_dateService.compareDayKeys(record.dayKey, currentDayKey) > 0) {
        hasAnomaly = true;
        anomalyMessage ??=
            'Record dayKey "${record.dayKey}" is in future relative to "$currentDayKey".';
        continue;
      }

      // 7. Duplicate records for the same dayKey
      if (validDayMap.containsKey(record.dayKey)) {
        final existing = validDayMap[record.dayKey]!;
        if (existing.id != record.id ||
            !existing.checkedAt.isAtSameMomentAs(record.checkedAt)) {
          hasAnomaly = true;
          anomalyMessage ??=
              'Duplicate conflicting records found for dayKey "${record.dayKey}".';
        }
        // Deduplicate: do not count duplicate
        continue;
      }

      validDayMap[record.dayKey] = record;
    }

    // Calculate consecutive valid completed days starting from startDayKey
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

    // If there are records after a gap, flag as nonconsecutive anomaly
    if (validDayMap.length > consecutiveDays) {
      hasAnomaly = true;
      anomalyMessage ??=
          'Nonconsecutive stored day keys detected for program "${program.id}".';
    }

    final completedDays = consecutiveDays;
    final remainingDays =
        (program.targetDays - completedDays).clamp(0, program.targetDays);
    final isCompletedToday = validDayMap.containsKey(currentDayKey);
    // Final target is reached ONLY if completedDays >= targetDays AND no corrupt/anomalous records exist
    final isTargetReached =
        !hasAnomaly && (completedDays >= program.targetDays);

    final snapshot = ProgramProgressSnapshot(
      programId: program.id,
      targetDays: program.targetDays,
      completedDays: completedDays,
      remainingDays: remainingDays,
      isCompletedToday: isCompletedToday,
      isTargetReached: isTargetReached,
    );

    return _ProgressCalculationResult(
      snapshot: snapshot,
      hasAnomaly: hasAnomaly,
      anomalyDetails: anomalyMessage,
    );
  }

  /// Executes a daily check-in for [programId].
  ///
  /// Serialized in-process to guarantee idempotency and prevent duplicate records
  /// even if multiple concurrent requests are initiated simultaneously.
  Future<DailyCheckInResult> checkIn({
    required String programId,
    required bool confirmedByUser,
  }) {
    return _synchronized(() async {
      // 1. Validate program ID format
      final cleanProgramId = programId.trim();
      if (cleanProgramId.isEmpty) {
        return DailyCheckInResult.failure(
          reason: DailyCheckInFailureReason.invalidProgramId,
          message: 'Program ID must not be empty or blank.',
        );
      }

      // 2. Validate user confirmation modal outcome
      if (!confirmedByUser) {
        return DailyCheckInResult.failure(
          reason: DailyCheckInFailureReason.confirmationRequired,
          message: 'Check-in requires user confirmation.',
        );
      }

      // 3. Lookup program in storage
      final ProgramV2Model? program;
      try {
        program = _programRepository.getById(cleanProgramId);
      } on HiveError {
        return DailyCheckInResult.failure(
          reason: DailyCheckInFailureReason.persistenceError,
          message: 'Storage operation failed during program lookup.',
        );
      } on Exception {
        return DailyCheckInResult.failure(
          reason: DailyCheckInFailureReason.persistenceError,
          message: 'Storage operation failed during program lookup.',
        );
      }

      if (program == null) {
        return DailyCheckInResult.failure(
          reason: DailyCheckInFailureReason.programNotFound,
          message: 'Program "$cleanProgramId" was not found in storage.',
        );
      }

      // 4. Validate program status (must be ACTIVE)
      if (program.status != ProgramV2Model.statusActive) {
        return DailyCheckInResult.failure(
          reason: DailyCheckInFailureReason.programNotActive,
          message:
              'Cannot check in on program with status "${program.status}". Only ACTIVE programs are eligible.',
        );
      }

      // 5. Capture single current instant and derive operational dayKey
      final capturedNow = _dateService.now;
      final currentDayKey = _dateService.getMujahadahDayKey(capturedNow);

      // 6. Check start day eligibility (cannot check in before operational start)
      if (_dateService.compareDayKeys(currentDayKey, program.startDayKey) < 0) {
        return DailyCheckInResult.failure(
          reason: DailyCheckInFailureReason.programNotStarted,
          message:
              'Program is scheduled to start on ${program.startDayKey}. Cannot check in before start date.',
        );
      }

      // 7. Verify storage key occupancy & data integrity for the expected check-in ID
      final expectedCheckInId = DailyCheckInV2Repository.buildCheckInId(
          currentDayKey, cleanProgramId);

      try {
        if (_checkInRepository.containsId(expectedCheckInId)) {
          final existingAtKey = _checkInRepository.getById(expectedCheckInId);
          if (existingAtKey == null ||
              existingAtKey.id != expectedCheckInId ||
              existingAtKey.programId != cleanProgramId ||
              existingAtKey.dayKey != currentDayKey) {
            // Storage key is occupied by another record's identity or corrupt data
            return DailyCheckInResult.failure(
              reason: DailyCheckInFailureReason.dataIntegrityError,
              message:
                  'Canonical check-in storage key "$expectedCheckInId" is occupied by a conflicting record.',
            );
          }
          // Legitimate duplicate check-in for today
          return DailyCheckInResult.failure(
            reason: DailyCheckInFailureReason.alreadyCheckedIn,
            message:
                'Program has already checked in for operational day $currentDayKey.',
          );
        }

        // Check if an anomalous-key record exists for the same program and dayKey
        final existingCheckIn =
            _checkInRepository.getCheckIn(cleanProgramId, currentDayKey);
        if (existingCheckIn != null) {
          return DailyCheckInResult.failure(
            reason: DailyCheckInFailureReason.dataIntegrityError,
            message:
                'An existing check-in for operational day $currentDayKey has an anomalous key or conflicting ID ("${existingCheckIn.id}").',
          );
        }
      } on HiveError {
        return DailyCheckInResult.failure(
          reason: DailyCheckInFailureReason.persistenceError,
          message: 'Storage operation failed during duplicate check-in lookup.',
        );
      } on Exception {
        return DailyCheckInResult.failure(
          reason: DailyCheckInFailureReason.persistenceError,
          message: 'Storage operation failed during duplicate check-in lookup.',
        );
      }

      // 8. Authoritative progress calculation before writing
      final _ProgressCalculationResult preWriteResult;
      try {
        preWriteResult = _calculateProgress(program, currentDayKey);
      } on HiveError {
        return DailyCheckInResult.failure(
          reason: DailyCheckInFailureReason.persistenceError,
          message: 'Storage operation failed during progress calculation.',
        );
      } on Exception {
        return DailyCheckInResult.failure(
          reason: DailyCheckInFailureReason.persistenceError,
          message: 'Storage operation failed during progress calculation.',
        );
      }

      final existingProgress = preWriteResult.snapshot;
      // Target reached guard: distinguish clean completion from anomalous completion
      if (existingProgress.completedDays >= program.targetDays) {
        if (preWriteResult.hasAnomaly) {
          return DailyCheckInResult.failure(
            reason: DailyCheckInFailureReason.dataIntegrityError,
            message:
                'Target duration reached but stored check-in data contains integrity anomalies: ${preWriteResult.anomalyDetails}',
          );
        }
        return DailyCheckInResult.failure(
          reason: DailyCheckInFailureReason.targetAlreadyReached,
          message:
              'Program has already reached its target duration of ${program.targetDays} days. No further check-ins allowed.',
        );
      }

      // 9. Continuity & missed-day protection
      // All operational days from startDayKey up to yesterday must have valid check-ins
      if (_dateService.compareDayKeys(program.startDayKey, currentDayKey) < 0) {
        final previousDayKey = _dateService.getPreviousDayKey(currentDayKey);
        final requiredDays = _dateService.getDayKeyRangeInclusive(
            program.startDayKey, previousDayKey);

        for (final requiredDay in requiredDays) {
          try {
            if (!_checkInRepository.hasCheckIn(cleanProgramId, requiredDay)) {
              return DailyCheckInResult.failure(
                reason: DailyCheckInFailureReason.requiresMuhasabah,
                message:
                    'Missed required check-in for operational day $requiredDay. Failure reconciliation required.',
              );
            }
          } on HiveError {
            return DailyCheckInResult.failure(
              reason: DailyCheckInFailureReason.persistenceError,
              message:
                  'Storage operation failed during continuity verification.',
            );
          } on Exception {
            return DailyCheckInResult.failure(
              reason: DailyCheckInFailureReason.persistenceError,
              message:
                  'Storage operation failed during continuity verification.',
            );
          }
        }
      }

      // 10. Block check-in if existing stored records have integrity anomalies
      if (preWriteResult.hasAnomaly) {
        return DailyCheckInResult.failure(
          reason: DailyCheckInFailureReason.dataIntegrityError,
          message:
              'Data integrity anomaly detected in existing check-in records: ${preWriteResult.anomalyDetails}',
        );
      }

      // 11. Instantiate DailyCheckInModel with deterministic composite identity
      final checkIn = DailyCheckInModel(
        id: expectedCheckInId,
        programId: cleanProgramId,
        dayKey: currentDayKey,
        checkedAt: capturedNow,
        createdAt: capturedNow,
      );

      // 12. Persist to storage
      try {
        await _checkInRepository.save(checkIn);
      } on StateError catch (e) {
        return DailyCheckInResult.failure(
          reason: DailyCheckInFailureReason.dataIntegrityError,
          message: e.message,
        );
      } on HiveError {
        return DailyCheckInResult.failure(
          reason: DailyCheckInFailureReason.persistenceError,
          message: 'Storage operation failed while persisting DailyCheckIn.',
        );
      } on Exception {
        return DailyCheckInResult.failure(
          reason: DailyCheckInFailureReason.persistenceError,
          message: 'Storage operation failed while persisting DailyCheckIn.',
        );
      }

      // 13. Safely derive immediate post-write progress snapshot from validated pre-write state
      // (avoids redundant repository read after write while ensuring consistency)
      final newCompletedDays = existingProgress.completedDays + 1;
      final newRemainingDays =
          (program.targetDays - newCompletedDays).clamp(0, program.targetDays);
      final targetReached = newCompletedDays >= program.targetDays;

      final updatedProgress = ProgramProgressSnapshot(
        programId: program.id,
        targetDays: program.targetDays,
        completedDays: newCompletedDays,
        remainingDays: newRemainingDays,
        isCompletedToday: true,
        isTargetReached: targetReached,
      );

      return DailyCheckInResult.success(
        checkIn: checkIn,
        targetReached: targetReached,
        progress: updatedProgress,
      );
    });
  }
}

/// Internal result container capturing both calculated progress snapshot
/// and whether any data integrity anomalies were encountered.
class _ProgressCalculationResult {
  final ProgramProgressSnapshot snapshot;
  final bool hasAnomaly;
  final String? anomalyDetails;

  const _ProgressCalculationResult({
    required this.snapshot,
    required this.hasAnomaly,
    this.anomalyDetails,
  });
}
