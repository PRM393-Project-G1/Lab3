import 'ref_status.dart';

class ReferenceIssue {
  const ReferenceIssue({
    required this.type,
    required this.message,
    this.cited,
    this.actual,
  });

  factory ReferenceIssue.fromMap(Map<String, dynamic> map) => ReferenceIssue(
    type: map['type'] as String? ?? 'other',
    message: map['message'] as String? ?? '',
    cited: map['cited']?.toString(),
    actual: map['actual']?.toString(),
  );

  final String type;
  final String message;
  final String? cited;
  final String? actual;
}

/// One entry of the reference list, stored at `analyses/{id}/references/{refId}`.
class Reference {
  const Reference({
    required this.id,
    required this.index,
    required this.title,
    required this.status,
    this.authors = const [],
    this.year,
    this.venue,
    this.url,
    this.issues = const [],
    this.hallucinationNote,
    this.closestMatchTitle,
    this.closestMatchUrl,
    this.topicIds = const [],
  });

  factory Reference.fromMap(String id, Map<String, dynamic> map) {
    final hallucination = (map['hallucination'] as Map?)
        ?.cast<String, dynamic>();
    return Reference(
      id: id,
      index: (map['index'] as num?)?.toInt() ?? 0,
      title: map['title'] as String? ?? 'Untitled',
      status: RefStatusParsing.parse(map['status'] as String?),
      authors: (map['authors'] as List?)?.cast<String>() ?? const [],
      year: (map['year'] as num?)?.toInt(),
      venue: map['venue'] as String?,
      url: map['url'] as String?,
      issues: ((map['issues'] as List?) ?? const [])
          .map(
            (e) => ReferenceIssue.fromMap((e as Map).cast<String, dynamic>()),
          )
          .toList(),
      hallucinationNote: hallucination?['explanation'] as String?,
      closestMatchTitle: hallucination?['closestMatchTitle'] as String?,
      closestMatchUrl: hallucination?['closestMatchUrl'] as String?,
      topicIds: (map['topicIds'] as List?)?.cast<String>() ?? const [],
    );
  }

  final String id;
  final int index;
  final String title;
  final RefStatus status;
  final List<String> authors;
  final int? year;
  final String? venue;
  final String? url;
  final List<ReferenceIssue> issues;
  final String? hallucinationNote;
  final String? closestMatchTitle;
  final String? closestMatchUrl;
  final List<String> topicIds;

  bool get isUnclassified => topicIds.isEmpty;

  String get byline => [
    if (authors.isNotEmpty)
      authors.length > 2 ? '${authors.first} et al.' : authors.join(', '),
    if (year != null) '$year',
    if (venue != null && venue!.isNotEmpty) venue!,
  ].join(' · ');

  String? get firstIssue => issues.isEmpty ? null : issues.first.message;

  List<ReferenceIssue> get comparableIssues =>
      issues.where((i) => i.cited != null && i.actual != null).toList();

  /// Plain text a reader can paste into their own bibliography.
  String get fixText => comparableIssues
      .map((i) => '${i.type}: ${i.cited} -> ${i.actual}')
      .join('\n');
}

/// Most severe first, then in the order of the paper.
List<Reference> sortBySeverity(Iterable<Reference> references) =>
    references.toList()..sort((a, b) {
      final byStatus = a.status.index.compareTo(b.status.index);
      return byStatus != 0 ? byStatus : a.index.compareTo(b.index);
    });
