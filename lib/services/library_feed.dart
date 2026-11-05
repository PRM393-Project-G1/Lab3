import 'dart:async';

import '../models/analysis.dart';
import '../models/library_entry.dart';
import 'analysis_repository.dart';
import 'library_repository.dart';

/// The user's history joined with the live status of each paper, so a card
/// marked Running updates as soon as the backend finishes.
class LibraryFeed {
  LibraryFeed(this._library, this._analyses);

  final LibraryRepository _library;
  final AnalysisRepository _analyses;

  Stream<List<LibraryEntry>> watch(String uid) {
    late final StreamController<List<LibraryEntry>> out;
    StreamSubscription<List<LibraryEntry>>? entriesSub;
    final watchers = <String, StreamSubscription<Analysis?>>{};
    final latest = <String, Analysis?>{};
    var entries = <LibraryEntry>[];

    void emit() => out.add([
      for (final entry in entries) entry.withAnalysis(latest[entry.arxivId]),
    ]);

    void sync(List<LibraryEntry> next) {
      entries = next;
      final ids = {for (final entry in next) entry.arxivId};
      for (final id in watchers.keys.toList()) {
        if (!ids.contains(id)) {
          watchers.remove(id)?.cancel();
          latest.remove(id);
        }
      }
      for (final id in ids) {
        watchers[id] ??= _analyses.watchAnalysis(id).listen((analysis) {
          latest[id] = analysis;
          emit();
        }, onError: out.addError);
      }
      emit();
    }

    out = StreamController<List<LibraryEntry>>(
      onListen: () {
        entriesSub = _library
            .watchLibrary(uid)
            .listen(sync, onError: out.addError);
      },
      onCancel: () async {
        await entriesSub?.cancel();
        await Future.wait(watchers.values.map((sub) => sub.cancel()));
      },
    );
    return out.stream;
  }
}
