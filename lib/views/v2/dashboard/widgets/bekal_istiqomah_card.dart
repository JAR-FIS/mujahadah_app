import 'package:flutter/material.dart';

import '../../../../theme/v2_design_tokens.dart';

/// "Bekal Istiqomah" section on S08 Dashboard:
/// Features inspirational Quranic quote with link to Dalil destination.
class BekalIstiqomahSection extends StatelessWidget {
  final String? quote;
  final String? source;
  final VoidCallback? onReadMoreTap;

  const BekalIstiqomahSection({
    super.key,
    this.quote,
    this.source,
    this.onReadMoreTap,
  });

  static const String defaultQuote =
      '"Maka karena itu serulah (mereka) dan tetaplah (beristiqomah) sebagaimana diperintahkan kepadamu dan janganlah mengikuti hawa nafsu mereka..."';
  static const String defaultSource = 'Q.S. Asy-Syura Ayat 15';

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Bekal Istiqomah',
                  style: V2Typography.headingMedium.copyWith(
                    color: primaryTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Semantics(
                label: 'Baca Dalil Lainnya',
                button: true,
                child: InkWell(
                  key: const ValueKey('v2_dashboard_read_more_dalil'),
                  onTap: onReadMoreTap,
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
                          'Baca Lainnya',
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
            key: const ValueKey('v2_dashboard_bekal_istiqomah_card'),
            padding: const EdgeInsets.all(V2Spacing.lg),
            decoration: BoxDecoration(
              color: V2Colors.deepTosca,
              borderRadius: V2Radius.borderLg,
              border: Border.all(
                color: isDark ? V2Colors.darkBorder : Colors.transparent,
              ),
              boxShadow:
                  isDark ? V2Elevation.darkSubtle : V2Elevation.lightCard,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quote ?? defaultQuote,
                  style: V2Typography.bodyMedium.copyWith(
                    color: Colors.white,
                    fontStyle: FontStyle.italic,
                    height: 1.45,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: V2Spacing.sm),
                Text(
                  source ?? defaultSource,
                  style: V2Typography.labelSmall.copyWith(
                    color: V2Colors.mint,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
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
