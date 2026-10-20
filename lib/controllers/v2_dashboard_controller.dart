import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../core/date/date_service.dart';
import '../core/runtime/v2_recipient_name_provider.dart';
import '../models/achievement_model.dart';
import '../models/program_v2_model.dart';
import '../repositories/achievement_v2_repository.dart';
import '../repositories/daily_checkin_v2_repository.dart';
import '../repositories/failure_record_v2_repository.dart';
import '../repositories/program_v2_repository.dart';
import '../services/daily_checkin_v2_service.dart';

/// Presentation data for prayer times schedule in S08 Dashboard.
@immutable
class PrayerScheduleData {
  final String locationName;
  final String nextPrayerName;
  final String nextPrayerTime;
  final String countdownText;
  final String subuh;
  final String dzuhur;
  final String ashar;
  final String maghrib;
  final String isya;

  const PrayerScheduleData({
    required this.locationName,
    required this.nextPrayerName,
    required this.nextPrayerTime,
    required this.countdownText,
    required this.subuh,
    required this.dzuhur,
    required this.ashar,
    required this.maghrib,
    required this.isya,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerScheduleData &&
          runtimeType == other.runtimeType &&
          locationName == other.locationName &&
          nextPrayerName == other.nextPrayerName &&
          nextPrayerTime == other.nextPrayerTime &&
          countdownText == other.countdownText &&
          subuh == other.subuh &&
          dzuhur == other.dzuhur &&
          ashar == other.ashar &&
          maghrib == other.maghrib &&
          isya == other.isya;

  @override
  int get hashCode => Object.hash(
        locationName,
        nextPrayerName,
        nextPrayerTime,
        countdownText,
        subuh,
        dzuhur,
        ashar,
        maghrib,
        isya,
      );
}

/// Represents an active program preview item on the S08 Dashboard.
@immutable
class DashboardProgramItem {
  final ProgramV2Model program;
  final int? completedDays;
  final int targetDays;
  final bool? isCompletedToday;
  final bool isPendingMuhasabah;

  const DashboardProgramItem({
    required this.program,
    required this.completedDays,
    required this.targetDays,
    required this.isCompletedToday,
    required this.isPendingMuhasabah,
  });

  /// True only when authoritative progress calculation was successful.
  bool get isProgressAvailable => completedDays != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DashboardProgramItem &&
          runtimeType == other.runtimeType &&
          program.id == other.program.id &&
          completedDays == other.completedDays &&
          targetDays == other.targetDays &&
          isCompletedToday == other.isCompletedToday &&
          isPendingMuhasabah == other.isPendingMuhasabah;

  @override
  int get hashCode => Object.hash(
        program.id,
        completedDays,
        targetDays,
        isCompletedToday,
        isPendingMuhasabah,
      );
}

/// Aggregated failure reason count for S08 Muhasabah card.
@immutable
class MuhasabahReasonSummary {
  final String reasonCode;
  final String label;
  final int count;

  const MuhasabahReasonSummary({
    required this.reasonCode,
    required this.label,
    required this.count,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MuhasabahReasonSummary &&
          runtimeType == other.runtimeType &&
          reasonCode == other.reasonCode &&
          label == other.label &&
          count == other.count;

  @override
  int get hashCode => Object.hash(reasonCode, label, count);
}

/// Presentation controller for Mujahadah V2 Dashboard (Screen S08).
///
/// Responsibilities:
/// 1. Project read-only domain data into presentation observables.
/// 2. Aggregate "Perjalanan Saya" statistics (Aktif, Tercapai, Terhenti).
/// 3. Provide preview of up to 3 active programs with authoritative progress.
/// 4. Aggregate top failure reasons for the Muhasabah card.
/// 5. Provide latest completed achievement for Achievement preview.
/// 6. Handle intentional unavailable states for future services (Prayer, Qibla, Hijri).
/// 7. Strictly avoid storage writes, automatic check-ins, or domain mutations.
class V2DashboardController extends GetxController {
  final ProgramV2Repository? _programRepository;
  final DailyCheckInV2Service? _dailyCheckInService;
  final FailureRecordV2Repository? _failureRecordRepository;
  final AchievementV2Repository? _achievementRepository;
  final DateService _dateService;
  final V2RecipientNameProvider? _recipientNameProvider;

  // Initial optional fixtures (for testing or future background services)
  final PrayerScheduleData? _initialPrayerSchedule;
  final String? _initialHijriDate;

  // --- Observables ---

  final RxBool _isLoading = false.obs;
  bool get isLoading => _isLoading.value;

  final RxString _userName = ''.obs;
  String get userName => _userName.value;

  final RxString _gregorianDateText = ''.obs;
  String get gregorianDateText => _gregorianDateText.value;

  final RxnString _hijriDateText = RxnString();
  String? get hijriDateText => _hijriDateText.value;

  final Rxn<PrayerScheduleData> _prayerSchedule = Rxn<PrayerScheduleData>();
  PrayerScheduleData? get prayerSchedule => _prayerSchedule.value;

  // Perjalanan Saya
  final RxInt _activeCount = 0.obs;
  int get activeCount => _activeCount.value;

  final RxInt _achievedCount = 0.obs;
  int get achievedCount => _achievedCount.value;
  int get completedCount => _achievedCount.value;

  final RxInt _stoppedCount = 0.obs;
  int get stoppedCount => _stoppedCount.value;

  // Active programs preview (Max 2-3)
  final RxList<DashboardProgramItem> _activePrograms =
      <DashboardProgramItem>[].obs;
  List<DashboardProgramItem> get activePrograms => _activePrograms;

  // Top failure reasons for Muhasabah preview
  final RxList<MuhasabahReasonSummary> _topFailureReasons =
      <MuhasabahReasonSummary>[].obs;
  List<MuhasabahReasonSummary> get topFailureReasons => _topFailureReasons;

  // Latest Achievement
  final Rxn<AchievementModel> _latestAchievement = Rxn<AchievementModel>();
  AchievementModel? get latestAchievement => _latestAchievement.value;

  // Error state
  final RxnString _errorMessage = RxnString();
  String? get errorMessage => _errorMessage.value;

  final RxBool _hasError = false.obs;
  bool get hasError => _hasError.value;

  V2DashboardController({
    ProgramV2Repository? programRepository,
    DailyCheckInV2Service? dailyCheckInService,
    DailyCheckInV2Repository? checkInRepository,
    FailureRecordV2Repository? failureRecordRepository,
    AchievementV2Repository? achievementRepository,
    DateService? dateService,
    V2RecipientNameProvider? recipientNameProvider,
    PrayerScheduleData? initialPrayerSchedule,
    String? initialHijriDate,
  })  : _programRepository = programRepository,
        _dailyCheckInService = dailyCheckInService,
        _failureRecordRepository = failureRecordRepository,
        _achievementRepository = achievementRepository,
        _dateService = dateService ?? DateService(),
        _recipientNameProvider = recipientNameProvider,
        _initialPrayerSchedule = initialPrayerSchedule,
        _initialHijriDate = initialHijriDate {
    _prayerSchedule.value = _initialPrayerSchedule;
    _hijriDateText.value = _initialHijriDate;
    _gregorianDateText.value = _formatIndonesianDate(_dateService.now);
    _userName.value = 'Sobat Istiqomah';
  }

  // Track initial data loading to prevent duplicate execution
  int _loadDataCallCount = 0;
  int get loadDataCallCount => _loadDataCallCount;

  bool _hasLoadedInitialData = false;
  bool get hasLoadedInitialData => _hasLoadedInitialData;

  @override
  void onInit() {
    super.onInit();
    _prayerSchedule.value = _initialPrayerSchedule;
    _hijriDateText.value = _initialHijriDate;
    if (!_hasLoadedInitialData) {
      loadDashboardData();
    }
  }

  /// Refreshes all Dashboard read-only projections.
  Future<void> loadDashboardData() async {
    _loadDataCallCount++;
    _hasLoadedInitialData = true;
    _isLoading.value = true;
    _hasError.value = false;
    _errorMessage.value = null;

    try {
      // 1. Date & Profile Formatting
      _gregorianDateText.value = _formatIndonesianDate(_dateService.now);

      final recipientProvider = _recipientNameProvider;
      if (recipientProvider != null) {
        try {
          final name = await recipientProvider.getRecipientName();
          _userName.value = (name != null && name.trim().isNotEmpty)
              ? name.trim()
              : 'Sobat Istiqomah';
        } catch (_) {
          _userName.value = 'Sobat Istiqomah';
        }
      } else {
        _userName.value = 'Sobat Istiqomah';
      }

      // 2. Perjalanan Saya & Active Programs
      final programRepo = _programRepository;
      if (programRepo != null) {
        final allPrograms = programRepo.getAll();

        final activeList = allPrograms
            .where((p) =>
                p.status == ProgramV2Model.statusActive ||
                p.status == ProgramV2Model.statusPendingFailure)
            .toList();

        final achievedList = allPrograms
            .where((p) => p.status == ProgramV2Model.statusSuccess)
            .toList();

        final stoppedList = allPrograms
            .where((p) =>
                p.status == ProgramV2Model.statusFailed ||
                p.status == ProgramV2Model.statusWarning)
            .toList();

        _activeCount.value = activeList.length;
        _achievedCount.value = achievedList.length;
        _stoppedCount.value = stoppedList.length;

        // Preview at most 2-3 active programs (per specification section 4.2)
        final previewSubset = activeList.take(3).toList();
        final programItems = <DashboardProgramItem>[];
        final checkInSvc = _dailyCheckInService;

        for (final program in previewSubset) {
          int? completed;
          bool? isCompletedToday;

          // Strictly use authoritative DailyCheckInV2Service projection.
          // Never calculate completed days from raw storage counts.
          if (checkInSvc != null) {
            final progress = await checkInSvc.getProgress(program.id);
            if (progress != null) {
              completed = progress.completedDays;
              isCompletedToday = progress.isCompletedToday;
            }
          }

          final isPendingMuhasabah =
              program.status == ProgramV2Model.statusPendingFailure ||
                  program.pendingMissedDayKey != null;

          programItems.add(
            DashboardProgramItem(
              program: program,
              completedDays: completed,
              targetDays: program.targetDays,
              isCompletedToday: isCompletedToday,
              isPendingMuhasabah: isPendingMuhasabah,
            ),
          );
        }

        _activePrograms.assignAll(programItems);
      } else {
        _activeCount.value = 0;
        _achievedCount.value = 0;
        _stoppedCount.value = 0;
        _activePrograms.clear();
      }

      // 3. Muhasabah Aggregation
      final failureRepo = _failureRecordRepository;
      if (failureRepo != null) {
        final failures = failureRepo.getAll();
        if (failures.isNotEmpty) {
          final countMap = <String, _ReasonCounter>{};
          for (final f in failures) {
            final key = f.reasonCode;
            final label = f.reasonLabelSnapshot.isNotEmpty
                ? f.reasonLabelSnapshot
                : f.reasonCode;
            final existing = countMap[key];
            if (existing != null) {
              existing.count++;
            } else {
              countMap[key] = _ReasonCounter(
                reasonCode: key,
                label: label,
                count: 1,
              );
            }
          }

          final sorted = countMap.values.toList()
            ..sort((a, b) => b.count.compareTo(a.count));

          _topFailureReasons.assignAll(
            sorted.take(2).map((r) => MuhasabahReasonSummary(
                  reasonCode: r.reasonCode,
                  label: r.label,
                  count: r.count,
                )),
          );
        } else {
          _topFailureReasons.clear();
        }
      } else {
        _topFailureReasons.clear();
      }

      // 4. Achievement Preview
      final achievementRepo = _achievementRepository;
      if (achievementRepo != null) {
        final achievements = achievementRepo.getAll();
        if (achievements.isNotEmpty) {
          // Sort descending by achievedAt / createdAt to get latest
          achievements.sort((a, b) => b.achievedAt.compareTo(a.achievedAt));
          _latestAchievement.value = achievements.first;
        } else {
          _latestAchievement.value = null;
        }
      } else {
        _latestAchievement.value = null;
      }
    } on HiveError catch (e) {
      _hasError.value = true;
      _errorMessage.value = 'Gagal mengakses data lokal: ${e.message}';
    } catch (e) {
      _hasError.value = true;
      _errorMessage.value = 'Gagal memuat dashboard: $e';
    } finally {
      _isLoading.value = false;
    }
  }

  /// Sets prayer schedule data (used in tests or by future background service).
  void setPrayerSchedule(PrayerScheduleData? data) {
    _prayerSchedule.value = data;
  }

  /// Sets Hijri date text (used in tests or by future Hijri calendar service).
  void setHijriDate(String? hijriDate) {
    _hijriDateText.value = hijriDate;
  }

  /// Helper formatting DateTime to Indonesian date string without external dependencies.
  static String _formatIndonesianDate(DateTime dateTime) {
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    final dayName = days[dateTime.weekday - 1];
    final monthName = months[dateTime.month - 1];
    return '$dayName, ${dateTime.day} $monthName ${dateTime.year}';
  }
}

class _ReasonCounter {
  final String reasonCode;
  final String label;
  int count;

  _ReasonCounter({
    required this.reasonCode,
    required this.label,
    required this.count,
  });
}
