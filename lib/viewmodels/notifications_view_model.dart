import 'dart:async';

import '../firebase/analytics_service.dart';
import '../firebase/auth_service.dart';
import '../firebase/firestore_service.dart';
import '../models/app_notification.dart';
import 'base_view_model.dart';
import 'view_state.dart';

class NotificationsViewModel extends BaseViewModel {
  NotificationsViewModel({
    required this._firestore,
    required this._auth,
    required this._analytics,
  }) {
    load();
  }

  final FirestoreService _firestore;
  final AuthService _auth;
  final AnalyticsService _analytics;

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
            _state = items.isEmpty ? const Empty() : Data(items);
            notifyListeners();
          },
          onError: (Object _) {
            _state = const Failure("Couldn't load");
            notifyListeners();
          },
        );
  }

  /// Marks it read and returns the analysis to open, if any.
  Future<String?> open(AppNotification notification) async {
    final uid = _auth.currentUser?.uid;
    if (uid != null && !notification.read) {
      await _firestore.markNotificationRead(uid, notification.id);
    }
    await _analytics.logNotificationOpen(notification.type);
    return notification.analysisId;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
