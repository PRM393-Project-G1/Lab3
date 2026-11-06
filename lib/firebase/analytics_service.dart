import 'package:firebase_analytics/firebase_analytics.dart';

/// Every event of `docs/analytics-plan.md`. No personal data in any parameter.
abstract class AnalyticsService {
  Future<void> setUser(String? uid);
  Future<void> logLogin();
  Future<void> logLogout();
  Future<void> logSearch(String arxivId, {required bool cacheHit});
  Future<void> logViewAnalysis(
    String id, {
    required int refCount,
    required int weakTopicCount,
  });
  Future<void> logViewTopic(
    String topicId,
    String name, {
    required bool isWeak,
  });
  Future<void> logViewReference(String refId, String status);
  Future<void> logFilterWeakTopics(String analysisId);
  Future<void> logExportReport(String analysisId, {required int fileSizeKb});
  Future<void> logNotificationOpen(String type);
}

class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService({FirebaseAnalytics? analytics})
    : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  @override
  Future<void> setUser(String? uid) => _analytics.setUserId(id: uid);

  @override
  Future<void> logLogin() => _analytics.logLogin(loginMethod: 'google');

  @override
  Future<void> logLogout() => _analytics.logEvent(name: 'logout');

  @override
  Future<void> logSearch(String arxivId, {required bool cacheHit}) =>
      _analytics.logEvent(
        name: 'search',
        parameters: {'search_term': arxivId, 'cache_hit': cacheHit ? 1 : 0},
      );

  @override
  Future<void> logViewAnalysis(
    String id, {
    required int refCount,
    required int weakTopicCount,
  }) => _analytics.logEvent(
    name: 'view_analysis',
    parameters: {
      'analysis_id': id,
      'ref_count': refCount,
      'weak_topic_count': weakTopicCount,
    },
  );

  @override
  Future<void> logViewTopic(
    String topicId,
    String name, {
    required bool isWeak,
  }) => _analytics.logEvent(
    name: 'view_topic',
    parameters: {
      'topic_id': topicId,
      'topic_name': name,
      'is_weak': isWeak ? 1 : 0,
    },
  );

  @override
  Future<void> logViewReference(String refId, String status) =>
      _analytics.logEvent(
        name: 'view_reference',
        parameters: {'reference_id': refId, 'status': status},
      );

  @override
  Future<void> logFilterWeakTopics(String analysisId) => _analytics.logEvent(
    name: 'filter_weak_topics',
    parameters: {'analysis_id': analysisId},
  );

  @override
  Future<void> logExportReport(String analysisId, {required int fileSizeKb}) =>
      _analytics.logEvent(
        name: 'export_report',
        parameters: {'analysis_id': analysisId, 'file_size_kb': fileSizeKb},
      );

  // Not `notification_open`: FCM logs that one itself, so the SDK rejects it.
  @override
  Future<void> logNotificationOpen(String type) => _analytics.logEvent(
    name: 'open_notification',
    parameters: {'notification_type': type},
  );
}
