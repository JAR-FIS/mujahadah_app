import 'package:flutter/material.dart';

import '../../../../models/dalil_item.dart';
import '../../../../theme/v2_design_tokens.dart';

/// Horizontal category selector bar for S15 Dalil.
///
/// Provides selection among: Semua / Al-Qur'an / Hadits / Kisah.
class DalilCategorySelector extends StatelessWidget {
  final DalilCategory selectedCategory;
  final ValueChanged<DalilCategory> onCategorySelected;

  const DalilCategorySelector({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  static const List<DalilCategory> _categories = [
    DalilCategory.all,
    DalilCategory.quran,
    DalilCategory.hadits,
    DalilCategory.doa,
    DalilCategory.kisahHikmah,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: V2Spacing.lg),
      child: Row(
        children: _categories.map((category) {
          final isSelected = category == selectedCategory;
          return Padding(
            padding: const EdgeInsets.only(right: V2Spacing.sm),
            child: _buildCategoryChip(
              context: context,
              category: category,
              isSelected: isSelected,
              isDark: isDark,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryChip({
    required BuildContext context,
    required DalilCategory category,
    required bool isSelected,
    required bool isDark,
  }) {
    final backgroundColor = isSelected
        ? (isDark ? V2Colors.mint.withValues(alpha: 0.2) : V2Colors.deepTosca)
        : (isDark ? V2Colors.darkSurfaceCard : V2Colors.lightSurface);

    final textColor = isSelected
        ? (isDark ? V2Colors.mint : Colors.white)
        : (isDark ? V2Colors.darkTextSecondary : V2Colors.lightTextSecondary);

    final borderColor = isSelected
        ? (isDark ? V2Colors.mint.withValues(alpha: 0.6) : V2Colors.deepTosca)
        : (isDark ? V2Colors.darkBorder : V2Colors.lightBorder);

    final String keyName;
    switch (category) {
      case DalilCategory.all:
        keyName = 'v2_dalil_filter_semua';
        break;
      case DalilCategory.quran:
        keyName = 'v2_dalil_filter_quran';
        break;
      case DalilCategory.hadits:
        keyName = 'v2_dalil_filter_hadits';
        break;
      case DalilCategory.doa:
        keyName = 'v2_dalil_filter_doa';
        break;
      case DalilCategory.kisahHikmah:
        keyName = 'v2_dalil_filter_kisah_hikmah';
        break;
    }

    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Kategori ${category.label}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey(keyName),
          onTap: () => onCategorySelected(category),
          borderRadius: V2Radius.borderFull,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            padding: const EdgeInsets.symmetric(
              horizontal: V2Spacing.lg,
              vertical: V2Spacing.sm,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: V2Radius.borderFull,
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: isSelected
                  ? (isDark
                      ? [
                          BoxShadow(
                            color: V2Colors.mint.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: V2Colors.deepTosca.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ])
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              category.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
