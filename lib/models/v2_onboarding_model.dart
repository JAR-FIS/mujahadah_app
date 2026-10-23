import 'package:flutter/material.dart';

/// Content model representing a single onboarding screen.
///
/// Five titles and feature scopes are Owner-approved. Body copy paragraphs
/// are provisional development text (DRAFT / PENDING OWNER COPY APPROVAL).
class V2OnboardingPageContent {
  final int pageIndex;
  final String badge;
  final String title;
  final String body;
  final IconData icon;
  final String copyKeyPrefix;
  final bool isBodyProvisional;

  const V2OnboardingPageContent({
    required this.pageIndex,
    required this.badge,
    required this.title,
    required this.body,
    required this.icon,
    required this.copyKeyPrefix,
    this.isBodyProvisional = true,
  });
}

/// Abstract contract for translatable onboarding copy.
///
/// Designed to support four application languages (id, ms, en, ar) with structured
/// keys, directional metadata, and honest fallback notice when Owner translations are pending.
abstract class V2OnboardingStrings {
  String get languageCode;
  bool get isFullyLocalized;
  bool get isRtl;

  String get nextLabel;
  String get backLabel;
  String get finishLabel;
  String progressLabel(int current, int total);
  String get saveErrorMessage;
  String get fallbackNotice;

  List<V2OnboardingPageContent> get pages;
}

/// Approved Bahasa Indonesia onboarding copywriting baseline.
///
/// Titles and feature scopes are Owner-approved. Body paragraphs are provisional
/// development placeholders pending Owner copy approval.
class V2OnboardingStringsId implements V2OnboardingStrings {
  const V2OnboardingStringsId();

  @override
  String get languageCode => 'id';

  @override
  bool get isFullyLocalized => true;

  @override
  bool get isRtl => false;

  @override
  String get nextLabel => 'Lanjut';

  @override
  String get backLabel => 'Kembali';

  @override
  String get finishLabel => 'Mulai Perjalanan';

  @override
  String progressLabel(int current, int total) =>
      'Halaman $current dari $total';

  @override
  String get saveErrorMessage =>
      'Gagal menyimpan status onboarding. Silakan coba lagi.';

  @override
  String get fallbackNotice => '';

  @override
  List<V2OnboardingPageContent> get pages => const [
        V2OnboardingPageContent(
          pageIndex: 0,
          badge: 'Aplikasi Mujahadah',
          title: 'Selamat Datang di Mujahadah',
          body:
              'Aplikasi pendamping ibadah harian untuk membantumu membangun dan menjaga konsistensi (istiqomah) dalam kebaikan langkah demi langkah.',
          icon: Icons.mosque_outlined,
          copyKeyPrefix: 'onboarding_01',
          isBodyProvisional: true,
        ),
        V2OnboardingPageContent(
          pageIndex: 1,
          badge: 'Target Bertahap',
          title: 'Bangun Istiqomah dengan Target yang Jelas',
          body:
              'Pilih target perjalanan istiqomah mulai dari 40, 60, 90, 100 hari, atau tentukan target kustom minimal 40 hari sesuai komitmen ibadahmu.',
          icon: Icons.flag_outlined,
          copyKeyPrefix: 'onboarding_02',
          isBodyProvisional: true,
        ),
        V2OnboardingPageContent(
          pageIndex: 2,
          badge: 'Disiplin Waktu',
          title: 'Check-in, Ingat, dan Jangan Terlewat',
          body:
              'Lakukan check-in satu kali setiap hari operasional (03:00–02:59) dengan konfirmasi yang aman dan pengingat agar ibadahmu tidak terlewat.',
          icon: Icons.alarm_on_outlined,
          copyKeyPrefix: 'onboarding_03',
          isBodyProvisional: true,
        ),
        V2OnboardingPageContent(
          pageIndex: 3,
          badge: 'Evaluasi Diri',
          title: 'Muhasabah, Bukan Sekadar Streak',
          body:
              'Saat ada hari yang terlewat, lakukan muhasabah dengan mencatat alasan dan temukan pesan penyemangat untuk bangkit kembali tanpa rasa putus asa.',
          icon: Icons.self_improvement_outlined,
          copyKeyPrefix: 'onboarding_04',
          isBodyProvisional: true,
        ),
        V2OnboardingPageContent(
          pageIndex: 4,
          badge: 'Apresiasi & Rekam Jejak',
          title: 'Lihat Perjalanan dan Rayakan Milestone',
          body:
              'Pantau kemajuan ibadahmu, raih Piagam Istiqomah saat berhasil menyelesaikan target program, serta simpan dan bagikan perjalanan kebaikanmu.',
          icon: Icons.workspace_premium_outlined,
          copyKeyPrefix: 'onboarding_05',
          isBodyProvisional: true,
        ),
      ];
}

/// Fallback translatable strings implementation for languages awaiting Owner translation workbook.
///
/// Discloses `isFullyLocalized = false` and provides safe fallback to approved Indonesian text
/// without fabricating unapproved translations or religious terminology.
class V2OnboardingStringsFallback implements V2OnboardingStrings {
  @override
  final String languageCode;

  const V2OnboardingStringsFallback({required this.languageCode});

  static const _idBaseline = V2OnboardingStringsId();

  @override
  bool get isFullyLocalized => false;

  @override
  bool get isRtl => V2OnboardingModel.isRtl(languageCode);

  @override
  String get nextLabel => _idBaseline.nextLabel;

  @override
  String get backLabel => _idBaseline.backLabel;

  @override
  String get finishLabel => _idBaseline.finishLabel;

  @override
  String progressLabel(int current, int total) =>
      _idBaseline.progressLabel(current, total);

  @override
  String get saveErrorMessage => _idBaseline.saveErrorMessage;

  @override
  String get fallbackNotice =>
      'Terjemahan bahasa ini sedang disiapkan. Teks sementara ditampilkan dalam Bahasa Indonesia.';

  @override
  List<V2OnboardingPageContent> get pages => _idBaseline.pages;
}

/// Registry and utilities for four-language onboarding readiness.
class V2OnboardingModel {
  static const String langId = 'id';
  static const String langMs = 'ms';
  static const String langEn = 'en';
  static const String langAr = 'ar';

  static const List<String> supportedLanguages = [
    langId,
    langMs,
    langEn,
    langAr,
  ];

  static const int totalPages = 5;

  /// Determines whether a language requires Right-to-Left (RTL) layout.
  static bool isRtl(String? languageCode) {
    if (languageCode == null) return false;
    return languageCode.trim().toLowerCase() == langAr;
  }

  /// Normalizes language code safely to supported four languages, defaulting to Indonesian.
  static String normalizeLanguage(String? code) {
    if (code == null) return langId;
    final normalized = code.trim().toLowerCase();
    if (supportedLanguages.contains(normalized)) {
      return normalized;
    }
    return langId;
  }

  /// Resolves the onboarding strings for the specified language code.
  static V2OnboardingStrings stringsFor(String? languageCode) {
    final code = normalizeLanguage(languageCode);
    switch (code) {
      case langId:
        return const V2OnboardingStringsId();
      case langMs:
      case langEn:
      case langAr:
        return V2OnboardingStringsFallback(languageCode: code);
      default:
        return const V2OnboardingStringsId();
    }
  }
}
