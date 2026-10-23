import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/v2_onboarding_controller.dart';
import '../../../models/v2_onboarding_model.dart';
import '../../../repositories/v2_onboarding_repository.dart';
import '../../../theme/v2_design_tokens.dart';

/// Screen S01–S05: 5-Screen V2 Onboarding Flow.
///
/// Features contemporary Islamic design, light and dark themes, 320dp width responsiveness,
/// accessible 48dp touch targets, four-language readiness with honest fallback notice,
/// and durable Hive completion persistence.
class V2OnboardingView extends StatefulWidget {
  final V2OnboardingController? controller;
  final V2OnboardingRepository? repository;
  final VoidCallback? onCompleted;
  final String? languageCode;

  const V2OnboardingView({
    super.key,
    this.controller,
    this.repository,
    this.onCompleted,
    this.languageCode,
  });

  @override
  State<V2OnboardingView> createState() => _V2OnboardingViewState();
}

class _V2OnboardingViewState extends State<V2OnboardingView> {
  late final V2OnboardingController _controller;
  late final bool _ownsController;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      final repo = widget.repository ?? HiveV2OnboardingRepository();
      _controller = V2OnboardingController(
        repository: repo,
        languageCode: widget.languageCode,
      );
      _ownsController = true;
    }
    _pageController =
        PageController(initialPage: _controller.currentIndex.value);
  }

  @override
  void dispose() {
    _pageController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleNext() {
    if (_controller.isLastPage ||
        _controller.isSaving.value ||
        _controller.isCompleted.value) {
      return;
    }
    _controller.nextPage();
    _pageController.animateToPage(
      _controller.currentIndex.value,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
    );
  }

  void _handlePrevious() {
    if (_controller.isFirstPage ||
        _controller.isSaving.value ||
        _controller.isCompleted.value) {
      return;
    }
    _controller.previousPage();
    _pageController.animateToPage(
      _controller.currentIndex.value,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _handleFinish() async {
    if (_controller.isSaving.value || _controller.isCompleted.value) return;

    final success = await _controller.completeOnboarding();
    if (!mounted) return;

    if (success) {
      widget.onCompleted?.call();
    } else {
      // Keep PageController viewport synchronized on page 5 on failure
      if (_pageController.hasClients &&
          _pageController.page?.round() != _controller.currentIndex.value) {
        _pageController.jumpToPage(_controller.currentIndex.value);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final scaffoldBg = isDark
        ? V2Colors.darkScaffoldBackground
        : V2Colors.lightScaffoldBackground;
    final primaryAccent = isDark ? V2Colors.mint : V2Colors.deepTosca;
    final textPrimary =
        isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary;
    final textSecondary =
        isDark ? V2Colors.darkTextSecondary : V2Colors.lightTextSecondary;
    final isRtl = _controller.isRtl;

    Widget content = Scaffold(
      key: const ValueKey('v2_onboarding_screen'),
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Stepper & Progress Header
            _buildProgressHeader(isDark, primaryAccent, textSecondary),

            // Honest Fallback Notice for non-Indonesian languages awaiting Owner workbook
            _buildFallbackNotice(isDark),

            // 5-Screen Swipable Page View with saving-time scroll lock (P1-02)
            Expanded(
              child: Obx(() {
                final isSaving = _controller.isSaving.value;
                return PageView.builder(
                  controller: _pageController,
                  physics: isSaving
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  itemCount: _controller.totalPages,
                  onPageChanged: (page) {
                    if (!_controller.isSaving.value) {
                      _controller.goToPage(page);
                    }
                  },
                  itemBuilder: (context, index) {
                    final pageContent = _controller.strings.pages[index];
                    return _buildPageCard(
                      pageContent: pageContent,
                      isDark: isDark,
                      primaryAccent: primaryAccent,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    );
                  },
                );
              }),
            ),

            // Optional Error Banner
            Obx(() {
              final err = _controller.errorMessage.value;
              if (err.isEmpty) return const SizedBox.shrink();
              return _buildErrorBanner(err, isDark);
            }),

            // Bottom Navigation CTA Bar
            _buildBottomCta(
              isDark: isDark,
              scaffoldBg: scaffoldBg,
              primaryAccent: primaryAccent,
              isRtl: isRtl,
            ),
          ],
        ),
      ),
    );

    if (isRtl) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: content,
      );
    }
    return content;
  }

  Widget _buildProgressHeader(
    bool isDark,
    Color primaryAccent,
    Color textSecondary,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: V2Spacing.xl,
        vertical: V2Spacing.md,
      ),
      child: Obx(() {
        final current = _controller.currentIndex.value;
        final total = _controller.totalPages;
        final progressLabel =
            _controller.strings.progressLabel(current + 1, total);

        return Semantics(
          label: progressLabel,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                key: const ValueKey('v2_onboarding_progress_indicator'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(total, (index) {
                  final isActive = index == current;
                  final isPassed = index < current;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    width: isActive ? 28.0 : 8.0,
                    height: 8.0,
                    decoration: BoxDecoration(
                      color: isActive
                          ? primaryAccent
                          : isPassed
                              ? primaryAccent.withValues(alpha: 0.5)
                              : (isDark
                                  ? V2Colors.darkBorder
                                  : V2Colors.lightBorder),
                      borderRadius: V2Radius.borderFull,
                    ),
                  );
                }),
              ),
              const SizedBox(height: V2Spacing.xs),
              Text(
                progressLabel,
                style: V2Typography.labelSmall.copyWith(
                  color: textSecondary,
                  fontSize: 12.0,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildFallbackNotice(bool isDark) {
    final notice = _controller.strings.fallbackNotice;
    if (notice.isEmpty) return const SizedBox.shrink();

    final noticeBg = isDark
        ? V2Colors.darkSurfaceCard
        : V2Colors.warmGold.withValues(alpha: 0.12);
    final noticeBorder =
        isDark ? V2Colors.darkBorder : V2Colors.warmGold.withValues(alpha: 0.4);
    final textColor = isDark ? V2Colors.mint : V2Colors.deepTosca;

    return Semantics(
      label: notice,
      child: Container(
        key: const ValueKey('v2_onboarding_fallback_notice'),
        margin: const EdgeInsets.symmetric(
          horizontal: V2Spacing.xl,
          vertical: V2Spacing.xs,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: V2Spacing.md,
          vertical: V2Spacing.xs,
        ),
        decoration: BoxDecoration(
          color: noticeBg,
          borderRadius: V2Radius.borderMd,
          border: Border.all(color: noticeBorder),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 16,
              color: textColor,
            ),
            const SizedBox(width: V2Spacing.xs),
            Expanded(
              child: Text(
                notice,
                textDirection: TextDirection.ltr,
                style: V2Typography.bodySmall.copyWith(
                  color: textColor,
                  fontSize: 12.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageCard({
    required V2OnboardingPageContent pageContent,
    required bool isDark,
    required Color primaryAccent,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final cardBg =
        isDark ? V2Colors.darkSurfaceCard : V2Colors.lightSurfaceCard;
    final borderColor = isDark ? V2Colors.darkBorder : V2Colors.lightBorder;
    final pageIndex = pageContent.pageIndex;

    // For Arabic fallback Indonesian text, maintain LTR reading direction
    final contentTextDirection =
        (_controller.strings.isFullyLocalized && _controller.isRtl)
            ? TextDirection.rtl
            : TextDirection.ltr;

    return SingleChildScrollView(
      key: ValueKey('v2_onboarding_page_$pageIndex'),
      padding: const EdgeInsets.symmetric(
        horizontal: V2Spacing.xl,
        vertical: V2Spacing.lg,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: V2Spacing.md),

            // Hero Emblem Container with Contemporary Islamic Accent
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryAccent.withValues(alpha: 0.12),
                border: Border.all(
                  color: primaryAccent.withValues(alpha: 0.28),
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryAccent.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  pageContent.icon,
                  size: 52,
                  color: primaryAccent,
                ),
              ),
            ),

            const SizedBox(height: V2Spacing.xl),

            // Badge Chip
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: V2Spacing.md,
                vertical: V2Spacing.xs,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? V2Colors.darkSurfaceCard
                    : V2Colors.warmGold.withValues(alpha: 0.12),
                borderRadius: V2Radius.borderFull,
                border: Border.all(
                  color: isDark ? V2Colors.darkBorder : V2Colors.warmGold,
                  width: 1.0,
                ),
              ),
              child: Text(
                pageContent.badge,
                textDirection: contentTextDirection,
                style: V2Typography.labelSmall.copyWith(
                  color: isDark ? V2Colors.mint : V2Colors.deepTosca,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),

            const SizedBox(height: V2Spacing.lg),

            // Card enclosing Title and Body
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(V2Spacing.xl),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: V2Radius.borderXl,
                border: Border.all(color: borderColor),
                boxShadow:
                    isDark ? V2Elevation.darkSubtle : V2Elevation.lightCard,
              ),
              child: Column(
                children: [
                  Text(
                    pageContent.title,
                    key: ValueKey('v2_onboarding_title_$pageIndex'),
                    textDirection: contentTextDirection,
                    textAlign: TextAlign.center,
                    style: V2Typography.headingMedium.copyWith(
                      color: textPrimary,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: V2Spacing.md),
                  Text(
                    pageContent.body,
                    textDirection: contentTextDirection,
                    textAlign: TextAlign.center,
                    style: V2Typography.bodyMedium.copyWith(
                      color: textSecondary,
                      height: 1.5,
                      fontSize: 14.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message, bool isDark) {
    final errorColor =
        isDark ? const Color(0xFFFF8B8B) : const Color(0xFFC53030);
    final errorBg = errorColor.withValues(alpha: isDark ? 0.18 : 0.08);

    return Container(
      key: const ValueKey('v2_onboarding_error_banner'),
      margin: const EdgeInsets.symmetric(
        horizontal: V2Spacing.xl,
        vertical: V2Spacing.xs,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: V2Spacing.md,
        vertical: V2Spacing.sm,
      ),
      decoration: BoxDecoration(
        color: errorBg,
        borderRadius: V2Radius.borderMd,
        border: Border.all(color: errorColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 20,
            color: errorColor,
          ),
          const SizedBox(width: V2Spacing.sm),
          Expanded(
            child: Text(
              message,
              textDirection: TextDirection.ltr,
              style: V2Typography.bodySmall.copyWith(
                color: errorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            color: errorColor,
            onPressed: _controller.clearError,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCta({
    required bool isDark,
    required Color scaffoldBg,
    required Color primaryAccent,
    required bool isRtl,
  }) {
    final borderColor = isDark ? V2Colors.darkBorder : V2Colors.lightBorder;

    return Container(
      padding: const EdgeInsets.all(V2Spacing.lg),
      decoration: BoxDecoration(
        color: scaffoldBg,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Obx(() {
        final isLastPage = _controller.isLastPage;
        final isFirstPage = _controller.isFirstPage;
        final isSaving = _controller.isSaving.value;
        final isCompleted = _controller.isCompleted.value;
        final isBusy = isSaving || isCompleted;
        final nextLabel = _controller.strings.nextLabel;
        final backLabel = _controller.strings.backLabel;
        final finishLabel = _controller.strings.finishLabel;

        return Row(
          children: [
            // Back Button (accessible min 48dp, hidden on first page)
            if (!isFirstPage)
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 52.0,
                  child: OutlinedButton(
                    key: const ValueKey('v2_onboarding_back_button'),
                    onPressed: isBusy ? null : _handlePrevious,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark
                          ? V2Colors.darkTextPrimary
                          : V2Colors.lightTextPrimary,
                      side: BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: V2Radius.borderLg,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isRtl
                              ? Icons.arrow_forward_rounded
                              : Icons.arrow_back_rounded,
                          size: 18,
                        ),
                        const SizedBox(width: 4.0),
                        Flexible(
                          child: Text(
                            backLabel,
                            overflow: TextOverflow.ellipsis,
                            style: V2Typography.labelLarge.copyWith(
                              fontSize: 15.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            if (!isFirstPage) const SizedBox(width: V2Spacing.md),

            // Primary Next / Finish Button
            Expanded(
              flex: isFirstPage ? 1 : 2,
              child: SizedBox(
                height: 52.0,
                child: ElevatedButton(
                  key: ValueKey(
                    isLastPage
                        ? 'v2_onboarding_finish_button'
                        : 'v2_onboarding_next_button',
                  ),
                  onPressed: isBusy
                      ? null
                      : (isLastPage ? _handleFinish : _handleNext),
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
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                isLastPage ? finishLabel : nextLabel,
                                overflow: TextOverflow.ellipsis,
                                style: V2Typography.labelLarge.copyWith(
                                  color:
                                      isDark ? V2Colors.charcoal : Colors.white,
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6.0),
                            Icon(
                              isLastPage
                                  ? Icons.check_circle_outline
                                  : (isRtl
                                      ? Icons.arrow_back_rounded
                                      : Icons.arrow_forward_rounded),
                              size: 18,
                              color: isDark ? V2Colors.charcoal : Colors.white,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
