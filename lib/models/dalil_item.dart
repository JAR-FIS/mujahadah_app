/// Categories for Dalil and Bekal Istiqomah in Mujahadah V2 (S15/S16).
enum DalilCategory {
  all,
  quran,
  hadits,
  doa,
  kisahHikmah;

  /// Backwards-compatible alias for kisahHikmah.
  static const DalilCategory kisah = DalilCategory.kisahHikmah;

  String get label {
    switch (this) {
      case DalilCategory.all:
        return 'Semua';
      case DalilCategory.quran:
        return "Al-Qur'an";
      case DalilCategory.hadits:
        return 'Hadits';
      case DalilCategory.doa:
        return 'Doa';
      case DalilCategory.kisahHikmah:
        return 'Kisah & Hikmah';
    }
  }

  static DalilCategory fromString(String? value) {
    if (value == null) return DalilCategory.all;
    final normalized = value.trim().toLowerCase();
    if (normalized.contains("qur'an") ||
        normalized.contains('quran') ||
        normalized == "al-qur'an") {
      return DalilCategory.quran;
    }
    if (normalized.contains('hadits') || normalized.contains('hadith')) {
      return DalilCategory.hadits;
    }
    if (normalized.contains('doa') ||
        normalized.contains("du'a") ||
        normalized.contains('dua')) {
      return DalilCategory.doa;
    }
    if (normalized.contains('kisah') ||
        normalized.contains('hikmah') ||
        normalized.contains('story')) {
      return DalilCategory.kisahHikmah;
    }
    return DalilCategory.all;
  }
}

/// Lightweight, typed presentation model for Dalil and Bekal Istiqomah content (S15/S16).
///
/// Designed to hold content provided later via authoritative Excel catalog.
/// Supports optional Arabic text, source attribution, and rich paragraphs.
class DalilItem {
  final String id;
  final String title;
  final DalilCategory category;
  final String excerpt;
  final String body;
  final String? sourceReference;
  final String? arabicText;

  const DalilItem({
    required this.id,
    required this.title,
    required this.category,
    required this.excerpt,
    required this.body,
    this.sourceReference,
    this.arabicText,
  });

  bool get hasArabicText => arabicText != null && arabicText!.trim().isNotEmpty;
  bool get hasSourceReference =>
      sourceReference != null && sourceReference!.trim().isNotEmpty;

  DalilItem copyWith({
    String? id,
    String? title,
    DalilCategory? category,
    String? excerpt,
    String? body,
    String? sourceReference,
    String? arabicText,
  }) {
    return DalilItem(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      excerpt: excerpt ?? this.excerpt,
      body: body ?? this.body,
      sourceReference: sourceReference ?? this.sourceReference,
      arabicText: arabicText ?? this.arabicText,
    );
  }
}
