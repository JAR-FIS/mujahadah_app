import 'package:flutter/material.dart';

import '../../../models/v2_ibadah_catalog_item.dart';
import '../../../theme/v2_design_tokens.dart';

/// Screen S18 — Pilih Ibadah (Detail & Keutamaan).
///
/// Implements the approved S18 catalog detail view:
/// - Worship activity name, category, and target duration.
/// - Detailed description and method/time guidelines.
/// - Comprehensive list of Keutamaan (virtues) with bullet points.
/// - Dalil and authoritative references.
/// - Daily eligibility enforcement: Intermittent/non-daily schedules are
///   clearly flagged as ineligible for consecutive-day Mujahadah programs.
/// - CTA button 'Mulai Program Mujahadah' preparing typed downstream contract.
class V2PilihIbadahView extends StatelessWidget {
  final V2IbadahCatalogItem item;
  final VoidCallback onBack;
  final ValueChanged<V2IbadahCatalogItem>? onStartProgram;

  const V2PilihIbadahView({
    super.key,
    required this.item,
    required this.onBack,
    this.onStartProgram,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final scaffoldBg = isDark
        ? V2Colors.darkScaffoldBackground
        : V2Colors.lightScaffoldBackground;
    final surfaceCard =
        isDark ? V2Colors.darkSurfaceCard : V2Colors.lightSurfaceCard;
    final borderColor = isDark ? V2Colors.darkBorder : V2Colors.lightBorder;
    final textPrimary =
        isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary;
    final textSecondary =
        isDark ? V2Colors.darkTextSecondary : V2Colors.lightTextSecondary;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(context, isDark, textPrimary),
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: V2Spacing.lg,
                  vertical: V2Spacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Card (Category & Target)
                    _buildHeaderCard(context, isDark, surfaceCard, borderColor,
                        textPrimary, textSecondary),
                    const SizedBox(height: V2Spacing.lg),

                    // Description Section
                    _buildSectionContainer(
                      isDark: isDark,
                      surfaceCard: surfaceCard,
                      borderColor: borderColor,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Deskripsi',
                            style: V2Typography.headingMedium.copyWith(
                              color: textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: V2Spacing.sm),
                          Text(
                            item.deskripsi,
                            style: V2Typography.bodyMedium.copyWith(
                              color: textPrimary,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: V2Spacing.md),

                    // Keutamaan Section
                    if (item.hasKeutamaan) ...[
                      _buildKeutamaanSection(isDark, surfaceCard, borderColor,
                          textPrimary, textSecondary),
                      const SizedBox(height: V2Spacing.md),
                    ],

                    // Tata Cara & Waktu Section (if available)
                    if (item.hasTataCaraDanWaktu) ...[
                      _buildSectionContainer(
                        isDark: isDark,
                        surfaceCard: surfaceCard,
                        borderColor: borderColor,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tata Cara & Waktu',
                              style: V2Typography.headingMedium.copyWith(
                                color: textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: V2Spacing.sm),
                            Text(
                              item.tataCaraDanWaktu!,
                              style: V2Typography.bodyMedium.copyWith(
                                color: textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: V2Spacing.md),
                    ],

                    // Dalil & Rujukan Section (if available)
                    if (item.hasDalilDanRujukan) ...[
                      _buildSectionContainer(
                        isDark: isDark,
                        surfaceCard: surfaceCard,
                        borderColor: borderColor,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dalil & Rujukan',
                              style: V2Typography.headingMedium.copyWith(
                                color: textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: V2Spacing.sm),
                            Text(
                              item.dalilDanRujukan!,
                              style: V2Typography.bodySmall.copyWith(
                                color: textSecondary,
                                fontStyle: FontStyle.italic,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: V2Spacing.md),
                    ],

                    // Ineligibility Notice (if not daily eligible)
                    if (!item.isDailyEligible) ...[
                      Container(
                        padding: const EdgeInsets.all(V2Spacing.md),
                        decoration: BoxDecoration(
                          color: isDark
                              ? V2Colors.peach.withValues(alpha: 0.15)
                              : V2Colors.peach.withValues(alpha: 0.25),
                          borderRadius: V2Radius.borderMd,
                          border: Border.all(
                            color: isDark ? V2Colors.peach : Colors.brown,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: isDark ? V2Colors.peach : Colors.brown,
                            ),
                            const SizedBox(width: V2Spacing.sm),
                            Expanded(
                              child: Text(
                                item.ineligibilityReason ??
                                    'Program Mujahadah V2 dirancang untuk target harian berturut-turut. Ibadah dengan jadwal berkala tidak dapat dibuat sebagai target harian.',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: isDark ? V2Colors.peach : Colors.brown,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: V2Spacing.md),
                    ],

                    const SizedBox(height: V2Spacing.xl),
                  ],
                ),
              ),
            ),
            // Bottom Action Bar
            _buildBottomActionBar(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isDark, Color textPrimary) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: V2Spacing.md,
        vertical: V2Spacing.sm,
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Kembali ke Katalog Program',
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: IconButton(
                key: const ValueKey('v2_pilih_ibadah_back_button'),
                icon: const Icon(Icons.arrow_back),
                color: textPrimary,
                onPressed: onBack,
                tooltip: 'Kembali',
              ),
            ),
          ),
          const SizedBox(width: V2Spacing.xs),
          Expanded(
            child: Text(
              item.namaIbadah,
              style: V2Typography.headingLarge.copyWith(
                color: textPrimary,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    bool isDark,
    Color surfaceCard,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final catBg = isDark
        ? V2Colors.mint.withValues(alpha: 0.15)
        : V2Colors.deepTosca.withValues(alpha: 0.1);
    final catText = isDark ? V2Colors.mint : V2Colors.deepTosca;

    final targetBg = isDark ? V2Colors.darkSurfaceElevated : V2Colors.lightGray;
    final targetText = isDark ? V2Colors.peach : V2Colors.warmGold;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(V2Spacing.lg),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: V2Radius.borderLg,
        border: Border.all(color: borderColor),
        boxShadow: isDark ? V2Elevation.darkSubtle : V2Elevation.lightSubtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: V2Spacing.sm,
            runSpacing: V2Spacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Category Pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: V2Spacing.md,
                  vertical: V2Spacing.xs,
                ),
                decoration: BoxDecoration(
                  color: catBg,
                  borderRadius: V2Radius.borderFull,
                ),
                child: Text(
                  item.category.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: catText,
                  ),
                ),
              ),
              // Default Target Days Pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: V2Spacing.md,
                  vertical: V2Spacing.xs,
                ),
                decoration: BoxDecoration(
                  color: targetBg,
                  borderRadius: V2Radius.borderFull,
                ),
                child: Text(
                  'Min. ${item.defaultTargetDays} hari',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: targetText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: V2Spacing.md),
          Text(
            item.namaIbadah,
            style: V2Typography.headingLarge.copyWith(
              color: textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContainer({
    required bool isDark,
    required Color surfaceCard,
    required Color borderColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(V2Spacing.lg),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: V2Radius.borderLg,
        border: Border.all(color: borderColor),
        boxShadow: isDark ? V2Elevation.darkSubtle : V2Elevation.lightSubtle,
      ),
      child: child,
    );
  }

  Widget _buildKeutamaanSection(
    bool isDark,
    Color surfaceCard,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return _buildSectionContainer(
      isDark: isDark,
      surfaceCard: surfaceCard,
      borderColor: borderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Keutamaan',
            style: V2Typography.headingMedium.copyWith(
              color: textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: V2Spacing.md),
          ...item.keutamaan.map((keutamaanItem) {
            return Padding(
              padding: const EdgeInsets.only(bottom: V2Spacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isDark ? V2Colors.mint : V2Colors.deepTosca,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: V2Spacing.sm),
                  Expanded(
                    child: Text(
                      keutamaanItem,
                      style: V2Typography.bodyMedium.copyWith(
                        color: textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(BuildContext context, bool isDark) {
    final bottomBarBg = isDark ? V2Colors.darkSurface : V2Colors.lightSurface;
    final topBorderColor = isDark ? V2Colors.darkBorder : V2Colors.lightBorder;

    final isEligible = item.isDailyEligible;
    final hasCallback = onStartProgram != null;
    final isEnabled = isEligible && hasCallback;

    return Container(
      padding: const EdgeInsets.all(V2Spacing.lg),
      decoration: BoxDecoration(
        color: bottomBarBg,
        border: Border(
          top: BorderSide(color: topBorderColor, width: 1.0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isEligible && !hasCallback)
              Padding(
                padding: const EdgeInsets.only(bottom: V2Spacing.sm),
                child: Text(
                  'Pengaturan target dan durasi program (S20) akan segera tersedia.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? V2Colors.darkTextMuted
                        : V2Colors.lightTextMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: 48,
                minWidth: double.infinity,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  key: const ValueKey('v2_pilih_ibadah_mulai_button'),
                  onPressed: isEnabled ? () => onStartProgram!(item) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: V2Colors.warmGold,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        isDark ? V2Colors.darkBorder : V2Colors.lightGray,
                    disabledForegroundColor: isDark
                        ? V2Colors.darkTextMuted
                        : V2Colors.lightTextMuted,
                    shape: const RoundedRectangleBorder(
                      borderRadius: V2Radius.borderFull,
                    ),
                    elevation: isEnabled ? 2 : 0,
                  ),
                  child: const Text(
                    'Mulai Program Mujahadah',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
