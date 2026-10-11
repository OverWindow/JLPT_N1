import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/models/japanese_word.dart';
import 'package:jlpt/services/word_loader.dart';

void main() {
  test('all words have a complete example, kana readings and Korean', () {
    final words = WordLoader.parse(
      File('assets/words/words.json').readAsStringSync(),
    );
    final audit = jsonDecode(File('data/import-v1.3.json').readAsStringSync());
    expect(words.length, audit['total']);
    final sentences = <String>{};
    for (final word in words) {
      final example = word.example;
      expect(example, isNotNull, reason: word.prompt);
      expect(example!.korean, matches(RegExp(r'[가-힣]')));
      expect(example.japanese.endsWith('。'), isTrue, reason: word.prompt);
      expect(example.reading, isNot(matches(RegExp(r'[一-鿿々〆ヶ]'))));
      expect(example.japanese, isNot(contains('{w}')));
      expect(
        sentences.add(example.japanese),
        isTrue,
        reason: 'Repeated example: ${word.prompt}',
      );
      for (final part in example.segments) {
        if (RegExp(r'[一-鿿々〆ヶ]').hasMatch(part.text)) {
          expect(part.reading, isNotNull, reason: part.text);
        }
      }
    }
  });

  test(
    'source examples cover each word exactly once and match compiled content',
    () {
      final words = WordLoader.parse(
        File('assets/words/words.json').readAsStringSync(),
      );
      final seen = <int>{};
      final files = Directory('data/examples')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.tsv'));
      for (final file in files) {
        for (final line in file.readAsLinesSync()) {
          final cells = line.split('\t');
          expect(cells.length, 3);
          final index = int.parse(cells[0]) - 1;
          expect(seen.add(index), isTrue);
          final word = words[index];
          final japanese = cells[1]
              .replaceAll('{w}', word.prompt)
              .replaceAllMapped(RegExp(r'\[([^|\]]+)\|[^\]]+\]'), (m) => m[1]!);
          expect(word.example!.japanese, japanese);
          expect(word.example!.korean, cells[2]);
        }
      }
      expect(seen, Set.of(List.generate(words.length, (i) => i)));
    },
  );

  test('invalid examples fail clearly and examples do not change progress identity', () {
    for (final example in [
      {},
      {'segments': [], 'korean': '뜻'},
      {
        'segments': [
          {'text': '学校'},
        ],
        'korean': '학교',
      },
      {
        'segments': [
          {'text': '学校', 'reading': 'school'},
        ],
        'korean': '학교',
      },
      {
        'segments': [
          {'text': '', 'reading': 'がっこう'},
        ],
        'korean': '학교',
      },
      {
        'segments': [
          {'text': '学校', 'reading': 'がっこう'},
        ],
        'korean': '',
      },
    ]) {
      expect(
        () => WordLoader.parse(
          jsonEncode([
            {
              'kanji': '学校',
              'hiragana': 'がっこう',
              'korean': '학교',
              'example': example,
            },
          ]),
        ),
        throwsFormatException,
      );
    }
    const word = JapaneseWord(kanji: '学校', hiragana: 'がっこう', korean: '학교');
    const withExample = JapaneseWord(
      kanji: '学校',
      hiragana: 'がっこう',
      korean: '학교',
      example: WordExample(
        segments: [RubySegment('学校', 'がっこう'), RubySegment('へいく。')],
        korean: '학교에 간다.',
      ),
    );
    expect(withExample.progressKey, word.progressKey);
  });
}
