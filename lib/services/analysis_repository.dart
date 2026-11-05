import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/analysis.dart';
import '../models/reference.dart';
import '../models/topic.dart';

/// The device has no network and no cached copy of the document.
class OfflineException implements Exception {
  const OfflineException();
}

/// Shared results under `analyses/{id}`. Only the backend writes these.
abstract class AnalysisRepository {
  Future<Analysis?> getAnalysis(String id);
  Stream<Analysis?> watchAnalysis(String id);
  Future<List<Topic>> getTopics(String id);
  Future<List<Reference>> getReferences(String id);
  Future<Reference?> getReference(String id, String refId);
}

class FirestoreAnalysisRepository implements AnalysisRepository {
  FirestoreAnalysisRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String id) =>
      _db.collection('analyses').doc(id);

  Analysis? _map(DocumentSnapshot<Map<String, dynamic>> snap) => snap.exists
      ? Analysis.fromMap(
          snap.id,
          snap.data()!,
          fromCache: snap.metadata.isFromCache,
        )
      : null;

  @override
  Future<Analysis?> getAnalysis(String id) async {
    try {
      return _map(await _doc(id).get());
    } on FirebaseException catch (error) {
      if (error.code == 'unavailable') throw const OfflineException();
      rethrow;
    }
  }

  @override
  Stream<Analysis?> watchAnalysis(String id) =>
      _doc(id).snapshots(includeMetadataChanges: true).map(_map);

  @override
  Future<List<Topic>> getTopics(String id) async {
    final snap = await _doc(id).collection('topics').get();
    return snap.docs.map((d) => Topic.fromMap(d.id, d.data())).toList();
  }

  @override
  Future<List<Reference>> getReferences(String id) async {
    final snap = await _doc(id).collection('references').orderBy('index').get();
    return snap.docs.map((d) => Reference.fromMap(d.id, d.data())).toList();
  }

  @override
  Future<Reference?> getReference(String id, String refId) async {
    final snap = await _doc(id).collection('references').doc(refId).get();
    return snap.exists ? Reference.fromMap(snap.id, snap.data()!) : null;
  }
}
