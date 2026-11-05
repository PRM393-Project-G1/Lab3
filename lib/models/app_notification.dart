/// One item of the in-app inbox at `users/{uid}/notifications/{id}`.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.type = 'analysis_done',
    this.analysisId,
    this.read = false,
  });

  factory AppNotification.fromMap(String id, Map<String, dynamic> map) =>
      AppNotification(
        id: id,
        title: map['title'] as String? ?? 'Analysis done',
        body: map['body'] as String? ?? '',
        type: map['type'] as String? ?? 'analysis_done',
        analysisId: map['analysisId'] as String?,
        createdAt: map['createdAt'] as DateTime? ?? DateTime.now(),
        read: map['read'] as bool? ?? false,
      );

  final String id;
  final String title;
  final String body;
  final String type;
  final String? analysisId;
  final DateTime createdAt;
  final bool read;
}
