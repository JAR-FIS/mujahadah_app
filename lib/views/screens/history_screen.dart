import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../controllers/ibadah_controller.dart';
import '../../models/program_model.dart';

class HistoryScreenController extends GetxController {
  var selectedFilter = 'Semua'.obs;
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final IbadahController controller = Get.find<IbadahController>();
    final HistoryScreenController filterController = Get.put(HistoryScreenController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Program'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filter Chips
          Obx(() {
            int allCount = controller.historyPrograms.length;
            int successCount = controller.historyPrograms.where((p) => p.status == 'SUCCESS').length;
            int warningCount = controller.historyPrograms.where((p) => p.status == 'WARNING').length;
            int failedCount = controller.historyPrograms.where((p) => p.status == 'FAILED').length;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  _buildFilterChip(filterController, 'Semua', 'Semua ($allCount)'),
                  const SizedBox(width: 8),
                  _buildFilterChip(filterController, 'SUCCESS', '🟢 Sukses ($successCount)'),
                  const SizedBox(width: 8),
                  _buildFilterChip(filterController, 'WARNING', '🟡 Hampir ($warningCount)'),
                  const SizedBox(width: 8),
                  _buildFilterChip(filterController, 'FAILED', '🔴 Gagal ($failedCount)'),
                ],
              ),
            ).animate().fadeIn().slideY(begin: -0.1, end: 0);
          }),
          
          Expanded(
            child: Obx(() {
              List<ProgramModel> displayedList = controller.historyPrograms;
              if (filterController.selectedFilter.value != 'Semua') {
                displayedList = displayedList.where((p) => p.status == filterController.selectedFilter.value).toList();
              }

              if (displayedList.isEmpty) {
                return const Center(child: Text("Tidak ada riwayat."));
              }

              return ListView.builder(
                itemCount: displayedList.length,
                itemBuilder: (context, index) {
                  final program = displayedList[index];
                  Icon statusIcon;
                  if (program.status == 'SUCCESS') {
                    statusIcon = const Icon(Icons.check_circle, color: Colors.green);
                  } else if (program.status == 'WARNING') {
                    statusIcon = const Icon(Icons.warning, color: Colors.orange);
                  } else {
                    statusIcon = const Icon(Icons.cancel, color: Colors.red);
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                    child: ListTile(
                      leading: statusIcon,
                      title: Text(program.namaIbadah, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Target: ${program.targetHari} | Selesai: ${program.hariBerjalan}'),
                          if (program.alasanGagal != null && program.alasanGagal!.isNotEmpty)
                            Text('Alasan: ${program.alasanGagal}', style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ).animate(delay: (index * 50).ms).fadeIn(duration: 300.ms);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(HistoryScreenController filterController, String filterValue, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: filterController.selectedFilter.value == filterValue,
      onSelected: (selected) {
        if (selected) {
          filterController.selectedFilter.value = filterValue;
        }
      },
    );
  }
}
