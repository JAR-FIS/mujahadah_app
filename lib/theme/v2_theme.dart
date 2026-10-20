import 'package:flutter/material.dart';

import 'v2_design_tokens.dart';

/// Centralized V2 Theme Definitions.
///
/// Provides isolated, locked ThemeData implementations for Light and Dark modes.
/// Preserves accessible contrast ratios, readable typography scales, and responsive tokens.
/// Does not mutate or depend on the legacy V1 [AppTheme].
abstract class V2Theme {
  // --- Light Theme (White with Tosca Green and Warm Gold accent) ---
  static ThemeData get lightTheme {
    final baseTextTheme = Typography.material2021().black;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: V2Colors.deepTosca,
      scaffoldBackgroundColor: V2Colors.lightScaffoldBackground,
      colorScheme: const ColorScheme.light(
        primary: V2Colors.deepTosca,
        onPrimary: Colors.white,
        primaryContainer: V2Colors.mint,
        onPrimaryContainer: V2Colors.deepTosca,
        secondary: V2Colors.warmGold,
        onSecondary: Colors.white,
        secondaryContainer: V2Colors.peach,
        onSecondaryContainer: V2Colors.charcoal,
        surface: V2Colors.lightSurface,
        onSurface: V2Colors.lightTextPrimary,
        error: V2Colors.pink,
        onError: V2Colors.charcoal,
        outline: V2Colors.lightBorder,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: V2Colors.lightSurface,
        foregroundColor: V2Colors.deepTosca,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: V2Colors.deepTosca,
          fontSize: 18.0,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: V2Colors.deepTosca),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: V2Colors.lightSurface,
        selectedItemColor: V2Colors.deepTosca,
        unselectedItemColor: V2Colors.lightTextSecondary,
        selectedLabelStyle: V2Typography.labelMedium,
        unselectedLabelStyle: V2Typography.labelSmall,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      cardTheme: CardThemeData(
        color: V2Colors.lightSurfaceCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: V2Radius.borderLg,
          side: const BorderSide(color: V2Colors.lightBorder),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: V2Colors.lightDivider,
        thickness: 1,
        space: 1,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge:
            V2Typography.display.copyWith(color: V2Colors.lightTextPrimary),
        headlineLarge: V2Typography.headingLarge
            .copyWith(color: V2Colors.lightTextPrimary),
        headlineMedium: V2Typography.headingMedium
            .copyWith(color: V2Colors.lightTextPrimary),
        headlineSmall: V2Typography.headingSmall
            .copyWith(color: V2Colors.lightTextPrimary),
        bodyLarge:
            V2Typography.bodyLarge.copyWith(color: V2Colors.lightTextPrimary),
        bodyMedium:
            V2Typography.bodyMedium.copyWith(color: V2Colors.lightTextPrimary),
        bodySmall:
            V2Typography.bodySmall.copyWith(color: V2Colors.lightTextSecondary),
        labelLarge:
            V2Typography.labelLarge.copyWith(color: V2Colors.lightTextPrimary),
        labelMedium: V2Typography.labelMedium
            .copyWith(color: V2Colors.lightTextSecondary),
        labelSmall:
            V2Typography.labelSmall.copyWith(color: V2Colors.lightTextMuted),
      ),
    );
  }

  // --- Dark Theme (Elegant Black with Dark Tosca and Warm Gold accent) ---
  static ThemeData get darkTheme {
    final baseTextTheme = Typography.material2021().white;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: V2Colors.deepTosca,
      scaffoldBackgroundColor: V2Colors.darkScaffoldBackground,
      colorScheme: const ColorScheme.dark(
        primary: V2Colors.mint,
        onPrimary: V2Colors.charcoal,
        primaryContainer: V2Colors.deepTosca,
        onPrimaryContainer: V2Colors.mint,
        secondary: V2Colors.warmGold,
        onSecondary: Colors.black,
        secondaryContainer: V2Colors.peach,
        onSecondaryContainer: V2Colors.charcoal,
        surface: V2Colors.darkSurface,
        onSurface: V2Colors.darkTextPrimary,
        error: V2Colors.pink,
        onError: V2Colors.charcoal,
        outline: V2Colors.darkBorder,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: V2Colors.darkSurface,
        foregroundColor: V2Colors.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: V2Colors.darkTextPrimary,
          fontSize: 18.0,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: V2Colors.darkTextPrimary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: V2Colors.darkSurface,
        selectedItemColor: V2Colors.mint,
        unselectedItemColor: V2Colors.darkTextSecondary,
        selectedLabelStyle: V2Typography.labelMedium,
        unselectedLabelStyle: V2Typography.labelSmall,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      cardTheme: CardThemeData(
        color: V2Colors.darkSurfaceCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: V2Radius.borderLg,
          side: const BorderSide(color: V2Colors.darkBorder),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: V2Colors.darkDivider,
        thickness: 1,
        space: 1,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge:
            V2Typography.display.copyWith(color: V2Colors.darkTextPrimary),
        headlineLarge:
            V2Typography.headingLarge.copyWith(color: V2Colors.darkTextPrimary),
        headlineMedium: V2Typography.headingMedium
            .copyWith(color: V2Colors.darkTextPrimary),
        headlineSmall:
            V2Typography.headingSmall.copyWith(color: V2Colors.darkTextPrimary),
        bodyLarge:
            V2Typography.bodyLarge.copyWith(color: V2Colors.darkTextPrimary),
        bodyMedium:
            V2Typography.bodyMedium.copyWith(color: V2Colors.darkTextPrimary),
        bodySmall:
            V2Typography.bodySmall.copyWith(color: V2Colors.darkTextSecondary),
        labelLarge:
            V2Typography.labelLarge.copyWith(color: V2Colors.darkTextPrimary),
        labelMedium: V2Typography.labelMedium
            .copyWith(color: V2Colors.darkTextSecondary),
        labelSmall:
            V2Typography.labelSmall.copyWith(color: V2Colors.darkTextMuted),
      ),
    );
  }
}
