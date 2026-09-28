import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../models/program_model.dart';
import '../models/ibadah_model.dart';

class IbadahController extends GetxController {
  late Box<ProgramModel> _programBox;
  late Box<IbadahModel> _ibadahBox;

  var activePrograms = <ProgramModel>[].obs;
  var historyPrograms = <ProgramModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    _programBox = Hive.box<ProgramModel>('program');
    _ibadahBox = Hive.box<IbadahModel>('ibadah');
    loadPrograms();
  }

  void loadPrograms() {
    final allPrograms = _programBox.values.toList();
    activePrograms.value = allPrograms.where((p) => p.status == 'ACTIVE').toList();
    historyPrograms.value = allPrograms.where((p) => p.status != 'ACTIVE').toList();
  }

  void addProgram(String namaIbadah, int targetHari, String jamPengingat) {
    final newProgram = ProgramModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      namaIbadah: namaIbadah,
      targetHari: targetHari,
      tglMulai: DateTime.now(),
      hariBerjalan: 0,
      jamPengingat: jamPengingat,
      status: 'ACTIVE',
    );
    _programBox.put(newProgram.id, newProgram);
    loadPrograms();
  }

  void checkIn(String programId) {
    final program = _programBox.get(programId);
    if (program != null && program.status == 'ACTIVE') {
      program.hariBerjalan += 1;
      program.tglTerakhirCheckin = DateTime.now();
      
      if (program.hariBerjalan >= program.targetHari) {
        program.status = 'SUCCESS';
      }
      
      program.save();
      loadPrograms();
    }
  }

  void markAsFailed(String programId, String alasan) {
    final program = _programBox.get(programId);
    if (program != null && program.status == 'ACTIVE') {
      if (program.hariBerjalan < 40) {
        program.status = 'FAILED';
      } else {
        program.status = 'WARNING';
      }
      program.alasanGagal = alasan;
      program.save();
      loadPrograms();
    }
  }
}
