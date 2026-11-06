import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_notification.dart';
import '../models/app_user.dart';
import 'firestore_schema.dart';

/// Documents that belong to one user, under `users/{uid}`.
abstract class FirestoreService {
  Future<void> ensureUser(AppUser user);
  Future<void> addFcmToken(String uid, String token);
  Stream<List<AppNotification>> watchNotifications(String uid);
  Future<void> markNotificationRead(String uid, String id);
  Future<void> addReport({
    required String uid,
    required String analysisId,
    required String storagePath,
    required String downloadUrl,
    required int sizeKb,
  });
}

class CloudFirestoreService implements FirestoreService {
  CloudFirestoreService({FirebaseFirestore? db})
    : _paths = FirestorePaths(db ?? FirebaseFirestore.instance);

  final FirestorePaths _paths;

  @override
  Future<void> ensureUser(AppUser user) async {
    final doc = _paths.user(user.uid);
    final snap = await doc.get();
    await doc.set({
      'displayName': user.displayName,
      'photoUrl': user.photoUrl,
      if (!snap.exists) 'createdAt': FieldValue.serverTimestamp(),
      if (!snap.exists) 'role': 'user',
    }, SetOptions(merge: true));
  }

  @override
  Future<void> addFcmToken(String uid, String token) => _paths.user(uid).set({
    'fcmTokens': FieldValue.arrayUnion([token]),
  }, SetOptions(merge: true));

  @override
  Stream<List<AppNotification>> watchNotifications(String uid) => _paths
      .notifications(uid)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((d) => AppNotification.fromMap(d.id, withDates(d.data())))
            .toList(),
      );

  @override
  Future<void> markNotificationRead(String uid, String id) =>
      _paths.notifications(uid).doc(id).update({'read': true});

  @override
  Future<void> addReport({
    required String uid,
    required String analysisId,
    required String storagePath,
    required String downloadUrl,
    required int sizeKb,
  }) => _paths.reports(uid).add({
    'analysisId': analysisId,
    'storagePath': storagePath,
    'downloadUrl': downloadUrl,
    'sizeKb': sizeKb,
    'createdAt': FieldValue.serverTimestamp(),
  });
}
