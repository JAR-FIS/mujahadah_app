import 'dart:async';
import 'dart:math';

import 'package:hive/hive.dart';

import '../core/date/date_service.dart';
import '../models/program_v2_model.dart';
import '../repositories/program_v2_repository.dart';

/// Transient selection for when the program should begin its operational journey.
enum ProgramStartSelection {
  today,
  tomorrow,
}

/// Typed request DTO for program creation.
class CreateProgramV2Request {
  final String ibadahId;
  final String ibadahNameSnapshot;
  final int targetDays;
  final ProgramStartSelection startSelection;
  final String? reminderTime;
  final String? restartedFromProgramId;

  const CreateProgramV2Request({
    required this.ibadahId,
    required this.ibadahNameSnapshot,
    required this.targetDays,
    required this.startSelection,
    this.reminderTime,
    this.restartedFromProgramId,
  });
}

/// Enumeration of all possible validation and creation failure reasons.
enum ProgramCreationFailureReason {
  emptyIbadahId,
  emptyIbadahName,
  invalidDuration,
  invalidReminderTime,
  duplicateActiveProgram,
  idCollision,
  idGenerationError,
  invalidRestartSource,
  persistenceError,
}

/// Result object for Program V2 creation attempts.
class ProgramCreationResult {
  final bool isSuccess;
  final ProgramV2Model? program;
  final ProgramCreationFailureReason? failureReason;
  final String? errorMessage;

  const ProgramCreationResult._({
    required this.isSuccess,
    this.program,
    this.failureReason,
    this.errorMessage,
  });

  /// Successful creation outcome containing the persisted [ProgramV2Model].
  factory ProgramCreationResult.success(ProgramV2Model program) =>
      ProgramCreationResult._(
        isSuccess: true,
        program: program,
      );

  /// Failed creation outcome containing the specific [ProgramCreationFailureReason].
  factory ProgramCreationResult.failure({
    required ProgramCreationFailureReason reason,
    String? message,
  }) =>
      ProgramCreationResult._(
        isSuccess: false,
        failureReason: reason,
        errorMessage: message,
      );

  bool get isFailure => !isSuccess;
}

/// Default offline collision-resistant ID generator for Program V2 instances.
///
/// Combines microsecond timestamp with cryptographically secure random hexadecimal characters.
String defaultProgramV2IdGenerator([Random? random]) {
  final rng = random ?? Random.secure();
  final timestamp = DateTime.now().microsecondsSinceEpoch;
  final randomHex =
      List.generate(12, (_) => rng.nextInt(16).toRadixString(16)).join();
  return 'prog_${timestamp}_$randomHex';
}

/// Domain service responsible for validating and persisting new Program V2 instances.
///
/// Enforces all Mujahadah V2 creation invariants:
/// 1. Ibadah ID and historical name snapshot must be non-empty strings.
/// 2. Target duration must be between 40 and 365 days inclusive.
/// 3. Reminder time (if provided) must be strict 24-hour HH:mm format (00:00 - 23:59).
/// 4. An ibadah cannot have multiple simultaneous ACTIVE or PENDING_FAILURE programs.
/// 5. Start day key resolves deterministically according to the 03:00 operational boundary.
/// 6. In-process serialization guarantees atomic validation and persistence per service instance.
///
/// Concurrency Scope & Limitations:
/// In-process serialization is strictly scoped to this single [ProgramV2CreationService] instance.
/// It serializes overlapping asynchronous calls to prevent race conditions within the same service instance.
/// It does NOT guarantee cross-instance, cross-isolate, or multi-process synchronization.
class ProgramV2CreationService {
  static const int minTargetDays = 40;
  static const int maxTargetDays = 365;

  /// Strict regex matching 24-hour format HH:mm (00:00 to 23:59).
  static final RegExp _reminderTimeRegex =
      RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');

  final ProgramV2Repository _repository;
  final DateService _dateService;
  final String Function() _idGenerator;

  // In-process FIFO lock to prevent race conditions during concurrent creation requests.
  Future<void> _lock = Future.value();

  ProgramV2CreationService({
    required ProgramV2Repository repository,
    DateService? dateService,
    String Function()? idGenerator,
  })  : _repository = repository,
        _dateService = dateService ?? DateService(),
        _idGenerator = idGenerator ?? defaultProgramV2IdGenerator;

  /// In-process synchronization to serialize async read-check-write sequences.
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

  /// Checks whether a new program can be created for [ibadahId] based on current storage state.
  ///
  /// NOTE: This is strictly an advisory availability check suitable for preliminary UI validation
  /// or hints. The authoritative duplicate-prevention check is enforced atomically inside
  /// the serialized [createProgram] method.
  bool canCreateProgram(String ibadahId) {
    final cleanId = ibadahId.trim();
    if (cleanId.isEmpty) {
      return false;
    }
    try {
      return !_repository.hasActiveOrPendingProgram(cleanId);
    } on HiveError {
      return false;
    } on Exception {
      return false;
    }
  }

  /// Convenience method to create a program from a [CreateProgramV2Request].
  Future<ProgramCreationResult> createFromRequest(
      CreateProgramV2Request request) {
    return createProgram(
      ibadahId: request.ibadahId,
      ibadahNameSnapshot: request.ibadahNameSnapshot,
      targetDays: request.targetDays,
      startSelection: request.startSelection,
      reminderTime: request.reminderTime,
      restartedFromProgramId: request.restartedFromProgramId,
    );
  }

  /// Validates inputs and persists a new [ProgramV2Model] instance into storage.
  ///
  /// Serialized in-process to guarantee that duplicate active programs cannot
  /// be created even if multiple concurrent requests are initiated simultaneously
  /// on the same service instance.
  Future<ProgramCreationResult> createProgram({
    required String ibadahId,
    required String ibadahNameSnapshot,
    required int targetDays,
    required ProgramStartSelection startSelection,
    String? reminderTime,
    String? restartedFromProgramId,
  }) {
    return _synchronized(() async {
      // 1. Validate ibadah identity
      final cleanIbadahId = ibadahId.trim();
      if (cleanIbadahId.isEmpty) {
        return ProgramCreationResult.failure(
          reason: ProgramCreationFailureReason.emptyIbadahId,
          message: 'Ibadah ID must not be empty or blank.',
        );
      }

      final cleanNameSnapshot = ibadahNameSnapshot.trim();
      if (cleanNameSnapshot.isEmpty) {
        return ProgramCreationResult.failure(
          reason: ProgramCreationFailureReason.emptyIbadahName,
          message: 'Ibadah name snapshot must not be empty or blank.',
        );
      }

      // 2. Validate duration (40..365 inclusive)
      if (targetDays < minTargetDays || targetDays > maxTargetDays) {
        return ProgramCreationResult.failure(
          reason: ProgramCreationFailureReason.invalidDuration,
          message:
              'Target days must be between $minTargetDays and $maxTargetDays inclusive (received: $targetDays).',
        );
      }

      // 3. Validate optional reminderTime (strict HH:mm 24h format)
      if (reminderTime != null) {
        if (!_reminderTimeRegex.hasMatch(reminderTime)) {
          return ProgramCreationResult.failure(
            reason: ProgramCreationFailureReason.invalidReminderTime,
            message:
                'Reminder time must be in strict HH:mm 24-hour format (received: "$reminderTime").',
          );
        }
      }

      // 4. Validate active program exclusivity
      try {
        if (_repository.hasActiveOrPendingProgram(cleanIbadahId)) {
          return ProgramCreationResult.failure(
            reason: ProgramCreationFailureReason.duplicateActiveProgram,
            message:
                'An ACTIVE or PENDING_FAILURE program already exists for ibadah ID "$cleanIbadahId".',
          );
        }
      } on HiveError {
        return ProgramCreationResult.failure(
          reason: ProgramCreationFailureReason.persistenceError,
          message: 'Storage operation failed during active program lookup.',
        );
      } on Exception {
        return ProgramCreationResult.failure(
          reason: ProgramCreationFailureReason.persistenceError,
          message: 'Storage operation failed during active program lookup.',
        );
      }

      // 5. Validate optional restart origin if provided
      final String? cleanRestartedFromId;
      if (restartedFromProgramId != null) {
        final trimmed = restartedFromProgramId.trim();
        if (trimmed.isEmpty) {
          return ProgramCreationResult.failure(
            reason: ProgramCreationFailureReason.invalidRestartSource,
            message:
                'Restart origin program ID must not be empty or whitespace-only.',
          );
        }

        final ProgramV2Model? sourceProgram;
        try {
          sourceProgram = _repository.getById(trimmed);
        } on HiveError {
          return ProgramCreationResult.failure(
            reason: ProgramCreationFailureReason.persistenceError,
            message: 'Storage operation failed during restart source lookup.',
          );
        } on Exception {
          return ProgramCreationResult.failure(
            reason: ProgramCreationFailureReason.persistenceError,
            message: 'Storage operation failed during restart source lookup.',
          );
        }

        if (sourceProgram == null) {
          return ProgramCreationResult.failure(
            reason: ProgramCreationFailureReason.invalidRestartSource,
            message:
                'Restart source program "$trimmed" was not found in storage.',
          );
        }

        // Must be in a terminal status: SUCCESS, WARNING, or FAILED
        final isTerminal =
            sourceProgram.status == ProgramV2Model.statusSuccess ||
                sourceProgram.status == ProgramV2Model.statusWarning ||
                sourceProgram.status == ProgramV2Model.statusFailed;
        if (!isTerminal) {
          return ProgramCreationResult.failure(
            reason: ProgramCreationFailureReason.invalidRestartSource,
            message:
                'Restart source program must be in a terminal status (SUCCESS, WARNING, or FAILED; received: "${sourceProgram.status}").',
          );
        }

        // Must match requested ibadah ID
        if (sourceProgram.ibadahId != cleanIbadahId) {
          return ProgramCreationResult.failure(
            reason: ProgramCreationFailureReason.invalidRestartSource,
            message:
                'Restart source program ibadah ID ("${sourceProgram.ibadahId}") does not match requested ibadah ID ("$cleanIbadahId").',
          );
        }

        cleanRestartedFromId = trimmed;
      } else {
        cleanRestartedFromId = null;
      }

      // 6. Generate and validate unique ID
      final String generatedId;
      try {
        generatedId = _idGenerator();
      } catch (e) {
        return ProgramCreationResult.failure(
          reason: ProgramCreationFailureReason.idGenerationError,
          message: 'ID generation failed with an error.',
        );
      }

      final cleanId = generatedId.trim();
      if (cleanId.isEmpty) {
        return ProgramCreationResult.failure(
          reason: ProgramCreationFailureReason.idGenerationError,
          message: 'Generated program ID must not be empty or whitespace-only.',
        );
      }

      if (cleanRestartedFromId != null && cleanId == cleanRestartedFromId) {
        return ProgramCreationResult.failure(
          reason: ProgramCreationFailureReason.idCollision,
          message: 'Generated program ID matches restart source ID.',
        );
      }

      // Check for ID collision in storage
      try {
        if (_repository.containsId(cleanId)) {
          return ProgramCreationResult.failure(
            reason: ProgramCreationFailureReason.idCollision,
            message:
                'Generated program ID "$cleanId" already exists in storage.',
          );
        }
      } on HiveError {
        return ProgramCreationResult.failure(
          reason: ProgramCreationFailureReason.persistenceError,
          message: 'Storage operation failed during ID collision check.',
        );
      } on Exception {
        return ProgramCreationResult.failure(
          reason: ProgramCreationFailureReason.persistenceError,
          message: 'Storage operation failed during ID collision check.',
        );
      }

      // 7. Capture single current instant and resolve operational startDayKey
      final capturedNow = _dateService.now;
      final todayKey = _dateService.getMujahadahDayKey(capturedNow);
      final String startDayKey;
      switch (startSelection) {
        case ProgramStartSelection.today:
          startDayKey = todayKey;
          break;
        case ProgramStartSelection.tomorrow:
          startDayKey = _dateService.getNextDayKey(todayKey);
          break;
      }

      // 8. Instantiate ProgramV2Model
      final program = ProgramV2Model(
        id: cleanId,
        ibadahId: cleanIbadahId,
        ibadahNameSnapshot: cleanNameSnapshot,
        targetDays: targetDays,
        startDayKey: startDayKey,
        status: ProgramV2Model.statusActive,
        reminderTime: reminderTime,
        restartedFromProgramId: cleanRestartedFromId,
        recipientNameSnapshot: null,
        createdAt: capturedNow,
        updatedAt: capturedNow,
        finalizedAt: null,
        pendingMissedDayKey: null,
      );

      // 9. Persist to storage
      try {
        await _repository.save(program);
        return ProgramCreationResult.success(program);
      } on HiveError {
        return ProgramCreationResult.failure(
          reason: ProgramCreationFailureReason.persistenceError,
          message: 'Storage operation failed while persisting ProgramV2Model.',
        );
      } on Exception {
        return ProgramCreationResult.failure(
          reason: ProgramCreationFailureReason.persistenceError,
          message: 'Storage operation failed while persisting ProgramV2Model.',
        );
      }
    });
  }
}
