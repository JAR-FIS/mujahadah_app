import 'package:hive/hive.dart';

import '../models/achievement_model.dart';

/// Hive-backed repository providing dedicated persistence operations
/// for [AchievementModel] without coupling domain services to direct global Hive calls.
class AchievementV2Repository {
  final Box<AchievementModel> _box;

  AchievementV2Repository({required Box<AchievementModel> box}) : _box = box;

  /// Underlying Hive box exposed for lifecycle operations (e.g. flush, close in tests).
  Box<AchievementModel> get box => _box;

  /// Returns all achievement records stored in the box.
  List<AchievementModel> getAll() => _box.values.toList();

  /// Returns an achievement record by its unique storage key / ID, or `null` if not found.
  AchievementModel? getById(String id) => _box.get(id);

  /// Checks whether a record with [id] exists in the box.
  bool containsId(String id) => _box.containsKey(id);

  /// Returns all achievement records associated with a given [programId].
  List<AchievementModel> getByProgramId(String programId) {
    return _box.values.where((a) => a.programId == programId).toList();
  }

  /// Builds a deterministic, collision-safe composite identity for final success: `ach_final_<programId>`.
  static String buildFinalSuccessId(String programId) {
    return 'ach_final_$programId';
  }

  /// Checks whether the canonical key for [programId] final success is already occupied in the box.
  bool isCanonicalKeyOccupied(String programId) {
    final expectedId = buildFinalSuccessId(programId);
    return _box.containsKey(expectedId);
  }

  /// Returns all FINAL_SUCCESS achievement records associated with [programId].
  List<AchievementModel> getFinalSuccessRecordsForProgram(String programId) {
    return _box.values
        .where((a) =>
            a.programId == programId &&
            a.type == AchievementModel.typeFinalSuccess)
        .toList();
  }

  /// Persists [achievement] into the box using its [AchievementModel.id] as the key.
  ///
  /// Insert-only contract: Achievements are immutable once persisted.
  /// Throws [StateError] if the storage key [achievement.id] is already occupied,
  /// preventing overwriting existing achievement records.
  Future<void> save(AchievementModel achievement) async {
    if (_box.containsKey(achievement.id)) {
      throw StateError(
        'Cannot overwrite existing Achievement at storage key "${achievement.id}". Repository is insert-only.',
      );
    }
    await _box.put(achievement.id, achievement);
  }

  /// Flushes any pending writes to disk.
  Future<void> flush() async {
    await _box.flush();
  }
}
