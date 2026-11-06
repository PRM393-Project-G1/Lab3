import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:realtron/models/analysis.dart';
import 'package:realtron/models/ref_status.dart';
import 'package:realtron/models/topic.dart';
import 'package:realtron/models/topic_tree.dart';
import 'package:realtron/models/weak_topic_rule.dart';
import 'package:realtron/services/report_service.dart';

import '../fakes.dart';

void main() {
  test('builds a PDF, even from titles outside the built-in font', () async {
    final references = [
      ref('a', RefStatus.hallucinated, title: 'Học sâu 深度学习 — ∑'),
      ref('b', RefStatus.error),
      ref('c', RefStatus.verified),
    ];
    final tree = TopicTree.build(
      topics: const [
        Topic(id: 't', term: 'Chủ đề 主题', refIds: ['a', 'b', 'c']),
      ],
      references: references,
      weakRule: const WeakTopicRule(threshold: 0.5, minRefs: 3),
    );

    final bytes = await PdfReportService().buildReport(
      analysis: const Analysis(
        id: '1706.03762',
        status: AnalysisStatus.done,
        title: 'Attention Is All You Need',
        authors: ['Vaswani', 'Nguyễn'],
        counts: StatusCounts(hallucinated: 1, error: 1, verified: 1),
        totalRefs: 3,
      ),
      weakTopics: tree.weak,
      flagged: references.take(2).toList(),
    );

    expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    expect(bytes.length, greaterThan(500));
  });
}
