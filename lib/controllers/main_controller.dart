import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../models/program_model.dart';
import 'ibadah_controller.dart';

class MainController extends GetxController {
  late Box<ProgramModel> _programBox;

  @override
  void onInit() {
    super.onInit();
    _programBox = Hive.box<ProgramModel>('program');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkMissedPrograms();
    });
  }

  void checkMissedPrograms() {
    final activePrograms = _programBox.values.where((p) => p.status == 'ACTIVE').toList();
    DateTime now = DateTime.now();
    DateTime justDateNow = DateTime(now.year, now.month, now.day);

    for (var program in activePrograms) {
      DateTime dateToCompare = program.tglTerakhirCheckin ?? program.tglMulai;
      DateTime justDateCompare = DateTime(dateToCompare.year, dateToCompare.month, dateToCompare.day);

      if (justDateNow.difference(justDateCompare).inDays > 1) {
        showFailedDialog(program);
      }
    }
  }

  void showFailedDialog(ProgramModel program) {
    Get.dialog(
      AlertDialog(
        title: const Text('Missed Program'),
        content: Text('Anda melewatkan ibadah: ${program.namaIbadah}.'),
        actions: [
          TextButton(
            onPressed: () {
              // Mark as failed in IbadahController as a placeholder action
              if (Get.isRegistered<IbadahController>()) {
                Get.find<IbadahController>().markAsFailed(program.id, "Lupa/Missed");
              }
              Get.back();
            },
            child: const Text('OK'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }
}
