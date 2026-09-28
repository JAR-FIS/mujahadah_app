import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'controllers/theme_controller.dart';
import 'controllers/main_controller.dart';
import 'controllers/ibadah_controller.dart';

import 'models/user_model.dart';
import 'models/ibadah_model.dart';
import 'models/program_model.dart';

import 'theme/app_theme.dart';
import 'views/screens/main_screen.dart';
import 'views/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Hive.initFlutter();
  
  Hive.registerAdapter(UserModelAdapter());
  Hive.registerAdapter(IbadahModelAdapter());
  Hive.registerAdapter(ProgramModelAdapter());
  
  await Hive.openBox('settings');
  await Hive.openBox<UserModel>('user');
  await Hive.openBox<IbadahModel>('ibadah');
  await Hive.openBox<ProgramModel>('program');
  
  Get.put(ThemeController());
  Get.put(IbadahController());
  Get.put(MainController());
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = Get.find();
    
    return Obx(() => GetMaterialApp(
      title: 'Mujahadah App',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeController.isDarkMode.value ? ThemeMode.dark : ThemeMode.light,
      home: const SplashScreen(),
    ));
  }
}
