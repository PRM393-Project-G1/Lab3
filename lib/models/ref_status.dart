/// Verification status of one reference, most severe first.
/// The order is the display precedence used everywhere in the app.
enum RefStatus {
  hallucinated,
  error,
  warning,
  unverified,
  verified;

  /// Reads the value stored by the backend. Unknown values count as unverified,
  /// so a reference is never shown as clean by mistake.
  static RefStatus parse(String? value) => switch (value) {
    'hallucinated' || 'hallucination' => hallucinated,
    'error' => error,
    'warning' => warning,
    'verified' => verified,
    _ => unverified,
  };

  /// A problem was found, so the reference is listed in the PDF report.
  bool get isFlagged =>
      this == hallucinated || this == error || this == warning;
}

/// Reference counts per status for a paper or a topic.
class StatusCounts {
  const StatusCounts({
    this.hallucinated = 0,
    this.error = 0,
    this.warning = 0,
    this.unverified = 0,
    this.verified = 0,
  });

  factory StatusCounts.fromMap(Map<String, dynamic> map) {
    int read(String key) => (map[key] as num?)?.toInt() ?? 0;
    return StatusCounts(
      hallucinated: read('hallucinated'),
      error: read('error'),
      warning: read('warning'),
      unverified: read('unverified'),
      verified: read('verified'),
    );
  }

  /// Tallies one status per reference.
  factory StatusCounts.fromStatuses(Iterable<RefStatus> statuses) {
    var hallucinated = 0, error = 0, warning = 0, unverified = 0, verified = 0;
    for (final status in statuses) {
      switch (status) {
        case RefStatus.hallucinated:
          hallucinated++;
        case RefStatus.error:
          error++;
        case RefStatus.warning:
          warning++;
        case RefStatus.unverified:
          unverified++;
        case RefStatus.verified:
          verified++;
      }
    }
    return StatusCounts(
      hallucinated: hallucinated,
      error: error,
      warning: warning,
      unverified: unverified,
      verified: verified,
    );
  }

  final int hallucinated;
  final int error;
  final int warning;
  final int unverified;
  final int verified;

  int get total => hallucinated + error + warning + unverified + verified;

  /// References that make a topic weak.
  int get issues => hallucinated + error;

  int of(RefStatus status) => switch (status) {
    RefStatus.hallucinated => hallucinated,
    RefStatus.error => error,
    RefStatus.warning => warning,
    RefStatus.unverified => unverified,
    RefStatus.verified => verified,
  };
}
