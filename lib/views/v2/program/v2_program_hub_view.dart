import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/v2_navigation_controller.dart';
import '../../../controllers/v2_program_hub_controller.dart';
import '../../../models/v2_ibadah_catalog_item.dart';
import '../../../repositories/program_v2_repository.dart';
import '../../../theme/v2_design_tokens.dart';
import 'v2_pilih_ibadah_view.dart';
import 'widgets/program_active_card.dart';
import 'widgets/program_catalog_card.dart';
import 'widgets/program_empty_state.dart';
import 'widgets/program_search_bar.dart';
import 'widgets/program_segment_selector.dart';

/// Screen S17 — Program Hub and Screen S18 — Pilih Ibadah coordinator view.
///
/// Implements:
/// - S17: Program Hub header, two-segment selector ([Katalog Ibadah] / [Ibadah Saya]),
///   real-time search bar, and '+ Baru' custom creation shortcut.
/// - S18: Full worship activity detail view with back navigation, Keutamaan bullets,
///   daily-eligibility enforcement, and 'Mulai Program Mujahadah' CTA.
/// - Tab-aware PopScope: never intercepts Android back navigation when Program tab is inactive.
/// - Safe GetX controller lifecycle without build-time registrations.
class V2ProgramHubView extends StatefulWidget {
  final V2ProgramHubController? controller;
  final V2NavigationController? navigationController;
  final ProgramV2Repository? programRepository;
  final ValueChanged<V2IbadahCatalogItem>? onStartProgram;
  final VoidCallback? onNewCustomTap;

  const V2ProgramHubView({
    super.key,
    this.controller,
    this.navigationController,
    this.programRepository,
    this.onStartProgram,
    this.onNewCustomTap,
  });

  @override
  State<V2ProgramHubView> createState() => _V2ProgramHubViewState();
}

class _V2ProgramHubViewState extends State<V2ProgramHubView> {
  late V2ProgramHubController _controller;
  V2NavigationController? _navigationController;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      final repo = widget.programRepository ??
          (Get.isRegistered<ProgramV2Repository>()
              ? Get.find<ProgramV2Repository>()
              : null);
      if (widget.programRepository == null &&
          Get.isRegistered<V2ProgramHubController>()) {
        _controller = Get.find<V2ProgramHubController>();
        _ownsController = false;
      } else {
        _controller = V2ProgramHubController(
          programRepository: repo,
        );
        _ownsController = true;
      }
    }

    _navigationController = widget.navigationController ??
        (Get.isRegistered<V2NavigationController>()
            ? Get.find<V2NavigationController>()
            : null);
  }

  @override
  void didUpdateWidget(V2ProgramHubView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null &&
        widget.controller != oldWidget.controller) {
      if (_ownsController) {
        _controller.onClose();
        _ownsController = false;
      }
      _controller = widget.controller!;
    } else if (widget.programRepository != oldWidget.programRepository &&
        widget.controller == null) {
      if (_ownsController) {
        _controller.onClose();
      }
      final repo = widget.programRepository ??
          (Get.isRegistered<ProgramV2Repository>()
              ? Get.find<ProgramV2Repository>()
              : null);
      _controller = V2ProgramHubController(
        programRepository: repo,
      );
      _ownsController = true;
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
      final selectedItem = _controller.selectedCatalogItem;

      // Tab-aware back navigation:
      // When Program is embedded in an App Shell, check if Program is the currently active tab.
      // When Program is NOT active, its PopScope must never block system Back navigation.
      final isProgramActive = _navigationController == null ||
          _navigationController!.currentTab == V2NavigationTab.program;

      final canPop = !isProgramActive || selectedItem == null;

      return PopScope(
        canPop: canPop,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop &&
              isProgramActive &&
              _controller.selectedCatalogItem != null) {
            _controller.clearSelection();
          }
        },
        child: Scaffold(
          backgroundColor: scaffoldBg,
          body: selectedItem != null
              ? V2PilihIbadahView(
                  item: selectedItem,
                  onBack: _controller.clearSelection,
                  onStartProgram: widget.onStartProgram,
                )
              : _buildProgramHubHome(context, isDark),
        ),
      );
    });
  }

  Widget _buildProgramHubHome(BuildContext context, bool isDark) {
    final primaryTextColor =
        isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // S17 Header
          Padding(
            padding: const EdgeInsets.only(
              left: V2Spacing.lg,
              right: V2Spacing.lg,
              top: V2Spacing.lg,
              bottom: V2Spacing.sm,
            ),
            child: Text(
              'Program',
              style: V2Typography.display.copyWith(
                color: primaryTextColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          // Two-Segment Switcher: [Katalog Ibadah] / [Ibadah Saya]
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: V2Spacing.lg,
              vertical: V2Spacing.xs,
            ),
            child: Obx(
              () => ProgramSegmentSelector(
                selectedTab: _controller.currentTab,
                onTabSelected: _controller.selectTab,
              ),
            ),
          ),
          const SizedBox(height: V2Spacing.sm),

          // Search Row & '+ Baru' action button
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: V2Spacing.lg,
              vertical: V2Spacing.xs,
            ),
            child: Obx(
              () => ProgramSearchBar(
                query: _controller.searchQuery,
                onChanged: _controller.setSearchQuery,
                onClear: _controller.clearSearch,
                onNewCustomTap:
                    widget.onNewCustomTap ?? _handleNewCustomDefault,
              ),
            ),
          ),
          const SizedBox(height: V2Spacing.sm),

          // Content Area (Katalog vs Ibadah Saya)
          Expanded(
            child: Obx(() {
              if (_controller.currentTab == ProgramHubTab.katalog) {
                return _buildCatalogTabContent(context, isDark);
              } else {
                return _buildMyProgramsTabContent(context, isDark);
              }
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogTabContent(BuildContext context, bool isDark) {
    if (_controller.catalogItems.isEmpty) {
      return const ProgramEmptyState(
        icon: Icons.menu_book_outlined,
        title: 'Katalog Ibadah Belum Tersedia',
        message:
            'Katalog ibadah sedang dipersiapkan dan akan segera dimuat secara lengkap.',
      );
    }

    final filtered = _controller.filteredCatalogItems;
    if (filtered.isEmpty) {
      return ProgramEmptyState(
        icon: Icons.search_off_outlined,
        title: 'Ibadah Tidak Ditemukan',
        message:
            'Tidak ada ibadah yang cocok dengan kata kunci "${_controller.searchQuery}".',
        actionLabel: 'Hapus Pencarian',
        onAction: _controller.clearSearch,
      );
    }

    return ListView.separated(
      key: const ValueKey('v2_program_catalog_list'),
      padding: const EdgeInsets.symmetric(
        horizontal: V2Spacing.lg,
        vertical: V2Spacing.sm,
      ),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: V2Spacing.sm),
      itemBuilder: (context, index) {
        final item = filtered[index];
        return ProgramCatalogCard(
          item: item,
          onTap: _controller.selectItem,
        );
      },
    );
  }

  Widget _buildMyProgramsTabContent(BuildContext context, bool isDark) {
    if (_controller.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_controller.errorMessage != null) {
      return ProgramEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Terjadi Kesalahan',
        message: _controller.errorMessage!,
        actionLabel: 'Muat Ulang',
        onAction: _controller.loadUserPrograms,
      );
    }

    if (_controller.userPrograms.isEmpty) {
      return ProgramEmptyState(
        icon: Icons.calendar_today_outlined,
        title: 'Belum Ada Program Aktif',
        message:
            'Kamu belum memiliki ibadah yang ditargetkan. Pilih ibadah dari katalog untuk memulai perjalanan mujahadahmu.',
        actionLabel: 'Pilih dari Katalog',
        onAction: () => _controller.selectTab(ProgramHubTab.katalog),
      );
    }

    final filtered = _controller.filteredMyPrograms;
    if (filtered.isEmpty) {
      return ProgramEmptyState(
        icon: Icons.search_off_outlined,
        title: 'Program Tidak Ditemukan',
        message:
            'Tidak ada program aktif yang cocok dengan kata kunci "${_controller.searchQuery}".',
        actionLabel: 'Hapus Pencarian',
        onAction: _controller.clearSearch,
      );
    }

    // Display all active/muhasabah programs without an artificial limit
    return ListView.separated(
      key: const ValueKey('v2_program_my_programs_list'),
      padding: const EdgeInsets.symmetric(
        horizontal: V2Spacing.lg,
        vertical: V2Spacing.sm,
      ),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: V2Spacing.sm),
      itemBuilder: (context, index) {
        final program = filtered[index];
        return ProgramActiveCard(
          program: program,
        );
      },
    );
  }

  void _handleNewCustomDefault() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Fitur Tambah Ibadah Kustom (S19) akan hadir pada tahap selanjutnya.',
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
