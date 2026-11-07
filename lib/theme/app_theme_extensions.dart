import 'package:flutter/material.dart';

import '../models/ref_status.dart';
import 'app_tokens.dart';

/// Colours of one reference status.
class StatusTier {
  const StatusTier({
    required this.foreground,
    required this.icon,
    required this.container,
    required this.border,
  });

  final Color foreground;
  final Color icon;
  final Color container;
  final Color border;

  static StatusTier lerp(StatusTier a, StatusTier b, double t) => StatusTier(
    foreground: Color.lerp(a.foreground, b.foreground, t)!,
    icon: Color.lerp(a.icon, b.icon, t)!,
    container: Color.lerp(a.container, b.container, t)!,
    border: Color.lerp(a.border, b.border, t)!,
  );
}

/// Status colours that have no slot in [ColorScheme].
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.hallucinated,
    required this.error,
    required this.warning,
    required this.unverified,
    required this.verified,
  });

  static const standard = StatusColors(
    hallucinated: StatusTier(
      foreground: AppPalette.hallucinated,
      icon: AppPalette.hallucinated,
      container: AppPalette.hallucinatedContainer,
      border: AppPalette.hallucinatedBorder,
    ),
    error: StatusTier(
      foreground: AppPalette.error,
      icon: AppPalette.error,
      container: AppPalette.errorContainer,
      border: AppPalette.errorBorder,
    ),
    warning: StatusTier(
      foreground: AppPalette.warning,
      icon: AppPalette.warningIcon,
      container: AppPalette.warningContainer,
      border: AppPalette.warningBorder,
    ),
    unverified: StatusTier(
      foreground: AppPalette.unverified,
      icon: AppPalette.unverified,
      container: AppPalette.unverifiedContainer,
      border: AppPalette.unverifiedBorder,
    ),
    verified: StatusTier(
      foreground: AppPalette.verified,
      icon: AppPalette.verified,
      container: AppPalette.verifiedContainer,
      border: AppPalette.verifiedBorder,
    ),
  );

  final StatusTier hallucinated;
  final StatusTier error;
  final StatusTier warning;
  final StatusTier unverified;
  final StatusTier verified;

  StatusTier of(RefStatus status) => switch (status) {
    RefStatus.hallucinated => hallucinated,
    RefStatus.error => error,
    RefStatus.warning => warning,
    RefStatus.unverified => unverified,
    RefStatus.verified => verified,
  };

  @override
  StatusColors copyWith({
    StatusTier? hallucinated,
    StatusTier? error,
    StatusTier? warning,
    StatusTier? unverified,
    StatusTier? verified,
  }) => StatusColors(
    hallucinated: hallucinated ?? this.hallucinated,
    error: error ?? this.error,
    warning: warning ?? this.warning,
    unverified: unverified ?? this.unverified,
    verified: verified ?? this.verified,
  );

  @override
  StatusColors lerp(ThemeExtension<StatusColors>? other, double t) {
    if (other is! StatusColors) return this;
    return StatusColors(
      hallucinated: StatusTier.lerp(hallucinated, other.hallucinated, t),
      error: StatusTier.lerp(error, other.error, t),
      warning: StatusTier.lerp(warning, other.warning, t),
      unverified: StatusTier.lerp(unverified, other.unverified, t),
      verified: StatusTier.lerp(verified, other.verified, t),
    );
  }
}

/// Colours of the knowledge graph.
class GraphColors extends ThemeExtension<GraphColors> {
  const GraphColors({
    required this.topic,
    required this.author,
    required this.edge,
    required this.isA,
    required this.partOf,
    required this.sameAs,
    required this.weak,
    required this.selected,
  });

  static const standard = GraphColors(
    topic: AppPalette.graphTopic,
    author: AppPalette.graphAuthor,
    edge: AppPalette.graphEdge,
    isA: AppPalette.graphIsA,
    partOf: AppPalette.graphPartOf,
    sameAs: AppPalette.graphSameAs,
    weak: AppPalette.error,
    selected: AppPalette.textPrimary,
  );

  final Color topic;
  final Color author;

  /// Subtopic, related and author links.
  final Color edge;
  final Color isA;
  final Color partOf;
  final Color sameAs;

  /// Ring around a weak topic.
  final Color weak;

  /// Ring around the selected node.
  final Color selected;

  @override
  GraphColors copyWith({
    Color? topic,
    Color? author,
    Color? edge,
    Color? isA,
    Color? partOf,
    Color? sameAs,
    Color? weak,
    Color? selected,
  }) => GraphColors(
    topic: topic ?? this.topic,
    author: author ?? this.author,
    edge: edge ?? this.edge,
    isA: isA ?? this.isA,
    partOf: partOf ?? this.partOf,
    sameAs: sameAs ?? this.sameAs,
    weak: weak ?? this.weak,
    selected: selected ?? this.selected,
  );

  @override
  GraphColors lerp(ThemeExtension<GraphColors>? other, double t) {
    if (other is! GraphColors) return this;
    return GraphColors(
      topic: Color.lerp(topic, other.topic, t)!,
      author: Color.lerp(author, other.author, t)!,
      edge: Color.lerp(edge, other.edge, t)!,
      isA: Color.lerp(isA, other.isA, t)!,
      partOf: Color.lerp(partOf, other.partOf, t)!,
      sameAs: Color.lerp(sameAs, other.sameAs, t)!,
      weak: Color.lerp(weak, other.weak, t)!,
      selected: Color.lerp(selected, other.selected, t)!,
    );
  }
}

/// Text tokens that have no slot in [TextTheme].
class AppTextExtras extends ThemeExtension<AppTextExtras> {
  const AppTextExtras({required this.mono, required this.muted});

  final TextStyle mono;
  final Color muted;

  @override
  AppTextExtras copyWith({TextStyle? mono, Color? muted}) =>
      AppTextExtras(mono: mono ?? this.mono, muted: muted ?? this.muted);

  @override
  AppTextExtras lerp(ThemeExtension<AppTextExtras>? other, double t) {
    if (other is! AppTextExtras) return this;
    return AppTextExtras(
      mono: TextStyle.lerp(mono, other.mono, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
    );
  }
}

/// Icon and label of a status: never colour alone.
extension RefStatusVisuals on RefStatus {
  String get label => switch (this) {
    RefStatus.hallucinated => 'Hallucinated',
    RefStatus.error => 'Error',
    RefStatus.warning => 'Warning',
    RefStatus.unverified => 'Unverified',
    RefStatus.verified => 'Verified',
  };

  IconData get icon => switch (this) {
    RefStatus.hallucinated => Icons.gpp_bad_rounded,
    RefStatus.error => Icons.error_rounded,
    RefStatus.warning => Icons.warning_amber_rounded,
    RefStatus.unverified => Icons.help_rounded,
    RefStatus.verified => Icons.check_circle_rounded,
  };
}

extension AppThemeContext on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  StatusTier status(RefStatus status) =>
      Theme.of(this).extension<StatusColors>()!.of(status);
  TextStyle get mono => Theme.of(this).extension<AppTextExtras>()!.mono;
  Color get muted => Theme.of(this).extension<AppTextExtras>()!.muted;
  GraphColors get graph =>
      Theme.of(this).extension<GraphColors>() ?? GraphColors.standard;
}
