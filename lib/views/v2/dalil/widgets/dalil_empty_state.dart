import 'package:flutter/material.dart';

import '../../../../models/dalil_item.dart';
import '../../../../theme/v2_design_tokens.dart';

/// Empty state widget for Dalil S15 when no items exist or match the filter.
class DalilEmptyState extends StatelessWidget {
  final DalilCategory selectedCategory;
  final bool isCatalogEmpty;

  const DalilEmptyState({
    super.key,
    required this.selectedCategory,
    required this.isCatalogEmpty,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? V2Colors.darkSurfaceCard : V2Colors.lightSurface;
    final borderColor = isDark ? V2Colors.darkBorder : V2Colors.lightBorder;
    final primaryTextColor =
        isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary;
    final secondaryTextColor =
        isDark ? V2Colors.darkTextSecondary : V2Colors.lightTextSecondary;

    final title =
        isCatalogEmpty ? 'Katalog Dalil Belum Tersedia' : 'Belum Ada Dalil';

    final message = isCatalogEmpty
        ? 'Koleksi dalil Al-Qur\'an, hadits, doa, dan kisah & hikmah sedang dipersiapkan dan akan hadir pada pembaruan mendatang.'
        : 'Belum ada konten untuk kategori ${selectedCategory.label}. Silakan pilih kategori lain.';

    return Container(
      key: const ValueKey('v2_dalil_empty_state'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: V2Spacing.xl,
        vertical: V2Spacing.xxxl,
      ),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: V2Radius.borderXl,
        border: Border.all(color: borderColor),
        boxShadow: isDark ? V2Elevation.darkSubtle : V2Elevation.lightSubtle,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? V2Colors.mint.withValues(alpha: 0.12)
                  : V2Colors.deepTosca.withValues(alpha: 0.08),
            ),
            child: Icon(
              Icons.auto_stories_outlined,
              size: 32,
              color: isDark ? V2Colors.mint : V2Colors.deepTosca,
            ),
          ),
          const SizedBox(height: V2Spacing.lg),
          Text(
            title,
            style: V2Typography.headingMedium.copyWith(
              color: primaryTextColor,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: V2Spacing.sm),
          Text(
            message,
            style: V2Typography.bodyMedium.copyWith(
              color: secondaryTextColor,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
