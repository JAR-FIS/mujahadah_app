import 'package:flutter/material.dart';

import '../../../../controllers/v2_dashboard_controller.dart';
import '../../../../theme/v2_design_tokens.dart';

/// "Mujahadah Hari Ini" section on S08 Dashboard:
/// Previews up to 2-3 active programs or renders the approved empty state.
class ActiveProgramsPreviewSection extends StatelessWidget {
  final List<DashboardProgramItem> programs;
  final VoidCallback? onViewAllTap;
  final VoidCallback? onCreateProgramTap;

  const ActiveProgramsPreviewSection({
    super.key,
    required this.programs,
    this.onViewAllTap,
    this.onCreateProgramTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryTextColor =
        isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: V2Spacing.lg,
        vertical: V2Spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section header with optional "Lihat Semua →"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Mujahadah Hari Ini',
                  style: V2Typography.headingMedium.copyWith(
                    color: primaryTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (programs.isNotEmpty)
                Semantics(
                  label: 'Lihat Semua Program',
                  button: true,
                  child: InkWell(
                    key: const ValueKey('v2_dashboard_view_all_programs'),
                    onTap: onViewAllTap,
                    borderRadius: V2Radius.borderSm,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: V2Spacing.xs,
                        vertical: V2Spacing.xxs,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Lihat Semua',
                            style: V2Typography.labelMedium.copyWith(
                              color: V2Colors.warmGold,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: V2Colors.warmGold,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: V2Spacing.sm),

          // Content: Empty State vs Cards
          if (programs.isEmpty)
            _buildEmptyState(context, isDark)
          else
            Column(
              children: programs
                  .take(3)
                  .map((item) => _buildProgramCard(context, item, isDark))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    final cardBg =
        isDark ? V2Colors.darkSurfaceCard : V2Colors.lightSurfaceCard;
    final borderColor = isDark ? V2Colors.darkBorder : V2Colors.lightBorder;
    final secondaryTextColor =
        isDark ? V2Colors.darkTextSecondary : V2Colors.lightTextSecondary;

    return Container(
      key: const ValueKey('v2_dashboard_programs_empty_state'),
      padding: const EdgeInsets.symmetric(
        vertical: V2Spacing.xl,
        horizontal: V2Spacing.lg,
      ),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: V2Radius.borderLg,
        border: Border.all(color: borderColor),
        boxShadow: isDark ? V2Elevation.darkSubtle : V2Elevation.lightSubtle,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Kamu belum memiliki ibadah yang ditargetkan',
            textAlign: TextAlign.center,
            style: V2Typography.bodyMedium.copyWith(
              color: secondaryTextColor,
            ),
          ),
          const SizedBox(height: V2Spacing.lg),
          Semantics(
            label: 'Buat Target Ibadahmu Sekarang',
            button: true,
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                key: const ValueKey('v2_dashboard_create_program_cta'),
                onPressed: onCreateProgramTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: V2Colors.warmGold,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: const RoundedRectangleBorder(
                    borderRadius: V2Radius.borderFull,
                  ),
                ),
                child: const Text(
                  'Buat Target Ibadahmu Sekarang',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramCard(
    BuildContext context,
    DashboardProgramItem item,
    bool isDark,
  ) {
    final cardBg =
        isDark ? V2Colors.darkSurfaceCard : V2Colors.lightSurfaceCard;
    final borderColor = isDark ? V2Colors.darkBorder : V2Colors.lightBorder;
    final primaryTextColor =
        isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary;
    final secondaryTextColor =
        isDark ? V2Colors.darkTextSecondary : V2Colors.lightTextSecondary;

    final subtitle = item.completedDays != null
        ? 'Hari ke-${item.completedDays} dari ${item.targetDays}'
        : 'Progres belum tersedia';

    return Container(
      key: ValueKey('v2_dashboard_program_card_${item.program.id}'),
      margin: const EdgeInsets.only(bottom: V2Spacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: V2Spacing.lg,
        vertical: V2Spacing.md,
      ),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: V2Radius.borderLg,
        border: Border.all(color: borderColor),
        boxShadow: isDark ? V2Elevation.darkSubtle : V2Elevation.lightSubtle,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.program.ibadahNameSnapshot,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V2Typography.headingSmall.copyWith(
                    color: primaryTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: V2Typography.bodySmall.copyWith(
                    color: secondaryTextColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: V2Spacing.md),
          _buildStatusIndicator(item, isDark),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(DashboardProgramItem item, bool isDark) {
    if (item.isCompletedToday == true) {
      return Semantics(
        label: 'Sudah check-in hari ini',
        child: Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: Color(0xFF22C55E),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check,
            color: Colors.white,
            size: 20,
          ),
        ),
      );
    } else if (item.isPendingMuhasabah) {
      return Semantics(
        label: 'Perlu Muhasabah',
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDark
                ? V2Colors.peach.withValues(alpha: 0.2)
                : const Color(0xFFFEF3C7),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFF59E0B),
              width: 1.5,
            ),
          ),
          child: const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFD97706),
            size: 20,
          ),
        ),
      );
    } else if (item.isCompletedToday == false) {
      return Semantics(
        label: 'Belum check-in hari ini',
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDark
                ? V2Colors.darkSurfaceElevated
                : V2Colors.lightScaffoldBackground,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? V2Colors.darkBorder : V2Colors.lightBorder,
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.radio_button_unchecked,
            color: isDark
                ? V2Colors.darkTextSecondary
                : V2Colors.lightTextSecondary,
            size: 18,
          ),
        ),
      );
    } else {
      // Progress or check-in status is explicitly unavailable
      return Semantics(
        label: 'Status belum tersedia',
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDark
                ? V2Colors.darkSurfaceElevated
                : V2Colors.lightScaffoldBackground,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? V2Colors.darkBorder : V2Colors.lightBorder,
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.help_outline_rounded,
            color: isDark
                ? V2Colors.darkTextSecondary.withValues(alpha: 0.4)
                : V2Colors.lightTextSecondary.withValues(alpha: 0.4),
            size: 18,
          ),
        ),
      );
    }
  }
}
