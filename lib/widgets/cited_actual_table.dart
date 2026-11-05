import 'package:flutter/material.dart';

import '../models/ref_status.dart';
import '../theme/app_theme_extensions.dart';
import '../theme/app_tokens.dart';

class CitedActualRow {
  const CitedActualRow({
    required this.field,
    required this.cited,
    required this.actual,
  });

  final String field;
  final String cited;
  final String actual;

  bool get mismatch => cited != actual;
}

/// Compares what the paper cites with what the source says. A mismatch is
/// tinted and also marked with an icon and text, so it never relies on colour.
class CitedActualTable extends StatelessWidget {
  const CitedActualTable({super.key, required this.rows});

  final List<CitedActualRow> rows;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [for (final row in rows) _Row(row: row)],
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.row});

  final CitedActualRow row;

  @override
  Widget build(BuildContext context) {
    final tier = context.status(RefStatus.error);
    return Semantics(
      label:
          '${row.field}. Cited: ${row.cited}. Actual: ${row.actual}.'
          '${row.mismatch ? ' Mismatch.' : ''}',
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: row.mismatch ? tier.container : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: row.mismatch ? tier.border : context.colors.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.field.toUpperCase(),
                    style: context.text.labelMedium,
                  ),
                ),
                if (row.mismatch) ...[
                  Icon(
                    Icons.error_rounded,
                    size: AppSizes.iconSm,
                    color: tier.icon,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Mismatch',
                    style: context.text.labelSmall?.copyWith(
                      color: tier.foreground,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Cell(label: 'Cited', value: row.cited),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _Cell(label: 'Actual', value: row.actual),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: context.text.labelSmall),
      Text(
        value,
        style: context.text.bodyMedium?.copyWith(
          color: context.colors.onSurface,
        ),
      ),
    ],
  );
}
