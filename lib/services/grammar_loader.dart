import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/japanese_word.dart';

class GrammarDeck {
  const GrammarDeck({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.words,
  });
  final String id;
  final String category;
  final String title;
  final String description;
  final List<JapaneseWord> words;
  String get quizTitle => 'N1 문법 · $title';
}

class GrammarLoader {
  static Future<List<GrammarDeck>> load({AssetBundle? bundle}) async => parse(
    await (bundle ?? rootBundle).loadString('assets/grammar/grammar.json'),
  );

  static List<GrammarDeck> parse(String source) {
    final data = jsonDecode(source);
    if (data is! Map<String, dynamic> || data['decks'] is! List) {
      throw const FormatException('N1 문법 세트 목록이 필요합니다.');
    }
    final decks = <GrammarDeck>[];
    final ids = <String>{};
    final wordIds = <String>{};
    for (final row in data['decks']) {
      if (row is! Map<String, dynamic>) {
        throw const FormatException('N1 문법 세트가 올바르지 않습니다.');
      }
      String field(String key) {
        final value = row[key];
        if (value is! String || value.trim().isEmpty) {
          throw FormatException('N1 문법 $key 값이 필요합니다.');
        }
        return value;
      }

      final id = field('id');
      if (!ids.add(id) ||
          row['items'] is! List ||
          (row['items'] as List).isEmpty) {
        throw const FormatException('빈 세트 또는 중복된 N1 문법 세트입니다.');
      }
      final words = <JapaneseWord>[];
      for (final item in row['items']) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('N1 문법 항목이 올바르지 않습니다.');
        }
        final word = JapaneseWord.fromJson(item);
        if (word.id == null ||
            !RegExp(r'^grammar\.(noun|verb|mixed|multi)\.[0-9]{3}$')
                .hasMatch(word.id!) ||
            !wordIds.add(word.id!) ||
            word.example == null ||
            word.connection == null ||
            !RegExp(r'^[ぁ-ゖー～／…（）]+$').hasMatch(word.hiragana)) {
          throw const FormatException('N1 문법 ID·읽기·접속·예문을 확인하세요.');
        }
        words.add(word);
      }
      decks.add(
        GrammarDeck(
          id: id,
          category: field('category'),
          title: field('title'),
          description: field('description'),
          words: List.unmodifiable(words),
        ),
      );
    }
    return List.unmodifiable(decks);
  }
}
