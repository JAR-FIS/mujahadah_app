import 'package:flutter/material.dart';

import '../../../../models/achievement_model.dart';
import '../../../../theme/v2_design_tokens.dart';

/// "Achievement Terbaru" preview section on S08 Dashboard.
class AchievementPreviewSection extends StatelessWidget {
  final AchievementModel? achievement;
  final VoidCallback? onViewAllTap;

  const AchievementPreviewSection({
    super.key,
    this.achievement,
    this.onViewAllTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryTextColor =
        isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary;
    final secondaryTextColor =
        isDark ? V2Colors.darkTextSecondary : V2Colors.lightTextSecondary;
    final cardBg =
        isDark ? V2Colors.darkSurfaceCard : V2Colors.lightSurfaceCard;
    final borderColor = isDark ? V2Colors.darkBorder : V2Colors.lightBorder;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: V2Spacing.lg,
        vertical: V2Spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Achievement Terbaru',
                  style: V2Typography.headingMedium.copyWith(
                    color: primaryTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (achievement != null)
                Semantics(
                  label: 'Lihat Semua Achievement',
                  button: true,
                  child: InkWell(
                    key: const ValueKey('v2_dashboard_view_all_achievements'),
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
          Container(
            key: const ValueKey('v2_dashboard_achievement_card'),
            padding: const EdgeInsets.symmetric(
              horizontal: V2Spacing.lg,
              vertical: V2Spacing.md,
            ),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: V2Radius.borderLg,
              border: Border.all(color: borderColor),
              boxShadow:
                  isDark ? V2Elevation.darkSubtle : V2Elevation.lightSubtle,
            ),
            child: achievement == null
                ? Text(
                    'Belum ada catatan ibadah yang berhasil terselesaikan!',
                    style: V2Typography.bodyMedium.copyWith(
                      color: secondaryTextColor,
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              achievement!.type ==
                                      AchievementModel.typeFinalSuccess
                                  ? 'Target Selesai'
                                  : 'Milestone Tercapai',
                              style: V2Typography.headingSmall.copyWith(
                                color: primaryTextColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Istiqomah ${achievement!.milestoneDays} Hari',
                              style: V2Typography.bodySmall.copyWith(
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: V2Colors.warmGold.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.workspace_premium,
                          color: V2Colors.warmGold,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
