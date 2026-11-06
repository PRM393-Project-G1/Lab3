import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase/firestore_schema.dart';
import '../models/library_entry.dart';

/// The user's own history at `users/{uid}/library`. Deleting a row here never
/// touches the shared result.
abstract class LibraryRepository {
  Stream<List<LibraryEntry>> watchLibrary(String uid);
  Future<void> addOrTouch(String uid, String arxivId);
  Future<void> rename(String uid, String arxivId, String title);
  Future<void> remove(String uid, String arxivId);
}

class FirestoreLibraryRepository implements LibraryRepository {
  FirestoreLibraryRepository({FirebaseFirestore? db})
    : _paths = FirestorePaths(db ?? FirebaseFirestore.instance);

  final FirestorePaths _paths;

  @override
  Stream<List<LibraryEntry>> watchLibrary(String uid) => _paths
      .library(uid)
      .orderBy('lastOpenedAt', descending: true)
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((d) => LibraryEntry.fromMap(d.id, withDates(d.data())))
            .toList(),
      );

  @override
  Future<void> addOrTouch(String uid, String arxivId) async {
    final doc = _paths.library(uid).doc(arxivId);
    final snap = await doc.get();
    await doc.set({
      if (!snap.exists) 'addedAt': FieldValue.serverTimestamp(),
      'lastOpenedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> rename(String uid, String arxivId, String title) =>
      _paths.library(uid).doc(arxivId).update({'customTitle': title});

  @override
  Future<void> remove(String uid, String arxivId) =>
      _paths.library(uid).doc(arxivId).delete();
}
