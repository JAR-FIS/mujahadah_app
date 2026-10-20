import 'package:flutter/material.dart';

import '../../../../controllers/v2_dashboard_controller.dart';
import '../../../../theme/v2_design_tokens.dart';

/// "Muhasabah" section on S08 Dashboard:
/// Displays top interruption reasons and insight link, or empty state.
class MuhasabahPreviewSection extends StatelessWidget {
  final List<MuhasabahReasonSummary> reasons;
  final VoidCallback? onInsightTap;

  const MuhasabahPreviewSection({
    super.key,
    required this.reasons,
    this.onInsightTap,
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
          Text(
            'Muhasabah',
            style: V2Typography.headingMedium.copyWith(
              color: primaryTextColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: V2Spacing.sm),
          Container(
            key: const ValueKey('v2_dashboard_muhasabah_card'),
            padding: const EdgeInsets.all(V2Spacing.lg),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: V2Radius.borderLg,
              border: Border.all(color: borderColor),
              boxShadow:
                  isDark ? V2Elevation.darkSubtle : V2Elevation.lightSubtle,
            ),
            child: reasons.isEmpty
                ? Text(
                    'Catatan kelalaian belum terekam. Kamu belum memiliki ibadah yang ditargetkan.',
                    style: V2Typography.bodyMedium.copyWith(
                      color: secondaryTextColor,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Penyebab paling sering:',
                        style: V2Typography.bodyMedium.copyWith(
                          color: secondaryTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: V2Spacing.sm),
                      ...reasons.map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.play_arrow_rounded,
                                size: 16,
                                color: V2Colors.warmGold,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${r.label} · ${r.count} kali',
                                style: V2Typography.bodyMedium.copyWith(
                                  color: primaryTextColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: V2Spacing.md),
                      Semantics(
                        label: 'Lihat Insight Muhasabah',
                        button: true,
                        child: SizedBox(
                          height: 38,
                          child: ElevatedButton(
                            key: const ValueKey('v2_dashboard_muhasabah_cta'),
                            onPressed: onInsightTap,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: V2Colors.warmGold,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: const RoundedRectangleBorder(
                                borderRadius: V2Radius.borderFull,
                              ),
                            ),
                            child: const Text(
                              'Lihat Insight',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
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
