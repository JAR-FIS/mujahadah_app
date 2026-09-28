import 'package:hive/hive.dart';

part 'ibadah_model.g.dart';

@HiveType(typeId: 1)
class IbadahModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String namaIbadah;

  @HiveField(2)
  bool isDefault;

  IbadahModel({
    required this.id,
    required this.namaIbadah,
    this.isDefault = false,
  });
}
