import 'package:hive/hive.dart';

part 'user_model.g.dart';

@HiveType(typeId: 0)
class UserModel extends HiveObject {
  @HiveField(0)
  String nama;

  @HiveField(1)
  int umur;

  @HiveField(2)
  String pekerjaan;

  @HiveField(3)
  String alamat;

  UserModel({
    required this.nama,
    required this.umur,
    required this.pekerjaan,
    required this.alamat,
  });
}
