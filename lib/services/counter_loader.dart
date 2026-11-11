import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/japanese_word.dart';

class CounterDeck {
  const CounterDeck({
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
  String get quizTitle => '$category · $title';
}

class CounterLoader {
  static Future<List<CounterDeck>> load({AssetBundle? bundle}) async => parse(
    await (bundle ?? rootBundle).loadString('assets/counters/counters.json'),
  );

  static List<CounterDeck> parse(String source) {
    final data = jsonDecode(source);
    if (data is! Map<String, dynamic> || data['decks'] is! List) {
      throw const FormatException('조수사 세트 목록이 필요합니다.');
    }
    final decks = <CounterDeck>[];
    final ids = <String>{};
    final wordIds = <String>{};
    for (final row in data['decks']) {
      if (row is! Map<String, dynamic>) {
        throw const FormatException('조수사 세트가 올바르지 않습니다.');
      }
      String field(String key) {
        final value = row[key];
        if (value is! String || value.trim().isEmpty) {
          throw FormatException('조수사 $key 값이 필요합니다.');
        }
        return value;
      }

      final id = field('id');
      if (!ids.add(id) ||
          row['items'] is! List ||
          (row['items'] as List).isEmpty) {
        throw const FormatException('빈 세트 또는 중복된 조수사 세트입니다.');
      }
      final words = <JapaneseWord>[];
      for (final item in row['items']) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('조수사 항목이 올바르지 않습니다.');
        }
        final word = JapaneseWord.fromJson(item);
        final number = item['number'];
        if (number != null && (number is! int || number < 0)) {
          throw const FormatException('조수사 숫자가 올바르지 않습니다.');
        }
        if (word.id != '$id.${number ?? 'question'}' ||
            !wordIds.add(word.id!) ||
            !word.hasKanji ||
            word.example == null ||
            !RegExp(r'^[ぁ-ゖー]+$').hasMatch(word.hiragana) ||
            RegExp(r'[0-9０-９]').hasMatch(word.prompt)) {
          throw const FormatException('조수사 ID·한자·읽기·예문을 확인하세요.');
        }
        words.add(word);
      }
      decks.add(
        CounterDeck(
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
