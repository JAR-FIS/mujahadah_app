import 'package:flutter/material.dart';

import '../../../../theme/v2_design_tokens.dart';

/// Presentation widget for empty, filter-empty, and error states in the History screen.
class HistoryEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const HistoryEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
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
        padding: const EdgeInsets.all(V2Spacing.xl),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.all(V2Spacing.xl),
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
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: V2Spacing.lg),
              Text(
                title,
                key: const ValueKey('v2_history_empty_title'),
                style: V2Typography.headingMedium.copyWith(color: textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: V2Spacing.sm),
              Text(
                message,
                key: const ValueKey('v2_history_empty_message'),
                style: V2Typography.bodyMedium.copyWith(
                  color: textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: V2Spacing.lg),
                Semantics(
                  button: true,
                  label: actionLabel,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 48,
                      minWidth: 48,
                    ),
                    child: OutlinedButton(
                      key: ValueKey(
                          'v2_history_empty_action_${actionLabel!.toLowerCase().replaceAll(' ', '_')}'),
                      onPressed: onAction,
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            isDark ? V2Colors.mint : V2Colors.deepTosca,
                        side: BorderSide(
                          color: isDark ? V2Colors.mint : V2Colors.deepTosca,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: V2Radius.borderFull,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: V2Spacing.xl,
                          vertical: V2Spacing.sm,
                        ),
                      ),
                      child: Text(
                        actionLabel!,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
