import 'package:flutter/material.dart';

import '../../../../theme/v2_design_tokens.dart';

/// "Perjalanan Saya" summary metrics section on S08 Dashboard:
/// Displays Aktif, Tercapai, and Terhenti counts from real read-only repository data.
class PerjalananSayaSection extends StatelessWidget {
  final int activeCount;
  final int achievedCount;
  final int stoppedCount;

  const PerjalananSayaSection({
    super.key,
    required this.activeCount,
    required this.achievedCount,
    required this.stoppedCount,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Perjalanan Saya',
            style: V2Typography.headingMedium.copyWith(
              color: primaryTextColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: V2Spacing.sm),
          Row(
            children: [
              _buildMetricCard(
                context: context,
                number: activeCount,
                label: 'Aktif',
                accentColor: isDark ? V2Colors.mint : const Color(0xFF0D9488),
                backgroundColor: isDark
                    ? V2Colors.mint.withValues(alpha: 0.1)
                    : V2Colors.cyan.withValues(alpha: 0.35),
                keyName: 'v2_metric_aktif',
              ),
              const SizedBox(width: V2Spacing.md),
              _buildMetricCard(
                context: context,
                number: achievedCount,
                label: 'Tercapai',
                accentColor: isDark ? V2Colors.mint : const Color(0xFF16A34A),
                backgroundColor: isDark
                    ? Colors.green.withValues(alpha: 0.12)
                    : V2Colors.mint.withValues(alpha: 0.4),
                keyName: 'v2_metric_tercapai',
              ),
              const SizedBox(width: V2Spacing.md),
              _buildMetricCard(
                context: context,
                number: stoppedCount,
                label: 'Terhenti',
                accentColor: isDark ? V2Colors.pink : const Color(0xFFE11D48),
                backgroundColor: isDark
                    ? V2Colors.pink.withValues(alpha: 0.12)
                    : V2Colors.pink.withValues(alpha: 0.35),
                keyName: 'v2_metric_terhenti',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required BuildContext context,
    required int number,
    required String label,
    required Color accentColor,
    required Color backgroundColor,
    required String keyName,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final borderColor = isDark ? V2Colors.darkBorder : V2Colors.lightBorder;
    final labelColor =
        isDark ? V2Colors.darkTextSecondary : V2Colors.lightTextSecondary;

    return Expanded(
      child: Container(
        key: ValueKey(keyName),
        padding: const EdgeInsets.symmetric(
          vertical: V2Spacing.md,
          horizontal: V2Spacing.sm,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: V2Radius.borderLg,
          border: Border.all(color: borderColor),
          boxShadow: isDark ? V2Elevation.darkSubtle : V2Elevation.lightSubtle,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$number',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: accentColor,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: V2Typography.labelMedium.copyWith(
                color: labelColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
