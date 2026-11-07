import 'dart:async';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';

import '../models/topic_relation.dart';

/// Gemini through Firebase AI Logic. The Gemini key stays with Firebase, and
/// App Check proves each request comes from this app.
abstract class AiService {
  /// Named relations between [terms], which are topics of one paper.
  /// [paperTitle] gives Gemini the field the terms belong to.
  ///
  /// Throws [AiException] when Gemini gives no answer.
  Future<List<TopicRelation>> relateTerms(
    List<String> terms, {
    required String model,
    String? paperTitle,
  });
}

/// Why Gemini gave no answer, as far as the user can act on it.
enum AiFailure {
  /// Overloaded or a server error; usually passes within minutes.
  busy,

  /// The free daily or per-minute limit is used up.
  quota,
  timeout,
  other,
}

class AiException implements Exception {
  const AiException(this.failure, [this.cause]);

  final AiFailure failure;
  final Object? cause;

  @override
  String toString() => 'AiException(${failure.name}): $cause';
}

class FirebaseAiService implements AiService {
  FirebaseAiService({FirebaseAI? ai}) : _ai = ai ?? FirebaseAI.googleAI();

  static const timeout = Duration(seconds: 45);

  final FirebaseAI _ai;

  // One answer per paper and model for the session: opening the graph again
  // costs no request.
  final _cache = <String, List<TopicRelation>>{};

  static final _schema = Schema.object(
    properties: {
      'relations': Schema.array(
        items: Schema.object(
          properties: {
            'from': Schema.string(description: 'A topic, exactly as given'),
            'to': Schema.string(description: 'A topic, exactly as given'),
            'type': Schema.enumString(
              enumValues: [for (final kind in RelationKind.values) kind.key],
            ),
          },
        ),
      ),
    },
  );

  @override
  Future<List<TopicRelation>> relateTerms(
    List<String> terms, {
    required String model,
    String? paperTitle,
  }) async {
    final key = '$model\n${paperTitle ?? ''}\n${terms.join('\n')}';
    final cached = _cache[key];
    if (cached != null) return cached;

    final gemini = _ai.generativeModel(
      model: model,
      generationConfig: GenerationConfig(
        temperature: 0,
        responseMimeType: 'application/json',
        responseSchema: _schema,
      ),
    );
    final GenerateContentResponse response;
    try {
      response = await gemini
          .generateContent([Content.text(relationPrompt(terms, paperTitle))])
          .timeout(timeout);
    } on TimeoutException catch (error) {
      throw AiException(AiFailure.timeout, error);
    } on QuotaExceeded catch (error) {
      throw AiException(AiFailure.quota, error);
    } on ServerException catch (error) {
      // For example "This model is currently experiencing high demand".
      throw AiException(AiFailure.busy, error);
    } on Exception catch (error) {
      throw AiException(AiFailure.other, error);
    }
    final relations = parseRelations(response.text ?? '', terms);
    _cache[key] = relations;
    return relations;
  }
}

/// Most relations kept from one answer, so a long answer cannot clutter the graph.
const maxRelations = 60;

String relationPrompt(List<String> terms, String? paperTitle) {
  final context = paperTitle == null || paperTitle.isEmpty
      ? 'a research paper'
      : 'the paper "$paperTitle"';
  return '''
These topics were extracted from the works cited by $context.
Label the relations between them that you are confident about:
- is_a: "from" is a kind, method or subfield of "to".
- part_of: "from" is a component or part of "to".
- same_as: both topics name the same concept.
Use the topic names exactly as written. Leave out pairs that are only loosely related.

Topics:
${terms.map((term) => '- $term').join('\n')}''';
}

/// Keeps only relations between the given [terms], each once, with the terms
/// spelled as given. Anything malformed is skipped.
List<TopicRelation> parseRelations(String json, Iterable<String> terms) {
  final canonical = {for (final term in terms) term.trim().toLowerCase(): term};
  Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return const [];
  }
  final items = decoded is Map ? decoded['relations'] : null;
  if (items is! List) return const [];

  final seen = <TopicRelation>{};
  final relations = <TopicRelation>[];
  for (final item in items) {
    if (item is! Map) continue;
    final kind = RelationKind.fromKey(item['type']);
    final from = canonical[item['from']?.toString().trim().toLowerCase()];
    final to = canonical[item['to']?.toString().trim().toLowerCase()];
    if (kind == null || from == null || to == null || from == to) continue;
    // "A same_as B" and "B same_as A" are one relation.
    final relation = kind == RelationKind.sameAs && from.compareTo(to) > 0
        ? TopicRelation(to, from, kind)
        : TopicRelation(from, to, kind);
    if (seen.add(relation)) relations.add(relation);
    if (relations.length == maxRelations) break;
  }
  return relations;
}
