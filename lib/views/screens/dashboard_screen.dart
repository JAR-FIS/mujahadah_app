import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../controllers/ibadah_controller.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final IbadahController controller = Get.find<IbadahController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mujahadah Dashboard'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero Container
            Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1ABC9C), Color(0xFF16A085)], // Tosca gradient
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16.0),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  )
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '“Barangsiapa yang bersungguh-sungguh, maka dia akan berhasil.”',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '- Man Jadda Wajada',
                    style: TextStyle(
                      color: Color(0xFFFFD700), // Gold accent
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ).animate().fade(duration: 500.ms).slideY(begin: -0.2, end: 0),

            // Stat Cards
            Obx(() {
              int activeCount = controller.activePrograms.length;
              int almostCount = controller.historyPrograms.where((p) => p.status == 'WARNING').length;
              int failedCount = controller.historyPrograms.where((p) => p.status == 'FAILED').length;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatCard('Aktif', activeCount, Colors.blue),
                    _buildStatCard('Hampir', almostCount, Colors.orange),
                    _buildStatCard('Gagal', failedCount, Colors.red),
                  ],
                ),
              ).animate().fade().scale();
            }),

            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Program Aktif Anda',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ListView of Active Programs
            Obx(() {
              if (controller.activePrograms.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: Text("Belum ada program ibadah yang aktif.")),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: controller.activePrograms.length,
                itemBuilder: (context, index) {
                  final program = controller.activePrograms[index];
                  double progress = program.hariBerjalan / program.targetHari;
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: ListTile(
                      title: Text(program.namaIbadah, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            backgroundColor: Colors.grey[300],
                            color: const Color(0xFF1ABC9C),
                          ),
                          const SizedBox(height: 4),
                          Text('${program.hariBerjalan} / ${program.targetHari} Hari'),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.check_circle_outline, color: Color(0xFF1ABC9C), size: 32),
                        onPressed: () {
                          controller.checkIn(program.id);
                        },
                      ),
                    ),
                  ).animate(delay: (index * 100).ms).fade().slideX();
                },
              );
            }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, int count, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            children: [
              Text(
                count.toString(),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
