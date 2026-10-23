import 'package:flutter/material.dart';

import '../../../core/date/date_service.dart';
import '../../../models/failure_record_model.dart';
import '../../../models/program_v2_model.dart';
import '../../../services/daily_checkin_v2_service.dart';
import '../../../theme/v2_design_tokens.dart';

/// Read-only Detail Screen for a terminal Mujahadah program.
///
/// Features:
/// - Full historical summary (Title, Target, Completed Days, Start & End dates).
/// - Exact Muhasabah failure record evaluation snapshot for FAILED and WARNING journeys.
/// - Restart link indicator when the journey was itself restarted from a prior program.
/// - Gated "Mulai Lagi" action allowing the user to initiate a new journey via S20.
class V2HistoryDetailView extends StatelessWidget {
  final ProgramV2Model program;
  final ProgramProgressSnapshot? progress;
  final FailureRecordModel? failureRecord;
  final VoidCallback onBack;
  final ValueChanged<ProgramV2Model>? onRestartTap;

  const V2HistoryDetailView({
    super.key,
    required this.program,
    this.progress,
    this.failureRecord,
    required this.onBack,
    this.onRestartTap,
  });

  String _formatDayKeyIndonesian(String dayKey) {
    try {
      final dt = DateService.parseDayKey(dayKey);
      return _formatDateTimeIndonesian(dt);
    } catch (_) {
      return dayKey;
    }
  }

  String _formatDateTimeIndonesian(DateTime dt) {
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final scaffoldBg = isDark
        ? V2Colors.darkScaffoldBackground
        : V2Colors.lightScaffoldBackground;
    final surfaceCard =
        isDark ? V2Colors.darkSurfaceCard : V2Colors.lightSurfaceCard;
    final borderColor = isDark ? V2Colors.darkBorder : V2Colors.lightBorder;
    final textPrimary =
        isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary;
    final textSecondary =
        isDark ? V2Colors.darkTextSecondary : V2Colors.lightTextSecondary;

    final statusStyle = _resolveStatusStyle(isDark);
    final completionDate = program.finalizedAt ?? program.updatedAt;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(context, isDark, textPrimary),

            // Scrollable Details
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: V2Spacing.lg,
                  vertical: V2Spacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Card with Title and Status Badge
                    _buildHeaderCard(
                      isDark: isDark,
                      surfaceCard: surfaceCard,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      statusStyle: statusStyle,
                    ),
                    const SizedBox(height: V2Spacing.lg),

                    // Program Details Breakdown Card
                    _buildJourneyCard(
                      isDark: isDark,
                      surfaceCard: surfaceCard,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      completionDate: completionDate,
                    ),
                    const SizedBox(height: V2Spacing.lg),

                    // Muhasabah Record Card (for FAILED / WARNING)
                    if (program.status == ProgramV2Model.statusFailed ||
                        program.status == ProgramV2Model.statusWarning) ...[
                      _buildMuhasabahCard(
                        isDark: isDark,
                        surfaceCard: surfaceCard,
                        borderColor: borderColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                      const SizedBox(height: V2Spacing.lg),
                    ],

                    // Genealogy Link Card (if restarted from an earlier program)
                    if (program.restartedFromProgramId != null) ...[
                      _buildRestartOriginCard(
                        isDark: isDark,
                        surfaceCard: surfaceCard,
                        borderColor: borderColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                      const SizedBox(height: V2Spacing.lg),
                    ],

                    const SizedBox(height: V2Spacing.xl),
                  ],
                ),
              ),
            ),

            // Bottom Action Bar: Mulai Lagi CTA
            _buildBottomActionBar(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isDark, Color textPrimary) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: V2Spacing.md,
        vertical: V2Spacing.sm,
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Kembali ke Daftar Riwayat',
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: IconButton(
                key: const ValueKey('v2_history_detail_back_button'),
                icon: const Icon(Icons.arrow_back),
                color: textPrimary,
                onPressed: onBack,
                tooltip: 'Kembali',
              ),
            ),
          ),
          const SizedBox(width: V2Spacing.xs),
          Expanded(
            child: Text(
              'Detail Riwayat',
              key: const ValueKey('v2_history_detail_title'),
              style: V2Typography.headingLarge.copyWith(
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

  Widget _buildHeaderCard({
    required bool isDark,
    required Color surfaceCard,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required _DetailStatusStyle statusStyle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(V2Spacing.lg),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: V2Radius.borderLg,
        border: Border.all(color: borderColor),
        boxShadow: isDark ? V2Elevation.darkSubtle : V2Elevation.lightSubtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Badge
          Container(
            key: const ValueKey('v2_history_detail_status'),
            padding: const EdgeInsets.symmetric(
              horizontal: V2Spacing.md,
              vertical: V2Spacing.xs,
            ),
            decoration: BoxDecoration(
              color: statusStyle.backgroundColor,
              borderRadius: V2Radius.borderFull,
              border: Border.all(color: statusStyle.borderColor, width: 1.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  statusStyle.icon,
                  size: 16,
                  color: statusStyle.foregroundColor,
                ),
                const SizedBox(width: V2Spacing.xs),
                Text(
                  statusStyle.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: statusStyle.foregroundColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: V2Spacing.md),

          // Title
          Text(
            program.ibadahNameSnapshot,
            key: const ValueKey('v2_history_detail_name'),
            style: V2Typography.headingLarge.copyWith(
              color: textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyCard({
    required bool isDark,
    required Color surfaceCard,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required DateTime completionDate,
  }) {
    final completedDaysText = progress != null
        ? '${progress!.completedDays} Hari Berturut-turut'
        : 'Informasi belum tersedia';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(V2Spacing.lg),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: V2Radius.borderLg,
        border: Border.all(color: borderColor),
        boxShadow: isDark ? V2Elevation.darkSubtle : V2Elevation.lightSubtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rincian Perjalanan',
            style: V2Typography.headingMedium.copyWith(
              color: textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: V2Spacing.md),

          // Target Days
          _buildDetailRow(
            label: 'Target Durasi',
            value: '${program.targetDays} Hari',
            valueKey: 'v2_history_detail_target',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            highlightColor: isDark ? V2Colors.peach : V2Colors.warmGold,
          ),
          const Divider(height: V2Spacing.lg),

          // Completed Days
          _buildDetailRow(
            label: 'Hari Selesai',
            value: completedDaysText,
            valueKey: 'v2_history_detail_progress',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            isEmphasized: true,
          ),
          const Divider(height: V2Spacing.lg),

          // Start Date
          _buildDetailRow(
            label: 'Tanggal Mulai',
            value: _formatDayKeyIndonesian(program.startDayKey),
            valueKey: 'v2_history_detail_start_date',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const Divider(height: V2Spacing.lg),

          // End Date
          _buildDetailRow(
            label: 'Tanggal Berakhir',
            value: _formatDateTimeIndonesian(completionDate),
            valueKey: 'v2_history_detail_end_date',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const Divider(height: V2Spacing.lg),

          // Reminder Setting
          _buildDetailRow(
            label: 'Pengingat Harian',
            value: program.reminderTime != null
                ? 'Pukul ${program.reminderTime}'
                : 'Tidak Diaktifkan',
            valueKey: 'v2_history_detail_reminder',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildMuhasabahCard({
    required bool isDark,
    required Color surfaceCard,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final reasonSnapshot = failureRecord?.reasonLabelSnapshot;
    final hasReason =
        reasonSnapshot != null && reasonSnapshot.trim().isNotEmpty;
    final note = failureRecord?.note;
    final hasNote = note != null && note.trim().isNotEmpty;

    final missedDateText = program.pendingMissedDayKey != null &&
            program.pendingMissedDayKey!.isNotEmpty
        ? _formatDayKeyIndonesian(program.pendingMissedDayKey!)
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(V2Spacing.lg),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: V2Radius.borderLg,
        border: Border.all(color: borderColor),
        boxShadow: isDark ? V2Elevation.darkSubtle : V2Elevation.lightSubtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology_outlined,
                size: 20,
                color: isDark ? V2Colors.peach : V2Colors.warmGold,
              ),
              const SizedBox(width: V2Spacing.xs),
              Expanded(
                child: Text(
                  'Catatan Evaluasi / Muhasabah',
                  style: V2Typography.headingMedium.copyWith(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: V2Spacing.md),

          // Missed Day Key (if recorded)
          if (missedDateText != null) ...[
            _buildDetailRow(
              label: 'Hari Terkendala',
              value: missedDateText,
              valueKey: 'v2_history_detail_missed_date',
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            const Divider(height: V2Spacing.lg),
          ],

          // Reason Snapshot
          _buildDetailRow(
            label: 'Alasan Terkendala',
            value: hasReason ? reasonSnapshot : 'Catatan alasan tidak tersedia',
            valueKey: 'v2_history_detail_reason',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            isEmphasized: true,
          ),

          // Optional Private Note
          if (hasNote) ...[
            const Divider(height: V2Spacing.lg),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Catatan Pribadi',
                  style: TextStyle(
                    fontSize: 13,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(V2Spacing.sm),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: V2Radius.borderSm,
                  ),
                  child: Text(
                    note,
                    key: const ValueKey('v2_history_detail_note'),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: textPrimary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRestartOriginCard({
    required bool isDark,
    required Color surfaceCard,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(V2Spacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? V2Colors.mint.withValues(alpha: 0.1)
            : V2Colors.deepTosca.withValues(alpha: 0.06),
        borderRadius: V2Radius.borderMd,
        border: Border.all(
          color: isDark
              ? V2Colors.mint.withValues(alpha: 0.25)
              : V2Colors.deepTosca.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.history_edu_rounded,
            size: 20,
            color: isDark ? V2Colors.mint : V2Colors.deepTosca,
          ),
          const SizedBox(width: V2Spacing.sm),
          Expanded(
            child: Text(
              'Program ini merupakan perjalanan baru yang dimulai ulang dari riwayat program sebelumnya. Riwayat awal tetap terjaga.',
              key: const ValueKey('v2_history_detail_restart_origin'),
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: isDark ? V2Colors.mint : V2Colors.deepTosca,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    required String valueKey,
    required Color textPrimary,
    required Color textSecondary,
    Color? highlightColor,
    bool isEmphasized = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 110, maxWidth: 130),
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            key: ValueKey(valueKey),
            style: TextStyle(
              fontSize: 14,
              fontWeight: isEmphasized ? FontWeight.w700 : FontWeight.w600,
              color: highlightColor ?? textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionBar(BuildContext context, bool isDark) {
    final bottomBarBg = isDark ? V2Colors.darkSurface : V2Colors.lightSurface;
    final topBorderColor = isDark ? V2Colors.darkBorder : V2Colors.lightBorder;

    return Container(
      padding: const EdgeInsets.all(V2Spacing.lg),
      decoration: BoxDecoration(
        color: bottomBarBg,
        border: Border(
          top: BorderSide(color: topBorderColor, width: 1.0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const ValueKey('v2_history_detail_restart_button'),
              onPressed:
                  onRestartTap != null ? () => onRestartTap!(program) : null,
              icon: const Icon(Icons.replay_rounded, size: 20),
              label: const Text(
                'Mulai Lagi Program Ini',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: V2Colors.warmGold,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: V2Radius.borderFull,
                ),
                padding: const EdgeInsets.symmetric(vertical: V2Spacing.md),
                elevation: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  _DetailStatusStyle _resolveStatusStyle(bool isDark) {
    switch (program.status) {
      case ProgramV2Model.statusSuccess:
        final fg = isDark ? V2Colors.mint : const Color(0xFF2E7D32);
        return _DetailStatusStyle(
          label: 'Selesai',
          icon: Icons.check_circle_outline_rounded,
          foregroundColor: fg,
          backgroundColor: fg.withValues(alpha: isDark ? 0.2 : 0.1),
          borderColor: fg.withValues(alpha: 0.4),
        );

      case ProgramV2Model.statusWarning:
        final fg = isDark ? V2Colors.peach : V2Colors.warmGold;
        return _DetailStatusStyle(
          label: 'Hampir Selesai',
          icon: Icons.flag_outlined,
          foregroundColor: fg,
          backgroundColor: fg.withValues(alpha: isDark ? 0.2 : 0.12),
          borderColor: fg.withValues(alpha: 0.4),
        );

      case ProgramV2Model.statusFailed:
      default:
        final fg = isDark ? const Color(0xFFFF8A80) : const Color(0xFFC62828);
        return _DetailStatusStyle(
          label: 'Belum Selesai',
          icon: Icons.highlight_off_rounded,
          foregroundColor: fg,
          backgroundColor: fg.withValues(alpha: isDark ? 0.2 : 0.1),
          borderColor: fg.withValues(alpha: 0.4),
        );
    }
  }
}

class _DetailStatusStyle {
  final String label;
  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;

  const _DetailStatusStyle({
    required this.label,
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
  });
}
