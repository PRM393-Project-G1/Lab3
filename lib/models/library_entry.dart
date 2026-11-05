import 'analysis.dart';

/// One row of the user's history at `users/{uid}/library/{arxivId}`.
class LibraryEntry {
  const LibraryEntry({
    required this.arxivId,
    required this.addedAt,
    this.customTitle,
    this.lastOpenedAt,
    this.analysis,
  });

  factory LibraryEntry.fromMap(String id, Map<String, dynamic> map) =>
      LibraryEntry(
        arxivId: id,
        customTitle: map['customTitle'] as String?,
        addedAt: map['addedAt'] as DateTime? ?? DateTime.now(),
        lastOpenedAt: map['lastOpenedAt'] as DateTime?,
      );

  final String arxivId;
  final String? customTitle;
  final DateTime addedAt;
  final DateTime? lastOpenedAt;
  final Analysis? analysis;

  DateTime get sortTime => lastOpenedAt ?? addedAt;

  String get title => customTitle ?? analysis?.displayTitle ?? 'arXiv:$arxivId';

  LibraryEntry withAnalysis(Analysis? value) => LibraryEntry(
    arxivId: arxivId,
    customTitle: customTitle,
    addedAt: addedAt,
    lastOpenedAt: lastOpenedAt,
    analysis: value,
  );
}
