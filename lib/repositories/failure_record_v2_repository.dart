import 'package:hive/hive.dart';

import '../models/failure_record_model.dart';

/// Hive-backed repository providing dedicated persistence operations
/// for [FailureRecordModel] without coupling domain services to direct global Hive calls.
class FailureRecordV2Repository {
  final Box<FailureRecordModel> _box;

  FailureRecordV2Repository({required Box<FailureRecordModel> box})
      : _box = box;

  /// Underlying Hive box exposed for lifecycle operations (e.g. flush, close in tests).
  Box<FailureRecordModel> get box => _box;

  /// Returns all failure records stored in the box.
  List<FailureRecordModel> getAll() => _box.values.toList();

  /// Returns a failure record by its unique storage key / ID, or `null` if not found.
  FailureRecordModel? getById(String id) => _box.get(id);

  /// Checks whether a record with [id] exists in the box.
  bool containsId(String id) => _box.containsKey(id);

  /// Returns all failure records associated with a given [programId].
  List<FailureRecordModel> getByProgramId(String programId) {
    return _box.values.where((f) => f.programId == programId).toList();
  }

  /// Builds a deterministic, collision-safe composite identity: `fail_<missedDayKey>_<programId>`.
  ///
  /// The fixed 10-character `missedDayKey` (YYYY-MM-DD) followed by `_` guarantees unambiguous
  /// parsing and collision resistance even if `programId` contains delimiters.
  static String buildFailureRecordId(String missedDayKey, String programId) {
    return 'fail_${missedDayKey}_$programId';
  }

  /// Checks whether the canonical key for [programId] and [missedDayKey] is already occupied in the box.
  bool isCanonicalKeyOccupied(String missedDayKey, String programId) {
    final expectedId = buildFailureRecordId(missedDayKey, programId);
    return _box.containsKey(expectedId);
  }

  /// Returns all failure records associated with [programId] and [missedDayKey].
  List<FailureRecordModel> getRecordsForInterruption(
    String programId,
    String missedDayKey,
  ) {
    return _box.values
        .where(
            (f) => f.programId == programId && f.missedDayKey == missedDayKey)
        .toList();
  }

  /// Returns a failure record for a given [programId] and [missedDayKey], or `null` if not found.
  FailureRecordModel? getByProgramAndMissedDay(
    String programId,
    String missedDayKey,
  ) {
    final expectedId = buildFailureRecordId(missedDayKey, programId);
    final direct = _box.get(expectedId);
    if (direct != null &&
        direct.programId == programId &&
        direct.missedDayKey == missedDayKey) {
      return direct;
    }
    // Fallback scan in case a record was stored with an anomalous/custom key
    for (final record in _box.values) {
      if (record.programId == programId &&
          record.missedDayKey == missedDayKey) {
        return record;
      }
    }
    return null;
  }

  /// Persists [failureRecord] into the box using its [FailureRecordModel.id] as the key.
  ///
  /// Insert-only contract: FailureRecord records are immutable once persisted.
  /// Throws [StateError] if the storage key [failureRecord.id] is already occupied,
  /// preventing overwriting existing failure records.
  Future<void> save(FailureRecordModel failureRecord) async {
    if (_box.containsKey(failureRecord.id)) {
      throw StateError(
        'Cannot overwrite existing FailureRecord at storage key "${failureRecord.id}". Repository is insert-only.',
      );
    }
    await _box.put(failureRecord.id, failureRecord);
  }

  /// Flushes any pending writes to disk.
  Future<void> flush() async {
    await _box.flush();
  }
}
