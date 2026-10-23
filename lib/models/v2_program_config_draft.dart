import 'package:flutter/foundation.dart';

import '../services/program_v2_creation_service.dart';

/// Form configuration draft for Mujahadah Program setup (Screen S20).
///
/// Encapsulates all user selections prior to final confirmation in Review Program:
/// - Target duration (presets: 40, 60, 90, 100 days; custom: 40..365 days).
/// - Operational start selection ([ProgramStartSelection.today] or [ProgramStartSelection.tomorrow]).
/// - Optional reminder switch and 24h `HH:mm` reminder time.
@immutable
class V2ProgramConfigDraft {
  static const List<int> presetDurations = [40, 60, 90, 100];
  static const int minTargetDays = 40;
  static const int maxTargetDays = 365;

  /// Strict regex matching 24-hour format HH:mm (00:00 to 23:59).
  static final RegExp reminderTimeRegex =
      RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');

  final int targetDays;
  final bool isCustomDuration;
  final String customDurationText;
  final ProgramStartSelection startSelection;
  final bool isReminderEnabled;
  final String? reminderTime;
  final String? reviewedStartDayKey;
  final String? restartedFromProgramId;

  const V2ProgramConfigDraft({
    this.targetDays = 40,
    this.isCustomDuration = false,
    this.customDurationText = '',
    this.startSelection = ProgramStartSelection.today,
    this.isReminderEnabled = false,
    this.reminderTime,
    this.reviewedStartDayKey,
    this.restartedFromProgramId,
  });

  /// Evaluates the effective target days based on preset vs custom entry.
  int get effectiveTargetDays {
    if (isCustomDuration) {
      final parsed = int.tryParse(customDurationText.trim());
      if (parsed != null) return parsed;
    }
    return targetDays;
  }

  /// Validates target duration according to Mujahadah V2 creation invariants.
  ///
  /// Rejects empty, non-numeric, fractional, zero, negative, < 40, and > 365 inputs.
  /// 40 is valid, 365 is valid.
  String? validateDuration() {
    if (!isCustomDuration) {
      if (targetDays < minTargetDays || targetDays > maxTargetDays) {
        return 'Target durasi harus antara $minTargetDays dan $maxTargetDays hari.';
      }
      return null;
    }

    final trimmed = customDurationText.trim();
    if (trimmed.isEmpty) {
      return 'Masukkan jumlah hari target.';
    }

    // Must be integer: reject fractional, decimal point, comma, or non-digits
    final parsed = int.tryParse(trimmed);
    if (parsed == null || trimmed.contains('.') || trimmed.contains(',')) {
      return 'Durasi harus berupa angka bulat.';
    }

    if (parsed < minTargetDays) {
      return 'Durasi minimal $minTargetDays hari.';
    }
    if (parsed > maxTargetDays) {
      return 'Durasi maksimal $maxTargetDays hari.';
    }

    return null;
  }

  /// Validates optional reminder time against strict HH:mm 24-hour format.
  String? validateReminder() {
    if (!isReminderEnabled) return null;
    if (reminderTime == null || reminderTime!.trim().isEmpty) {
      return 'Pilih waktu pengingat harian.';
    }
    if (!reminderTimeRegex.hasMatch(reminderTime!.trim())) {
      return 'Format waktu pengingat harus HH:mm (24 jam).';
    }
    return null;
  }

  /// Overall validity of the program configuration draft.
  bool get isValid => validateDuration() == null && validateReminder() == null;

  V2ProgramConfigDraft copyWith({
    int? targetDays,
    bool? isCustomDuration,
    String? customDurationText,
    ProgramStartSelection? startSelection,
    bool? isReminderEnabled,
    String? reminderTime,
    String? reviewedStartDayKey,
    String? restartedFromProgramId,
  }) {
    return V2ProgramConfigDraft(
      targetDays: targetDays ?? this.targetDays,
      isCustomDuration: isCustomDuration ?? this.isCustomDuration,
      customDurationText: customDurationText ?? this.customDurationText,
      startSelection: startSelection ?? this.startSelection,
      isReminderEnabled: isReminderEnabled ?? this.isReminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      reviewedStartDayKey: reviewedStartDayKey ?? this.reviewedStartDayKey,
      restartedFromProgramId:
          restartedFromProgramId ?? this.restartedFromProgramId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is V2ProgramConfigDraft &&
          runtimeType == other.runtimeType &&
          targetDays == other.targetDays &&
          isCustomDuration == other.isCustomDuration &&
          customDurationText == other.customDurationText &&
          startSelection == other.startSelection &&
          isReminderEnabled == other.isReminderEnabled &&
          reminderTime == other.reminderTime &&
          reviewedStartDayKey == other.reviewedStartDayKey &&
          restartedFromProgramId == other.restartedFromProgramId;

  @override
  int get hashCode =>
      targetDays.hashCode ^
      isCustomDuration.hashCode ^
      customDurationText.hashCode ^
      startSelection.hashCode ^
      isReminderEnabled.hashCode ^
      reminderTime.hashCode ^
      reviewedStartDayKey.hashCode ^
      restartedFromProgramId.hashCode;
}

/// Typed callback signature for creating a Program V2 instance.
typedef ProgramCreationCallback = Future<ProgramCreationResult> Function(
    CreateProgramV2Request request);
