import 'package:hive/hive.dart';
import '../models/program_v2_model.dart';

/// Hive-backed repository providing dedicated persistence operations
/// for [ProgramV2Model] without coupling domain services to direct global Hive calls.
class ProgramV2Repository {
  final Box<ProgramV2Model> _box;

  ProgramV2Repository({required Box<ProgramV2Model> box}) : _box = box;

  /// Underlying Hive box exposed for lifecycle operations (e.g. flush, close in tests).
  Box<ProgramV2Model> get box => _box;

  /// Returns all stored programs.
  List<ProgramV2Model> getAll() => _box.values.toList();

  /// Returns a program by [id], or `null` if not found.
  ProgramV2Model? getById(String id) => _box.get(id);

  /// Checks whether a program with [id] exists in the box.
  bool containsId(String id) => _box.containsKey(id);

  /// Returns all programs associated with a given [ibadahId].
  List<ProgramV2Model> getByIbadahId(String ibadahId) {
    return _box.values.where((p) => p.ibadahId == ibadahId).toList();
  }

  /// Checks whether an ACTIVE or PENDING_FAILURE program exists for [ibadahId].
  ///
  /// Per Mujahadah V2 business rules, only one active or pending failure program
  /// may exist at a time for any given ibadah.
  bool hasActiveOrPendingProgram(String ibadahId) {
    return _box.values.any((p) =>
        p.ibadahId == ibadahId &&
        (p.status == ProgramV2Model.statusActive ||
            p.status == ProgramV2Model.statusPendingFailure));
  }

  /// Persists [program] using its [ProgramV2Model.id] as the key.
  Future<void> save(ProgramV2Model program) async {
    await _box.put(program.id, program);
  }

  /// Flushes any pending writes to disk.
  Future<void> flush() async {
    await _box.flush();
  }
}
