import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'dashboard_screen.dart';
import 'program_screen.dart';
import 'history_screen.dart';
import 'akun_screen.dart';

class MainScreenController extends GetxController {
  var currentIndex = 0.obs;

  void changePage(int index) {
    currentIndex.value = index;
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MainScreenController());

    final screens = [
      const DashboardScreen(),
      const ProgramScreen(),
      const HistoryScreen(),
      const AkunScreen(),
    ];

    return Scaffold(
      body: Obx(
        () => AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: screens[controller.currentIndex.value],
        ),
      ),
      bottomNavigationBar: Obx(
        () => BottomNavigationBar(
          currentIndex: controller.currentIndex.value,
          onTap: controller.changePage,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt),
              label: 'Program',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Akun',
            ),
          ],
        ),
      ),
    );
  }
}
