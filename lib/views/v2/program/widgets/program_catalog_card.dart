import 'package:flutter/material.dart';

import '../../../../models/v2_ibadah_catalog_item.dart';
import '../../../../theme/v2_design_tokens.dart';

/// Card tile representing an item from the 59-Ibadah catalog on S17 Program Hub.
class ProgramCatalogCard extends StatelessWidget {
  final V2IbadahCatalogItem item;
  final ValueChanged<V2IbadahCatalogItem> onTap;

  const ProgramCatalogCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg =
        isDark ? V2Colors.darkSurfaceCard : V2Colors.lightSurfaceCard;
    final borderColor = isDark ? V2Colors.darkBorder : V2Colors.lightBorder;
    final textPrimary =
        isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary;
    final textSecondary =
        isDark ? V2Colors.darkTextSecondary : V2Colors.lightTextSecondary;

    final badgeBg = isDark ? V2Colors.darkSurfaceElevated : V2Colors.lightGray;
    final badgeText = isDark ? V2Colors.peach : V2Colors.warmGold;

    return Semantics(
      button: true,
      label:
          '${item.namaIbadah}, Kategori ${item.category.label}, Min. ${item.defaultTargetDays} hari',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('v2_catalog_item_${item.id}'),
          onTap: () => onTap(item),
          borderRadius: V2Radius.borderLg,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
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
            child: Row(
              children: [
                // Left: Name and Category
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.namaIbadah,
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
                          Text(
                            item.category.label,
                            style: V2Typography.bodySmall.copyWith(
                              color: textSecondary,
                            ),
                          ),
                          if (!item.isDailyEligible)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? V2Colors.peach.withValues(alpha: 0.15)
                                    : V2Colors.peach.withValues(alpha: 0.25),
                                borderRadius: V2Radius.borderXs,
                              ),
                              child: Text(
                                'Bukan Harian',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? V2Colors.peach : Colors.brown,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: V2Spacing.md),
                // Right: Target Days Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: V2Spacing.md,
                    vertical: V2Spacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: V2Radius.borderFull,
                  ),
                  child: Text(
                    'Min. ${item.defaultTargetDays} hari',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: badgeText,
                    ),
                  ),
                ),
                const SizedBox(width: V2Spacing.xs),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color:
                      isDark ? V2Colors.darkTextMuted : V2Colors.lightTextMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
