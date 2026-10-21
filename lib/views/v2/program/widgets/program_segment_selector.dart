import 'package:flutter/material.dart';

import '../../../../controllers/v2_program_hub_controller.dart';
import '../../../../theme/v2_design_tokens.dart';

/// Two-segment tab switcher for S17 Program Hub: [Katalog Ibadah] and [Ibadah Saya].
class ProgramSegmentSelector extends StatelessWidget {
  final ProgramHubTab selectedTab;
  final ValueChanged<ProgramHubTab> onTabSelected;

  const ProgramSegmentSelector({
    super.key,
    required this.selectedTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final containerBg =
        isDark ? V2Colors.darkSurfaceElevated : V2Colors.lightGray;
    final containerBorder =
        isDark ? V2Colors.darkBorder : V2Colors.lightBorder;

    return Container(
      height: 58,
      padding: const EdgeInsets.all(V2Spacing.xs),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: V2Radius.borderFull,
        border: Border.all(color: containerBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSegmentButton(
              context: context,
              tab: ProgramHubTab.katalog,
              isSelected: selectedTab == ProgramHubTab.katalog,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: V2Spacing.xs),
          Expanded(
            child: _buildSegmentButton(
              context: context,
              tab: ProgramHubTab.ibadahSaya,
              isSelected: selectedTab == ProgramHubTab.ibadahSaya,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required BuildContext context,
    required ProgramHubTab tab,
    required bool isSelected,
    required bool isDark,
  }) {
    final activeBg = isDark ? V2Colors.mint : V2Colors.deepTosca;
    final activeText = isDark ? V2Colors.darkSurface : Colors.white;

    final inactiveBg = Colors.transparent;
    final inactiveText =
        isDark ? V2Colors.darkTextSecondary : V2Colors.lightTextSecondary;

    return Semantics(
      button: true,
      selected: isSelected,
      label: tab.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('v2_program_segment_${tab.name}'),
          onTap: () => onTabSelected(tab),
          borderRadius: V2Radius.borderFull,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? activeBg : inactiveBg,
              borderRadius: V2Radius.borderFull,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            child: Text(
              tab.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeText : inactiveText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
