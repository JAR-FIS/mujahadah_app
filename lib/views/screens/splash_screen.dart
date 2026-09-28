import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 3500), () {
      Get.offAll(() => const MainScreen());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.mosque,
                size: 72,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 24),
              const Text(
                "Rasulullah SAW bersabda:\n\n\"Amalan yang paling dicintai oleh Allah Ta'ala adalah amalan yang paling konsisten (istiqomah) meskipun itu sedikit.\"\n\n(HR. Bukhari dan Muslim)",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
