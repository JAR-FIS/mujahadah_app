import 'package:flutter/material.dart';

import '../../../../theme/v2_design_tokens.dart';

/// Quick action buttons grid row for S08 Dashboard:
/// 1. Kiblat (S10)
/// 2. Kalender Mujahadah (S12)
/// 3. Kalender Hijriah (S11)
/// 4. Doa Istiqomah (S15/Dalil filtered)
class DashboardQuickActions extends StatelessWidget {
  final VoidCallback? onKiblatTap;
  final VoidCallback? onKalenderMujahadahTap;
  final VoidCallback? onKalenderHijriahTap;
  final VoidCallback? onDoaIstiqomahTap;

  const DashboardQuickActions({
    super.key,
    this.onKiblatTap,
    this.onKalenderMujahadahTap,
    this.onKalenderHijriahTap,
    this.onDoaIstiqomahTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: V2Spacing.lg,
        vertical: V2Spacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActionButton(
            context: context,
            keyName: 'v2_quick_action_kiblat',
            icon: Icons.explore_outlined,
            label: 'Kiblat',
            semanticLabel: 'Kiblat',
            onTap: onKiblatTap,
          ),
          _buildActionButton(
            context: context,
            keyName: 'v2_quick_action_kalender_mujahadah',
            icon: Icons.event_available_outlined,
            label: 'Kalender\nMujahadah',
            semanticLabel: 'Kalender Mujahadah',
            onTap: onKalenderMujahadahTap,
          ),
          _buildActionButton(
            context: context,
            keyName: 'v2_quick_action_kalender_hijriah',
            icon: Icons.calendar_month_outlined,
            label: 'Kalender\nHijriah',
            semanticLabel: 'Kalender Hijriah',
            onTap: onKalenderHijriahTap,
          ),
          _buildActionButton(
            context: context,
            keyName: 'v2_quick_action_doa_istiqomah',
            icon: Icons.volunteer_activism_outlined,
            label: 'Doa\nIstiqomah',
            semanticLabel: 'Doa Istiqomah',
            onTap: onDoaIstiqomahTap,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String keyName,
    required IconData icon,
    required String label,
    required String semanticLabel,
    required VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isEnabled = onTap != null;
    final cardBg =
        isDark ? V2Colors.darkSurfaceElevated : V2Colors.lightSurface;
    final borderColor = isDark ? V2Colors.darkBorder : V2Colors.lightBorder;
    final iconColor = isEnabled
        ? (isDark ? V2Colors.mint : V2Colors.deepTosca)
        : (isDark
            ? V2Colors.darkTextSecondary.withValues(alpha: 0.38)
            : V2Colors.lightTextSecondary.withValues(alpha: 0.38));
    final textColor = isEnabled
        ? (isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary)
        : (isDark
            ? V2Colors.darkTextSecondary.withValues(alpha: 0.38)
            : V2Colors.lightTextSecondary.withValues(alpha: 0.38));

    return Expanded(
      child: Semantics(
        label: isEnabled ? semanticLabel : '$semanticLabel (Belum tersedia)',
        button: isEnabled,
        enabled: isEnabled,
        child: InkWell(
          key: ValueKey(keyName),
          onTap: onTap,
          borderRadius: V2Radius.borderLg,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: V2Radius.borderLg,
                      border: Border.all(color: borderColor),
                      boxShadow: isEnabled
                          ? (isDark
                              ? V2Elevation.darkSubtle
                              : V2Elevation.lightSubtle)
                          : null,
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        color: iconColor,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
