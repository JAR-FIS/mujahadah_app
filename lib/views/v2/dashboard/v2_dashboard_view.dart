import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/v2_dashboard_controller.dart';
import '../../../controllers/v2_navigation_controller.dart';
import '../../../core/date/date_service.dart';
import '../../../core/runtime/v2_recipient_name_provider.dart';
import '../../../repositories/achievement_v2_repository.dart';
import '../../../repositories/daily_checkin_v2_repository.dart';
import '../../../repositories/failure_record_v2_repository.dart';
import '../../../repositories/program_v2_repository.dart';
import '../../../services/daily_checkin_v2_service.dart';
import '../../../theme/v2_design_tokens.dart';
import 'widgets/achievement_preview_card.dart';
import 'widgets/active_programs_preview.dart';
import 'widgets/bekal_istiqomah_card.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/dashboard_quick_actions.dart';
import 'widgets/muhasabah_preview_card.dart';
import 'widgets/perjalanan_saya_card.dart';
import 'widgets/prayer_schedule_card.dart';

/// Mujahadah V2 Dashboard (Screen S08).
///
/// Implements the owner-approved Canva S08 mockup layout:
/// - Header with personal greeting, user name snapshot, and date.
/// - Next prayer card with countdown, location, and 5 prayer pills.
/// - Quick action icons (Kiblat, Kalender Mujahadah, Kalender Hijriah, Doa Istiqomah).
/// - "Perjalanan Saya" summary metrics (Aktif, Tercapai, Terhenti).
/// - "Mujahadah Hari Ini" previewing at most 2-3 active programs or approved empty state.
/// - "Muhasabah" interruption insights or empty state.
/// - "Achievement Terbaru" preview or empty state.
/// - "Bekal Istiqomah" Quran quote card with CTA to Dalil.
class V2DashboardView extends StatefulWidget {
  final V2DashboardController? controller;
  final V2NavigationController? navigationController;

  const V2DashboardView({
    super.key,
    this.controller,
    this.navigationController,
  });

  @override
  State<V2DashboardView> createState() => _V2DashboardViewState();
}

class _V2DashboardViewState extends State<V2DashboardView> {
  late V2DashboardController _controller;
  V2NavigationController? _navigationController;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    _navigationController = widget.navigationController ??
        (Get.isRegistered<V2NavigationController>()
            ? Get.find<V2NavigationController>()
            : null);

    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else if (Get.isRegistered<V2DashboardController>()) {
      _controller = Get.find<V2DashboardController>();
      _ownsController = false;
    } else {
      _controller = _createDefaultController();
      _ownsController = true;
    }

    // Trigger initial loading only if not already loaded (e.g. by onInit)
    if (!_controller.hasLoadedInitialData) {
      _controller.loadDashboardData();
    }
  }

  @override
  void didUpdateWidget(V2DashboardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null &&
        widget.controller != oldWidget.controller) {
      if (_ownsController) {
        _controller.onClose();
        _ownsController = false;
      }
      _controller = widget.controller!;
      if (!_controller.hasLoadedInitialData) {
        _controller.loadDashboardData();
      }
    }
  }

  V2DashboardController _createDefaultController() {
    final programRepo = Get.isRegistered<ProgramV2Repository>()
        ? Get.find<ProgramV2Repository>()
        : null;
    final checkInSvc = Get.isRegistered<DailyCheckInV2Service>()
        ? Get.find<DailyCheckInV2Service>()
        : null;
    final checkInRepo = Get.isRegistered<DailyCheckInV2Repository>()
        ? Get.find<DailyCheckInV2Repository>()
        : null;
    final failureRepo = Get.isRegistered<FailureRecordV2Repository>()
        ? Get.find<FailureRecordV2Repository>()
        : null;
    final achievementRepo = Get.isRegistered<AchievementV2Repository>()
        ? Get.find<AchievementV2Repository>()
        : null;
    final dateService = Get.isRegistered<DateService>()
        ? Get.find<DateService>()
        : DateService();
    final recipientProvider = Get.isRegistered<V2RecipientNameProvider>()
        ? Get.find<V2RecipientNameProvider>()
        : null;

    final controller = V2DashboardController(
      programRepository: programRepo,
      dailyCheckInService: checkInSvc,
      checkInRepository: checkInRepo,
      failureRecordRepository: failureRepo,
      achievementRepository: achievementRepo,
      dateService: dateService,
      recipientNameProvider: recipientProvider,
    );
    return controller;
  }

  @override
  void dispose() {
    if (_ownsController) {
      if (Get.isRegistered<V2DashboardController>()) {
        Get.delete<V2DashboardController>();
      } else {
        _controller.dispose();
      }
    }
    super.dispose();
  }

  void _navigateToTab(V2NavigationTab tab) {
    if (_navigationController != null) {
      _navigationController!.selectTab(tab);
    } else if (Get.isRegistered<V2NavigationController>()) {
      Get.find<V2NavigationController>().selectTab(tab);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? V2Colors.darkScaffoldBackground
          : V2Colors.lightScaffoldBackground,
      body: SafeArea(
        top: true,
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _controller.loadDashboardData(),
          color: V2Colors.deepTosca,
          child: Obx(() {
            if (_controller.hasError &&
                _controller.errorMessage != null &&
                _controller.activePrograms.isEmpty) {
              return _buildErrorState(_controller.errorMessage!, isDark);
            }

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Header (Greeting, User name, Date)
                  DashboardHeader(
                    userName: _controller.userName,
                    gregorianDate: _controller.gregorianDateText,
                    hijriDate: _controller.hijriDateText,
                  ),

                  const SizedBox(height: V2Spacing.xs),

                  // 2. Next Prayer Schedule Card
                  PrayerScheduleCard(
                    schedule: _controller.prayerSchedule,
                    onLocationRefresh: () => _controller.loadDashboardData(),
                  ),

                  const SizedBox(height: V2Spacing.md),

                  // 3. Quick Action Icons Grid (Kiblat, Kalender Mujahadah, Kalender Hijriah, Doa)
                  DashboardQuickActions(
                    onKiblatTap:
                        null, // S10 destination not yet implemented in this wave
                    onKalenderMujahadahTap:
                        null, // S12 destination not yet implemented in this wave
                    onKalenderHijriahTap:
                        null, // S11 destination not yet implemented in this wave
                    onDoaIstiqomahTap: () =>
                        _navigateToTab(V2NavigationTab.dalil),
                  ),

                  const SizedBox(height: V2Spacing.sm),

                  // 4. Perjalanan Saya (Aktif, Tercapai, Terhenti)
                  PerjalananSayaSection(
                    activeCount: _controller.activeCount,
                    achievedCount: _controller.achievedCount,
                    stoppedCount: _controller.stoppedCount,
                  ),

                  const SizedBox(height: V2Spacing.sm),

                  // 5. Mujahadah Hari Ini (Active programs preview or empty state)
                  ActiveProgramsPreviewSection(
                    programs: _controller.activePrograms,
                    onViewAllTap: () => _navigateToTab(V2NavigationTab.program),
                    onCreateProgramTap: () =>
                        _navigateToTab(V2NavigationTab.program),
                  ),

                  const SizedBox(height: V2Spacing.sm),

                  // 6. Muhasabah (Interruption reasons or empty state)
                  MuhasabahPreviewSection(
                    reasons: _controller.topFailureReasons,
                    onInsightTap: () => _navigateToTab(V2NavigationTab.history),
                  ),

                  const SizedBox(height: V2Spacing.sm),

                  // 7. Achievement Terbaru (Latest achievement preview or empty state)
                  AchievementPreviewSection(
                    achievement: _controller.latestAchievement,
                    onViewAllTap: () => _navigateToTab(V2NavigationTab.history),
                  ),

                  const SizedBox(height: V2Spacing.sm),

                  // 8. Bekal Istiqomah (Quran quote card with CTA to Dalil)
                  BekalIstiqomahSection(
                    onReadMoreTap: () => _navigateToTab(V2NavigationTab.dalil),
                  ),

                  const SizedBox(height: V2Spacing.lg),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildErrorState(String message, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(V2Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: isDark ? V2Colors.pink : Colors.redAccent,
            ),
            const SizedBox(height: V2Spacing.md),
            Text(
              'Gagal Memuat Dashboard',
              style: V2Typography.headingMedium.copyWith(
                color: isDark
                    ? V2Colors.darkTextPrimary
                    : V2Colors.lightTextPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: V2Spacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: V2Typography.bodyMedium.copyWith(
                color: isDark
                    ? V2Colors.darkTextSecondary
                    : V2Colors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: V2Spacing.lg),
            ElevatedButton(
              onPressed: () => _controller.loadDashboardData(),
              style: ElevatedButton.styleFrom(
                backgroundColor: V2Colors.warmGold,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: V2Radius.borderFull,
                ),
              ),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
