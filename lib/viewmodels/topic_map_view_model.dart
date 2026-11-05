import '../firebase/analytics_service.dart';
import '../firebase/remote_config_service.dart';
import '../models/analysis.dart';
import '../models/ref_status.dart';
import '../models/reference.dart';
import '../models/topic.dart';
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
  Analysis? _analysis;
  List<Topic> _topics = const [];
  List<Reference> _references = const [];
  final Set<String> _collapsed = {};
  bool _weakOnly = false;

  ViewState<TopicTree> get state => _state;
  bool get weakOnly => _weakOnly;
  String? get paperTitle => _analysis?.displayTitle;

  int get unclassifiedCount =>
      _references.where((ref) => ref.isUnclassified).length;

  StatusCounts get unclassifiedCounts {
    final refs = _references.where((ref) => ref.isUnclassified).toList();
    int of(RefStatus status) => refs.where((r) => r.status == status).length;
    return StatusCounts(
      hallucinated: of(RefStatus.hallucinated),
      error: of(RefStatus.error),
      warning: of(RefStatus.warning),
      unverified: of(RefStatus.unverified),
      verified: of(RefStatus.verified),
    );
  }

  /// Whole percent used by the footer rule, from Remote Config.
  int get weakPercent => (_remoteConfig.weakTopicThreshold * 100).round();

  List<TopicRow> get rows {
    final tree = switch (_state) {
      Data(:final value) => value,
      _ => null,
    };
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
      final (analysis, topics, references) = await (
        _analyses.getAnalysis(analysisId),
        _analyses.getTopics(analysisId),
        _analyses.getReferences(analysisId),
      ).wait;
      _analysis = analysis;
      _topics = topics;
      _references = references;
      _rebuild();
    } catch (_) {
      _state = const Failure("Couldn't load");
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
    if (_analysis == null) {
      notifyListeners();
      return;
    }
    _state = _topics.isEmpty && unclassifiedCount == 0
        ? const Empty()
        : Data(
            TopicTree.build(
              topics: _topics,
              references: _references,
              weakThreshold: _remoteConfig.weakTopicThreshold,
              weakMinRefs: _remoteConfig.weakTopicMinRefs,
            ),
          );
    notifyListeners();
  }

  @override
  void dispose() {
    _remoteConfig.removeListener(_rebuild);
    super.dispose();
  }
}
