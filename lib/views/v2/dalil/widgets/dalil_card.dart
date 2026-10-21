import 'package:flutter/material.dart';

import '../../../../models/dalil_item.dart';
import '../../../../theme/v2_design_tokens.dart';

/// Card component presenting a Dalil item in S15 list or S16 related content.
class DalilCard extends StatelessWidget {
  final DalilItem item;
  final VoidCallback onTap;
  final bool isRelatedMode;

  const DalilCard({
    super.key,
    required this.item,
    required this.onTap,
    this.isRelatedMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? V2Colors.darkSurfaceElevated : V2Colors.deepTosca;
    final borderColor = isDark ? V2Colors.darkBorder : Colors.transparent;

    return Semantics(
      button: true,
      label: '${item.title}, Kategori ${item.category.label}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey(isRelatedMode
              ? 'v2_dalil_related_card_${item.id}'
              : 'v2_dalil_card_${item.id}'),
          onTap: onTap,
          borderRadius: V2Radius.borderLg,
          child: Container(
            padding: const EdgeInsets.all(V2Spacing.lg),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: V2Radius.borderLg,
              border: Border.all(color: borderColor),
              boxShadow: isDark
                  ? V2Elevation.darkSubtle
                  : [
                      BoxShadow(
                        color: V2Colors.deepTosca.withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top row: Title & Category badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: V2Typography.headingMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: V2Spacing.sm),
                    _buildCategoryBadge(item.category, isDark),
                  ],
                ),
                const SizedBox(height: V2Spacing.md),

                // Excerpt / Quote
                Text(
                  item.excerpt,
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 13.5,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),

                // Optional Arabic preview if available
                if (item.hasArabicText && !isRelatedMode) ...[
                  const SizedBox(height: V2Spacing.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: V2Spacing.xs,
                      horizontal: V2Spacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15),
                      borderRadius: V2Radius.borderSm,
                    ),
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(
                        item.arabicText!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: V2Colors.mint,
                          fontSize: 16,
                          height: 1.6,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: V2Spacing.md),

                // Bottom row: Source Reference & Action
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: item.hasSourceReference
                          ? Text(
                              item.sourceReference!,
                              style: const TextStyle(
                                color: V2Colors.peach,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : const SizedBox.shrink(),
                    ),
                    InkWell(
                      key: ValueKey('v2_dalil_detail_btn_${item.id}'),
                      onTap: onTap,
                      borderRadius: V2Radius.borderSm,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: V2Spacing.xs,
                          vertical: V2Spacing.xxs,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'Lihat detail',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward,
                              size: 13,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(DalilCategory category, bool isDark) {
    Color badgeBg;
    Color badgeText;

    switch (category) {
      case DalilCategory.quran:
        badgeBg = V2Colors.warmGold.withValues(alpha: 0.3);
        badgeText = V2Colors.peach;
        break;
      case DalilCategory.hadits:
        badgeBg = V2Colors.cyan.withValues(alpha: 0.25);
        badgeText = V2Colors.cyan;
        break;
      case DalilCategory.doa:
        badgeBg = V2Colors.pink.withValues(alpha: 0.25);
        badgeText = V2Colors.pink;
        break;
      case DalilCategory.kisahHikmah:
        badgeBg = V2Colors.mint.withValues(alpha: 0.25);
        badgeText = V2Colors.mint;
        break;
      case DalilCategory.all:
        badgeBg = Colors.white.withValues(alpha: 0.2);
        badgeText = Colors.white;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: V2Spacing.sm,
        vertical: V2Spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: V2Radius.borderFull,
      ),
      child: Text(
        category.label,
        style: TextStyle(
          color: badgeText,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
