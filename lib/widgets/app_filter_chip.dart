import 'package:flutter/material.dart';

import '../theme/app_theme_extensions.dart';
import '../theme/app_tokens.dart';

/// Selectable filter with an optional count, for example "All 41".
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.count,
  });

  final String label;
  final int? count;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FilterChip(
      label: Text(count == null ? label : '$label $count'),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: true,
      checkmarkColor: colors.onPrimary,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      backgroundColor: colors.surface,
      selectedColor: colors.primary,
      labelStyle: context.text.labelSmall?.copyWith(
        color: selected ? colors.onPrimary : colors.onSurface,
      ),
      side: BorderSide(color: selected ? colors.primary : colors.outline),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    );
  }
}
