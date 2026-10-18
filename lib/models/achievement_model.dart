import 'package:hive/hive.dart';

part 'achievement_model.g.dart';

@HiveType(typeId: 5)
class AchievementModel extends HiveObject {
  static const String typeMilestone = 'MILESTONE';
  static const String typeFinalSuccess = 'FINAL_SUCCESS';

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String programId;

  @HiveField(2)
  final String type;

  @HiveField(3)
  final int milestoneDays;

  @HiveField(4)
  final DateTime achievedAt;

  @HiveField(5)
  final String? recipientNameSnapshot;

  @HiveField(6)
  final DateTime createdAt;

  AchievementModel({
    required this.id,
    required this.programId,
    required this.type,
    required this.milestoneDays,
    required this.achievedAt,
    this.recipientNameSnapshot,
    required this.createdAt,
  });
}
