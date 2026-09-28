import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

class ThemeController extends GetxController {
  final _settingsBox = Hive.box('settings');
  var isDarkMode = false.obs;

  @override
  void onInit() {
    super.onInit();
    isDarkMode.value = _settingsBox.get('isDarkMode', defaultValue: false);
    Get.changeThemeMode(isDarkMode.value ? ThemeMode.dark : ThemeMode.light);
  }

  void toggleTheme() {
    isDarkMode.value = !isDarkMode.value;
    _settingsBox.put('isDarkMode', isDarkMode.value);
    Get.changeThemeMode(isDarkMode.value ? ThemeMode.dark : ThemeMode.light);
  }
}
