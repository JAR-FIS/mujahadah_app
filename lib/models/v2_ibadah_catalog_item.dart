import 'package:flutter/foundation.dart';

/// Standard categories from the authoritative Mujahadah 59-Ibadah Catalog.
enum V2IbadahCategory {
  sholatSunnah,
  dzikir,
  ibadahHarian,
  quran,
  maulid,
  puasa,
  custom;

  String get label {
    switch (this) {
      case V2IbadahCategory.sholatSunnah:
        return 'Sholat Sunnah';
      case V2IbadahCategory.dzikir:
        return 'Dzikir';
      case V2IbadahCategory.ibadahHarian:
        return 'Ibadah Harian';
      case V2IbadahCategory.quran:
        return "Al-Qur'an";
      case V2IbadahCategory.maulid:
        return 'Maulid';
      case V2IbadahCategory.puasa:
        return 'Puasa';
      case V2IbadahCategory.custom:
        return 'Ibadah Kustom';
    }
  }

  static V2IbadahCategory fromString(String? value) {
    if (value == null) return V2IbadahCategory.custom;
    final normalized = value.trim().toLowerCase();
    if (normalized.contains('sholat')) return V2IbadahCategory.sholatSunnah;
    if (normalized.contains('dzikir') || normalized.contains('zikir')) {
      return V2IbadahCategory.dzikir;
    }
    if (normalized.contains('harian')) return V2IbadahCategory.ibadahHarian;
    if (normalized.contains("qur'an") || normalized.contains('quran')) {
      return V2IbadahCategory.quran;
    }
    if (normalized.contains('maulid')) return V2IbadahCategory.maulid;
    if (normalized.contains('puasa')) return V2IbadahCategory.puasa;
    return V2IbadahCategory.custom;
  }
}

/// Typed presentation model for Ibadah Catalog items in Mujahadah V2 (S17/S18).
///
/// Designed to hold content provided by the authoritative 59-Ibadah catalog.
/// Implements eligibility enforcement: only daily-check-in ibadah are eligible
/// as target templates in Mujahadah V2.
@immutable
class V2IbadahCatalogItem {
  final String id;
  final String namaIbadah;
  final V2IbadahCategory category;
  final String deskripsi;
  final String? tataCaraDanWaktu;
  final List<String> keutamaan;
  final String? dalilDanRujukan;
  final int defaultTargetDays;
  final bool isDailyEligible;
  final String? ineligibilityReason;
  final bool isCustom;

  const V2IbadahCatalogItem({
    required this.id,
    required this.namaIbadah,
    required this.category,
    required this.deskripsi,
    this.tataCaraDanWaktu,
    this.keutamaan = const [],
    this.dalilDanRujukan,
    this.defaultTargetDays = 40,
    required this.isDailyEligible,
    this.ineligibilityReason,
    this.isCustom = false,
  });

  bool get hasTataCaraDanWaktu =>
      tataCaraDanWaktu != null && tataCaraDanWaktu!.trim().isNotEmpty;

  bool get hasKeutamaan => keutamaan.isNotEmpty;

  bool get hasDalilDanRujukan =>
      dalilDanRujukan != null && dalilDanRujukan!.trim().isNotEmpty;

  V2IbadahCatalogItem copyWith({
    String? id,
    String? namaIbadah,
    V2IbadahCategory? category,
    String? deskripsi,
    String? tataCaraDanWaktu,
    List<String>? keutamaan,
    String? dalilDanRujukan,
    int? defaultTargetDays,
    bool? isDailyEligible,
    String? ineligibilityReason,
    bool? isCustom,
  }) {
    return V2IbadahCatalogItem(
      id: id ?? this.id,
      namaIbadah: namaIbadah ?? this.namaIbadah,
      category: category ?? this.category,
      deskripsi: deskripsi ?? this.deskripsi,
      tataCaraDanWaktu: tataCaraDanWaktu ?? this.tataCaraDanWaktu,
      keutamaan: keutamaan ?? this.keutamaan,
      dalilDanRujukan: dalilDanRujukan ?? this.dalilDanRujukan,
      defaultTargetDays: defaultTargetDays ?? this.defaultTargetDays,
      isDailyEligible: isDailyEligible ?? this.isDailyEligible,
      ineligibilityReason: ineligibilityReason ?? this.ineligibilityReason,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is V2IbadahCatalogItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          namaIbadah == other.namaIbadah &&
          category == other.category &&
          deskripsi == other.deskripsi &&
          tataCaraDanWaktu == other.tataCaraDanWaktu &&
          listEquals(keutamaan, other.keutamaan) &&
          dalilDanRujukan == other.dalilDanRujukan &&
          defaultTargetDays == other.defaultTargetDays &&
          isDailyEligible == other.isDailyEligible &&
          ineligibilityReason == other.ineligibilityReason &&
          isCustom == other.isCustom;

  @override
  int get hashCode =>
      id.hashCode ^
      namaIbadah.hashCode ^
      category.hashCode ^
      deskripsi.hashCode ^
      tataCaraDanWaktu.hashCode ^
      Object.hashAll(keutamaan) ^
      dalilDanRujukan.hashCode ^
      defaultTargetDays.hashCode ^
      isDailyEligible.hashCode ^
      ineligibilityReason.hashCode ^
      isCustom.hashCode;
}
