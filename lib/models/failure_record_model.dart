import 'package:hive/hive.dart';

part 'failure_record_model.g.dart';

@HiveType(typeId: 4)
class FailureRecordModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String programId;

  @HiveField(2)
  final String missedDayKey;

  @HiveField(3)
  final String reasonCode;

  @HiveField(4)
  final String reasonLabelSnapshot;

  @HiveField(5)
  final String? note;

  @HiveField(6)
  final DateTime createdAt;

  FailureRecordModel({
    required this.id,
    required this.programId,
    required this.missedDayKey,
    required this.reasonCode,
    required this.reasonLabelSnapshot,
    this.note,
    required this.createdAt,
  });
}
