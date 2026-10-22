import 'package:get/get.dart';

import '../models/program_v2_model.dart';
import '../models/v2_custom_ibadah_draft.dart';
import '../models/v2_ibadah_catalog_item.dart';
import '../models/v2_program_config_draft.dart';
import '../repositories/program_v2_repository.dart';

/// Top-level tabs for V2 Program Hub (Screen S17).
enum ProgramHubTab {
  katalog,
  ibadahSaya;

  String get label {
    switch (this) {
      case ProgramHubTab.katalog:
        return 'Katalog Ibadah';
      case ProgramHubTab.ibadahSaya:
        return 'Ibadah Saya';
    }
  }
}

/// Navigation steps within the Program Hub workflow.
enum ProgramScreenStep {
  hub, // S17: Program Hub Home (Katalog / Ibadah Saya)
  catalogDetail, // S18: Detail & Keutamaan
  customIbadah, // S19: Tambah Ibadah Kustom
  programConfig, // S20: Konfigurasi Target & Durasi Program
  programReview, // Review Program: Konfirmasi Mandatori
  programDetail, // S21: Detail Program & Daily Check-in
}

/// Controller coordinating V2 Program Hub (S17), Pilih Ibadah (S18),
/// Tambah Ibadah Kustom (S19), Konfigurasi Program (S20), Review Program,
/// and Program Detail (S21).
///
/// Responsibilities:
/// 1. Manages Program Hub segment switching (Katalog Ibadah / Ibadah Saya).
/// 2. Manages real-time search across catalog items and active user programs.
/// 3. Projects active programs from [ProgramV2Repository] without domain mutations.
/// 4. Coordinates step navigation: S17 -> S18 -> S20 -> Review -> Hub, S17 -> S19 -> S20,
///    and S17 (Ibadah Saya) -> S21 Program Detail.
/// 5. Maintains configuration draft state across "Kembali & Edit" navigation.
/// 6. Clears stale draft state when switching to a different ibadah.
/// 7. Ensures PENDING_FAILURE programs are surfaced as requiring Muhasabah,
///    while terminal programs (FAILED, WARNING, SUCCESS) are excluded from active list.
class V2ProgramHubController extends GetxController {
  final ProgramV2Repository? _programRepository;

  final Rx<ProgramHubTab> _currentTab;
  final Rx<ProgramScreenStep> _currentStep = ProgramScreenStep.hub.obs;
  final RxString _searchQuery = ''.obs;
  final RxList<V2IbadahCatalogItem> _catalogItems = <V2IbadahCatalogItem>[].obs;
  final RxList<ProgramV2Model> _userPrograms = <ProgramV2Model>[].obs;
  final Rxn<V2IbadahCatalogItem> _selectedCatalogItem =
      Rxn<V2IbadahCatalogItem>();
  final Rxn<V2IbadahCatalogItem> _configuringItem = Rxn<V2IbadahCatalogItem>();
  final Rxn<ProgramV2Model> _selectedProgram = Rxn<ProgramV2Model>();
  final Rx<V2ProgramConfigDraft> _configDraft =
      const V2ProgramConfigDraft().obs;
  final Rxn<V2CustomIbadahDraft> _customDraft = Rxn<V2CustomIbadahDraft>();
  final Rxn<V2IbadahCatalogItem> _persistedCustomItem =
      Rxn<V2IbadahCatalogItem>();
  final RxBool _isCustomSource = false.obs;
  final RxBool _isLoading = false.obs;
  final RxnString _errorMessage = RxnString();

  V2ProgramHubController({
    ProgramV2Repository? programRepository,
    List<V2IbadahCatalogItem>? initialCatalog,
    ProgramHubTab initialTab = ProgramHubTab.katalog,
  })  : _programRepository = programRepository,
        _currentTab = initialTab.obs {
    if (initialCatalog != null) {
      _catalogItems.assignAll(initialCatalog);
    }
    loadUserPrograms();
  }

  /// Current active hub tab.
  ProgramHubTab get currentTab => _currentTab.value;

  /// Current active screen step.
  ProgramScreenStep get currentStep => _currentStep.value;

  /// Current active search filter.
  String get searchQuery => _searchQuery.value;

  /// All registered catalog items.
  List<V2IbadahCatalogItem> get catalogItems => _catalogItems;

  /// All projected active user programs.
  List<ProgramV2Model> get userPrograms => _userPrograms;

  /// Currently selected catalog item for S18 detail, or null if on hub.
  V2IbadahCatalogItem? get selectedCatalogItem => _selectedCatalogItem.value;

  /// Currently configuring item for S20 / Review.
  V2IbadahCatalogItem? get configuringItem => _configuringItem.value;

  /// Currently selected user program for S21 Program Detail, or null if on hub.
  ProgramV2Model? get selectedProgram => _selectedProgram.value;

  /// Current program configuration draft.
  V2ProgramConfigDraft get configDraft => _configDraft.value;

  /// Current custom ibadah draft (S19).
  V2CustomIbadahDraft? get customDraft => _customDraft.value;

  /// Persisted custom ibadah template from successful save, if any.
  V2IbadahCatalogItem? get persistedCustomItem => _persistedCustomItem.value;

  /// Whether S18 detail view is currently open.
  bool get isDetailOpen => _selectedCatalogItem.value != null;

  /// Whether S19 custom ibadah view is currently open.
  bool get isCustomIbadahOpen =>
      _currentStep.value == ProgramScreenStep.customIbadah;

  /// Whether S20 configuration view is currently open.
  bool get isConfigOpen =>
      _currentStep.value == ProgramScreenStep.programConfig;

  /// Whether Review Program view is currently open.
  bool get isReviewOpen =>
      _currentStep.value == ProgramScreenStep.programReview;

  /// Whether S21 Program Detail view is currently open.
  bool get isProgramDetailOpen =>
      _currentStep.value == ProgramScreenStep.programDetail;

  /// Whether programs are currently being loaded.
  bool get isLoading => _isLoading.value;

  /// Error message from loading failure, if any.
  String? get errorMessage => _errorMessage.value;

  /// Switch the active tab between Katalog Ibadah and Ibadah Saya.
  void selectTab(ProgramHubTab tab) {
    _currentTab.value = tab;
  }

  /// Updates the search query filter.
  void setSearchQuery(String query) {
    _searchQuery.value = query;
  }

  /// Clears the active search query.
  void clearSearch() {
    _searchQuery.value = '';
  }

  /// Navigates to S19 Tambah Ibadah Kustom.
  /// When [isNew] is true, clears any prior draft and persisted template state
  /// so that a genuinely new custom ibadah flow starts with a clean slate.
  void openCustomIbadah({bool isNew = false}) {
    if (isNew) {
      resetCustomDraft();
    }
    _currentStep.value = ProgramScreenStep.customIbadah;
  }

  /// Resets custom ibadah draft and persisted custom template state.
  void resetCustomDraft() {
    _customDraft.value = null;
    _persistedCustomItem.value = null;
  }

  /// Updates the persisted custom item reference after a successful save.
  void setPersistedCustomItem(V2IbadahCatalogItem? item) {
    _persistedCustomItem.value = item;
  }

  /// Returns from S19 to S17 Hub while preserving current custom draft.
  void backFromCustomIbadah() {
    _currentStep.value = ProgramScreenStep.hub;
  }

  /// Updates the stored custom ibadah draft.
  void updateCustomDraft(V2CustomIbadahDraft draft) {
    _customDraft.value = draft;
  }

  /// Selects an ibadah item to navigate to S18 Pilih Ibadah.
  void selectItem(V2IbadahCatalogItem item) {
    _selectedCatalogItem.value = item;
    _currentStep.value = ProgramScreenStep.catalogDetail;
  }

  /// Selects an ibadah item by its stable unique ID.
  /// Returns `true` if item was found and selected, `false` otherwise.
  bool selectItemById(String id) {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return false;
    final match = _catalogItems.firstWhereOrNull((item) => item.id == cleanId);
    if (match != null) {
      selectItem(match);
      return true;
    }
    return false;
  }

  /// Begins S20 configuration for [item].
  ///
  /// Resets configuration draft when switching to a different ibadah,
  /// preventing stale duration or reminder values from bleeding across items.
  void startProgramSetup(V2IbadahCatalogItem item, {bool fromCustom = false}) {
    if (_configuringItem.value?.id != item.id) {
      _configDraft.value = V2ProgramConfigDraft(
        targetDays: item.defaultTargetDays >= 40 ? item.defaultTargetDays : 40,
      );
    }
    _configuringItem.value = item;
    _isCustomSource.value = fromCustom;
    _currentStep.value = ProgramScreenStep.programConfig;
  }

  /// Updates the active program configuration draft.
  void updateConfigDraft(V2ProgramConfigDraft draft) {
    _configDraft.value = draft;
  }

  /// Navigates from S20 to Review Program.
  void openReview() {
    _currentStep.value = ProgramScreenStep.programReview;
  }

  /// Navigates backwards from Review Program to S20 (preserves draft).
  void backFromReview() {
    _currentStep.value = ProgramScreenStep.programConfig;
  }

  /// Navigates backwards from S20 to previous screen.
  void backFromConfig() {
    if (_isCustomSource.value) {
      _currentStep.value = ProgramScreenStep.customIbadah;
    } else if (_selectedCatalogItem.value != null) {
      _currentStep.value = ProgramScreenStep.catalogDetail;
    } else {
      _currentStep.value = ProgramScreenStep.hub;
    }
  }

  /// Navigates to S21 Program Detail for [program].
  void openProgramDetail(ProgramV2Model program) {
    _selectedProgram.value = program;
    _currentStep.value = ProgramScreenStep.programDetail;
  }

  /// Selects and navigates to S21 Program Detail by [programId].
  /// Returns `true` if program was found and opened, `false` otherwise.
  bool openProgramDetailById(String programId) {
    final cleanId = programId.trim();
    if (cleanId.isEmpty) return false;

    final match = _userPrograms.firstWhereOrNull((p) => p.id == cleanId);
    if (match != null) {
      openProgramDetail(match);
      return true;
    }

    final fromRepo = _programRepository?.getById(cleanId);
    if (fromRepo != null) {
      openProgramDetail(fromRepo);
      return true;
    }

    return false;
  }

  /// Navigates backwards from S21 Program Detail to S17 Program Hub.
  void backFromProgramDetail() {
    _selectedProgram.value = null;
    _currentStep.value = ProgramScreenStep.hub;
  }

  /// Clears selection and navigates back to S17 Program Hub.
  void clearSelection() {
    _selectedCatalogItem.value = null;
    _configuringItem.value = null;
    _selectedProgram.value = null;
    _currentStep.value = ProgramScreenStep.hub;
  }

  /// Adds a newly persisted custom catalog item to the local catalog list.
  void addCatalogItem(V2IbadahCatalogItem item) {
    final index = _catalogItems.indexWhere((i) => i.id == item.id);
    if (index >= 0) {
      _catalogItems[index] = item;
    } else {
      _catalogItems.insert(0, item);
    }
  }

  /// Injects or updates the catalog items.
  void setCatalog(List<V2IbadahCatalogItem> items) {
    _catalogItems.assignAll(items);
  }

  /// Loads or refreshes active programs from the repository.
  ///
  /// Filters only ACTIVE and PENDING_FAILURE programs.
  /// Terminal states (FAILED, WARNING, SUCCESS) are never presented as active.
  void loadUserPrograms() {
    final repo = _programRepository;
    if (repo == null) {
      _userPrograms.clear();
      return;
    }
    try {
      _isLoading.value = true;
      _errorMessage.value = null;
      final all = repo.getAll();
      final active = all
          .where((p) =>
              p.status == ProgramV2Model.statusActive ||
              p.status == ProgramV2Model.statusPendingFailure)
          .toList();
      _userPrograms.assignAll(active);
    } catch (_) {
      _errorMessage.value = 'Gagal memuat program aktif. Silakan coba lagi.';
    } finally {
      _isLoading.value = false;
    }
  }

  /// Filtered catalog items matching [searchQuery] across name, category, or description.
  List<V2IbadahCatalogItem> get filteredCatalogItems {
    final query = _searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) {
      return _catalogItems;
    }
    return _catalogItems.where((item) {
      final name = item.namaIbadah.toLowerCase();
      final cat = item.category.label.toLowerCase();
      final desc = item.deskripsi.toLowerCase();
      return name.contains(query) ||
          cat.contains(query) ||
          desc.contains(query);
    }).toList();
  }

  /// Filtered active user programs matching [searchQuery] on ibadah name.
  List<ProgramV2Model> get filteredMyPrograms {
    final query = _searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) {
      return _userPrograms;
    }
    return _userPrograms.where((p) {
      final name = p.ibadahNameSnapshot.toLowerCase();
      return name.contains(query);
    }).toList();
  }
}
