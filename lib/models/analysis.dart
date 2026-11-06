import 'ref_status.dart';

enum AnalysisStatus {
  queued,
  processing,
  done,
  failed,
  cancelled,
  unknown;

  /// Reads the value stored by the backend.
  static AnalysisStatus parse(Object? value) => switch (value) {
    'queued' => queued,
    'processing' => processing,
    'done' => done,
    'failed' => failed,
    'cancelled' => cancelled,
    _ => unknown,
  };

  /// The backend still has work to do.
  bool get isRunning => this == queued || this == processing;

  /// The run ended without a result.
  bool get isStopped => this == failed || this == cancelled;
}

/// The five stages of the analysis pipeline, in order.
enum AnalysisStage {
  references,
  verify,
  fabrication,
  fullText,
  topics;

  /// Reads `progress.stage`. Unknown values count as the first stage.
  static AnalysisStage parse(Object? value) => switch (value) {
    'verify' => verify,
    'fabrication' => fabrication,
    'fulltext' || 'full_text' => fullText,
    'topics' => topics,
    _ => references,
  };
}

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
      stage: AnalysisStage.parse(map['stage']),
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
      status: AnalysisStatus.parse(map['status']),
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

  bool get isRunning => status.isRunning;

  bool get isStopped => status.isStopped;

  String get displayTitle => title ?? 'arXiv:$id';
}
