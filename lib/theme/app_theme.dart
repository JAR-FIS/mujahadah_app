import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryLight = Color(0xFF1ABC9C);
  static const Color primaryDark = Color(0xFF12876F);
  static const Color secondaryGold = Color(0xFFFFD700);
  
  static const Color bgLight = Color(0xFFF8F9FA);
  static const Color bgDark = Color(0xFF121212);

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryLight,
    scaffoldBackgroundColor: bgLight,
    colorScheme: const ColorScheme.light(
      primary: primaryLight,
      secondary: secondaryGold,
      surface: bgLight,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryLight,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: secondaryGold,
      foregroundColor: Colors.black,
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryDark,
    scaffoldBackgroundColor: bgDark,
    colorScheme: const ColorScheme.dark(
      primary: primaryDark,
      secondary: secondaryGold,
      surface: bgDark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryDark,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: secondaryGold,
      foregroundColor: Colors.black,
    ),
  );
}
