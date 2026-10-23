import 'package:get/get.dart';

/// Five primary V2 navigation destinations in locked sequence.
enum V2NavigationTab {
  dashboard,
  dalil,
  program,
  history,
  akun;

  String get label {
    switch (this) {
      case V2NavigationTab.dashboard:
        return 'Dashboard';
      case V2NavigationTab.dalil:
        return 'Dalil';
      case V2NavigationTab.program:
        return 'Program';
      case V2NavigationTab.history:
        return 'Riwayat';
      case V2NavigationTab.akun:
        return 'Akun';
    }
  }
}

/// Pure UI navigation controller managing the 5-tab App Shell state.
///
/// Architectural Guarantees:
/// 1. Exactly 5 tab destinations in locked order: Dashboard (0), Dalil (1), Program (2), History (3), Akun (4).
/// 2. Manages UI presentation state exclusively; contains zero domain, Hive, or database logic.
/// 3. Resilient against out-of-bounds tab indices or redundant taps.
/// 4. Decoupled from widget build cycles to prevent duplicate registrations or leaks.
class V2NavigationController extends GetxController {
  final Rx<V2NavigationTab> _currentTab;

  V2NavigationController(
      {V2NavigationTab initialTab = V2NavigationTab.dashboard})
      : _currentTab = initialTab.obs;

  /// Currently selected tab enum.
  V2NavigationTab get currentTab => _currentTab.value;

  /// Reactive stream for observing tab transitions across views.
  Rx<V2NavigationTab> get currentTabRx => _currentTab;

  /// Index of the currently selected tab (0 through 4).
  int get currentIndex => _currentTab.value.index;

  /// Changes navigation to the specified index if within valid 0..4 bounds.
  void changeTab(int index) {
    if (index >= 0 && index < V2NavigationTab.values.length) {
      _currentTab.value = V2NavigationTab.values[index];
    }
  }

  /// Explicitly selects a [V2NavigationTab].
  void selectTab(V2NavigationTab tab) {
    _currentTab.value = tab;
  }
}
