import 'package:flutter/material.dart';

import '../theme/app_theme_extensions.dart';
import '../theme/app_tokens.dart';

/// Loading placeholder: grey blocks in the shape of the coming content.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 4, this.itemHeight = 96});

  final int itemCount;
  final double itemHeight;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading',
    liveRegion: true,
    child: ExcludeSemantics(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.page),
        child: Column(
          children: [
            for (var i = 0; i < itemCount; i++)
              Container(
                height: itemHeight,
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: context.colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
