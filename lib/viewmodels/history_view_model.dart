import 'dart:async';

import '../firebase/auth_service.dart';
import '../firebase/crashlytics_service.dart';
import '../models/library_entry.dart';
import '../services/library_feed.dart';
import '../services/library_repository.dart';
import 'base_view_model.dart';
import 'view_state.dart';

enum HistoryPeriod { today, thisWeek, earlier }

class HistoryGroup {
  const HistoryGroup(this.period, this.entries);

  final HistoryPeriod period;
  final List<LibraryEntry> entries;
}

class HistoryViewModel extends BaseViewModel {
  HistoryViewModel({
    required this._library,
    required this._feed,
    required this._auth,
    required this._crashlytics,
  }) {
    load();
  }

  final LibraryRepository _library;
  final LibraryFeed _feed;
  final AuthService _auth;
  final CrashlyticsService _crashlytics;

  StreamSubscription<List<LibraryEntry>>? _sub;
  ViewState<List<LibraryEntry>> _state = const Loading();
  String _query = '';

  ViewState<List<LibraryEntry>> get state => _state;
  String get query => _query;

  void load() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    _sub?.cancel();
    _state = const Loading();
    notifyListeners();
    _sub = _feed
        .watch(uid)
        .listen(
          (entries) {
            _state = listState(entries);
            notifyListeners();
          },
          onError: (Object error, StackTrace stack) {
            _state = const Failure.loadFailed();
            _crashlytics.recordNonFatal(error, stack, reason: 'load_history');
            notifyListeners();
          },
        );
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  /// Search result grouped by time, newest first. Empty groups are left out.
  List<HistoryGroup> groups({DateTime? now}) {
    final entries = _state.valueOrNull ?? const <LibraryEntry>[];
    final query = _query.trim().toLowerCase();
    final matches = entries.where(
      (e) =>
          query.isEmpty ||
          e.title.toLowerCase().contains(query) ||
          e.arxivId.contains(query),
    );
    final today = _startOfDay(now ?? DateTime.now());
    final byPeriod = <HistoryPeriod, List<LibraryEntry>>{};
    for (final entry in matches) {
      final day = _startOfDay(entry.sortTime);
      final period = !day.isBefore(today)
          ? HistoryPeriod.today
          : today.difference(day).inDays < 7
          ? HistoryPeriod.thisWeek
          : HistoryPeriod.earlier;
      byPeriod.putIfAbsent(period, () => []).add(entry);
    }
    return [
      for (final period in HistoryPeriod.values)
        if (byPeriod[period] != null)
          HistoryGroup(
            period,
            byPeriod[period]!..sort((a, b) => b.sortTime.compareTo(a.sortTime)),
          ),
    ];
  }

  static DateTime _startOfDay(DateTime time) =>
      DateTime(time.year, time.month, time.day);

  Future<void> touch(LibraryEntry entry) =>
      _write((uid) => _library.addOrTouch(uid, entry.arxivId));

  Future<bool> rename(LibraryEntry entry, String title) =>
      _write((uid) => _library.rename(uid, entry.arxivId, title.trim()));

  /// Removes it from this user's history only.
  Future<bool> delete(LibraryEntry entry) =>
      _write((uid) => _library.remove(uid, entry.arxivId));

  Future<bool> _write(Future<void> Function(String uid) write) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    try {
      await write(uid);
      return true;
    } catch (error, stack) {
      await _crashlytics.recordNonFatal(error, stack, reason: 'edit_history');
      return false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
