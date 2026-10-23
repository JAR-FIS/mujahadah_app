import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/v2_initial_preferences_controller.dart';
import '../../../models/v2_initial_preferences_model.dart';
import '../../../repositories/v2_preferences_repository.dart';
import '../../../theme/v2_design_tokens.dart';

/// Screen S00A: First-Launch Initial Preferences Setup.
///
/// Prompts users on brand new install to select their preferred application language
/// and Light/Dark visual theme. Selections are persisted offline upon tapping 'Mulai'.
class V2InitialPreferencesView extends StatefulWidget {
  final V2InitialPreferencesController? controller;
  final V2PreferencesRepository? repository;
  final VoidCallback? onContinue;
  final Widget? brandHeader;

  const V2InitialPreferencesView({
    super.key,
    this.controller,
    this.repository,
    this.onContinue,
    this.brandHeader,
  });

  @override
  State<V2InitialPreferencesView> createState() =>
      _V2InitialPreferencesViewState();
}

class _V2InitialPreferencesViewState extends State<V2InitialPreferencesView> {
  late final V2InitialPreferencesController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      final repo = widget.repository ?? HiveV2PreferencesRepository();
      _controller = V2InitialPreferencesController(repository: repo);
      _ownsController = true;
    }
    _controller.loadExistingPreferences();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _handleMulai() async {
    final success = await _controller.confirmAndSave();
    if (success && mounted) {
      widget.onContinue?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final scaffoldBg = isDark
        ? V2Colors.darkScaffoldBackground
        : V2Colors.lightScaffoldBackground;
    final surfaceCardBg =
        isDark ? V2Colors.darkSurfaceCard : V2Colors.lightSurfaceCard;
    final textPrimary =
        isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary;
    final textSecondary =
        isDark ? V2Colors.darkTextSecondary : V2Colors.lightTextSecondary;
    final borderColor = isDark ? V2Colors.darkBorder : V2Colors.lightBorder;
    final primaryAccent = isDark ? V2Colors.mint : V2Colors.deepTosca;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: V2Spacing.xl,
                  vertical: V2Spacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand / Logo Area
                    widget.brandHeader ??
                        _buildBrandHeader(isDark, textPrimary, textSecondary),

                    const SizedBox(height: V2Spacing.xxl),

                    // Error Message Banner (if any)
                    Obx(() {
                      final error = _controller.errorMessage.value;
                      if (error.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: V2Spacing.lg),
                        child: _buildErrorBanner(error, isDark),
                      );
                    }),

                    // Section 1: Language Selection
                    _buildSectionHeader(
                      title: 'Pilih Penggunaan Bahasa',
                      subtitle:
                          'Sesuaikan bahasa pengantar aplikasi Mujahadah.',
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                    const SizedBox(height: V2Spacing.md),
                    _buildLanguageSection(
                      surfaceCardBg: surfaceCardBg,
                      borderColor: borderColor,
                      primaryAccent: primaryAccent,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      isDark: isDark,
                    ),

                    const SizedBox(height: V2Spacing.xxl),

                    // Section 2: Theme Selection
                    _buildSectionHeader(
                      title: 'Pilih Tema Aplikasi',
                      subtitle:
                          'Pilih kenyamanan visual untuk ibadah harian Anda.',
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                    const SizedBox(height: V2Spacing.md),
                    _buildThemeSection(
                      surfaceCardBg: surfaceCardBg,
                      borderColor: borderColor,
                      primaryAccent: primaryAccent,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      isDark: isDark,
                    ),

                    const SizedBox(height: V2Spacing.xl),
                  ],
                ),
              ),
            ),

            // Bottom Sticky CTA 'Mulai'
            _buildBottomCta(
              scaffoldBg: scaffoldBg,
              primaryAccent: primaryAccent,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandHeader(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Column(
      children: [
        const SizedBox(height: V2Spacing.md),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: isDark ? V2Colors.darkSurfaceElevated : V2Colors.mint,
            borderRadius: V2Radius.borderXl,
            border: Border.all(
              color: isDark ? V2Colors.mint : V2Colors.deepTosca,
              width: 1.5,
            ),
            boxShadow:
                isDark ? V2Elevation.darkSubtle : V2Elevation.lightSubtle,
          ),
          child: Center(
            child: Icon(
              Icons.mosque_rounded,
              size: 38,
              color: isDark ? V2Colors.mint : V2Colors.deepTosca,
            ),
          ),
        ),
        const SizedBox(height: V2Spacing.md),
        Text(
          'MUJAHADAH',
          textAlign: TextAlign.center,
          style: V2Typography.headingLarge.copyWith(
            color: isDark ? V2Colors.mint : V2Colors.deepTosca,
            letterSpacing: 2.0,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: V2Spacing.xs),
        Text(
          'Pengaturan Awal Aplikasi',
          textAlign: TextAlign.center,
          style: V2Typography.bodyMedium.copyWith(
            color: textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: V2Typography.headingSmall.copyWith(
            color: textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: V2Spacing.xxs),
        Text(
          subtitle,
          style: V2Typography.bodySmall.copyWith(
            color: textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageSection({
    required Color surfaceCardBg,
    required Color borderColor,
    required Color primaryAccent,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    return Obx(() {
      final selected = _controller.selectedLanguage.value;
      final isSaving = _controller.isSaving.value;

      return Column(
        children: [
          // Bahasa Indonesia Option
          _buildOptionTile(
            key: const ValueKey('v2_pref_lang_id'),
            title: 'Bahasa Indonesia',
            subtitle: 'Bahasa utama aplikasi',
            badgeText: 'ID',
            isSelected: selected == V2InitialPreferencesModel.languageId,
            isSaving: isSaving,
            onTap: () =>
                _controller.setLanguage(V2InitialPreferencesModel.languageId),
            surfaceCardBg: surfaceCardBg,
            borderColor: borderColor,
            primaryAccent: primaryAccent,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            isDark: isDark,
          ),

          const SizedBox(height: V2Spacing.sm),

          // English Option with Disclosure
          _buildOptionTile(
            key: const ValueKey('v2_pref_lang_en'),
            title: 'English',
            subtitle:
                'Konten aplikasi saat ini masih tersedia dalam Bahasa Indonesia',
            badgeText: 'EN',
            isSelected: selected == V2InitialPreferencesModel.languageEn,
            isSaving: isSaving,
            onTap: () =>
                _controller.setLanguage(V2InitialPreferencesModel.languageEn),
            surfaceCardBg: surfaceCardBg,
            borderColor: borderColor,
            primaryAccent: primaryAccent,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            isDark: isDark,
          ),
        ],
      );
    });
  }

  Widget _buildThemeSection({
    required Color surfaceCardBg,
    required Color borderColor,
    required Color primaryAccent,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    return Obx(() {
      final selected = _controller.selectedTheme.value;
      final isSaving = _controller.isSaving.value;

      return Column(
        children: [
          // Light Mode Option
          _buildOptionTile(
            key: const ValueKey('v2_pref_theme_light'),
            title: 'Mode Terang',
            subtitle: 'Tampilan bersih & cerah',
            icon: Icons.light_mode_rounded,
            isSelected: selected == V2InitialPreferencesModel.themeLight,
            isSaving: isSaving,
            onTap: () =>
                _controller.setTheme(V2InitialPreferencesModel.themeLight),
            surfaceCardBg: surfaceCardBg,
            borderColor: borderColor,
            primaryAccent: primaryAccent,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            isDark: isDark,
          ),

          const SizedBox(height: V2Spacing.sm),

          // Dark Mode Option
          _buildOptionTile(
            key: const ValueKey('v2_pref_theme_dark'),
            title: 'Mode Gelap',
            subtitle: 'Tampilan elegan, nyaman untuk malam hari',
            icon: Icons.dark_mode_rounded,
            isSelected: selected == V2InitialPreferencesModel.themeDark,
            isSaving: isSaving,
            onTap: () =>
                _controller.setTheme(V2InitialPreferencesModel.themeDark),
            surfaceCardBg: surfaceCardBg,
            borderColor: borderColor,
            primaryAccent: primaryAccent,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            isDark: isDark,
          ),
        ],
      );
    });
  }

  Widget _buildOptionTile({
    required Key key,
    required String title,
    required String subtitle,
    required bool isSelected,
    required bool isSaving,
    required VoidCallback onTap,
    required Color surfaceCardBg,
    required Color borderColor,
    required Color primaryAccent,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
    String? badgeText,
    IconData? icon,
  }) {
    final activeBorderColor = isSelected ? primaryAccent : borderColor;
    final activeBgColor = isSelected
        ? (isDark
            ? V2Colors.darkSurfaceElevated
            : V2Colors.mint.withValues(alpha: 0.15))
        : surfaceCardBg;

    return Semantics(
      label: '$title ${isSelected ? 'Terpilih' : 'Tidak terpilih'}',
      button: true,
      selected: isSelected,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56.0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: key,
            onTap: isSaving ? null : onTap,
            borderRadius: V2Radius.borderLg,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                horizontal: V2Spacing.lg,
                vertical: V2Spacing.md,
              ),
              decoration: BoxDecoration(
                color: activeBgColor,
                borderRadius: V2Radius.borderLg,
                border: Border.all(
                  color: activeBorderColor,
                  width: isSelected ? 2.0 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  // Leading Icon or Badge
                  if (icon != null)
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? V2Colors.deepTosca : V2Colors.mint)
                            : (isDark
                                ? V2Colors.darkSurface
                                : V2Colors.lightScaffoldBackground),
                        borderRadius: V2Radius.borderMd,
                      ),
                      child: Icon(
                        icon,
                        color: isSelected
                            ? (isDark ? V2Colors.mint : V2Colors.deepTosca)
                            : textSecondary,
                        size: 22,
                      ),
                    )
                  else if (badgeText != null)
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? V2Colors.deepTosca : V2Colors.mint)
                            : (isDark
                                ? V2Colors.darkSurface
                                : V2Colors.lightScaffoldBackground),
                        borderRadius: V2Radius.borderMd,
                      ),
                      child: Center(
                        child: Text(
                          badgeText,
                          style: V2Typography.labelLarge.copyWith(
                            color: isSelected
                                ? (isDark ? V2Colors.mint : V2Colors.deepTosca)
                                : textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(width: V2Spacing.md),

                  // Text Information
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: V2Typography.bodyLarge.copyWith(
                            color: textPrimary,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          subtitle,
                          style: V2Typography.bodySmall.copyWith(
                            color: textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: V2Spacing.sm),

                  // Selection Radio / Checkmark Indicator
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? primaryAccent : borderColor,
                        width: 2.0,
                      ),
                      color: isSelected ? primaryAccent : Colors.transparent,
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: isDark ? V2Colors.charcoal : Colors.white,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: V2Spacing.md,
        vertical: V2Spacing.sm,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? V2Colors.pink.withValues(alpha: 0.2)
            : const Color(0xFFFDE8E8),
        borderRadius: V2Radius.borderMd,
        border: Border.all(color: V2Colors.pink),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFC53030),
            size: 20,
          ),
          const SizedBox(width: V2Spacing.sm),
          Expanded(
            child: Text(
              message,
              style: V2Typography.bodySmall.copyWith(
                color:
                    isDark ? V2Colors.darkTextPrimary : const Color(0xFF9B1C1C),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCta({
    required Color scaffoldBg,
    required Color primaryAccent,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(V2Spacing.lg),
      decoration: BoxDecoration(
        color: scaffoldBg,
        border: Border(
          top: BorderSide(
            color: isDark ? V2Colors.darkBorder : V2Colors.lightBorder,
          ),
        ),
      ),
      child: Obx(() {
        final isSaving = _controller.isSaving.value;
        final isLoadingPreferences = _controller.isLoadingPreferences.value;
        final isBusy = isSaving || isLoadingPreferences;

        return SizedBox(
          width: double.infinity,
          height: 52.0,
          child: ElevatedButton(
            key: const ValueKey('v2_init_pref_mulai_button'),
            onPressed: isBusy ? null : _handleMulai,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryAccent,
              foregroundColor: isDark ? V2Colors.charcoal : Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: V2Radius.borderLg,
              ),
            ),
            child: isSaving
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? V2Colors.charcoal : Colors.white,
                      ),
                    ),
                  )
                : Text(
                    'Mulai',
                    style: V2Typography.labelLarge.copyWith(
                      color: isDark ? V2Colors.charcoal : Colors.white,
                      fontSize: 16.0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        );
      }),
    );
  }
}
