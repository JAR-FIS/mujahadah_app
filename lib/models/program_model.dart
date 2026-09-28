import 'package:hive/hive.dart';

part 'program_model.g.dart';

@HiveType(typeId: 2)
class ProgramModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String namaIbadah;

  @HiveField(2)
  int targetHari;

  @HiveField(3)
  int hariBerjalan;

  @HiveField(4)
  DateTime tglMulai;

  @HiveField(5)
  DateTime? tglTerakhirCheckin;

  @HiveField(6)
  String jamPengingat;

  @HiveField(7)
  String status;

  @HiveField(8)
  String? alasanGagal;

  ProgramModel({
    required this.id,
    required this.namaIbadah,
    required this.targetHari,
    this.hariBerjalan = 0,
    required this.tglMulai,
    this.tglTerakhirCheckin,
    required this.jamPengingat,
    required this.status,
    this.alasanGagal,
  });
}
