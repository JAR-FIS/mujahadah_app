import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/theme_controller.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AkunScreen extends StatelessWidget {
  const AkunScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = Get.find<ThemeController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Akun Saya'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const CircleAvatar(
            radius: 50,
            child: Icon(Icons.person, size: 50),
          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 16),
          const Text(
            'Hamba Allah',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ).animate().fadeIn(delay: 100.ms),
          const Text(
            'Pekerja Keras',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 32),
          const Divider(),
          Obx(() => SwitchListTile(
            title: const Text('Mode Gelap (Dark Mode)'),
            secondary: const Icon(Icons.dark_mode),
            value: themeController.isDarkMode.value,
            onChanged: (val) {
              themeController.toggleTheme();
            },
          )).animate().fadeIn(delay: 300.ms),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Tentang Aplikasi'),
            onTap: () {
              Get.snackbar("Info", "Aplikasi Mujahadah v1.0.0");
            },
          ).animate().fadeIn(delay: 400.ms),
        ],
      ),
    );
  }
}
