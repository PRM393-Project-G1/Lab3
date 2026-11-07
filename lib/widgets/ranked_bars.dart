import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme_extensions.dart';
import '../theme/app_tokens.dart';

class RankedBar {
  const RankedBar({
    required this.label,
    required this.value,
    required this.valueLabel,
    this.caption,
    this.onTap,
  });

  final String label;
  final double value;

  /// Printed at the tip of the bar.
  final String valueLabel;

  /// Muted text after the label, such as "31 mentions".
  final String? caption;
  final VoidCallback? onTap;
}

/// Horizontal bars, largest first, in one colour, each as long as its value
/// relative to the largest.
class RankedBars extends StatelessWidget {
  const RankedBars(this.bars, {super.key});

  static const barHeight = 8.0;

  /// Room kept after the longest bar for its value.
  static const valueWidth = 48.0;

  final List<RankedBar> bars;

  @override
  Widget build(BuildContext context) {
    final largest = bars.fold<double>(
      0,
      (top, bar) => math.max(top, bar.value),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final bar in bars)
          _Row(bar: bar, share: largest > 0 ? bar.value / largest : 0),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.bar, required this.share});

  final RankedBar bar;
  final double share;

  @override
  Widget build(BuildContext context) {
    final caption = bar.caption;
    return Semantics(
      container: true,
      button: bar.onTap != null,
      label: [bar.label, bar.valueLabel, ?caption].join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: bar.onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTap),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text.rich(
                  TextSpan(
                    text: bar.label,
                    children: [
                      if (caption != null)
                        TextSpan(
                          text: ' · $caption',
                          style: context.text.bodyMedium?.copyWith(
                            color: context.muted,
                          ),
                        ),
                    ],
                  ),
                  style: context.text.bodyLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final room = math.max(
                      0.0,
                      constraints.maxWidth - RankedBars.valueWidth,
                    );
                    return Row(
                      children: [
                        Container(
                          width: math.max(RankedBars.barHeight, room * share),
                          height: RankedBars.barHeight,
                          decoration: BoxDecoration(
                            color: context.colors.primary,
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            bar.valueLabel,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                            style: context.text.bodyMedium?.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
