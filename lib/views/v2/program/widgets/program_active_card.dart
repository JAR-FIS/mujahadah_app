import 'package:flutter/material.dart';

import '../../../../models/program_v2_model.dart';
import '../../../../theme/v2_design_tokens.dart';

/// Card tile representing an active or pending-muhasabah program in 'Ibadah Saya'.
class ProgramActiveCard extends StatelessWidget {
  final ProgramV2Model program;
  final VoidCallback? onTap;

  const ProgramActiveCard({
    super.key,
    required this.program,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isPendingFailure =
        program.status == ProgramV2Model.statusPendingFailure;

    final cardBg =
        isDark ? V2Colors.darkSurfaceCard : V2Colors.lightSurfaceCard;
    final borderColor = isPendingFailure
        ? (isDark ? V2Colors.peach.withValues(alpha: 0.5) : V2Colors.peach)
        : (isDark ? V2Colors.darkBorder : V2Colors.lightBorder);
    final textPrimary =
        isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary;
    final textSecondary =
        isDark ? V2Colors.darkTextSecondary : V2Colors.lightTextSecondary;

    // Status pill colors
    final statusBg = isPendingFailure
        ? (isDark
            ? V2Colors.peach.withValues(alpha: 0.2)
            : V2Colors.peach.withValues(alpha: 0.25))
        : (isDark
            ? V2Colors.mint.withValues(alpha: 0.2)
            : V2Colors.mint.withValues(alpha: 0.35));

    final statusText = isPendingFailure
        ? (isDark ? V2Colors.peach : const Color(0xFF8A5B00))
        : (isDark ? V2Colors.mint : V2Colors.deepTosca);

    final statusLabel = isPendingFailure ? 'Perlu Muhasabah' : 'Aktif';

    final isInteractive = onTap != null;

    final cardContent = Container(
      key: ValueKey('v2_active_program_${program.id}'),
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(
        horizontal: V2Spacing.lg,
        vertical: V2Spacing.md,
      ),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: V2Radius.borderLg,
        border: Border.all(
          color: borderColor,
          width: isPendingFailure ? 1.5 : 1.0,
        ),
        boxShadow: isDark ? V2Elevation.darkSubtle : V2Elevation.lightSubtle,
      ),
      child: Row(
        children: [
          // Leading status indicator icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: statusBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPendingFailure
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline_rounded,
              size: 20,
              color: statusText,
            ),
          ),
          const SizedBox(width: V2Spacing.md),
          // Program Name & Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  program.ibadahNameSnapshot,
                  style: V2Typography.bodyLarge.copyWith(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: V2Spacing.xxs),
                Wrap(
                  spacing: V2Spacing.xs,
                  runSpacing: V2Spacing.xxs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: V2Radius.borderXs,
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusText,
                        ),
                      ),
                    ),
                    Text(
                      '• Mulai: ${program.startDayKey}',
                      style: V2Typography.bodySmall.copyWith(
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: V2Spacing.md),
          // Target Days Badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: V2Spacing.md,
              vertical: V2Spacing.xs,
            ),
            decoration: BoxDecoration(
              color: isDark ? V2Colors.darkSurfaceElevated : V2Colors.lightGray,
              borderRadius: V2Radius.borderFull,
            ),
            child: Text(
              '${program.targetDays} Hari',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? V2Colors.peach : V2Colors.warmGold,
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: isInteractive,
      label:
          '${program.ibadahNameSnapshot}, Status $statusLabel, Target ${program.targetDays} Hari',
      child: isInteractive
          ? Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: V2Radius.borderLg,
                child: cardContent,
              ),
            )
          : cardContent,
    );
  }
}
