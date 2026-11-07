import 'dart:math' as math;
import 'dart:ui';

/// Places the nodes of a graph inside [size]: linked nodes end up close, and
/// every node is pushed away from the others (Fruchterman-Reingold, with a pull
/// to the centre so separate groups stay on screen).
///
/// The same input always gives the same positions.
Map<String, Offset> forceLayout(
  List<String> ids,
  List<(String, String)> links, {
  Size size = const Size(400, 640),
  int iterations = 300,
  double padding = 24,
}) {
  final n = ids.length;
  if (n == 0) return const {};
  if (n == 1) return {ids.single: size.center(Offset.zero)};

  final index = {for (var i = 0; i < n; i++) ids[i]: i};
  final edges = [
    for (final (a, b) in links)
      if (index[a] != null && index[b] != null && a != b)
        (index[a]!, index[b]!),
  ];

  // Start on a sunflower spiral, so no two nodes share a point.
  final xs = List<double>.generate(
    n,
    (i) => 10 * math.sqrt(i + 0.5) * math.cos(i * 2.39996),
  );
  final ys = List<double>.generate(
    n,
    (i) => 10 * math.sqrt(i + 0.5) * math.sin(i * 2.39996),
  );
  final dx = List<double>.filled(n, 0);
  final dy = List<double>.filled(n, 0);

  final k = math.sqrt(size.width * size.height / n) * 0.55;
  final start = size.shortestSide / 8;

  for (var step = 0; step < iterations; step++) {
    dx.fillRange(0, n, 0);
    dy.fillRange(0, n, 0);

    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        var ddx = xs[i] - xs[j];
        var ddy = ys[i] - ys[j];
        var distance = math.sqrt(ddx * ddx + ddy * ddy);
        if (distance < 0.01) {
          ddx = 0.01 * (i - j);
          ddy = 0.01;
          distance = math.sqrt(ddx * ddx + ddy * ddy);
        }
        final push = k * k / distance;
        dx[i] += ddx / distance * push;
        dy[i] += ddy / distance * push;
        dx[j] -= ddx / distance * push;
        dy[j] -= ddy / distance * push;
      }
    }

    for (final (a, b) in edges) {
      final ddx = xs[a] - xs[b];
      final ddy = ys[a] - ys[b];
      final distance = math.max(math.sqrt(ddx * ddx + ddy * ddy), 0.01);
      final pull = distance * distance / k;
      dx[a] -= ddx / distance * pull;
      dy[a] -= ddy / distance * pull;
      dx[b] += ddx / distance * pull;
      dy[b] += ddy / distance * pull;
    }

    final temperature = start * (1 - step / iterations) + 0.5;
    for (var i = 0; i < n; i++) {
      dx[i] -= xs[i] * 0.6;
      dy[i] -= ys[i] * 0.6;
      final moved = math.sqrt(dx[i] * dx[i] + dy[i] * dy[i]);
      if (moved > 0) {
        final limited = math.min(moved, temperature);
        xs[i] += dx[i] / moved * limited;
        ys[i] += dy[i] / moved * limited;
      }
    }
  }

  // Scale the result to fill the area, keeping its shape.
  final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
  final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
  final width = math.max(maxX - minX, 1.0);
  final height = math.max(maxY - minY, 1.0);
  final scale = math.min(
    (size.width - 2 * padding) / width,
    (size.height - 2 * padding) / height,
  );
  final offsetX = (size.width - width * scale) / 2;
  final offsetY = (size.height - height * scale) / 2;
  return {
    for (var i = 0; i < n; i++)
      ids[i]: Offset(
        offsetX + (xs[i] - minX) * scale,
        offsetY + (ys[i] - minY) * scale,
      ),
  };
}
