import 'package:get/get.dart';

import '../models/program_v2_model.dart';
import '../models/v2_ibadah_catalog_item.dart';
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

/// Controller coordinating V2 Program Hub (S17) and Pilih Ibadah (S18).
///
/// Responsibilities:
/// 1. Manages Program Hub segment switching (Katalog Ibadah / Ibadah Saya).
/// 2. Manages real-time search across catalog items and active user programs.
/// 3. Projects active programs from [ProgramV2Repository] without domain mutations.
/// 4. Handles S18 selection by item reference or stable ID.
/// 5. Ensures PENDING_FAILURE programs are surfaced as requiring Muhasabah,
///    while terminal programs (FAILED, WARNING, SUCCESS) are excluded from active list.
class V2ProgramHubController extends GetxController {
  final ProgramV2Repository? _programRepository;

  final Rx<ProgramHubTab> _currentTab;
  final RxString _searchQuery = ''.obs;
  final RxList<V2IbadahCatalogItem> _catalogItems = <V2IbadahCatalogItem>[].obs;
  final RxList<ProgramV2Model> _userPrograms = <ProgramV2Model>[].obs;
  final Rxn<V2IbadahCatalogItem> _selectedCatalogItem =
      Rxn<V2IbadahCatalogItem>();
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

  /// Current active search filter.
  String get searchQuery => _searchQuery.value;

  /// All registered catalog items.
  List<V2IbadahCatalogItem> get catalogItems => _catalogItems;

  /// All projected active user programs.
  List<ProgramV2Model> get userPrograms => _userPrograms;

  /// Currently selected catalog item for S18 detail, or null if on hub.
  V2IbadahCatalogItem? get selectedCatalogItem => _selectedCatalogItem.value;

  /// Whether S18 detail view is currently open.
  bool get isDetailOpen => _selectedCatalogItem.value != null;

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

  /// Selects an ibadah item to navigate to S18 Pilih Ibadah.
  void selectItem(V2IbadahCatalogItem item) {
    _selectedCatalogItem.value = item;
  }

  /// Selects an ibadah item by its stable unique ID.
  /// Returns `true` if item was found and selected, `false` otherwise.
  bool selectItemById(String id) {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return false;
    final match = _catalogItems.firstWhereOrNull((item) => item.id == cleanId);
    if (match != null) {
      _selectedCatalogItem.value = match;
      return true;
    }
    return false;
  }

  /// Clears selection and navigates back from S18 to S17 Program Hub.
  void clearSelection() {
    _selectedCatalogItem.value = null;
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
