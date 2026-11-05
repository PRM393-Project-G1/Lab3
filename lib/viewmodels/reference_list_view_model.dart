import '../models/analysis.dart';
import '../models/ref_status.dart';
import '../models/reference.dart';
import '../services/analysis_repository.dart';
import 'base_view_model.dart';
import 'view_state.dart';

/// Filter of the reference list: everything, one status, or Unclassified.
class ReferenceFilter {
  const ReferenceFilter._(this.key, {this.status});

  /// Reads the `?filter=` query value. Unknown values fall back to All.
  factory ReferenceFilter.parse(String? key) {
    if (key == unclassified.key) return unclassified;
    for (final status in RefStatus.values) {
      if (status.name == key) return ReferenceFilter.of(status);
    }
    return all;
  }

  factory ReferenceFilter.of(RefStatus status) =>
      ReferenceFilter._(status.name, status: status);

  static const all = ReferenceFilter._('all');
  static const unclassified = ReferenceFilter._('unclassified');

  final String key;
  final RefStatus? status;

  bool matches(Reference ref) {
    if (key == all.key) return true;
    if (key == unclassified.key) return ref.isUnclassified;
    return ref.status == status;
  }

  @override
  bool operator ==(Object other) =>
      other is ReferenceFilter && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

class ReferenceListViewModel extends BaseViewModel {
  ReferenceListViewModel({
    required this._analyses,
    required this.analysisId,
    String? filter,
  }) : _filter = ReferenceFilter.parse(filter) {
    load();
  }

  final String analysisId;
  final AnalysisRepository _analyses;

  ViewState<List<Reference>> _state = const Loading();
  Analysis? _analysis;
  ReferenceFilter _filter;
  String _query = '';

  ViewState<List<Reference>> get state => _state;
  ReferenceFilter get filter => _filter;
  String get query => _query;
  String? get paperTitle => _analysis?.displayTitle;

  List<Reference> get _all => switch (_state) {
    Data(:final value) => value,
    _ => const [],
  };

  int get totalCount => _all.length;

  int countOf(ReferenceFilter filter) => _all.where(filter.matches).length;

  /// Filters with at least one match, plus the one in use.
  List<ReferenceFilter> get filters => [
    ReferenceFilter.all,
    for (final status in RefStatus.values)
      if (countOf(ReferenceFilter.of(status)) > 0 ||
          _filter == ReferenceFilter.of(status))
        ReferenceFilter.of(status),
    if (countOf(ReferenceFilter.unclassified) > 0 ||
        _filter == ReferenceFilter.unclassified)
      ReferenceFilter.unclassified,
  ];

  List<Reference> get visible {
    final query = _query.trim().toLowerCase();
    return _all.where((ref) {
      if (!_filter.matches(ref)) return false;
      if (query.isEmpty) return true;
      return ref.title.toLowerCase().contains(query) ||
          ref.authors.any((a) => a.toLowerCase().contains(query));
    }).toList();
  }

  Future<void> load() async {
    _state = const Loading();
    notifyListeners();
    try {
      final (analysis, references) = await (
        _analyses.getAnalysis(analysisId),
        _analyses.getReferences(analysisId),
      ).wait;
      _analysis = analysis;
      _state = Data(sortBySeverity(references));
    } catch (_) {
      _state = const Failure("Couldn't load");
    }
    notifyListeners();
  }

  void setFilter(ReferenceFilter value) {
    _filter = value;
    notifyListeners();
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }
}
