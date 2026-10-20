import 'package:flutter/material.dart';

import '../../../../theme/v2_design_tokens.dart';

/// Header section of S08 Dashboard displaying greeting, user name, date, and weather/theme indicator.
class DashboardHeader extends StatelessWidget {
  final String greeting;
  final String userName;
  final String gregorianDate;
  final String? hijriDate;
  final VoidCallback? onActionTap;

  const DashboardHeader({
    super.key,
    this.greeting = 'Semangat Istiqomah',
    required this.userName,
    required this.gregorianDate,
    this.hijriDate,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryTextColor =
        isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary;
    final secondaryTextColor =
        isDark ? V2Colors.darkTextSecondary : V2Colors.lightTextSecondary;

    final dateDisplay = (hijriDate != null && hijriDate!.trim().isNotEmpty)
        ? '$gregorianDate / ${hijriDate!.trim()}'
        : gregorianDate;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: V2Spacing.lg,
        vertical: V2Spacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  greeting,
                  style: V2Typography.labelMedium.copyWith(
                    color: V2Colors.warmGold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V2Typography.headingLarge.copyWith(
                    color: primaryTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateDisplay,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V2Typography.bodySmall.copyWith(
                    color: secondaryTextColor,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: V2Spacing.md),
          Semantics(
            label: 'Indikator Suasana',
            button: onActionTap != null,
            child: InkResponse(
              onTap: onActionTap,
              radius: 20,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? V2Colors.darkSurfaceElevated
                      : V2Colors.lightSurface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? V2Colors.darkBorder : V2Colors.lightBorder,
                  ),
                  boxShadow:
                      isDark ? V2Elevation.darkSubtle : V2Elevation.lightSubtle,
                ),
                child: Icon(
                  isDark ? Icons.nightlight_round : Icons.wb_sunny_outlined,
                  color: isDark ? V2Colors.mint : V2Colors.warmGold,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
