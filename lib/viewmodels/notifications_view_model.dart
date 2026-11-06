import 'dart:async';

import '../firebase/analytics_service.dart';
import '../firebase/auth_service.dart';
import '../firebase/crashlytics_service.dart';
import '../firebase/firestore_service.dart';
import '../models/app_notification.dart';
import 'base_view_model.dart';
import 'view_state.dart';

class NotificationsViewModel extends BaseViewModel {
  NotificationsViewModel({
    required this._firestore,
    required this._auth,
    required this._analytics,
    required this._crashlytics,
  }) {
    load();
  }

  final FirestoreService _firestore;
  final AuthService _auth;
  final AnalyticsService _analytics;
  final CrashlyticsService _crashlytics;

  StreamSubscription<List<AppNotification>>? _sub;
  ViewState<List<AppNotification>> _state = const Loading();

  ViewState<List<AppNotification>> get state => _state;

  void load() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    _sub?.cancel();
    _state = const Loading();
    notifyListeners();
    _sub = _firestore
        .watchNotifications(uid)
        .listen(
          (items) {
            _state = listState(items);
            notifyListeners();
          },
          onError: (Object _) {
            _state = const Failure.loadFailed();
            notifyListeners();
          },
        );
  }

  /// Marks it read and returns the analysis to open, if any.
  Future<String?> open(AppNotification notification) async {
    final uid = _auth.currentUser?.uid;
    if (uid != null && !notification.read) {
      // A Firestore write only finishes once the server answers, so waiting
      // for it would keep the paper from opening while offline.
      unawaited(_markRead(uid, notification.id));
    }
    await _analytics.logNotificationOpen(notification.type);
    return notification.analysisId;
  }

  Future<void> _markRead(String uid, String id) async {
    try {
      await _firestore.markNotificationRead(uid, id);
    } catch (error, stack) {
      await _crashlytics.recordNonFatal(error, stack, reason: 'mark_read');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
