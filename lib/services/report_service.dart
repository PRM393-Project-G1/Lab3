import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/analysis.dart';
import '../models/ref_status.dart';
import '../models/reference.dart';
import '../models/topic_tree.dart';

abstract class ReportService {
  Future<Uint8List> buildReport({
    required Analysis analysis,
    required List<TopicNode> weakTopics,
    required List<Reference> flagged,
  });
}

class PdfReportService implements ReportService {
  /// The built-in PDF fonts only cover Latin-1.
  String _safe(String value) => value.replaceAll(RegExp(r'[^\x20-\xFF]'), '?');

  @override
  Future<Uint8List> buildReport({
    required Analysis analysis,
    required List<TopicNode> weakTopics,
    required List<Reference> flagged,
  }) async {
    final doc = pw.Document(title: 'Realtron report ${analysis.id}');
    final c = analysis.counts;
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Header(level: 0, text: _safe(analysis.displayTitle)),
          pw.Text('arXiv:${analysis.id}'),
          if (analysis.authors.isNotEmpty)
            pw.Text(_safe(analysis.authors.join(', '))),
          pw.SizedBox(height: 16),
          pw.Header(level: 1, text: 'References (${analysis.totalRefs})'),
          pw.TableHelper.fromTextArray(
            headers: const ['Status', 'Count'],
            data: [
              for (final s in RefStatus.values) [s.name, '${c.of(s)}'],
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Header(level: 1, text: 'Weak topics (${weakTopics.length})'),
          if (weakTopics.isEmpty) pw.Text('No weak topics'),
          for (final t in weakTopics)
            pw.Bullet(
              text:
                  '${_safe(t.term)}: ${t.counts.issues} of ${t.counts.total} refs have issues',
            ),
          pw.SizedBox(height: 16),
          pw.Header(level: 1, text: 'Flagged references (${flagged.length})'),
          for (final r in flagged)
            pw.Paragraph(
              text:
                  '[${r.index}] ${r.status.name.toUpperCase()}: ${_safe(r.title)}. ${_safe(r.byline)}'
                  '${r.firstIssue == null ? '' : ' ${_safe(r.firstIssue!)}'}',
            ),
        ],
      ),
    );
    return doc.save();
  }
}
