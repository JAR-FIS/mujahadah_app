import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/v2_navigation_controller.dart';
import '../../../theme/v2_design_tokens.dart';
import '../dalil/v2_dalil_view.dart';
import '../dashboard/v2_dashboard_view.dart';
import '../placeholders/v2_placeholders.dart';
import '../program/v2_program_hub_view.dart';

/// Isolated V2 App Shell implementing the approved 5-tab navigation foundation.
///
/// Tab Structure (Locked Order):
/// 0. Dashboard (S08)
/// 1. Dalil (S15)
/// 2. Program Hub (S17) — Center highlighted plus action
/// 3. History / Riwayat (S23)
/// 4. Akun (S26)
///
/// Lifecycle & Memory Safety:
/// - Never calls `Get.put()` inside widget build methods.
/// - Supports injected controller or lazily registered GetX controller without duplicate instances.
/// - Preserves state across tab transitions using [IndexedStack].
/// - Enforces safe-area insets and accessible touch targets (>= 48x48 dp).
class V2AppShell extends StatefulWidget {
  final V2NavigationController? controller;
  final Widget? dashboard;
  final Widget? dalil;
  final Widget? program;
  final bool? wireProgramSetup;

  const V2AppShell({
    super.key,
    this.controller,
    this.dashboard,
    this.dalil,
    this.program,
    this.wireProgramSetup,
  });

  @override
  State<V2AppShell> createState() => _V2AppShellState();
}

class _V2AppShellState extends State<V2AppShell> {
  late final V2NavigationController _navigationController;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _navigationController = widget.controller!;
      _ownsController = false;
    } else if (Get.isRegistered<V2NavigationController>()) {
      _navigationController = Get.find<V2NavigationController>();
      _ownsController = false;
    } else {
      _navigationController = V2NavigationController();
      _ownsController = true;
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _navigationController.dispose();
    }
    super.dispose();
  }

  List<Widget> get _destinations => [
        widget.dashboard ??
            V2DashboardView(navigationController: _navigationController),
        widget.dalil ??
            V2DalilView(navigationController: _navigationController),
        widget.program ??
            V2ProgramHubView(
              navigationController: _navigationController,
              wireProgramSetup: widget.wireProgramSetup ?? true,
            ),
        const V2HistoryPlaceholder(),
        const V2AkunPlaceholder(),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        child: Obx(
          () => IndexedStack(
            index: _navigationController.currentIndex,
            children: _destinations,
          ),
        ),
      ),
      bottomNavigationBar: V2BottomNavigationBar(
        controller: _navigationController,
      ),
    );
  }
}

/// Custom V2 Bottom Navigation Bar with elevated center action.
class V2BottomNavigationBar extends StatelessWidget {
  final V2NavigationController controller;

  const V2BottomNavigationBar({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor =
        isDark ? V2Colors.darkSurface : V2Colors.lightSurface;
    final borderColor = isDark ? V2Colors.darkBorder : V2Colors.lightBorder;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          top: BorderSide(
            color: borderColor,
            width: 1.0,
          ),
        ),
        boxShadow: isDark ? V2Elevation.darkSubtle : V2Elevation.lightSubtle,
      ),
      child: SafeArea(
        top: false,
        child: Obx(() {
          final currentTab = controller.currentTab;

          return SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  tab: V2NavigationTab.dashboard,
                  unselectedIcon: Icons.dashboard_outlined,
                  selectedIcon: Icons.dashboard,
                  isSelected: currentTab == V2NavigationTab.dashboard,
                  isDark: isDark,
                ),
                _buildNavItem(
                  tab: V2NavigationTab.dalil,
                  unselectedIcon: Icons.menu_book_outlined,
                  selectedIcon: Icons.menu_book,
                  isSelected: currentTab == V2NavigationTab.dalil,
                  isDark: isDark,
                ),
                _buildCenterProgramItem(
                  isSelected: currentTab == V2NavigationTab.program,
                  isDark: isDark,
                ),
                _buildNavItem(
                  tab: V2NavigationTab.history,
                  unselectedIcon: Icons.history_outlined,
                  selectedIcon: Icons.history,
                  isSelected: currentTab == V2NavigationTab.history,
                  isDark: isDark,
                ),
                _buildNavItem(
                  tab: V2NavigationTab.akun,
                  unselectedIcon: Icons.person_outline,
                  selectedIcon: Icons.person,
                  isSelected: currentTab == V2NavigationTab.akun,
                  isDark: isDark,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNavItem({
    required V2NavigationTab tab,
    required IconData unselectedIcon,
    required IconData selectedIcon,
    required bool isSelected,
    required bool isDark,
  }) {
    final selectedColor = isDark ? V2Colors.mint : V2Colors.deepTosca;
    final unselectedColor =
        isDark ? V2Colors.darkTextSecondary : V2Colors.lightTextSecondary;
    final color = isSelected ? selectedColor : unselectedColor;

    return Expanded(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Semantics(
          label: tab.label,
          selected: isSelected,
          button: true,
          child: InkResponse(
            key: ValueKey('v2_nav_item_${tab.name}'),
            onTap: () => controller.selectTab(tab),
            radius: 28,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? selectedIcon : unselectedIcon,
                  color: color,
                  size: 24,
                ),
                const SizedBox(height: 2),
                Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterProgramItem({
    required bool isSelected,
    required bool isDark,
  }) {
    const buttonColor = V2Colors.warmGold;
    const iconColor = Colors.white;

    return Expanded(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Semantics(
          label: 'Program',
          selected: isSelected,
          button: true,
          child: InkResponse(
            key: const ValueKey('v2_nav_item_program'),
            onTap: () => controller.selectTab(V2NavigationTab.program),
            radius: 28,
            child: Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: buttonColor,
                  shape: BoxShape.circle,
                  boxShadow: isDark
                      ? V2Elevation.centerActionButtonDark
                      : V2Elevation.centerActionButtonLight,
                  border: isSelected
                      ? Border.all(
                          color: isDark ? V2Colors.mint : V2Colors.deepTosca,
                          width: 2.0,
                        )
                      : null,
                ),
                child: const Center(
                  child: Icon(
                    Icons.add,
                    color: iconColor,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
