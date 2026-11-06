import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase/firestore_schema.dart';
import '../models/analysis.dart';
import '../models/analysis_results.dart';
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

/// Built on the interface, so every repository and test double gets it free.
extension AnalysisResultsReading on AnalysisRepository {
  /// Reads the paper, its topics and its references in parallel.
  Future<AnalysisResults> getResults(String id) async {
    final (analysis, topics, references) = await (
      getAnalysis(id),
      getTopics(id),
      getReferences(id),
    ).wait;
    return AnalysisResults(
      analysis: analysis,
      topics: topics,
      references: references,
    );
  }
}

class FirestoreAnalysisRepository implements AnalysisRepository {
  FirestoreAnalysisRepository({FirebaseFirestore? db})
    : _paths = FirestorePaths(db ?? FirebaseFirestore.instance);

  final FirestorePaths _paths;

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
      return _map(await _paths.analysis(id).get());
    } on FirebaseException catch (error) {
      if (error.code == 'unavailable') throw const OfflineException();
      rethrow;
    }
  }

  @override
  Stream<Analysis?> watchAnalysis(String id) =>
      _paths.analysis(id).snapshots(includeMetadataChanges: true).map(_map);

  @override
  Future<List<Topic>> getTopics(String id) async {
    final snap = await _paths.topics(id).get();
    return snap.docs.map((d) => Topic.fromMap(d.id, d.data())).toList();
  }

  @override
  Future<List<Reference>> getReferences(String id) async {
    final snap = await _paths.references(id).orderBy('index').get();
    return snap.docs.map((d) => Reference.fromMap(d.id, d.data())).toList();
  }

  @override
  Future<Reference?> getReference(String id, String refId) async {
    final snap = await _paths.references(id).doc(refId).get();
    return snap.exists ? Reference.fromMap(snap.id, snap.data()!) : null;
  }
}
