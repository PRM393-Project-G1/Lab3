import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:realtron/utils/force_layout.dart';

void main() {
  const size = Size(400, 640);
  final ids = [for (var i = 0; i < 12; i++) 'n$i'];
  // Two triangles joined by one link, and six loose nodes.
  const links = [
    ('n0', 'n1'),
    ('n1', 'n2'),
    ('n2', 'n0'),
    ('n3', 'n4'),
    ('n4', 'n5'),
    ('n5', 'n3'),
    ('n2', 'n3'),
  ];

  test('gives the same positions for the same input', () {
    expect(
      forceLayout(ids, links, size: size),
      forceLayout(ids, links, size: size),
    );
  });

  test('keeps every node inside the padded area', () {
    final positions = forceLayout(ids, links, size: size, padding: 24);

    expect(positions.keys, unorderedEquals(ids));
    for (final p in positions.values) {
      expect(p.dx, inInclusiveRange(24 - 1e-6, size.width - 24 + 1e-6));
      expect(p.dy, inInclusiveRange(24 - 1e-6, size.height - 24 + 1e-6));
    }
  });

  test('puts linked nodes closer than unlinked ones', () {
    final p = forceLayout(ids, links, size: size);
    double distance(String a, String b) => (p[a]! - p[b]!).distance;

    final linked = [for (final (a, b) in links) distance(a, b)];
    final unlinked = [
      for (var i = 0; i < 6; i++)
        for (var j = 6; j < 12; j++) distance('n$i', 'n$j'),
    ];
    double mean(List<double> values) =>
        values.reduce((a, b) => a + b) / values.length;

    expect(mean(linked), lessThan(mean(unlinked)));
  });

  test('ignores links to unknown nodes and handles tiny graphs', () {
    expect(forceLayout(const [], const []), isEmpty);
    expect(forceLayout(const ['a'], const [], size: size), {
      'a': const Offset(200, 320),
    });
    final two = forceLayout(const ['a', 'b'], const [('a', 'ghost')]);
    expect(two, hasLength(2));
    expect(two['a'], isNot(two['b']));
  });
}
