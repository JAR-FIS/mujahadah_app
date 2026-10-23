import 'package:flutter/material.dart';

import '../../../../core/date/date_service.dart';
import '../../../../models/failure_record_model.dart';
import '../../../../models/program_v2_model.dart';
import '../../../../services/daily_checkin_v2_service.dart';
import '../../../../theme/v2_design_tokens.dart';

/// Card component presenting a terminal Mujahadah Program in the History list.
///
/// Enforces all Mujahadah V2 History invariants:
/// 1. Status is differentiated by **icon + text + color** (never color alone).
/// 2. User-facing labels: SUCCESS -> "Selesai", WARNING -> "Hampir Selesai", FAILED -> "Belum Selesai".
/// 3. Display dates derived from persisted startDayKey and finalizedAt (fallback updatedAt).
/// 4. Completed day counts derive from authoritative [ProgramProgressSnapshot].
/// 5. Failure/interruption reasons derive strictly from stored [FailureRecordModel].
/// 6. Fully accessible touch target (>= 48dp) and Semantics labels.
class HistoryCard extends StatelessWidget {
  final ProgramV2Model program;
  final ProgramProgressSnapshot? progress;
  final FailureRecordModel? failureRecord;
  final VoidCallback onTap;

  const HistoryCard({
    super.key,
    required this.program,
    this.progress,
    this.failureRecord,
    required this.onTap,
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

    final surfaceCard =
        isDark ? V2Colors.darkSurfaceCard : V2Colors.lightSurfaceCard;
    final borderColor = isDark ? V2Colors.darkBorder : V2Colors.lightBorder;
    final textPrimary =
        isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary;
    final textSecondary =
        isDark ? V2Colors.darkTextSecondary : V2Colors.lightTextSecondary;

    final statusStyle = _resolveStatusStyle(isDark);
    final completionDate = program.finalizedAt ?? program.updatedAt;

    final completedText = progress != null
        ? '${progress!.completedDays} dari ${program.targetDays} hari'
        : '${program.targetDays} hari target';

    return Semantics(
      button: true,
      label:
          'Riwayat ${program.ibadahNameSnapshot}, Status ${statusStyle.label}, $completedText',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('v2_history_card_${program.id}'),
            onTap: onTap,
            borderRadius: V2Radius.borderLg,
            child: Container(
              padding: const EdgeInsets.all(V2Spacing.lg),
              decoration: BoxDecoration(
                color: surfaceCard,
                borderRadius: V2Radius.borderLg,
                border: Border.all(color: borderColor),
                boxShadow:
                    isDark ? V2Elevation.darkSubtle : V2Elevation.lightSubtle,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Status Badge + Optional Restart Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatusBadge(statusStyle),
                      if (program.restartedFromProgramId != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: V2Spacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? V2Colors.mint.withValues(alpha: 0.12)
                                : V2Colors.deepTosca.withValues(alpha: 0.08),
                            borderRadius: V2Radius.borderFull,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.replay_rounded,
                                size: 12,
                                color:
                                    isDark ? V2Colors.mint : V2Colors.deepTosca,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Program Restart',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? V2Colors.mint
                                      : V2Colors.deepTosca,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: V2Spacing.md),

                  // Ibadah Title
                  Text(
                    program.ibadahNameSnapshot,
                    key: ValueKey('v2_history_card_title_${program.id}'),
                    style: V2Typography.headingMedium.copyWith(
                      color: textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: V2Spacing.sm),

                  // Target & Completed Days Summary
                  Row(
                    children: [
                      Icon(
                        Icons.track_changes_outlined,
                        size: 16,
                        color: isDark ? V2Colors.peach : V2Colors.warmGold,
                      ),
                      const SizedBox(width: V2Spacing.xs),
                      Text(
                        completedText,
                        key: ValueKey('v2_history_card_progress_${program.id}'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: V2Spacing.xs),

                  // Dates: Start and End
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: textSecondary,
                      ),
                      const SizedBox(width: V2Spacing.xs),
                      Expanded(
                        child: Text(
                          '${_formatDayKeyIndonesian(program.startDayKey)} — ${_formatDateTimeIndonesian(completionDate)}',
                          key: ValueKey('v2_history_card_date_${program.id}'),
                          style: TextStyle(
                            fontSize: 12,
                            color: textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // Reason Note snippet for FAILED / WARNING programs
                  if (program.status == ProgramV2Model.statusFailed ||
                      program.status == ProgramV2Model.statusWarning) ...[
                    const SizedBox(height: V2Spacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: V2Spacing.sm,
                        vertical: V2Spacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03),
                        borderRadius: V2Radius.borderSm,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: textSecondary,
                          ),
                          const SizedBox(width: V2Spacing.xs),
                          Expanded(
                            child: Text(
                              failureRecord != null &&
                                      failureRecord!
                                          .reasonLabelSnapshot.isNotEmpty
                                  ? 'Alasan: ${failureRecord!.reasonLabelSnapshot}'
                                  : 'Catatan alasan tidak tersedia',
                              key: ValueKey(
                                  'v2_history_card_reason_${program.id}'),
                              style: TextStyle(
                                fontSize: 11,
                                color: textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(_StatusStyle style) {
    return Container(
      key: ValueKey('v2_history_card_status_${program.id}'),
      padding: const EdgeInsets.symmetric(
        horizontal: V2Spacing.md,
        vertical: V2Spacing.xs,
      ),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: V2Radius.borderFull,
        border: Border.all(color: style.borderColor, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            style.icon,
            size: 14,
            color: style.foregroundColor,
          ),
          const SizedBox(width: V2Spacing.xs),
          Text(
            style.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: style.foregroundColor,
            ),
          ),
        ],
      ),
    );
  }

  _StatusStyle _resolveStatusStyle(bool isDark) {
    switch (program.status) {
      case ProgramV2Model.statusSuccess:
        final fg = isDark ? V2Colors.mint : const Color(0xFF2E7D32);
        return _StatusStyle(
          label: 'Selesai',
          icon: Icons.check_circle_outline_rounded,
          foregroundColor: fg,
          backgroundColor: fg.withValues(alpha: isDark ? 0.2 : 0.1),
          borderColor: fg.withValues(alpha: 0.4),
        );

      case ProgramV2Model.statusWarning:
        final fg = isDark ? V2Colors.peach : V2Colors.warmGold;
        return _StatusStyle(
          label: 'Hampir Selesai',
          icon: Icons.flag_outlined,
          foregroundColor: fg,
          backgroundColor: fg.withValues(alpha: isDark ? 0.2 : 0.12),
          borderColor: fg.withValues(alpha: 0.4),
        );

      case ProgramV2Model.statusFailed:
      default:
        final fg = isDark ? const Color(0xFFFF8A80) : const Color(0xFFC62828);
        return _StatusStyle(
          label: 'Belum Selesai',
          icon: Icons.highlight_off_rounded,
          foregroundColor: fg,
          backgroundColor: fg.withValues(alpha: isDark ? 0.2 : 0.1),
          borderColor: fg.withValues(alpha: 0.4),
        );
    }
  }
}

class _StatusStyle {
  final String label;
  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;

  const _StatusStyle({
    required this.label,
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
  });
}
