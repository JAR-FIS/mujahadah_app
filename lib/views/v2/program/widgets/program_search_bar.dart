import 'package:flutter/material.dart';

import '../../../../theme/v2_design_tokens.dart';

/// Search input and '+ Baru' action row for S17 Program Hub.
class ProgramSearchBar extends StatefulWidget {
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback? onNewCustomTap;
  final String hintText;

  const ProgramSearchBar({
    super.key,
    required this.query,
    required this.onChanged,
    required this.onClear,
    this.onNewCustomTap,
    this.hintText = 'Cari Ibadah...',
  });

  @override
  State<ProgramSearchBar> createState() => _ProgramSearchBarState();
}

class _ProgramSearchBarState extends State<ProgramSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(ProgramSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _controller.text) {
      _controller.text = widget.query;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final fieldBg =
        isDark ? V2Colors.darkSurfaceCard : V2Colors.lightSurfaceCard;
    final borderColor = isDark ? V2Colors.darkBorder : V2Colors.lightBorder;
    final textPrimary =
        isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary;
    final textMuted =
        isDark ? V2Colors.darkTextMuted : V2Colors.lightTextMuted;

    return Row(
      children: [
        // Search Input
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: fieldBg,
              borderRadius: V2Radius.borderMd,
              border: Border.all(color: borderColor),
            ),
            child: TextField(
              key: const ValueKey('v2_program_search_field'),
              controller: _controller,
              onChanged: widget.onChanged,
              style: V2Typography.bodyMedium.copyWith(color: textPrimary),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle:
                    V2Typography.bodyMedium.copyWith(color: textMuted),
                prefixIcon: Icon(
                  Icons.search,
                  color: textMuted,
                  size: 20,
                ),
                suffixIcon: widget.query.isNotEmpty
                    ? IconButton(
                        key: const ValueKey('v2_program_search_clear_button'),
                        icon: const Icon(Icons.close, size: 18),
                        color: textMuted,
                        onPressed: () {
                          _controller.clear();
                          widget.onClear();
                        },
                        tooltip: 'Hapus Pencarian',
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: V2Spacing.md,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: V2Spacing.sm),
        // '+ Baru' Button (Navigates to S19 Custom Ibadah in future wave)
        Semantics(
          button: true,
          label: 'Tambah Ibadah Baru',
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Material(
              color: V2Colors.warmGold,
              borderRadius: V2Radius.borderMd,
              child: InkWell(
                key: const ValueKey('v2_program_new_custom_button'),
                borderRadius: V2Radius.borderMd,
                onTap: widget.onNewCustomTap,
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(
                    horizontal: V2Spacing.md,
                  ),
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: V2Spacing.xs),
                      Text(
                        'Baru',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
