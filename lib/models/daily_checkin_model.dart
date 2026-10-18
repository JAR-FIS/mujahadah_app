import 'package:hive/hive.dart';

part 'daily_checkin_model.g.dart';

@HiveType(typeId: 3)
class DailyCheckInModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String programId;

  @HiveField(2)
  final String dayKey;

  @HiveField(3)
  final DateTime checkedAt;

  @HiveField(4)
  final DateTime createdAt;

  DailyCheckInModel({
    required this.id,
    required this.programId,
    required this.dayKey,
    required this.checkedAt,
    required this.createdAt,
  });
}
