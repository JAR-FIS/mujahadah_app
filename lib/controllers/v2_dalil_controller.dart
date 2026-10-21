import 'package:get/get.dart';
import '../models/dalil_item.dart';

/// Presentation controller for S15 (Dalil Home) and S16 (Detail Dalil).
///
/// Responsibilities:
/// 1. Maintain active category filter (Semua / Al-Qur'an / Hadits / Kisah).
/// 2. Provide filtered Dalil presentation list.
/// 3. Manage navigation state to S16 Detail Dalil while preserving active filter.
/// 4. Provide related Dalil items for the active detail item.
/// 5. Support honest empty states when no catalog data is loaded.
/// 6. Guarantee zero storage mutations, Hive writes, or V1 side effects.
class V2DalilController extends GetxController {
  final List<DalilItem>? _initialItems;

  // --- Observables ---

  final Rx<DalilCategory> _selectedCategory = DalilCategory.all.obs;
  DalilCategory get selectedCategory => _selectedCategory.value;

  final RxList<DalilItem> _items = <DalilItem>[].obs;
  List<DalilItem> get items => _items;

  final Rxn<DalilItem> _selectedItem = Rxn<DalilItem>();
  DalilItem? get selectedItem => _selectedItem.value;

  final RxBool _isLoading = false.obs;
  bool get isLoading => _isLoading.value;

  final RxBool _hasError = false.obs;
  bool get hasError => _hasError.value;

  final RxnString _errorMessage = RxnString();
  String? get errorMessage => _errorMessage.value;

  V2DalilController({
    List<DalilItem>? initialItems,
    DalilCategory initialCategory = DalilCategory.all,
  }) : _initialItems = initialItems {
    _selectedCategory.value = initialCategory;
    if (_initialItems != null) {
      _items.assignAll(_initialItems!);
    }
  }

  /// Filtered items based on currently selected category.
  List<DalilItem> get filteredItems {
    if (_selectedCategory.value == DalilCategory.all) {
      return _items.toList();
    }
    return _items
        .where((item) => item.category == _selectedCategory.value)
        .toList();
  }

  /// Sets the active category filter.
  void selectCategory(DalilCategory category) {
    _selectedCategory.value = category;
  }

  /// Selects an item for S16 Detail presentation.
  void selectDalil(DalilItem item) {
    _selectedItem.value = item;
  }

  /// Clears selected item and returns to S15 List, preserving category filter.
  void clearSelection() {
    _selectedItem.value = null;
  }

  /// Returns related items in the same category, excluding the current item.
  List<DalilItem> getRelatedItems(DalilItem currentItem, {int limit = 2}) {
    return _items
        .where((item) =>
            item.category == currentItem.category && item.id != currentItem.id)
        .take(limit)
        .toList();
  }

  /// Explicitly loads or replaces items (e.g. from future Excel import service).
  void loadItems(List<DalilItem> newItems) {
    _items.assignAll(newItems);
  }
}
