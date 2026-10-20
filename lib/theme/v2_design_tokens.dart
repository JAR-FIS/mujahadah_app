import 'package:flutter/material.dart';

/// Centralized V2 Design Tokens.
///
/// Implements the owner-approved Mujahadah V2 Color Identity & Token Foundation.
/// Hex values are locked and must not be duplicated across ad-hoc widgets.
abstract class V2Colors {
  // --- Approved Locked Core Palette ---
  static const Color deepTosca = Color(0xFF1F4D59);
  static const Color mint = Color(0xFFC4FECF);
  static const Color warmGold = Color(0xFFD2964D);
  static const Color pink = Color(0xFFFEC4D2);
  static const Color peach = Color(0xFFFFBF72);
  static const Color lightGray = Color(0xFFEBEBEB);
  static const Color cyan = Color(0xFFC4F8FE);
  static const Color charcoal = Color(0xFF434343);

  // --- Light Theme Semantic Tokens ---
  static const Color lightScaffoldBackground = Color(0xFFF8FAF9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceCard = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF434343);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  static const Color lightTextMuted = Color(0xFF9CA3AF);
  static const Color lightBorder = Color(0xFFEBEBEB);
  static const Color lightDivider = Color(0xFFE5E7EB);
  static const Color lightPrimary = deepTosca;
  static const Color lightAccent = warmGold;

  // --- Dark Theme Semantic Tokens ---
  static const Color darkScaffoldBackground = Color(0xFF121617);
  static const Color darkSurface = Color(0xFF1A2426);
  static const Color darkSurfaceCard = Color(0xFF1A2426);
  static const Color darkSurfaceElevated = Color(0xFF233033);
  static const Color darkTextPrimary = Color(0xFFEBEBEB);
  static const Color darkTextSecondary = Color(0xFF9EABA8);
  static const Color darkTextMuted = Color(0xFF6B7B78);
  static const Color darkBorder = Color(0xFF2C3E42);
  static const Color darkDivider = Color(0xFF243336);
  static const Color darkPrimary = mint;
  static const Color darkAccent = warmGold;

  // --- Functional / Status Tokens ---
  static const Color success = mint;
  static const Color warning = peach;
  static const Color error = pink;
  static const Color info = cyan;
}

/// Centralized V2 Spacing Tokens.
abstract class V2Spacing {
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double huge = 48.0;
}

/// Centralized V2 Corner Radius Tokens.
abstract class V2Radius {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double full = 999.0;

  static const BorderRadius borderXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius borderSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius borderMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius borderLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius borderXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius borderXxl = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius borderFull =
      BorderRadius.all(Radius.circular(full));
}

/// Centralized V2 Typography Scale.
///
/// Uses standard Flutter TextTheme properties to preserve system font fallback
/// and offline independence without introducing unapproved font packages.
abstract class V2Typography {
  static const TextStyle display = TextStyle(
    fontSize: 28.0,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.25,
  );

  static const TextStyle headingLarge = TextStyle(
    fontSize: 22.0,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.3,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.35,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.4,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.45,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
    height: 1.4,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    height: 1.3,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    height: 1.3,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 10.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
    height: 1.25,
  );
}

/// Centralized V2 Shadows & Elevations.
abstract class V2Elevation {
  static const List<BoxShadow> lightSubtle = [
    BoxShadow(
      color: Color(0x0A000000),
      offset: Offset(0, 2),
      blurRadius: 8,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> lightCard = [
    BoxShadow(
      color: Color(0x0F000000),
      offset: Offset(0, 4),
      blurRadius: 16,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> darkSubtle = [
    BoxShadow(
      color: Color(0x40000000),
      offset: Offset(0, 2),
      blurRadius: 8,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> centerActionButtonLight = [
    BoxShadow(
      color: Color(0x331F4D59),
      offset: Offset(0, 4),
      blurRadius: 12,
      spreadRadius: 1,
    ),
  ];

  static const List<BoxShadow> centerActionButtonDark = [
    BoxShadow(
      color: Color(0x4DD2964D),
      offset: Offset(0, 4),
      blurRadius: 12,
      spreadRadius: 1,
    ),
  ];
}
