import 'package:flutter/material.dart';

import '../../../theme/v2_design_tokens.dart';

/// Base presentation component for temporary V2 destination placeholders.
///
/// Constraints strictly observed:
/// - Zero fake program data.
/// - Zero fake prayer times, Hijri dates, or achievements.
/// - Zero access to V1 controllers, boxes, or models.
/// - Zero automatic check-ins or domain mutations.
class _V2DestinationPlaceholderBase extends StatelessWidget {
  final String title;
  final String screenId;
  final IconData icon;

  const _V2DestinationPlaceholderBase({
    required this.title,
    required this.screenId,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor = isDark ? V2Colors.mint : V2Colors.deepTosca;
    final surfaceColor =
        isDark ? V2Colors.darkSurfaceCard : V2Colors.lightSurfaceCard;
    final borderColor = isDark ? V2Colors.darkBorder : V2Colors.lightBorder;
    final textPrimary =
        isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary;
    final textSecondary =
        isDark ? V2Colors.darkTextSecondary : V2Colors.lightTextSecondary;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(V2Spacing.xxl),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(V2Spacing.xxl),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: V2Radius.borderXl,
            border: Border.all(color: borderColor),
            boxShadow: isDark ? V2Elevation.darkSubtle : V2Elevation.lightCard,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: V2Spacing.lg),
              Text(
                title,
                style: V2Typography.headingLarge.copyWith(color: textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: V2Spacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: V2Spacing.md,
                  vertical: V2Spacing.xs,
                ),
                decoration: BoxDecoration(
                  color: V2Colors.warmGold.withValues(alpha: 0.15),
                  borderRadius: V2Radius.borderFull,
                ),
                child: Text(
                  '$screenId • Foundation Placeholder',
                  style: V2Typography.labelSmall.copyWith(
                    color: isDark ? V2Colors.peach : V2Colors.warmGold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: V2Spacing.md),
              Text(
                'This destination view is isolated and pending implementation in the scheduled development wave.',
                style: V2Typography.bodyMedium.copyWith(color: textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Minimal identifiable placeholder for V2 Dashboard (Screen S08).
class V2DashboardPlaceholder extends StatelessWidget {
  const V2DashboardPlaceholder(
      {super.key = const ValueKey('v2_placeholder_dashboard')});

  @override
  Widget build(BuildContext context) {
    return const _V2DestinationPlaceholderBase(
      title: 'Dashboard',
      screenId: 'S08',
      icon: Icons.dashboard_outlined,
    );
  }
}

/// Minimal identifiable placeholder for V2 Dalil (Screen S15).
class V2DalilPlaceholder extends StatelessWidget {
  const V2DalilPlaceholder(
      {super.key = const ValueKey('v2_placeholder_dalil')});

  @override
  Widget build(BuildContext context) {
    return const _V2DestinationPlaceholderBase(
      title: 'Dalil',
      screenId: 'S15',
      icon: Icons.menu_book_outlined,
    );
  }
}

/// Minimal identifiable placeholder for V2 Program Hub (Screen S17).
class V2ProgramPlaceholder extends StatelessWidget {
  const V2ProgramPlaceholder(
      {super.key = const ValueKey('v2_placeholder_program')});

  @override
  Widget build(BuildContext context) {
    return const _V2DestinationPlaceholderBase(
      title: 'Program',
      screenId: 'S17',
      icon: Icons.add_circle_outline,
    );
  }
}

/// Minimal identifiable placeholder for V2 History / Riwayat (Screen S23).
class V2HistoryPlaceholder extends StatelessWidget {
  const V2HistoryPlaceholder(
      {super.key = const ValueKey('v2_placeholder_history')});

  @override
  Widget build(BuildContext context) {
    return const _V2DestinationPlaceholderBase(
      title: 'Riwayat',
      screenId: 'S23',
      icon: Icons.history_outlined,
    );
  }
}

/// Minimal identifiable placeholder for V2 Akun (Screen S26).
class V2AkunPlaceholder extends StatelessWidget {
  const V2AkunPlaceholder({super.key = const ValueKey('v2_placeholder_akun')});

  @override
  Widget build(BuildContext context) {
    return const _V2DestinationPlaceholderBase(
      title: 'Akun',
      screenId: 'S26',
      icon: Icons.person_outline,
    );
  }
}
