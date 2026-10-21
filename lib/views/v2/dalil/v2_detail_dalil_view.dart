import 'package:flutter/material.dart';

import '../../../models/dalil_item.dart';
import '../../../theme/v2_design_tokens.dart';
import 'widgets/dalil_card.dart';

/// S16 Detail Dalil Screen.
///
/// Presents full content, category badge, optional Arabic text in RTL,
/// source attribution, and related items section with empty fallback.
class V2DetailDalilView extends StatelessWidget {
  final DalilItem item;
  final List<DalilItem> relatedItems;
  final VoidCallback onBack;
  final ValueChanged<DalilItem> onSelectDalil;

  const V2DetailDalilView({
    super.key,
    required this.item,
    required this.relatedItems,
    required this.onBack,
    required this.onSelectDalil,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final scaffoldBg = isDark
        ? V2Colors.darkScaffoldBackground
        : V2Colors.lightScaffoldBackground;
    final primaryTextColor =
        isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary;
    final secondaryTextColor =
        isDark ? V2Colors.darkTextSecondary : V2Colors.lightTextSecondary;
    final cardBg = isDark ? V2Colors.darkSurfaceCard : V2Colors.lightSurface;
    final borderColor = isDark ? V2Colors.darkBorder : V2Colors.lightBorder;

    return Container(
      color: scaffoldBg,
      child: Column(
        children: [
          // Header / Top App Bar
          _buildTopBar(context, isDark, primaryTextColor),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: V2Spacing.lg,
                vertical: V2Spacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Article / Dalil Card
                  _buildMainCard(
                    context: context,
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    primaryTextColor: primaryTextColor,
                    secondaryTextColor: secondaryTextColor,
                  ),

                  const SizedBox(height: V2Spacing.xxl),

                  // Related Content Section
                  Text(
                    '${item.category.label} lainnya',
                    style: V2Typography.headingMedium.copyWith(
                      color: primaryTextColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: V2Spacing.md),

                  // Related Items List or Empty Fallback
                  if (relatedItems.isNotEmpty)
                    ...relatedItems.map(
                      (related) => Padding(
                        padding: const EdgeInsets.only(bottom: V2Spacing.md),
                        child: DalilCard(
                          item: related,
                          isRelatedMode: true,
                          onTap: () => onSelectDalil(related),
                        ),
                      ),
                    )
                  else
                    _buildRelatedEmptyFallback(
                        isDark, cardBg, borderColor, secondaryTextColor),

                  const SizedBox(height: V2Spacing.xxxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    bool isDark,
    Color primaryTextColor,
  ) {
    return Container(
      key: const ValueKey('v2_dalil_detail_header'),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + V2Spacing.sm,
        left: V2Spacing.sm,
        right: V2Spacing.lg,
        bottom: V2Spacing.sm,
      ),
      decoration: BoxDecoration(
        color: isDark ? V2Colors.darkSurface : V2Colors.lightSurface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? V2Colors.darkBorder : V2Colors.lightBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Kembali ke daftar dalil',
            child: IconButton(
              key: const ValueKey('v2_dalil_detail_back_button'),
              icon: const Icon(Icons.arrow_back),
              color: primaryTextColor,
              tooltip: 'Kembali',
              onPressed: onBack,
            ),
          ),
          const SizedBox(width: V2Spacing.xs),
          Text(
            'Detail Dalil',
            style: V2Typography.headingLarge.copyWith(
              color: primaryTextColor,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainCard({
    required BuildContext context,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    return Container(
      key: const ValueKey('v2_dalil_detail_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(V2Spacing.xl),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: V2Radius.borderXl,
        border: Border.all(color: borderColor),
        boxShadow: isDark ? V2Elevation.darkSubtle : V2Elevation.lightSubtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Title & Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: V2Typography.headingLarge.copyWith(
                    color: primaryTextColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: V2Spacing.sm),
              _buildCategoryBadge(item.category, isDark),
            ],
          ),

          // Optional Arabic text with RTL directionality
          if (item.hasArabicText) ...[
            const SizedBox(height: V2Spacing.lg),
            Container(
              key: const ValueKey('v2_dalil_arabic_text'),
              width: double.infinity,
              padding: const EdgeInsets.all(V2Spacing.lg),
              decoration: BoxDecoration(
                color: isDark
                    ? V2Colors.mint.withValues(alpha: 0.08)
                    : V2Colors.deepTosca.withValues(alpha: 0.05),
                borderRadius: V2Radius.borderLg,
                border: Border.all(
                  color: isDark
                      ? V2Colors.mint.withValues(alpha: 0.2)
                      : V2Colors.deepTosca.withValues(alpha: 0.15),
                ),
              ),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  item.arabicText!,
                  style: TextStyle(
                    fontFamily: 'sans-serif',
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    height: 1.8,
                    color: isDark ? V2Colors.mint : V2Colors.deepTosca,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ],

          const SizedBox(height: V2Spacing.lg),

          // Detailed Body Paragraphs
          Text(
            item.body,
            style: V2Typography.bodyLarge.copyWith(
              color: primaryTextColor,
              height: 1.65,
              fontSize: 15,
            ),
          ),

          // Source attribution if supplied
          if (item.hasSourceReference) ...[
            const SizedBox(height: V2Spacing.xl),
            Container(
              key: const ValueKey('v2_dalil_source_reference'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: V2Spacing.md,
                vertical: V2Spacing.sm,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : const Color(0xFFF1F5F9),
                borderRadius: V2Radius.borderMd,
                border: Border.all(
                  color: isDark ? V2Colors.darkBorder : V2Colors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 16,
                    color: isDark ? V2Colors.warmGold : const Color(0xFFB45309),
                  ),
                  const SizedBox(width: V2Spacing.sm),
                  Expanded(
                    child: Text(
                      item.sourceReference!,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color:
                            isDark ? V2Colors.peach : const Color(0xFF9A3412),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRelatedEmptyFallback(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color secondaryTextColor,
  ) {
    return Container(
      key: const ValueKey('v2_dalil_related_empty'),
      width: double.infinity,
      padding: const EdgeInsets.all(V2Spacing.lg),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: V2Radius.borderLg,
        border: Border.all(color: borderColor),
      ),
      child: Text(
        'Belum ada ${item.category.label.toLowerCase()} lainnya yang tersedia.',
        style: TextStyle(
          color: secondaryTextColor,
          fontSize: 13.5,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildCategoryBadge(DalilCategory category, bool isDark) {
    Color badgeBg;
    Color badgeText;

    switch (category) {
      case DalilCategory.quran:
        badgeBg = isDark
            ? V2Colors.warmGold.withValues(alpha: 0.25)
            : const Color(0xFFFEF3C7);
        badgeText = isDark ? V2Colors.peach : const Color(0xFFB45309);
        break;
      case DalilCategory.hadits:
        badgeBg = isDark
            ? V2Colors.cyan.withValues(alpha: 0.25)
            : const Color(0xFFE0F2FE);
        badgeText = isDark ? V2Colors.cyan : const Color(0xFF0369A1);
        break;
      case DalilCategory.doa:
        badgeBg = isDark
            ? V2Colors.pink.withValues(alpha: 0.25)
            : const Color(0xFFFCE7F3);
        badgeText = isDark ? V2Colors.pink : const Color(0xFFBE185D);
        break;
      case DalilCategory.kisahHikmah:
        badgeBg = isDark
            ? V2Colors.mint.withValues(alpha: 0.25)
            : const Color(0xFFDCFCE7);
        badgeText = isDark ? V2Colors.mint : const Color(0xFF15803D);
        break;
      case DalilCategory.all:
        badgeBg = Colors.grey.withValues(alpha: 0.2);
        badgeText = isDark ? Colors.white : Colors.black87;
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
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
