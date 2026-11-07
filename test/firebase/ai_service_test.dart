import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:realtron/firebase/ai_service.dart';
import 'package:realtron/models/topic_relation.dart';

void main() {
  const terms = ['Attention', 'Self-attention', 'Transformer', 'Encoder'];

  String answer(List<Object?> relations) =>
      jsonEncode({'relations': relations});

  group('parseRelations', () {
    test('keeps relations between the given terms, spelled as given', () {
      final relations = parseRelations(
        answer([
          {'from': 'self-attention', 'to': ' ATTENTION ', 'type': 'is_a'},
          {'from': 'Encoder', 'to': 'Transformer', 'type': 'part_of'},
        ]),
        terms,
      );

      expect(relations, const [
        TopicRelation('Self-attention', 'Attention', RelationKind.isA),
        TopicRelation('Encoder', 'Transformer', RelationKind.partOf),
      ]);
    });

    test('skips unknown terms and types, self-links and malformed items', () {
      final relations = parseRelations(
        answer([
          {'from': 'Attention', 'to': 'Recurrence', 'type': 'is_a'},
          {'from': 'Attention', 'to': 'Transformer', 'type': 'uses'},
          {'from': 'Attention', 'to': 'attention', 'type': 'same_as'},
          {'from': 'Attention', 'type': 'is_a'},
          'Attention is_a Transformer',
          null,
          {'from': 'Encoder', 'to': 'Transformer', 'type': 'part_of'},
        ]),
        terms,
      );

      expect(relations, const [
        TopicRelation('Encoder', 'Transformer', RelationKind.partOf),
      ]);
    });

    test('keeps each relation once, whichever way same_as is written', () {
      final relations = parseRelations(
        answer([
          {'from': 'Self-attention', 'to': 'Attention', 'type': 'same_as'},
          {'from': 'Attention', 'to': 'Self-attention', 'type': 'same_as'},
          {'from': 'Encoder', 'to': 'Transformer', 'type': 'part_of'},
          {'from': 'encoder', 'to': 'transformer', 'type': 'part_of'},
        ]),
        terms,
      );

      expect(relations, const [
        TopicRelation('Attention', 'Self-attention', RelationKind.sameAs),
        TopicRelation('Encoder', 'Transformer', RelationKind.partOf),
      ]);
    });

    test('keeps at most maxRelations', () {
      final many = [for (var i = 0; i < 100; i++) 'Topic $i'];
      final relations = parseRelations(
        answer([
          for (var i = 1; i < many.length; i++)
            {'from': many[i], 'to': many[0], 'type': 'is_a'},
        ]),
        many,
      );

      expect(relations, hasLength(maxRelations));
    });

    test('returns nothing for text that is not the expected JSON', () {
      expect(parseRelations('', terms), isEmpty);
      expect(parseRelations('Sorry, I cannot help', terms), isEmpty);
      expect(parseRelations('[1, 2]', terms), isEmpty);
      expect(parseRelations('{"relations": "none"}', terms), isEmpty);
    });
  });

  group('relationPrompt', () {
    test('names the paper and lists every term', () {
      final prompt = relationPrompt(terms, 'Attention Is All You Need');

      expect(prompt, contains('the paper "Attention Is All You Need"'));
      for (final term in terms) {
        expect(prompt, contains('- $term'));
      }
      for (final kind in RelationKind.values) {
        expect(prompt, contains(kind.key));
      }
    });

    test('works without a title', () {
      expect(relationPrompt(terms, null), contains('a research paper'));
      expect(relationPrompt(terms, ''), contains('a research paper'));
    });
  });

  test('RelationKind reads only known keys', () {
    expect(RelationKind.fromKey('part_of'), RelationKind.partOf);
    expect(RelationKind.fromKey('PART_OF'), isNull);
    expect(RelationKind.fromKey(null), isNull);
    expect(RelationKind.fromKey(3), isNull);
  });
}
