import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/ibadah_model.dart';
import '../../controllers/ibadah_controller.dart';

class ProgramScreen extends StatelessWidget {
  const ProgramScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Daftar Ibadah'),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: "Rekomendasi"),
              Tab(text: "Buatan Saya"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildIbadahList(isDefault: true),
            _buildIbadahList(isDefault: false),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            _showAddIbadahDialog(context);
          },
          child: const Icon(Icons.add),
        ).animate().scale(delay: 500.ms, duration: 300.ms),
      ),
    );
  }

  Widget _buildIbadahList({required bool isDefault}) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<IbadahModel>('ibadah').listenable(),
      builder: (context, Box<IbadahModel> box, _) {
        final List<IbadahModel> items = box.values.where((i) => i.isDefault == isDefault).toList();

        if (items.isEmpty) {
          return Center(
            child: Text(isDefault ? "Belum ada rekomendasi." : "Belum ada ibadah buatan Anda."),
          ).animate().fadeIn();
        }

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final ibadah = items[index];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.book)),
              title: Text(ibadah.namaIbadah),
              trailing: IconButton(
                icon: const Icon(Icons.play_arrow, color: Colors.green),
                onPressed: () {
                  _showStartProgramDialog(context, ibadah.namaIbadah);
                },
              ),
            ).animate(delay: (index * 100).ms).fadeIn().slideY();
          },
        );
      },
    );
  }

  void _showAddIbadahDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: const Text('Tambah Ibadah Baru'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Nama Ibadah'),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                final ibadahBox = Hive.box<IbadahModel>('ibadah');
                final newIbadah = IbadahModel(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  namaIbadah: nameController.text,
                  isDefault: false,
                );
                ibadahBox.put(newIbadah.id, newIbadah);
                Get.back();
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ).animate().scale(duration: 200.ms),
    );
  }

  void _showStartProgramDialog(BuildContext context, String namaIbadah) {
    final TextEditingController targetController = TextEditingController(text: "40");
    Get.dialog(
      AlertDialog(
        title: Text('Mulai $namaIbadah'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Tentukan target hari untuk program ini.'),
            const SizedBox(height: 8),
            TextField(
              controller: targetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Target Hari'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final target = int.tryParse(targetController.text) ?? 40;
              Get.find<IbadahController>().addProgram(namaIbadah, target, "04:30"); // Default reminder
              Get.back();
              Get.snackbar("Berhasil", "Program $namaIbadah berhasil dimulai!");
            },
            child: const Text('Mulai'),
          ),
        ],
      ).animate().scale(duration: 200.ms),
    );
  }
}
