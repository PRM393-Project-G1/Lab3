import '../firebase/analytics_service.dart';
import '../firebase/remote_config_service.dart';
import '../models/analysis_results.dart';
import '../models/ref_status.dart';
import '../models/reference.dart';
import '../models/topic_tree.dart';
import '../services/analysis_repository.dart';
import 'base_view_model.dart';
import 'view_state.dart';

/// One visible row of the tree. A null [expanded] means no chevron: the node is
/// a leaf, or its children open on their own screen.
class TopicRow {
  const TopicRow(this.node, {this.expanded});

  final TopicNode node;
  final bool? expanded;
}

class TopicMapViewModel extends BaseViewModel {
  TopicMapViewModel({
    required this._analyses,
    required this._remoteConfig,
    required this._analytics,
    required this.analysisId,
  }) {
    _remoteConfig.addListener(_rebuild);
    load();
  }

  /// Levels below this one are opened on the Topic screen.
  static const maxInlineDepth = 3;

  final String analysisId;
  final AnalysisRepository _analyses;
  final RemoteConfigService _remoteConfig;
  final AnalyticsService _analytics;

  ViewState<TopicTree> _state = const Loading();
  AnalysisResults _results = const AnalysisResults();
  final Set<String> _collapsed = {};
  bool _weakOnly = false;

  ViewState<TopicTree> get state => _state;
  bool get weakOnly => _weakOnly;
  String? get paperTitle => _results.analysis?.displayTitle;

  /// References with no readable text, so no topic.
  Iterable<Reference> get _unclassified =>
      _results.references.where((ref) => ref.isUnclassified);

  int get unclassifiedCount => _unclassified.length;

  StatusCounts get unclassifiedCounts =>
      StatusCounts.fromStatuses(_unclassified.map((ref) => ref.status));

  /// Whole percent used by the footer rule, from Remote Config.
  int get weakPercent => _remoteConfig.weakTopicRule.percent;

  List<TopicRow> get rows {
    final tree = _state.valueOrNull;
    if (tree == null) return const [];
    final rows = <TopicRow>[];
    void visit(TopicNode node) {
      if (_weakOnly && !node.isWeak && !node.hasWeakBelow) return;
      final canExpand = node.children.isNotEmpty && node.depth < maxInlineDepth;
      // The Weak filter always shows the way down to a weak topic.
      final expanded =
          canExpand && (_weakOnly || !_collapsed.contains(node.id));
      rows.add(TopicRow(node, expanded: canExpand ? expanded : null));
      if (expanded) node.children.forEach(visit);
    }

    tree.roots.forEach(visit);
    return rows;
  }

  Future<void> load() async {
    _state = const Loading();
    notifyListeners();
    try {
      _results = await _analyses.getResults(analysisId);
      _rebuild();
    } catch (_) {
      _state = const Failure.loadFailed();
      notifyListeners();
    }
  }

  void toggle(String topicId) {
    if (!_collapsed.remove(topicId)) _collapsed.add(topicId);
    notifyListeners();
  }

  void setWeakOnly(bool value) {
    if (value == _weakOnly) return;
    _weakOnly = value;
    notifyListeners();
    if (value) _analytics.logFilterWeakTopics(analysisId);
  }

  void _rebuild() {
    if (_results.analysis == null) {
      notifyListeners();
      return;
    }
    _state = _results.topics.isEmpty && unclassifiedCount == 0
        ? const Empty()
        : Data(_results.tree(_remoteConfig.weakTopicRule));
    notifyListeners();
  }

  @override
  void dispose() {
    _remoteConfig.removeListener(_rebuild);
    super.dispose();
  }
}
