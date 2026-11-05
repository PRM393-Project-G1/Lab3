import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_notification.dart';
import '../models/app_user.dart';

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

/// Turns Firestore timestamps into [DateTime], so models stay free of Firebase.
Map<String, dynamic> withDates(Map<String, dynamic> data) => data.map(
  (key, value) => MapEntry(key, value is Timestamp ? value.toDate() : value),
);

class CloudFirestoreService implements FirestoreService {
  CloudFirestoreService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);

  @override
  Future<void> ensureUser(AppUser user) async {
    final doc = _user(user.uid);
    final snap = await doc.get();
    await doc.set({
      'displayName': user.displayName,
      'photoUrl': user.photoUrl,
      if (!snap.exists) 'createdAt': FieldValue.serverTimestamp(),
      if (!snap.exists) 'role': 'user',
    }, SetOptions(merge: true));
  }

  @override
  Future<void> addFcmToken(String uid, String token) => _user(uid).set({
    'fcmTokens': FieldValue.arrayUnion([token]),
  }, SetOptions(merge: true));

  @override
  Stream<List<AppNotification>> watchNotifications(String uid) =>
      _user(uid)
          .collection('notifications')
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
      _user(uid).collection('notifications').doc(id).update({'read': true});

  @override
  Future<void> addReport({
    required String uid,
    required String analysisId,
    required String storagePath,
    required String downloadUrl,
    required int sizeKb,
  }) => _user(uid).collection('reports').add({
    'analysisId': analysisId,
    'storagePath': storagePath,
    'downloadUrl': downloadUrl,
    'sizeKb': sizeKb,
    'createdAt': FieldValue.serverTimestamp(),
  });
}
