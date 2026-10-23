import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/v2_history_controller.dart';
import '../../../controllers/v2_navigation_controller.dart';
import '../../../controllers/v2_program_hub_controller.dart';
import '../../../models/program_v2_model.dart';
import '../../../repositories/failure_record_v2_repository.dart';
import '../../../repositories/program_v2_repository.dart';
import '../../../services/daily_checkin_v2_service.dart';
import '../../../theme/v2_design_tokens.dart';
import 'v2_history_detail_view.dart';
import 'widgets/history_card.dart';
import 'widgets/history_empty_state.dart';

/// Screen S23 — History / Riwayat V2 tab view.
///
/// Features:
/// - Projects terminal programs exclusively (SUCCESS, WARNING, FAILED) with active programs filtered out.
/// - Four-category segmented filter (Semua, Selesai, Hampir Selesai, Belum Selesai) with live counts.
/// - Deterministic newest-first sorting with tie-break stability.
/// - Detail view transition for in-depth evaluation and review.
/// - Gated "Mulai Lagi" action propagating through S20 -> Review -> Domain Creation.
/// - Tab-aware PopScope respecting App Shell navigation.
class V2HistoryView extends StatefulWidget {
  final V2HistoryController? controller;
  final V2NavigationController? navigationController;
  final ProgramV2Repository? programRepository;
  final FailureRecordV2Repository? failureRecordRepository;
  final DailyCheckInV2Service? dailyCheckInService;
  final V2ProgramHubController? programHubController;
  final ValueChanged<ProgramV2Model>? onRestartProgram;

  const V2HistoryView({
    super.key,
    this.controller,
    this.navigationController,
    this.programRepository,
    this.failureRecordRepository,
    this.dailyCheckInService,
    this.programHubController,
    this.onRestartProgram,
  });

  @override
  State<V2HistoryView> createState() => _V2HistoryViewState();
}

class _V2HistoryViewState extends State<V2HistoryView>
    with WidgetsBindingObserver {
  late V2HistoryController _controller;
  V2NavigationController? _navigationController;
  ProgramV2Repository? _programRepository;
  V2ProgramHubController? _programHubController;
  bool _ownsController = false;
  Worker? _tabWorker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDependencies();
    _bindTabListener();
  }

  void _bindTabListener() {
    _tabWorker?.dispose();
    if (_navigationController != null) {
      _tabWorker = ever(_navigationController!.currentTabRx, (tab) {
        if (tab == V2NavigationTab.history) {
          _controller.loadHistory(silent: true);
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final isHistoryActive = _navigationController == null ||
          _navigationController!.currentTab == V2NavigationTab.history;
      if (isHistoryActive) {
        _controller.loadHistory(silent: true);
      }
    }
  }

  void _initDependencies() {
    _navigationController = widget.navigationController ??
        (Get.isRegistered<V2NavigationController>()
            ? Get.find<V2NavigationController>()
            : null);

    _programRepository = widget.programRepository ??
        (Get.isRegistered<ProgramV2Repository>()
            ? Get.find<ProgramV2Repository>()
            : null);

    final failureRepo = widget.failureRecordRepository ??
        (Get.isRegistered<FailureRecordV2Repository>()
            ? Get.find<FailureRecordV2Repository>()
            : null);

    final checkInService = widget.dailyCheckInService ??
        (Get.isRegistered<DailyCheckInV2Service>()
            ? Get.find<DailyCheckInV2Service>()
            : null);

    _programHubController = widget.programHubController ??
        (Get.isRegistered<V2ProgramHubController>()
            ? Get.find<V2ProgramHubController>()
            : null);

    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else if (Get.isRegistered<V2HistoryController>()) {
      _controller = Get.find<V2HistoryController>();
      _ownsController = false;
    } else {
      _controller = V2HistoryController(
        programRepository: _programRepository,
        failureRecordRepository: failureRepo,
        dailyCheckInService: checkInService,
      );
      _ownsController = true;
    }
  }

  @override
  void didUpdateWidget(V2HistoryView oldWidget) {
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
      _bindTabListener();
    }
    if (widget.programHubController != null) {
      _programHubController = widget.programHubController;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabWorker?.dispose();
    if (_ownsController) {
      _controller.onClose();
    }
    super.dispose();
  }

  void _handleRestartTap(ProgramV2Model sourceProgram) {
    // 1. Terminal status verification
    final isTerminal = sourceProgram.status == ProgramV2Model.statusSuccess ||
        sourceProgram.status == ProgramV2Model.statusWarning ||
        sourceProgram.status == ProgramV2Model.statusFailed;
    if (!isTerminal) {
      _showNoticeDialog(
        title: 'Tidak Dapat Memulai Ulang',
        message:
            'Hanya program yang sudah selesai atau terhenti yang dapat dimulai ulang.',
      );
      return;
    }

    // 2. Duplicate active program guard
    final repo = _programRepository ??
        (Get.isRegistered<ProgramV2Repository>()
            ? Get.find<ProgramV2Repository>()
            : null);
    if (repo != null &&
        repo.hasActiveOrPendingProgram(sourceProgram.ibadahId)) {
      _showNoticeDialog(
        title: 'Program Masih Aktif',
        message:
            'Program aktif untuk ibadah "${sourceProgram.ibadahNameSnapshot}" masih berjalan. Selesaikan atau evaluasi program aktif terlebih dahulu.',
      );
      return;
    }

    // 3. External callback override (e.g. for testing)
    if (widget.onRestartProgram != null) {
      widget.onRestartProgram!(sourceProgram);
      return;
    }

    // 4. Resolve verified catalog template
    final hubCtrl = _programHubController ??
        (Get.isRegistered<V2ProgramHubController>()
            ? Get.find<V2ProgramHubController>()
            : null);

    if (hubCtrl == null) {
      _showNoticeDialog(
        title: 'Layanan Belum Tersedia',
        message:
            'Layanan konfigurasi program belum terhubung. Silakan coba lagi nanti.',
      );
      return;
    }

    final catalogItem = hubCtrl.catalogItems.firstWhereOrNull(
      (item) => item.id == sourceProgram.ibadahId,
    );

    if (catalogItem == null || !catalogItem.isDailyEligible) {
      _showNoticeDialog(
        title: 'Template Tidak Tersedia',
        message:
            'Template ibadah untuk program ini tidak ditemukan dalam katalog aktif atau tidak memenuhi syarat harian.',
      );
      return;
    }

    // 5. Initiate restart configuration and navigate to Program tab
    hubCtrl.startRestartProgramSetup(catalogItem, sourceProgram);

    final navCtrl = _navigationController ??
        (Get.isRegistered<V2NavigationController>()
            ? Get.find<V2NavigationController>()
            : null);
    if (navCtrl != null) {
      navCtrl.selectTab(V2NavigationTab.program);
    }
  }

  void _showNoticeDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(message),
        actions: [
          TextButton(
            key: const ValueKey('v2_history_notice_ok_button'),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final scaffoldBg = isDark
        ? V2Colors.darkScaffoldBackground
        : V2Colors.lightScaffoldBackground;

    return Obx(() {
      final isHistoryActive = _navigationController == null ||
          _navigationController!.currentTab == V2NavigationTab.history;

      final isDetailOpen = _controller.isDetailOpen;
      final canPop = !isHistoryActive || !isDetailOpen;

      return PopScope(
        canPop: canPop,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && isHistoryActive && isDetailOpen) {
            _controller.clearSelectedProgram();
          }
        },
        child: Scaffold(
          backgroundColor: scaffoldBg,
          body: isDetailOpen
              ? _buildDetailView()
              : _buildHistoryHome(context, isDark),
        ),
      );
    });
  }

  Widget _buildDetailView() {
    final selectedProg = _controller.selectedProgram!;
    return V2HistoryDetailView(
      program: selectedProg,
      progress: _controller.getCachedProgress(selectedProg.id),
      failureRecord: _controller.getCachedFailureRecord(selectedProg.id),
      onBack: _controller.clearSelectedProgram,
      onRestartTap: _handleRestartTap,
    );
  }

  Widget _buildHistoryHome(BuildContext context, bool isDark) {
    final primaryTextColor =
        isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(
              left: V2Spacing.lg,
              right: V2Spacing.lg,
              top: V2Spacing.lg,
              bottom: V2Spacing.xs,
            ),
            child: Text(
              'Riwayat',
              key: const ValueKey('v2_history_screen_title'),
              style: V2Typography.display.copyWith(
                color: primaryTextColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          // Filter Chips Row
          _buildFilterChips(context, isDark),
          const SizedBox(height: V2Spacing.sm),

          // Content Area (Loading / Error / Empty / List)
          Expanded(
            child: _buildHistoryContent(context, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: V2Spacing.lg,
        vertical: V2Spacing.xs,
      ),
      child: Obx(
        () => Row(
          children: [
            _buildFilterChip(
              filter: HistoryFilter.all,
              count: _controller.countAll,
              isDark: isDark,
            ),
            const SizedBox(width: V2Spacing.sm),
            _buildFilterChip(
              filter: HistoryFilter.success,
              count: _controller.countSuccess,
              isDark: isDark,
            ),
            const SizedBox(width: V2Spacing.sm),
            _buildFilterChip(
              filter: HistoryFilter.warning,
              count: _controller.countWarning,
              isDark: isDark,
            ),
            const SizedBox(width: V2Spacing.sm),
            _buildFilterChip(
              filter: HistoryFilter.failed,
              count: _controller.countFailed,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required HistoryFilter filter,
    required int count,
    required bool isDark,
  }) {
    final isSelected = _controller.selectedFilter == filter;
    final activeColor = isDark ? V2Colors.mint : V2Colors.deepTosca;
    final inactiveBorder = isDark ? V2Colors.darkBorder : V2Colors.lightBorder;

    final labelText = '${filter.label} ($count)';

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: ChoiceChip(
        key: ValueKey('v2_history_filter_${filter.name}'),
        label: Text(labelText),
        selected: isSelected,
        onSelected: (_) => _controller.selectFilter(filter),
        selectedColor: isDark
            ? V2Colors.mint.withValues(alpha: 0.25)
            : V2Colors.deepTosca.withValues(alpha: 0.15),
        backgroundColor:
            isDark ? V2Colors.darkSurfaceCard : V2Colors.lightSurfaceCard,
        side: BorderSide(
          color: isSelected ? activeColor : inactiveBorder,
        ),
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected
              ? activeColor
              : (isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary),
        ),
      ),
    );
  }

  Widget _buildHistoryContent(BuildContext context, bool isDark) {
    return Obx(() {
      if (_controller.isLoading) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }

      if (_controller.errorMessage != null) {
        return HistoryEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Gagal Memuat Riwayat',
          message: _controller.errorMessage!,
          actionLabel: 'Coba Lagi',
          onAction: _controller.loadHistory,
        );
      }

      if (_controller.countAll == 0) {
        return const HistoryEmptyState(
          icon: Icons.history_rounded,
          title: 'Belum Ada Riwayat',
          message:
              'Program mujahadah yang telah selesai atau telah dievaluasi akan dicatat dan muncul di sini.',
        );
      }

      final filtered = _controller.filteredPrograms;
      if (filtered.isEmpty) {
        return HistoryEmptyState(
          icon: Icons.filter_alt_off_outlined,
          title: 'Tidak Ada Riwayat',
          message:
              'Tidak ada program dengan status "${_controller.selectedFilter.label}" dalam riwayatmu.',
          actionLabel: 'Lihat Semua',
          onAction: () => _controller.selectFilter(HistoryFilter.all),
        );
      }

      return ListView.separated(
        key: const ValueKey('v2_history_list'),
        padding: const EdgeInsets.symmetric(
          horizontal: V2Spacing.lg,
          vertical: V2Spacing.sm,
        ),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: V2Spacing.sm),
        itemBuilder: (context, index) {
          final program = filtered[index];
          return Obx(
            () => HistoryCard(
              program: program,
              progress: _controller.getCachedProgress(program.id),
              failureRecord: _controller.getCachedFailureRecord(program.id),
              onTap: () => _controller.selectProgram(program),
            ),
          );
        },
      );
    });
  }
}
