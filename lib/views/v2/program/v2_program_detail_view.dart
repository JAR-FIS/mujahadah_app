import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/date/date_service.dart';
import '../../../models/program_v2_model.dart';
import '../../../repositories/program_v2_repository.dart';
import '../../../services/daily_checkin_v2_service.dart';
import '../../../theme/v2_design_tokens.dart';

/// Screen S21 — Program Detail & Daily Check-in presentation.
///
/// Responsibilities:
/// 1. Authoritative Program Presentation:
///    - Displays ibadah name, target days, lifecycle status, start date, reminder time,
///      and current operational day.
///    - Uses accessible status presentation (label + icon + accent color; never color alone).
/// 2. Authoritative Progress Projection:
///    - Derives completed days strictly from [ProgramProgressSnapshot] / [DailyCheckInV2Service].
///    - Never calculates completed check-ins from elapsed calendar days.
///    - Never fabricates unearned milestones or achievements.
/// 3. Daily Check-in CTA & Pre-Check Confirmation:
///    - Strictly requires explicit confirmation modal before dispatching check-in.
///    - Enforces the 03:00 operational-day boundary via [DateService].
///    - Validates operational day continuity: detects rollover if midnight/03:00 boundary
///      crosses while the confirmation modal is open.
///    - Prevents rapid double-submission during execution.
///    - Displays Indonesian user-safe copy: "Anda sudah menyelesaikan ibadahnya hari ini." on duplicate.
/// 4. Boundary Protection:
///    - When PENDING_FAILURE: Blocks standard check-in and surfaces "Perlu Muhasabah".
///    - When terminal (SUCCESS, FAILED, WARNING): Keeps check-in safely disabled/inaccessible.
///    - When no check-in handler/service is wired: CTA remains fail-closed with honest guidance.
///    - Performs zero direct writes to Hive or domain entities from presentation code.
class V2ProgramDetailView extends StatefulWidget {
  final ProgramV2Model program;
  final VoidCallback onBack;
  final ProgramV2Repository? programRepository;
  final DailyCheckInV2Service? dailyCheckInService;
  final Future<DailyCheckInResult> Function(String programId, bool confirmed)?
      onDailyCheckIn;
  final DateService? dateService;
  final VoidCallback? onProgramUpdated;
  final VoidCallback? onMuhasabahTap;
  final bool? isActiveTab;

  const V2ProgramDetailView({
    super.key,
    required this.program,
    required this.onBack,
    this.programRepository,
    this.dailyCheckInService,
    this.onDailyCheckIn,
    this.dateService,
    this.onProgramUpdated,
    this.onMuhasabahTap,
    this.isActiveTab,
  });

  @override
  State<V2ProgramDetailView> createState() => _V2ProgramDetailViewState();
}

class _V2ProgramDetailViewState extends State<V2ProgramDetailView>
    with WidgetsBindingObserver {
  late ProgramV2Model _program;
  late final DateService _dateService;
  DailyCheckInV2Service? _checkInService;
  ProgramV2Repository? _programRepo;

  ProgramProgressSnapshot? _progressSnapshot;
  String? _snapshotDayKey;
  String? _submittingProgramId;
  int _submissionToken = 0;
  String? _statusNoticeMessage;
  bool _isNoticeError = false;

  int _loadRequestId = 0;
  String? _lastLoadedDayKey;
  Timer? _dayRolloverTimer;

  bool get _isSubmittingCheckIn =>
      _submittingProgramId != null && _submittingProgramId == _program.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _program = widget.program;
    _dateService = widget.dateService ??
        (Get.isRegistered<DateService>()
            ? Get.find<DateService>()
            : DateService());

    _programRepo = widget.programRepository ??
        (Get.isRegistered<ProgramV2Repository>()
            ? Get.find<ProgramV2Repository>()
            : null);

    _checkInService = widget.dailyCheckInService ??
        (Get.isRegistered<DailyCheckInV2Service>()
            ? Get.find<DailyCheckInV2Service>()
            : null);

    _lastLoadedDayKey = _dateService.getTodayDayKey();
    _refreshProgramAndSnapshot();
    _scheduleNextDayRollover();
  }

  @override
  void dispose() {
    _dayRolloverTimer?.cancel();
    _dayRolloverTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshProgramAndSnapshot();
      _scheduleNextDayRollover();
    }
  }

  @override
  void didUpdateWidget(V2ProgramDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.program.id != oldWidget.program.id) {
      _program = widget.program;
      // Clear snapshot immediately to prevent stale cross-program displays
      _progressSnapshot = null;
      _snapshotDayKey = null;
      _statusNoticeMessage = null;
      _isNoticeError = false;
      _refreshProgramAndSnapshot();
      _scheduleNextDayRollover();
    } else if (widget.isActiveTab == true && oldWidget.isActiveTab != true) {
      _refreshProgramAndSnapshot();
      _scheduleNextDayRollover();
    } else if (widget.program.updatedAt != oldWidget.program.updatedAt) {
      _program = widget.program;
      _refreshProgramAndSnapshot();
      _scheduleNextDayRollover();
    }
  }

  /// Schedules a one-shot boundary timer to trigger exactly at the next local
  /// 03:00:00.001 operational-day transition. Automatically cancelled and rescheduled
  /// on resume, widget updates, or upon firing, preventing background battery drain
  /// or redundant periodic polling.
  void _scheduleNextDayRollover() {
    _dayRolloverTimer?.cancel();
    if (!mounted) return;

    final now = _dateService.now;
    final localNow = now.isUtc ? now.toLocal() : now;
    DateTime nextBoundary = DateTime(
      localNow.year,
      localNow.month,
      localNow.day,
      DateService.operationalBoundaryHour,
      0,
      0,
      1,
    );
    if (!localNow.isBefore(nextBoundary)) {
      nextBoundary = DateTime(
        localNow.year,
        localNow.month,
        localNow.day + 1,
        DateService.operationalBoundaryHour,
        0,
        0,
        1,
      );
    }
    var delay = nextBoundary.difference(localNow);
    if (delay <= Duration.zero) {
      delay = const Duration(milliseconds: 100);
    }

    _dayRolloverTimer = Timer(delay, () {
      if (!mounted) return;
      _refreshProgramAndSnapshot();
      _scheduleNextDayRollover();
    });
  }

  /// Refreshes program model and progress snapshot using generation tokens
  /// to eliminate race conditions and ignore out-of-order responses.
  /// Also enforces operational day provenance across the 03:00 boundary.
  Future<void> _refreshProgramAndSnapshot() async {
    final int currentRequestId = ++_loadRequestId;
    final String currentProgramId = _program.id;
    final String? previousLoadedDayKey = _lastLoadedDayKey;
    final String requestDayKey = _dateService.getTodayDayKey();
    final bool isOperationalDayTransition =
        previousLoadedDayKey != null && previousLoadedDayKey != requestDayKey;
    _lastLoadedDayKey = requestDayKey;

    if (isOperationalDayTransition) {
      if (_statusNoticeMessage != null &&
          _statusNoticeMessage!.contains('hari ini')) {
        _statusNoticeMessage = null;
        _isNoticeError = false;
      }
    }

    bool didUpdateState = false;

    // 1. Refresh program model from repository if available
    if (_programRepo != null) {
      try {
        final refreshed = _programRepo!.getById(currentProgramId);
        if (!mounted ||
            currentRequestId != _loadRequestId ||
            currentProgramId != _program.id) {
          return;
        }
        if (refreshed != null && refreshed.status != _program.status) {
          setState(() {
            _program = refreshed;
          });
          didUpdateState = true;
        }
      } catch (_) {
        // Fallback gracefully on repository read errors
      }
    }

    // 2. Refresh progress snapshot from DailyCheckInV2Service if available
    if (_checkInService != null) {
      try {
        final snapshot = await _checkInService!.getProgress(currentProgramId);
        if (!mounted ||
            currentRequestId != _loadRequestId ||
            currentProgramId != _program.id) {
          return;
        }

        // P1-02: Verify operational day boundary did not cross during async fetch
        final completionDayKey = _dateService.getTodayDayKey();
        if (completionDayKey != requestDayKey) {
          // Boundary crossed while await was in flight! Discard snapshot calculated for requestDayKey
          // and re-fetch deterministically for the new day.
          _scheduleNextDayRollover();
          await _refreshProgramAndSnapshot();
          return;
        }

        setState(() {
          _progressSnapshot = snapshot;
          _snapshotDayKey = requestDayKey;
        });
        didUpdateState = true;
      } catch (_) {
        // Fallback gracefully on service read errors
      }
    }

    // 3. Operational-day rollover redraw guarantee (P1):
    // When an actual operational day-key transition occurs and no state update was
    // performed above (e.g. callback-only mode where _checkInService is null),
    // trigger a mounted-aware rebuild so date getters, CTA availability, and check-in
    // state update to the new operational day without requiring user interaction.
    if (isOperationalDayTransition && !didUpdateState) {
      if (mounted &&
          currentRequestId == _loadRequestId &&
          currentProgramId == _program.id) {
        setState(() {});
      }
    }
  }

  /// Formats date string YYYY-MM-DD into Indonesian localized date string.
  String _formatIndonesianDate(String dayKey) {
    if (!DateService.isValidDayKey(dayKey)) {
      return dayKey;
    }
    try {
      final dt = DateService.parseDayKey(dayKey);
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
        'Desember'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return dayKey;
    }
  }

  bool get _isCheckInAvailable {
    return widget.onDailyCheckIn != null || _checkInService != null;
  }

  bool get _isProgramTerminal {
    return _program.status == ProgramV2Model.statusSuccess ||
        _program.status == ProgramV2Model.statusFailed ||
        _program.status == ProgramV2Model.statusWarning;
  }

  bool get _isProgramPendingFailure {
    return _program.status == ProgramV2Model.statusPendingFailure;
  }

  bool get _isAlreadyCheckedInToday {
    if (_snapshotDayKey != null &&
        _snapshotDayKey != _dateService.getTodayDayKey()) {
      return false;
    }
    return _progressSnapshot?.isCompletedToday == true;
  }

  bool get _hasProgramStarted {
    final currentDay = _dateService.getTodayDayKey();
    return _dateService.compareDayKeys(currentDay, _program.startDayKey) >= 0;
  }

  @override
  Widget build(BuildContext context) {
    // Operational-day rollover safety guard (03:00 local boundary)
    final currentDayKey = _dateService.getTodayDayKey();
    if (currentDayKey != _lastLoadedDayKey) {
      _lastLoadedDayKey = currentDayKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _refreshProgramAndSnapshot();
          _scheduleNextDayRollover();
        }
      });
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final scaffoldBg = isDark
        ? V2Colors.darkScaffoldBackground
        : V2Colors.lightScaffoldBackground;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context, isDark),
            Expanded(
              child: SingleChildScrollView(
                key: const ValueKey('v2_program_detail_scroll_view'),
                padding: const EdgeInsets.symmetric(
                  horizontal: V2Spacing.lg,
                  vertical: V2Spacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_statusNoticeMessage != null) ...[
                      _buildNoticeBanner(isDark),
                      const SizedBox(height: V2Spacing.md),
                    ],
                    _buildHeaderCard(isDark),
                    const SizedBox(height: V2Spacing.md),
                    _buildProgressCard(isDark),
                    const SizedBox(height: V2Spacing.md),
                    _buildCheckInSection(context, isDark),
                    const SizedBox(height: V2Spacing.xl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isDark) {
    final textPrimary =
        isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: V2Spacing.md,
        vertical: V2Spacing.sm,
      ),
      child: Row(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Semantics(
              label: 'Kembali ke Program Hub',
              button: true,
              child: IconButton(
                key: const ValueKey('v2_program_detail_back_button'),
                icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
                onPressed: widget.onBack,
              ),
            ),
          ),
          const SizedBox(width: V2Spacing.xs),
          Expanded(
            child: Text(
              'Detail Program',
              style: V2Typography.headingMedium.copyWith(
                color: textPrimary,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeBanner(bool isDark) {
    final bgColor = _isNoticeError
        ? (isDark
            ? Colors.red.withValues(alpha: 0.2)
            : Colors.red.withValues(alpha: 0.1))
        : (isDark
            ? V2Colors.mint.withValues(alpha: 0.2)
            : V2Colors.mint.withValues(alpha: 0.15));

    final textColor = _isNoticeError
        ? (isDark ? const Color(0xFFFF8A80) : Colors.red.shade900)
        : (isDark ? V2Colors.mint : V2Colors.deepTosca);

    final icon = _isNoticeError
        ? Icons.error_outline_rounded
        : Icons.check_circle_outline_rounded;

    return Container(
      key: const ValueKey('v2_program_detail_notice_banner'),
      padding: const EdgeInsets.all(V2Spacing.md),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: V2Radius.borderMd,
        border: Border.all(color: textColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: textColor),
          const SizedBox(width: V2Spacing.sm),
          Expanded(
            child: Text(
              _statusNoticeMessage ?? '',
              style: V2Typography.bodyMedium.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(Icons.close_rounded, size: 18, color: textColor),
            onPressed: () {
              setState(() {
                _statusNoticeMessage = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(bool isDark) {
    final cardBg =
        isDark ? V2Colors.darkSurfaceCard : V2Colors.lightSurfaceCard;
    final borderColor = isDark ? V2Colors.darkBorder : V2Colors.lightBorder;
    final textPrimary =
        isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary;
    final textSecondary =
        isDark ? V2Colors.darkTextSecondary : V2Colors.lightTextSecondary;

    final currentOpDay = _dateService.getTodayDayKey();

    return Container(
      key: const ValueKey('v2_program_detail_header_card'),
      padding: const EdgeInsets.all(V2Spacing.lg),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: V2Radius.borderLg,
        border: Border.all(color: borderColor),
        boxShadow: isDark ? V2Elevation.darkSubtle : V2Elevation.lightSubtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _program.ibadahNameSnapshot,
                  style: V2Typography.headingMedium.copyWith(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: V2Spacing.sm),
              _buildStatusBadge(_program.status, isDark),
            ],
          ),
          const SizedBox(height: V2Spacing.md),
          const Divider(height: 1),
          const SizedBox(height: V2Spacing.md),
          _buildDetailRow(
            icon: Icons.flag_outlined,
            label: 'Target Durasi',
            value: '${_program.targetDays} Hari Berturut-turut',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: V2Spacing.xs),
          _buildDetailRow(
            icon: Icons.calendar_month_outlined,
            label: 'Mulai Program',
            value: _formatIndonesianDate(_program.startDayKey),
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: V2Spacing.xs),
          _buildDetailRow(
            icon: Icons.notifications_none_rounded,
            label: 'Pengingat Harian',
            value: _program.reminderTime != null
                ? 'Pukul ${_program.reminderTime}'
                : 'Tidak aktif',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: V2Spacing.xs),
          _buildDetailRow(
            icon: Icons.access_time_rounded,
            label: 'Hari Operasional',
            value: '${_formatIndonesianDate(currentOpDay)} (Batas 03:00)',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isDark) {
    final (String label, IconData icon, Color bg, Color textColor) =
        switch (status) {
      ProgramV2Model.statusActive => (
          'Aktif',
          Icons.check_circle_outline_rounded,
          isDark
              ? V2Colors.mint.withValues(alpha: 0.2)
              : V2Colors.mint.withValues(alpha: 0.35),
          isDark ? V2Colors.mint : V2Colors.deepTosca,
        ),
      ProgramV2Model.statusPendingFailure => (
          'Perlu Muhasabah',
          Icons.warning_amber_rounded,
          isDark
              ? V2Colors.peach.withValues(alpha: 0.2)
              : V2Colors.peach.withValues(alpha: 0.25),
          isDark ? V2Colors.peach : const Color(0xFF8A5B00),
        ),
      ProgramV2Model.statusSuccess => (
          'Tercapai',
          Icons.emoji_events_outlined,
          isDark
              ? V2Colors.warmGold.withValues(alpha: 0.2)
              : V2Colors.warmGold.withValues(alpha: 0.25),
          isDark ? V2Colors.warmGold : const Color(0xFF8A5B00),
        ),
      ProgramV2Model.statusFailed => (
          'Terhenti',
          Icons.cancel_outlined,
          isDark
              ? Colors.red.withValues(alpha: 0.2)
              : Colors.red.withValues(alpha: 0.15),
          isDark ? const Color(0xFFFF8A80) : Colors.red.shade800,
        ),
      ProgramV2Model.statusWarning => (
          'Peringatan',
          Icons.info_outline_rounded,
          isDark
              ? V2Colors.peach.withValues(alpha: 0.2)
              : V2Colors.peach.withValues(alpha: 0.25),
          isDark ? V2Colors.peach : const Color(0xFF8A5B00),
        ),
      _ => (
          status,
          Icons.help_outline_rounded,
          isDark ? Colors.grey.withValues(alpha: 0.2) : Colors.grey.shade200,
          isDark ? Colors.grey : Colors.grey.shade800,
        ),
    };

    return Semantics(
      label: 'Status program: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: V2Radius.borderSm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Icon(icon, size: 16, color: textSecondary),
          ),
          const SizedBox(width: V2Spacing.xs),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '$label: ',
                  style: V2Typography.bodyMedium.copyWith(
                    color: textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: V2Typography.bodyMedium.copyWith(
                    color: textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(bool isDark) {
    final cardBg =
        isDark ? V2Colors.darkSurfaceCard : V2Colors.lightSurfaceCard;
    final borderColor = isDark ? V2Colors.darkBorder : V2Colors.lightBorder;
    final textPrimary =
        isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary;
    final textSecondary =
        isDark ? V2Colors.darkTextSecondary : V2Colors.lightTextSecondary;

    final snapshot = _progressSnapshot;
    if (snapshot == null) {
      return Container(
        key: const ValueKey('v2_program_detail_progress_card'),
        padding: const EdgeInsets.all(V2Spacing.lg),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: V2Radius.borderLg,
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progres Mujahadah',
              style: V2Typography.bodyLarge.copyWith(
                color: textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: V2Spacing.sm),
            Text(
              'Informasi catatan check-in belum tersedia atau layanan sedang tidak aktif.',
              style: V2Typography.bodyMedium.copyWith(
                color: textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final completed = snapshot.completedDays;
    final target = snapshot.targetDays;
    final remaining = snapshot.remainingDays;
    final progressFraction =
        target > 0 ? (completed / target).clamp(0.0, 1.0) : 0.0;
    final progressPercent = (progressFraction * 100).toInt();

    return Container(
      key: const ValueKey('v2_program_detail_progress_card'),
      padding: const EdgeInsets.all(V2Spacing.lg),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: V2Radius.borderLg,
        border: Border.all(color: borderColor),
        boxShadow: isDark ? V2Elevation.darkSubtle : V2Elevation.lightSubtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progres Mujahadah',
                style: V2Typography.bodyLarge.copyWith(
                  color: textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '$progressPercent%',
                style: V2Typography.headingMedium.copyWith(
                  color: isDark ? V2Colors.mint : V2Colors.deepTosca,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: V2Spacing.xs),
          Text(
            '$completed dari $target Hari Selesai',
            style: V2Typography.bodyMedium.copyWith(
              color: textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: V2Spacing.sm),
          ClipRRect(
            borderRadius: V2Radius.borderFull,
            child: LinearProgressIndicator(
              key: const ValueKey('v2_program_detail_progress_bar'),
              value: progressFraction,
              minHeight: 10,
              backgroundColor:
                  isDark ? V2Colors.darkSurfaceElevated : V2Colors.lightBorder,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? V2Colors.mint : V2Colors.deepTosca,
              ),
            ),
          ),
          const SizedBox(height: V2Spacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sisa $remaining hari lagi',
                style: V2Typography.bodySmall.copyWith(
                  color: textSecondary,
                ),
              ),
              if (_program.status == ProgramV2Model.statusSuccess)
                Row(
                  children: [
                    const Icon(
                      Icons.emoji_events_rounded,
                      size: 16,
                      color: V2Colors.warmGold,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Target Tercapai!',
                      style: V2Typography.bodySmall.copyWith(
                        color: V2Colors.warmGold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: V2Spacing.md),
          const Divider(height: 1),
          const SizedBox(height: V2Spacing.md),
          Text(
            'Milestone Capaian',
            style: V2Typography.bodyMedium.copyWith(
              color: textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: V2Spacing.sm),
          _buildMilestoneTimeline(completed, target, isDark),
        ],
      ),
    );
  }

  Widget _buildMilestoneTimeline(
      int completedDays, int targetDays, bool isDark) {
    const defaultMilestones = [40, 60, 90, 100];
    final visibleMilestones =
        defaultMilestones.where((m) => m <= targetDays).toList();
    if (!visibleMilestones.contains(targetDays) && targetDays >= 40) {
      visibleMilestones.add(targetDays);
      visibleMilestones.sort();
    }

    if (visibleMilestones.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: visibleMilestones.map((milestone) {
        final isReached = completedDays >= milestone;
        final iconColor = isReached
            ? (isDark ? V2Colors.mint : V2Colors.deepTosca)
            : (isDark
                ? V2Colors.darkTextSecondary
                : V2Colors.lightTextSecondary);
        final bgColor = isReached
            ? (isDark
                ? V2Colors.mint.withValues(alpha: 0.2)
                : V2Colors.mint.withValues(alpha: 0.25))
            : (isDark ? V2Colors.darkSurfaceElevated : V2Colors.lightGray);

        return Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isReached ? iconColor : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Icon(
                isReached ? Icons.check_rounded : Icons.lock_outline_rounded,
                size: 18,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$milestone Hari',
              style: TextStyle(
                fontSize: 10,
                fontWeight: isReached ? FontWeight.w700 : FontWeight.w500,
                color: isReached
                    ? (isDark ? V2Colors.mint : V2Colors.deepTosca)
                    : (isDark
                        ? V2Colors.darkTextSecondary
                        : V2Colors.lightTextSecondary),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildCheckInSection(BuildContext context, bool isDark) {
    // 1. Terminal Program handling (SUCCESS, FAILED, WARNING)
    if (_isProgramTerminal) {
      return _buildTerminalCard(isDark);
    }

    // 2. Pending Muhasabah handling
    if (_isProgramPendingFailure) {
      return _buildMuhasabahCard(context, isDark);
    }

    // 3. Active Program handling
    return _buildActiveCheckInCard(context, isDark);
  }

  Widget _buildTerminalCard(bool isDark) {
    final cardBg =
        isDark ? V2Colors.darkSurfaceCard : V2Colors.lightSurfaceCard;
    final borderColor = isDark ? V2Colors.darkBorder : V2Colors.lightBorder;
    final textPrimary =
        isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary;
    final textSecondary =
        isDark ? V2Colors.darkTextSecondary : V2Colors.lightTextSecondary;

    final String message;
    final IconData icon;
    final Color iconColor;

    if (_program.status == ProgramV2Model.statusSuccess) {
      message =
          'Program ini telah berhasil diselesaikan hingga hari terakhir. Alhamdulillah!';
      icon = Icons.emoji_events_rounded;
      iconColor = V2Colors.warmGold;
    } else {
      message =
          'Program ini telah berakhir dalam catatan riwayat dan tidak menerima check-in harian lagi.';
      icon = Icons.info_outline_rounded;
      iconColor = textSecondary;
    }

    return Container(
      key: const ValueKey('v2_program_detail_terminal_banner'),
      padding: const EdgeInsets.all(V2Spacing.lg),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: V2Radius.borderLg,
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: iconColor),
          const SizedBox(width: V2Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Program Telah Berakhir',
                  style: V2Typography.bodyLarge.copyWith(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: V2Typography.bodyMedium.copyWith(
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMuhasabahCard(BuildContext context, bool isDark) {
    final cardBg = isDark
        ? V2Colors.peach.withValues(alpha: 0.15)
        : V2Colors.peach.withValues(alpha: 0.2);
    final borderColor =
        isDark ? V2Colors.peach.withValues(alpha: 0.4) : V2Colors.peach;
    final textPrimary =
        isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary;
    final textPeach = isDark ? V2Colors.peach : const Color(0xFF8A5B00);

    return Container(
      key: const ValueKey('v2_program_detail_muhasabah_banner'),
      padding: const EdgeInsets.all(V2Spacing.lg),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: V2Radius.borderLg,
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 24, color: textPeach),
              const SizedBox(width: V2Spacing.sm),
              Expanded(
                child: Text(
                  'Perlu Muhasabah',
                  style: V2Typography.bodyLarge.copyWith(
                    color: textPeach,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: V2Spacing.sm),
          Text(
            'Terdapat hari ibadah yang terlewat pada program ini. Check-in harian ditangguhkan sampai proses muhasabah diselesaikan.',
            style: V2Typography.bodyMedium.copyWith(
              color: textPrimary,
            ),
          ),
          const SizedBox(height: V2Spacing.md),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              key: const ValueKey('v2_program_detail_muhasabah_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: V2Colors.warmGold,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: V2Radius.borderMd,
                ),
              ),
              icon: const Icon(Icons.self_improvement_rounded),
              label: const Text(
                'Mulai Muhasabah',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              onPressed: () {
                if (widget.onMuhasabahTap != null) {
                  widget.onMuhasabahTap!();
                } else {
                  _showMuhasabahNoticeDialog(context, isDark);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showMuhasabahNoticeDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Muhasabah Diperlukan'),
        content: const Text(
          'Fitur Muhasabah (S22) sedang dalam tahap integrasi. Check-in harian tetap ditangguhkan secara aman hingga proses muhasabah diselesaikan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCheckInCard(BuildContext context, bool isDark) {
    final cardBg =
        isDark ? V2Colors.darkSurfaceCard : V2Colors.lightSurfaceCard;
    final borderColor = isDark ? V2Colors.darkBorder : V2Colors.lightBorder;
    final textPrimary =
        isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary;
    final textSecondary =
        isDark ? V2Colors.darkTextSecondary : V2Colors.lightTextSecondary;

    final isCompletedToday = _isAlreadyCheckedInToday;
    final hasStarted = _hasProgramStarted;

    return Container(
      key: const ValueKey('v2_program_detail_checkin_section'),
      padding: const EdgeInsets.all(V2Spacing.lg),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: V2Radius.borderLg,
        border: Border.all(color: borderColor),
        boxShadow: isDark ? V2Elevation.darkSubtle : V2Elevation.lightSubtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Check-in Harian',
            style: V2Typography.bodyLarge.copyWith(
              color: textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: V2Spacing.sm),
          if (isCompletedToday) ...[
            Container(
              key: const ValueKey('v2_program_detail_already_checked_card'),
              padding: const EdgeInsets.all(V2Spacing.md),
              decoration: BoxDecoration(
                color: isDark
                    ? V2Colors.mint.withValues(alpha: 0.15)
                    : V2Colors.mint.withValues(alpha: 0.25),
                borderRadius: V2Radius.borderMd,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 22,
                    color: isDark ? V2Colors.mint : V2Colors.deepTosca,
                  ),
                  const SizedBox(width: V2Spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sudah Check-in Hari Ini',
                          style: V2Typography.bodyMedium.copyWith(
                            color: isDark ? V2Colors.mint : V2Colors.deepTosca,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Alhamdulillah! Amalan hari ini telah tercatat untuk hari operasional ${_dateService.getTodayDayKey()}.',
                          style: V2Typography.bodySmall.copyWith(
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: V2Spacing.md),
          ],
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              key: const ValueKey('v2_program_detail_checkin_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: V2Colors.deepTosca,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                disabledForegroundColor:
                    isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: V2Radius.borderMd,
                ),
              ),
              onPressed: (!isCompletedToday &&
                      hasStarted &&
                      _isCheckInAvailable &&
                      !_isSubmittingCheckIn)
                  ? () => _showCheckInConfirmationDialog(context)
                  : null,
              child: _isSubmittingCheckIn
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      isCompletedToday
                          ? 'Ibadah Hari Ini Selesai'
                          : (!hasStarted
                              ? 'Program Belum Dimulai'
                              : 'Check-in Ibadah Hari Ini'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
          const SizedBox(height: V2Spacing.xs),
          Text(
            isCompletedToday
                ? 'Anda sudah menyelesaikan ibadahnya hari ini.'
                : (!hasStarted
                    ? 'Program baru akan dimulai pada ${_formatIndonesianDate(_program.startDayKey)}.'
                    : (!_isCheckInAvailable
                        ? 'Layanan check-in belum tersedia.'
                        : 'Batas waktu check-in hari ini hingga pukul 03:00.')),
            textAlign: TextAlign.center,
            style: V2Typography.bodySmall.copyWith(
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Displays the mandatory check-in confirmation modal with 03:00 date snapshot protection.
  Future<void> _showCheckInConfirmationDialog(BuildContext context) async {
    final dialogOpenedDayKey = _dateService.getTodayDayKey();
    final String activeProgramId = _program.id;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        final textPrimary =
            isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary;
        final textSecondary =
            isDark ? V2Colors.darkTextSecondary : V2Colors.lightTextSecondary;

        return AlertDialog(
          key: const ValueKey('v2_checkin_confirmation_dialog'),
          title: Text(
            'Konfirmasi Check-in',
            style: V2Typography.headingSmall.copyWith(
              color: textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Apakah Anda telah menyelesaikan ibadah ${_program.ibadahNameSnapshot} untuk hari ini?',
                style: V2Typography.bodyMedium.copyWith(color: textPrimary),
              ),
              const SizedBox(height: V2Spacing.md),
              Container(
                padding: const EdgeInsets.all(V2Spacing.sm),
                decoration: BoxDecoration(
                  color: isDark
                      ? V2Colors.darkSurfaceElevated
                      : V2Colors.lightGray,
                  borderRadius: V2Radius.borderSm,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 16,
                      color: isDark ? V2Colors.peach : V2Colors.warmGold,
                    ),
                    const SizedBox(width: V2Spacing.xs),
                    Expanded(
                      child: Text(
                        'Hari operasional: ${_formatIndonesianDate(dialogOpenedDayKey)} (batas 03:00)',
                        style: V2Typography.bodySmall.copyWith(
                          color: textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              key: const ValueKey('v2_checkin_cancel_button'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              key: const ValueKey('v2_checkin_confirm_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: V2Colors.deepTosca,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Ya, Sudah Selesai'),
            ),
          ],
        );
      },
    );

    if (!mounted || activeProgramId != _program.id) return;

    // Cancelled: zero writes, zero dispatches
    if (confirmed != true) {
      return;
    }

    // 03:00 Operational-Day Rollover Guard:
    // If the operational boundary crossed while the modal was open, reject submission!
    final submitDayKey = _dateService.getTodayDayKey();
    if (submitDayKey != dialogOpenedDayKey) {
      if (mounted && activeProgramId == _program.id) {
        setState(() {
          _isNoticeError = true;
          _statusNoticeMessage =
              'Hari operasional telah berganti melewati batas pukul 03:00. Silakan periksa kembali dan lakukan konfirmasi ulang.';
        });
      }
      return;
    }

    // Execute check-in submission
    await _dispatchCheckIn(submitDayKey);
  }

  Future<void> _dispatchCheckIn(String validatedDayKey) async {
    final String activeProgramId = _program.id;
    if (_isSubmittingCheckIn) return;

    // Enforce validatedDayKey matches current operational day at dispatch time
    final currentDayKey = _dateService.getTodayDayKey();
    if (validatedDayKey != currentDayKey) {
      if (mounted && activeProgramId == _program.id) {
        setState(() {
          _isNoticeError = true;
          _statusNoticeMessage =
              'Hari operasional telah berganti melewati batas pukul 03:00. Silakan periksa kembali dan lakukan konfirmasi ulang.';
        });
      }
      return;
    }

    final int currentSubmissionToken = ++_submissionToken;
    if (mounted && activeProgramId == _program.id) {
      setState(() {
        _submittingProgramId = activeProgramId;
        _statusNoticeMessage = null;
      });
    }

    try {
      final DailyCheckInResult result;
      if (widget.onDailyCheckIn != null) {
        result = await widget.onDailyCheckIn!(activeProgramId, true);
      } else if (_checkInService != null) {
        result = await _checkInService!.checkIn(
          programId: activeProgramId,
          confirmedByUser: true,
        );
      } else {
        if (mounted &&
            activeProgramId == _program.id &&
            currentSubmissionToken == _submissionToken) {
          setState(() {
            _isNoticeError = true;
            _statusNoticeMessage = 'Layanan check-in belum tersedia.';
          });
        }
        return;
      }

      if (!mounted ||
          activeProgramId != _program.id ||
          currentSubmissionToken != _submissionToken) {
        return;
      }

      final String authoritativeDayKey =
          result.checkIn?.dayKey ?? validatedDayKey;
      final String nowDayKey = _dateService.getTodayDayKey();

      if (result.isSuccess) {
        // Refresh local program from repo if available
        if (_programRepo != null) {
          final refreshed = _programRepo!.getById(activeProgramId);
          if (!mounted ||
              activeProgramId != _program.id ||
              currentSubmissionToken != _submissionToken) {
            return;
          }
          if (refreshed != null) {
            _program = refreshed;
          }
        }

        if (mounted &&
            activeProgramId == _program.id &&
            currentSubmissionToken == _submissionToken) {
          setState(() {
            _isNoticeError = false;
            // PRODUCT GUARD: Do NOT claim final completion/success simply because targetReached is true.
            // Orchestrator handles finalization into ProgramStatus.SUCCESS.
            if (nowDayKey == authoritativeDayKey) {
              _statusNoticeMessage =
                  'Alhamdulillah! Check-in hari ini berhasil dicatat.';
              if (result.progress != null) {
                _progressSnapshot = result.progress;
                _snapshotDayKey = authoritativeDayKey;
              }
            } else {
              // Operational boundary crossed while operation was in flight.
              // Mark the check-in provenance to authoritativeDayKey (yesterday),
              // leaving today's check-in open and un-checked-in.
              _statusNoticeMessage =
                  'Alhamdulillah! Check-in untuk hari ${_formatIndonesianDate(authoritativeDayKey)} berhasil dicatat.';
              _snapshotDayKey = authoritativeDayKey;
            }
          });
        }

        // Trigger external program update callback
        if (mounted &&
            activeProgramId == _program.id &&
            currentSubmissionToken == _submissionToken) {
          widget.onProgramUpdated?.call();
        }

        // Reload progress asynchronously to ensure exact storage alignment
        if (mounted &&
            activeProgramId == _program.id &&
            currentSubmissionToken == _submissionToken) {
          await _refreshProgramAndSnapshot();
        }
      } else {
        if (!mounted ||
            activeProgramId != _program.id ||
            currentSubmissionToken != _submissionToken) {
          return;
        }

        // Handle failure safely with friendly Indonesian copy
        final userMessage = switch (result.failureReason) {
          DailyCheckInFailureReason.alreadyCheckedIn =>
            'Anda sudah menyelesaikan ibadahnya hari ini.',
          DailyCheckInFailureReason.requiresMuhasabah =>
            'Terdapat hari ibadah yang terlewat. Program memerlukan muhasabah.',
          DailyCheckInFailureReason.programNotActive =>
            'Program tidak lagi berstatus aktif.',
          DailyCheckInFailureReason.programNotStarted =>
            'Program belum dimulai.',
          DailyCheckInFailureReason.targetAlreadyReached =>
            'Target durasi program sudah tercapai sepenuhnya.',
          DailyCheckInFailureReason.persistenceError =>
            'Gagal menyimpan check-in ke penyimpanan. Silakan coba lagi.',
          DailyCheckInFailureReason.dataIntegrityError =>
            'Terjadi ketidaksesuaian data check-in pada program.',
          _ => result.errorMessage ??
              'Gagal melakukan check-in. Silakan coba lagi.',
        };

        if (mounted &&
            activeProgramId == _program.id &&
            currentSubmissionToken == _submissionToken) {
          setState(() {
            _isNoticeError = true;
            _statusNoticeMessage = userMessage;
          });
        }

        if (mounted &&
            activeProgramId == _program.id &&
            currentSubmissionToken == _submissionToken) {
          await _refreshProgramAndSnapshot();
        }
      }
    } catch (_) {
      if (mounted &&
          activeProgramId == _program.id &&
          currentSubmissionToken == _submissionToken) {
        setState(() {
          _isNoticeError = true;
          _statusNoticeMessage =
              'Terjadi kesalahan sistem saat memproses check-in.';
        });
      }
    } finally {
      // P2-01: Scoped cleanup - only clear if originating program and token still match
      if (mounted &&
          _submittingProgramId == activeProgramId &&
          currentSubmissionToken == _submissionToken) {
        setState(() {
          _submittingProgramId = null;
        });
      }
    }
  }
}
