import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/knowledge_graph.dart';
import '../theme/app_theme_extensions.dart';
import '../theme/app_tokens.dart';

/// Pan and zoom over a laid-out [KnowledgeGraph]. Tapping a node calls
/// [onNodeTap]; tapping empty space calls [onBackgroundTap].
///
/// Nodes keep their size on screen whatever the graph's size, and labels keep
/// theirs while zooming; a label that would cover another is left out.
class KnowledgeGraphView extends StatefulWidget {
  const KnowledgeGraphView({
    super.key,
    required this.graph,
    required this.nodes,
    required this.edges,
    required this.onNodeTap,
    required this.onBackgroundTap,
    this.highlighted = const {},
    this.selectedId,
  });

  final KnowledgeGraph graph;

  /// The nodes and edges to draw, a subset of [graph]'s.
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;

  /// When not empty, every other node and edge is dimmed.
  final Set<String> highlighted;
  final String? selectedId;
  final ValueChanged<String> onNodeTap;
  final VoidCallback onBackgroundTap;

  static const _labelSize = 11.0;
  static const _minHit = 32.0;

  static Key nodeKey(String id) => ValueKey('graph-node-$id');

  /// Radius on screen at the fitted zoom.
  static double radiusOf(GraphNode node) => switch (node.kind) {
    GraphNodeKind.topic => (5 + 2.2 * math.sqrt(node.weight)).clamp(6.0, 18.0),
    GraphNodeKind.author => (4 + 1.5 * math.sqrt(node.weight)).clamp(5.0, 11.0),
  };

  @override
  State<KnowledgeGraphView> createState() => _KnowledgeGraphViewState();
}

class _KnowledgeGraphViewState extends State<KnowledgeGraphView> {
  final _transform = TransformationController();
  double _scale = 1;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransform);
  }

  void _onTransform() {
    final scale = _transform.value.getMaxScaleOnAxis();
    // Labels are laid out again only when the zoom changes noticeably.
    if ((scale - _scale).abs() / _scale > 0.04) setState(() => _scale = scale);
  }

  void _fit() => _transform.value = Matrix4.identity();

  @override
  void dispose() {
    _transform
      ..removeListener(_onTransform)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final viewport = constraints.biggest;
      final positions = _fitPositions(viewport);
      return Stack(
        children: [
          InteractiveViewer(
            transformationController: _transform,
            minScale: 0.8,
            maxScale: 5,
            boundaryMargin: const EdgeInsets.all(AppSpacing.xl * 3),
            child: SizedBox.fromSize(
              size: viewport,
              child: _graph(context, positions),
            ),
          ),
          Positioned(
            right: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: Material(
              color: context.colors.surface,
              shape: CircleBorder(
                side: BorderSide(color: context.colors.outlineVariant),
              ),
              child: IconButton(
                tooltip: 'Fit to screen',
                icon: const Icon(Icons.fit_screen_rounded),
                onPressed: _fit,
              ),
            ),
          ),
        ],
      );
    },
  );

  /// Most one axis is stretched more than the other to fill the viewport.
  static const _maxStretch = 1.4;

  /// The graph's positions scaled to fill [viewport], with room for labels.
  ///
  /// Uses the box around every node, shown or not, so turning a filter on or
  /// off does not move the others.
  Map<String, Offset> _fitPositions(Size viewport) {
    final all = widget.graph.positions.values;
    if (all.isEmpty) return const {};
    var bounds = Rect.fromPoints(all.first, all.first);
    for (final p in all) {
      bounds = bounds.expandToInclude(Rect.fromPoints(p, p));
    }
    bounds = Rect.fromCenter(
      center: bounds.center,
      width: math.max(bounds.width, 1),
      height: math.max(bounds.height, 1),
    );

    const side = AppSpacing.xl * 1.5;
    const above = AppSpacing.lg;
    const below = AppSpacing.xl * 1.5;
    final width = math.max(viewport.width - 2 * side, 1.0);
    final height = math.max(viewport.height - above - below, 1.0);
    var scaleX = width / bounds.width;
    var scaleY = height / bounds.height;
    scaleX = math.min(scaleX, scaleY * _maxStretch);
    scaleY = math.min(scaleY, scaleX * _maxStretch);
    final left = side + (width - bounds.width * scaleX) / 2;
    final top = above + (height - bounds.height * scaleY) / 2;
    return {
      for (final node in widget.nodes)
        if (widget.graph.positions[node.id] case final p?)
          node.id: Offset(
            left + (p.dx - bounds.left) * scaleX,
            top + (p.dy - bounds.top) * scaleY,
          ),
    };
  }

  Widget _graph(BuildContext context, Map<String, Offset> positions) {
    final colors = context.graph;
    final radii = {
      for (final node in widget.nodes)
        node.id: KnowledgeGraphView.radiusOf(node),
    };
    final dimming = widget.highlighted.isNotEmpty;
    // Smaller nodes on top, so they stay tappable next to large ones.
    final ordered = [...widget.nodes]
      ..sort((a, b) => radii[b.id]!.compareTo(radii[a.id]!));
    double box(String id) =>
        math.max(KnowledgeGraphView._minHit / _scale, radii[id]! * 2);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onBackgroundTap,
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _EdgePainter(
                edges: widget.edges,
                positions: positions,
                radii: radii,
                colors: colors,
                scale: _scale,
                selectedId: dimming ? widget.selectedId : null,
              ),
            ),
          ),
        ),
        for (final node in ordered)
          if (positions[node.id] case final p?)
            Positioned.fromRect(
              rect: Rect.fromCenter(
                center: p,
                width: box(node.id),
                height: box(node.id),
              ),
              child: _NodeDot(
                key: KnowledgeGraphView.nodeKey(node.id),
                node: node,
                radius: radii[node.id]!,
                scale: _scale,
                selected: node.id == widget.selectedId,
                dimmed: dimming && !widget.highlighted.contains(node.id),
                onTap: () => widget.onNodeTap(node.id),
              ),
            ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _LabelPainter(
                _placeLabels(context, positions, radii),
                halo: context.colors.surface,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Labels by priority: the selection, then larger nodes. One that would
  /// overlap a label already placed is skipped.
  List<_Label> _placeLabels(
    BuildContext context,
    Map<String, Offset> positions,
    Map<String, double> radii,
  ) {
    final highlighted = widget.highlighted;
    final candidates = [
      for (final node in widget.nodes)
        if (highlighted.isEmpty || highlighted.contains(node.id)) node,
    ];
    int rank(GraphNode node) => node.id == widget.selectedId
        ? 0
        : node.kind == GraphNodeKind.topic
        ? 1
        : 2;
    candidates.sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : b.weight.compareTo(a.weight);
    });

    final base = context.text.labelSmall!;
    final size = KnowledgeGraphView._labelSize / _scale;
    final gap = 2 / _scale;
    final placed = <_Label>[];
    final taken = <Rect>[];
    for (final node in candidates) {
      final center = positions[node.id];
      if (center == null) continue;
      final selected = node.id == widget.selectedId;
      final painter = TextPainter(
        text: TextSpan(
          text: node.label,
          style: base.copyWith(
            fontSize: size,
            height: 1.2,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: 112 / _scale);
      final offset = Offset(
        center.dx - painter.width / 2,
        center.dy + radii[node.id]! + gap,
      );
      final box = (offset & painter.size).inflate(gap);
      if (taken.any(box.overlaps)) {
        painter.dispose();
        continue;
      }
      taken.add(box);
      placed.add(_Label(painter, offset, size));
    }
    return placed;
  }
}

class _NodeDot extends StatelessWidget {
  const _NodeDot({
    super.key,
    required this.node,
    required this.radius,
    required this.scale,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  final GraphNode node;
  final double radius;
  final double scale;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.graph;
    final isAuthor = node.kind == GraphNodeKind.author;
    final ring = selected
        ? BorderSide(color: colors.selected, width: 3 / scale)
        : node.isWeak
        ? BorderSide(color: colors.weak, width: 2.5 / scale)
        : BorderSide(color: context.colors.surface, width: 1.5 / scale);
    final description = isAuthor
        ? 'Author ${node.label}, ${node.weight} topics'
        : '${node.label}, ${node.weight} references${node.isWeak ? ', weak' : ''}';

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: description,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Opacity(
            opacity: dimmed ? 0.25 : 1,
            child: Container(
              width: radius * 2,
              height: radius * 2,
              decoration: BoxDecoration(
                color: isAuthor ? colors.author : colors.topic,
                shape: isAuthor ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: isAuthor
                    ? BorderRadius.circular(radius * 0.3)
                    : null,
                border: Border.fromBorderSide(ring),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label {
  const _Label(this.painter, this.offset, this.fontSize);

  final TextPainter painter;
  final Offset offset;
  final double fontSize;
}

class _LabelPainter extends CustomPainter {
  _LabelPainter(this.labels, {required this.halo});

  final List<_Label> labels;
  final Color halo;

  @override
  void paint(Canvas canvas, Size size) {
    for (final label in labels) {
      // A halo in the surface colour keeps the text readable over edges.
      final outline = TextPainter(
        text: TextSpan(
          text: (label.painter.text! as TextSpan).text,
          style: label.painter.text!.style!.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = label.fontSize * 0.3
              ..strokeJoin = StrokeJoin.round
              ..color = halo,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: label.painter.width + 1);
      outline.paint(canvas, label.offset);
      outline.dispose();
      label.painter.paint(canvas, label.offset);
    }
  }

  @override
  bool shouldRepaint(_LabelPainter old) => true;
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({
    required this.edges,
    required this.positions,
    required this.radii,
    required this.colors,
    required this.scale,
    this.selectedId,
  });

  final List<GraphEdge> edges;
  final Map<String, Offset> positions;
  final Map<String, double> radii;
  final GraphColors colors;
  final double scale;

  /// When set, edges away from this node are dimmed.
  final String? selectedId;

  @override
  void paint(Canvas canvas, Size size) {
    // Named relations last, so they sit above the faint Saffron links.
    final ordered = [
      ...edges.where((e) => !e.kind.isNamed),
      ...edges.where((e) => e.kind.isNamed),
    ];
    for (final edge in ordered) {
      final a = positions[edge.from];
      final b = positions[edge.to];
      if (a == null || b == null) continue;
      final focus = selectedId == null || edge.touches(selectedId!);
      paintGraphEdge(
        canvas,
        a,
        b,
        edge.kind,
        colors,
        scale: scale,
        startInset: radii[edge.from] ?? 0,
        endInset: radii[edge.to] ?? 0,
        emphasis: selectedId != null && focus,
        dimmed: !focus,
      );
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) => true;
}

/// Draws one edge from [a] to [b], trimmed by the node radii. Each kind has
/// its own line, so the legend and the graph never rely on colour alone.
void paintGraphEdge(
  Canvas canvas,
  Offset a,
  Offset b,
  GraphEdgeKind kind,
  GraphColors colors, {
  double scale = 1,
  double startInset = 0,
  double endInset = 0,
  bool emphasis = false,
  bool dimmed = false,
}) {
  final delta = b - a;
  final length = delta.distance;
  if (length <= startInset + endInset + 1) return;
  final unit = delta / length;
  final start = a + unit * startInset;
  final end = b - unit * endInset;

  final (color, width) = switch (kind) {
    GraphEdgeKind.subtopic => (colors.edge, 1.4),
    GraphEdgeKind.related => (colors.edge, 1.3),
    GraphEdgeKind.author => (colors.author.withValues(alpha: 0.45), 1.0),
    GraphEdgeKind.isA => (colors.isA, 2.0),
    GraphEdgeKind.partOf => (colors.partOf, 2.0),
    GraphEdgeKind.sameAs => (colors.sameAs, 1.2),
  };
  final paint = Paint()
    ..color = dimmed ? color.withValues(alpha: color.a * 0.12) : color
    ..strokeWidth = width * (emphasis ? 1.5 : 1) / scale
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  switch (kind) {
    case GraphEdgeKind.related:
      _dashed(canvas, start, end, paint, 0.5 / scale, 4 / scale);
    case GraphEdgeKind.partOf:
      _dashed(canvas, start, end, paint, 6 / scale, 4 / scale);
    case GraphEdgeKind.sameAs:
      final normal = Offset(-unit.dy, unit.dx) * (1.8 / scale);
      canvas
        ..drawLine(start + normal, end + normal, paint)
        ..drawLine(start - normal, end - normal, paint);
    default:
      canvas.drawLine(start, end, paint);
  }

  if (kind == GraphEdgeKind.isA || kind == GraphEdgeKind.partOf) {
    final head = 7 / scale;
    final normal = Offset(-unit.dy, unit.dx);
    final base = end - unit * head;
    final path = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        base.dx + normal.dx * head * 0.5,
        base.dy + normal.dy * head * 0.5,
      )
      ..lineTo(
        base.dx - normal.dx * head * 0.5,
        base.dy - normal.dy * head * 0.5,
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = paint.color
        ..style = PaintingStyle.fill,
    );
  }
}

void _dashed(
  Canvas canvas,
  Offset a,
  Offset b,
  Paint paint,
  double dash,
  double gap,
) {
  final delta = b - a;
  final length = delta.distance;
  final unit = delta / length;
  for (var at = 0.0; at < length; at += dash + gap) {
    canvas.drawLine(
      a + unit * at,
      a + unit * math.min(at + dash, length),
      paint,
    );
  }
}

/// A short sample of an edge, for the legend.
class GraphEdgeSwatch extends StatelessWidget {
  const GraphEdgeSwatch(this.kind, {super.key});

  final GraphEdgeKind kind;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(28, 12),
    painter: _SwatchPainter(kind, context.graph),
  );
}

class _SwatchPainter extends CustomPainter {
  _SwatchPainter(this.kind, this.colors);

  final GraphEdgeKind kind;
  final GraphColors colors;

  @override
  void paint(Canvas canvas, Size size) => paintGraphEdge(
    canvas,
    Offset(1, size.height / 2),
    Offset(size.width - 1, size.height / 2),
    kind,
    colors,
  );

  @override
  bool shouldRepaint(_SwatchPainter old) =>
      old.kind != kind || old.colors != colors;
}
