import 'package:flutter/foundation.dart';

import 'v2_ibadah_catalog_item.dart';

/// Draft model representing user input for a new custom worship template (Screen S19).
///
/// Business Separation Invariant:
/// A custom Ibadah template holds ONLY worship activity metadata:
/// - [namaIbadah]: Non-empty user-defined activity title.
/// - [category]: Category classification (defaults to [V2IbadahCategory.custom]).
/// - [deskripsi]: Optional personal notes or description.
///
/// It strictly does NOT store program lifecycle or scheduling data:
/// - NO [targetDays]
/// - NO [startDayKey]
/// - NO [reminderTime]
/// - NO [status]
///
/// Those parameters belong exclusively to [ProgramV2Model] and are configured in S20.
@immutable
class V2CustomIbadahDraft {
  final String namaIbadah;
  final V2IbadahCategory category;
  final String deskripsi;

  const V2CustomIbadahDraft({
    required this.namaIbadah,
    this.category = V2IbadahCategory.custom,
    this.deskripsi = '',
  });

  /// Validates the draft inputs for Indonesian user-facing presentation.
  ///
  /// Returns `null` if valid, or a descriptive error string if invalid.
  String? validate() {
    final cleanName = namaIbadah.trim();
    if (cleanName.isEmpty) {
      return 'Nama ibadah tidak boleh kosong.';
    }
    if (cleanName.length < 3) {
      return 'Nama ibadah minimal 3 karakter.';
    }
    if (cleanName.length > 100) {
      return 'Nama ibadah maksimal 100 karakter.';
    }
    return null;
  }

  /// Whether all input fields pass validation.
  bool get isValid => validate() == null;

  V2CustomIbadahDraft copyWith({
    String? namaIbadah,
    V2IbadahCategory? category,
    String? deskripsi,
  }) {
    return V2CustomIbadahDraft(
      namaIbadah: namaIbadah ?? this.namaIbadah,
      category: category ?? this.category,
      deskripsi: deskripsi ?? this.deskripsi,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is V2CustomIbadahDraft &&
          runtimeType == other.runtimeType &&
          namaIbadah == other.namaIbadah &&
          category == other.category &&
          deskripsi == other.deskripsi;

  @override
  int get hashCode =>
      namaIbadah.hashCode ^ category.hashCode ^ deskripsi.hashCode;
}

/// Typed asynchronous callback contract for persisting a custom ibadah draft.
///
/// Implementations must persist the template into an authoritative store and
/// return the resulting [V2IbadahCatalogItem] (with its unique persisted ID
/// and `isCustom: true`).
///
/// Returns `null` if storage failed or was rejected.
typedef CustomIbadahSaveCallback = Future<V2IbadahCatalogItem?> Function(
    V2CustomIbadahDraft draft);
