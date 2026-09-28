import 'package:flutter/material.dart';

class ReasonBadge extends StatelessWidget {
  final Function(String) onSelected;
  final String? selectedReason;

  const ReasonBadge({
    Key? key,
    required this.onSelected,
    this.selectedReason,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final reasons = ["Lupa", "Ketiduran", "Sibuk Kerja", "Sakit", "Lainnya"];

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: reasons.map((reason) {
        return ChoiceChip(
          label: Text(reason),
          selected: selectedReason == reason,
          onSelected: (bool selected) {
            onSelected(reason);
          },
        );
      }).toList(),
    );
  }
}
