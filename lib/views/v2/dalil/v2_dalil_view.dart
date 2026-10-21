import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/v2_dalil_controller.dart';
import '../../../controllers/v2_navigation_controller.dart';
import '../../../theme/v2_design_tokens.dart';
import 'v2_detail_dalil_view.dart';
import 'widgets/dalil_card.dart';
import 'widgets/dalil_category_selector.dart';
import 'widgets/dalil_empty_state.dart';

/// S15 Dalil / Bekal Istiqomah and S16 Detail Dalil coordination view.
///
/// Implements:
/// - S15: Header, Category Filter (Semua/Al-Qur'an/Hadits/Kisah), and Dalil list / empty state.
/// - S16: Full article detail with back navigation, Arabic text, and related content.
/// - Preserves category selection when returning from detail.
/// - Integrates seamlessly into V2AppShell five-tab navigation.
class V2DalilView extends StatefulWidget {
  final V2DalilController? controller;
  final V2NavigationController? navigationController;

  const V2DalilView({
    super.key,
    this.controller,
    this.navigationController,
  });

  @override
  State<V2DalilView> createState() => _V2DalilViewState();
}

class _V2DalilViewState extends State<V2DalilView> {
  late V2DalilController _controller;
  V2NavigationController? _navigationController;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else if (Get.isRegistered<V2DalilController>()) {
      _controller = Get.find<V2DalilController>();
      _ownsController = false;
    } else {
      _controller = V2DalilController();
      _ownsController = true;
    }

    _navigationController = widget.navigationController ??
        (Get.isRegistered<V2NavigationController>()
            ? Get.find<V2NavigationController>()
            : null);
  }

  @override
  void didUpdateWidget(V2DalilView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null &&
        widget.controller != oldWidget.controller) {
      if (_ownsController) {
        _controller.onClose();
        _ownsController = false;
      }
      _controller = widget.controller!;
    }
    if (widget.navigationController != null &&
        widget.navigationController != oldWidget.navigationController) {
      _navigationController = widget.navigationController;
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.onClose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final scaffoldBg = isDark
        ? V2Colors.darkScaffoldBackground
        : V2Colors.lightScaffoldBackground;

    return Obx(() {
      final selectedItem = _controller.selectedItem;

      // Tab-aware back navigation:
      // When Dalil is embedded in an App Shell, check if Dalil is the currently active tab.
      // When Dalil is NOT active, its PopScope must never block system Back navigation.
      final isDalilActive = _navigationController == null ||
          _navigationController!.currentTab == V2NavigationTab.dalil;

      // Dalil only intercepts back navigation when it is the active tab AND detail is open.
      final canPop = !isDalilActive || selectedItem == null;

      return PopScope(
        canPop: canPop,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && isDalilActive && _controller.selectedItem != null) {
            _controller.clearSelection();
          }
        },
        child: Scaffold(
          backgroundColor: scaffoldBg,
          body: selectedItem != null
              ? V2DetailDalilView(
                  item: selectedItem,
                  relatedItems: _controller.getRelatedItems(selectedItem),
                  onBack: _controller.clearSelection,
                  onSelectDalil: _controller.selectDalil,
                )
              : _buildDalilHome(context, isDark),
        ),
      );
    });
  }

  Widget _buildDalilHome(BuildContext context, bool isDark) {
    final primaryTextColor =
        isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary;
    final secondaryTextColor =
        isDark ? V2Colors.darkTextSecondary : V2Colors.lightTextSecondary;

    final filtered = _controller.filteredItems;
    final isCatalogEmpty = _controller.items.isEmpty;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // S15 Header
          Padding(
            padding: const EdgeInsets.only(
              left: V2Spacing.lg,
              right: V2Spacing.lg,
              top: V2Spacing.lg,
              bottom: V2Spacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dalil - Bekal Istiqomah',
                  key: const ValueKey('v2_dalil_header'),
                  style: V2Typography.headingLarge.copyWith(
                    color: primaryTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: V2Spacing.xs),
                Text(
                  'Bekal untuk menjaga semangat dan keistiqomahan.',
                  style: V2Typography.bodyMedium.copyWith(
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: V2Spacing.sm),

          // Category Selector
          DalilCategorySelector(
            selectedCategory: _controller.selectedCategory,
            onCategorySelected: _controller.selectCategory,
          ),

          const SizedBox(height: V2Spacing.md),

          // Dalil Content List or Empty State
          Expanded(
            child: filtered.isNotEmpty
                ? ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: V2Spacing.lg,
                      vertical: V2Spacing.sm,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: V2Spacing.md),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return DalilCard(
                        item: item,
                        onTap: () => _controller.selectDalil(item),
                      );
                    },
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: V2Spacing.lg,
                      vertical: V2Spacing.md,
                    ),
                    child: DalilEmptyState(
                      selectedCategory: _controller.selectedCategory,
                      isCatalogEmpty: isCatalogEmpty,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
