import 'package:hive/hive.dart';

part 'program_v2_model.g.dart';

@HiveType(typeId: 6)
class ProgramV2Model extends HiveObject {
  // Approved lifecycle status constants
  static const String statusActive = 'ACTIVE';
  static const String statusPendingFailure = 'PENDING_FAILURE';
  static const String statusSuccess = 'SUCCESS';
  static const String statusFailed = 'FAILED';
  static const String statusWarning = 'WARNING';

  static const List<String> validStatuses = [
    statusActive,
    statusPendingFailure,
    statusSuccess,
    statusFailed,
    statusWarning,
  ];

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String ibadahId;

  @HiveField(2)
  final String ibadahNameSnapshot;

  @HiveField(3)
  final int targetDays;

  @HiveField(4)
  final String startDayKey;

  @HiveField(5)
  final String status;

  @HiveField(6)
  final String? reminderTime;

  @HiveField(7)
  final String? restartedFromProgramId;

  @HiveField(8)
  final String? recipientNameSnapshot;

  @HiveField(9)
  final DateTime createdAt;

  @HiveField(10)
  final DateTime updatedAt;

  @HiveField(11)
  final DateTime? finalizedAt;

  @HiveField(12)
  final String? pendingMissedDayKey;

  ProgramV2Model({
    required this.id,
    required this.ibadahId,
    required this.ibadahNameSnapshot,
    required this.targetDays,
    required this.startDayKey,
    required this.status,
    this.reminderTime,
    this.restartedFromProgramId,
    this.recipientNameSnapshot,
    required this.createdAt,
    required this.updatedAt,
    this.finalizedAt,
    this.pendingMissedDayKey,
  });
}
