import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/v2_navigation_controller.dart';
import '../../../controllers/v2_program_hub_controller.dart';
import '../../../core/date/date_service.dart';
import '../../../models/program_v2_model.dart';
import '../../../models/v2_custom_ibadah_draft.dart';
import '../../../models/v2_ibadah_catalog_item.dart';
import '../../../models/v2_program_config_draft.dart';
import '../../../repositories/program_v2_repository.dart';
import '../../../services/program_v2_creation_service.dart';
import '../../../theme/v2_design_tokens.dart';
import 'v2_custom_ibadah_view.dart';
import 'v2_pilih_ibadah_view.dart';
import 'v2_program_config_view.dart';
import 'v2_program_review_view.dart';
import 'widgets/program_active_card.dart';
import 'widgets/program_catalog_card.dart';
import 'widgets/program_empty_state.dart';
import 'widgets/program_search_bar.dart';
import 'widgets/program_segment_selector.dart';

/// Screen S17 — Program Hub coordinator view.
///
/// Implements and coordinates the full Mujahadah Program journey:
/// - S17: Program Hub header, two-segment selector ([Katalog Ibadah] / [Ibadah Saya]),
///   real-time search bar, and '+ Baru' custom creation shortcut (navigating to S19).
/// - S18: Full worship activity detail view with back navigation, Keutamaan bullets,
///   daily-eligibility enforcement, and 'Mulai Program Mujahadah' CTA.
/// - S19: Custom ibadah template definition with typed persistence boundary.
/// - S20: Program target duration (40..365), start date (Hari Ini/Besok), and reminder configuration.
/// - Review Program: Mandatory confirmation step before final creation.
/// - Tab-aware PopScope: never intercepts Android back navigation when Program tab is inactive in App Shell.
/// - Safe GetX controller lifecycle without build-time registrations.
class V2ProgramHubView extends StatefulWidget {
  final V2ProgramHubController? controller;
  final V2NavigationController? navigationController;
  final ProgramV2Repository? programRepository;
  final ProgramV2CreationService? creationService;
  final ProgramCreationCallback? onConfirmCreate;
  final CustomIbadahSaveCallback? onSaveCustomIbadah;
  final ValueChanged<ProgramV2Model>? onProgramCreated;
  final DateService? dateService;
  @Deprecated(
    'Legacy creation callback from MV2-B0-02-05. Direct creation from S18 '
    'is disabled; program creation must pass through S20 and Review Program. '
    'Use onConfirmCreate or creationService instead.',
  )
  final ValueChanged<V2IbadahCatalogItem>? onStartProgram;
  final VoidCallback? onNewCustomTap;
  final bool? wireProgramSetup;

  const V2ProgramHubView({
    super.key,
    this.controller,
    this.navigationController,
    this.programRepository,
    this.creationService,
    this.onConfirmCreate,
    this.onSaveCustomIbadah,
    this.onProgramCreated,
    this.dateService,
    this.onStartProgram,
    this.onNewCustomTap,
    this.wireProgramSetup,
  });

  @override
  State<V2ProgramHubView> createState() => _V2ProgramHubViewState();
}

class _V2ProgramHubViewState extends State<V2ProgramHubView> {
  late V2ProgramHubController _controller;
  V2NavigationController? _navigationController;
  ProgramV2CreationService? _creationService;
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

    _creationService = widget.creationService ??
        (Get.isRegistered<ProgramV2CreationService>()
            ? Get.find<ProgramV2CreationService>()
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
    if (widget.creationService != null &&
        widget.creationService != oldWidget.creationService) {
      _creationService = widget.creationService;
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.onClose();
    }
    super.dispose();
  }

  void _handleBackNavigation() {
    switch (_controller.currentStep) {
      case ProgramScreenStep.programReview:
        _controller.backFromReview();
        break;
      case ProgramScreenStep.programConfig:
        _controller.backFromConfig();
        break;
      case ProgramScreenStep.customIbadah:
        _controller.backFromCustomIbadah();
        break;
      case ProgramScreenStep.catalogDetail:
        _controller.clearSelection();
        break;
      case ProgramScreenStep.hub:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final scaffoldBg = isDark
        ? V2Colors.darkScaffoldBackground
        : V2Colors.lightScaffoldBackground;

    return Obx(() {
      // Tab-aware back navigation:
      // When Program is embedded in an App Shell, check if Program is the currently active tab.
      // When Program is NOT active, its PopScope must never block system Back navigation.
      final isProgramActive = _navigationController == null ||
          _navigationController!.currentTab == V2NavigationTab.program;

      final step = _controller.currentStep;
      final canPop = !isProgramActive || step == ProgramScreenStep.hub;

      return PopScope(
        canPop: canPop,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && isProgramActive) {
            _handleBackNavigation();
          }
        },
        child: Scaffold(
          backgroundColor: scaffoldBg,
          body: _buildCurrentScreen(context, isDark),
        ),
      );
    });
  }

  Widget _buildCurrentScreen(BuildContext context, bool isDark) {
    final step = _controller.currentStep;

    switch (step) {
      case ProgramScreenStep.catalogDetail:
        final selectedItem = _controller.selectedCatalogItem;
        if (selectedItem != null) {
          return V2PilihIbadahView(
            item: selectedItem,
            onBack: _controller.clearSelection,
            onStartProgram: _resolveStartProgramCallback(),
          );
        }
        return _buildProgramHubHome(context, isDark);

      case ProgramScreenStep.customIbadah:
        return V2CustomIbadahView(
          onBack: _controller.backFromCustomIbadah,
          initialDraft: _controller.customDraft,
          persistedItem: _controller.persistedCustomItem,
          onDraftChanged: _controller.updateCustomDraft,
          onSave: widget.onSaveCustomIbadah,
          onSaved: (savedItem) {
            _controller.setPersistedCustomItem(savedItem);
            _controller.addCatalogItem(savedItem);
            _controller.startProgramSetup(savedItem, fromCustom: true);
          },
        );

      case ProgramScreenStep.programConfig:
        final configItem = _controller.configuringItem;
        if (configItem != null) {
          return V2ProgramConfigView(
            item: configItem,
            initialDraft: _controller.configDraft,
            dateService: widget.dateService,
            onBack: _controller.backFromConfig,
            onProceedToReview: (draft) {
              _controller.updateConfigDraft(draft);
              _controller.openReview();
            },
          );
        }
        return _buildProgramHubHome(context, isDark);

      case ProgramScreenStep.programReview:
        final reviewItem = _controller.configuringItem;
        if (reviewItem != null) {
          return V2ProgramReviewView(
            item: reviewItem,
            draft: _controller.configDraft,
            dateService: widget.dateService,
            creationService: _creationService,
            onConfirmCreate: widget.onConfirmCreate,
            onBackAndEdit: _controller.backFromReview,
            onProgramCreated: (program) {
              _controller.resetCustomDraft();
              _controller.loadUserPrograms();
              _controller.selectTab(ProgramHubTab.ibadahSaya);
              _controller.clearSelection();
              widget.onProgramCreated?.call(program);
            },
          );
        }
        return _buildProgramHubHome(context, isDark);

      case ProgramScreenStep.hub:
        return _buildProgramHubHome(context, isDark);
    }
  }

  ValueChanged<V2IbadahCatalogItem>? _resolveStartProgramCallback() {
    if (widget.wireProgramSetup == false) {
      return null;
    }

    final setupEnabled = widget.wireProgramSetup == true ||
        _creationService != null ||
        widget.onConfirmCreate != null;

    if (!setupEnabled) {
      return null;
    }

    return (item) => _controller.startProgramSetup(item);
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
                    widget.onNewCustomTap ?? _controller.openCustomIbadah,
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
}
