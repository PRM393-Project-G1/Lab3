import 'package:cloud_firestore/cloud_firestore.dart';

/// Every Firestore location the app reads or writes. The data model is in
/// `docs/architecture.md`, section 7; collection names live here only.
class FirestorePaths {
  const FirestorePaths(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> user(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> library(String uid) =>
      user(uid).collection('library');

  CollectionReference<Map<String, dynamic>> notifications(String uid) =>
      user(uid).collection('notifications');

  CollectionReference<Map<String, dynamic>> reports(String uid) =>
      user(uid).collection('reports');

  DocumentReference<Map<String, dynamic>> analysis(String id) =>
      _db.collection('analyses').doc(id);

  CollectionReference<Map<String, dynamic>> topics(String analysisId) =>
      analysis(analysisId).collection('topics');

  CollectionReference<Map<String, dynamic>> references(String analysisId) =>
      analysis(analysisId).collection('references');
}

/// Turns Firestore timestamps into [DateTime], so models stay free of Firebase.
Map<String, dynamic> withDates(Map<String, dynamic> data) => data.map(
  (key, value) => MapEntry(key, value is Timestamp ? value.toDate() : value),
);
