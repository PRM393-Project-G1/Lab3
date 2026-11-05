import 'ref_status.dart';

enum AnalysisStatus { queued, processing, done, failed, cancelled, unknown }

/// The five stages of the analysis pipeline, in order.
enum AnalysisStage { references, verify, fabrication, fullText, topics }

class AnalysisProgress {
  const AnalysisProgress({
    this.stage = AnalysisStage.references,
    this.percent = 0,
    this.processedRefs = 0,
    this.message,
  });

  factory AnalysisProgress.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const AnalysisProgress();
    return AnalysisProgress(
      stage: switch (map['stage']) {
        'verify' => AnalysisStage.verify,
        'fabrication' => AnalysisStage.fabrication,
        'fulltext' || 'full_text' => AnalysisStage.fullText,
        'topics' => AnalysisStage.topics,
        _ => AnalysisStage.references,
      },
      percent: (map['percent'] as num?)?.toInt() ?? 0,
      processedRefs: (map['processedRefs'] as num?)?.toInt() ?? 0,
      message: map['message'] as String?,
    );
  }

  final AnalysisStage stage;
  final int percent;
  final int processedRefs;
  final String? message;
}

/// Shared result of one paper, stored at `analyses/{arxivId}`.
class Analysis {
  const Analysis({
    required this.id,
    required this.status,
    this.title,
    this.authors = const [],
    this.progress = const AnalysisProgress(),
    this.counts = const StatusCounts(),
    this.totalRefs = 0,
    this.error,
    this.fromCache = false,
  });

  factory Analysis.fromMap(
    String id,
    Map<String, dynamic> map, {
    bool fromCache = false,
  }) {
    final summary = (map['summary'] as Map?)?.cast<String, dynamic>() ?? {};
    final counts = StatusCounts.fromMap(summary);
    return Analysis(
      id: id,
      status: switch (map['status']) {
        'queued' => AnalysisStatus.queued,
        'processing' => AnalysisStatus.processing,
        'done' => AnalysisStatus.done,
        'failed' => AnalysisStatus.failed,
        'cancelled' => AnalysisStatus.cancelled,
        _ => AnalysisStatus.unknown,
      },
      title: map['paperTitle'] as String?,
      authors: (map['paperAuthors'] as List?)?.cast<String>() ?? const [],
      progress: AnalysisProgress.fromMap(
        (map['progress'] as Map?)?.cast<String, dynamic>(),
      ),
      counts: counts,
      totalRefs: (summary['totalRefs'] as num?)?.toInt() ?? counts.total,
      error: map['error'] as String?,
      fromCache: fromCache,
    );
  }

  final String id;
  final AnalysisStatus status;
  final String? title;
  final List<String> authors;
  final AnalysisProgress progress;
  final StatusCounts counts;
  final int totalRefs;
  final String? error;

  /// True while the device cannot confirm this copy with the server.
  final bool fromCache;

  bool get isDone => status == AnalysisStatus.done;

  bool get isRunning =>
      status == AnalysisStatus.queued || status == AnalysisStatus.processing;

  String get displayTitle => title ?? 'arXiv:$id';
}
