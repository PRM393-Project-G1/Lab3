import 'package:flutter/material.dart';

import '../theme/app_theme_extensions.dart';
import '../theme/app_tokens.dart';

/// One Remote Config key and its current value, shown in the demo area.
class RemoteConfigRow extends StatelessWidget {
  const RemoteConfigRow({
    super.key,
    required this.keyName,
    required this.value,
  });

  final String keyName;
  final String value;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$keyName: $value',
    excludeSemantics: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(keyName, style: context.mono)),
          const SizedBox(width: AppSpacing.sm),
          Text(
            value,
            style: context.mono.copyWith(color: context.colors.onSurface),
          ),
        ],
      ),
    ),
  );
}
