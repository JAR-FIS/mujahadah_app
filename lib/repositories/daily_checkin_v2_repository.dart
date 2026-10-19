import 'package:hive/hive.dart';

import '../models/daily_checkin_model.dart';

/// Hive-backed repository providing dedicated persistence operations
/// for [DailyCheckInModel] without coupling domain services to direct global Hive calls.
class DailyCheckInV2Repository {
  final Box<DailyCheckInModel> _box;

  DailyCheckInV2Repository({required Box<DailyCheckInModel> box}) : _box = box;

  /// Underlying Hive box exposed for lifecycle operations (e.g. flush, close in tests).
  Box<DailyCheckInModel> get box => _box;

  /// Returns all check-in records stored in the box.
  List<DailyCheckInModel> getAll() => _box.values.toList();

  /// Returns a check-in record by its unique storage key / ID, or `null` if not found.
  DailyCheckInModel? getById(String id) => _box.get(id);

  /// Checks whether a record with [id] exists in the box.
  bool containsId(String id) => _box.containsKey(id);

  /// Returns all check-in records associated with a given [programId].
  List<DailyCheckInModel> getByProgramId(String programId) {
    return _box.values.where((c) => c.programId == programId).toList();
  }

  /// Builds a deterministic, collision-safe composite identity: `<dayKey>_<programId>`.
  ///
  /// The fixed 10-character `dayKey` (YYYY-MM-DD) followed by `_` guarantees unambiguous
  /// parsing and collision resistance even if `programId` contains delimiters.
  static String buildCheckInId(String dayKey, String programId) {
    return '${dayKey}_$programId';
  }

  /// Checks whether the canonical key for [programId] and [dayKey] is already occupied in the box.
  bool isCanonicalKeyOccupied(String dayKey, String programId) {
    final expectedId = buildCheckInId(dayKey, programId);
    return _box.containsKey(expectedId);
  }

  /// Returns a check-in record for a given [programId] and [dayKey], or `null` if not found.
  DailyCheckInModel? getCheckIn(String programId, String dayKey) {
    final expectedId = buildCheckInId(dayKey, programId);
    final direct = _box.get(expectedId);
    if (direct != null &&
        direct.programId == programId &&
        direct.dayKey == dayKey) {
      return direct;
    }
    // Fallback scan in case a record was stored with an anomalous/legacy key
    for (final record in _box.values) {
      if (record.programId == programId && record.dayKey == dayKey) {
        return record;
      }
    }
    return null;
  }

  /// Checks whether a check-in already exists for [programId] on [dayKey].
  bool hasCheckIn(String programId, String dayKey) {
    return getCheckIn(programId, dayKey) != null;
  }

  /// Persists [checkIn] into the box using its [DailyCheckInModel.id] as the key.
  ///
  /// Insert-only contract: DailyCheckIn records are immutable once persisted.
  /// Throws [StateError] if the storage key [checkIn.id] is already occupied,
  /// preventing overwriting existing check-ins (even if fields are identical).
  Future<void> save(DailyCheckInModel checkIn) async {
    if (_box.containsKey(checkIn.id)) {
      throw StateError(
        'Cannot overwrite existing check-in at storage key "${checkIn.id}". Repository is insert-only.',
      );
    }
    await _box.put(checkIn.id, checkIn);
  }

  /// Flushes any pending writes to disk.
  Future<void> flush() async {
    await _box.flush();
  }
}
