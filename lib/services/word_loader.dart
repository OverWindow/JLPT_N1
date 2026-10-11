import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/japanese_word.dart';

class WordLoader {
  static Future<List<JapaneseWord>> load({AssetBundle? bundle}) async =>
      parse(await (bundle ?? rootBundle).loadString('assets/words/words.json'));

  static List<JapaneseWord> parse(String source) {
    final data = jsonDecode(source);
    if (data is! List) {
      throw const FormatException('단어 데이터는 JSON 배열이어야 합니다.');
    }
    final words = <JapaneseWord>[];
    final seen = <String>{};
    for (var i = 0; i < data.length; i++) {
      try {
        final entry = data[i];
        if (entry is! Map<String, dynamic>) {
          throw const FormatException('단어는 JSON 객체여야 합니다.');
        }
        final word = JapaneseWord.fromJson(entry);
        final key = word.progressKey;
        if (!seen.add(key)) {
          throw FormatException('중복 단어: ${word.prompt} (${word.hiragana})');
        }
        words.add(word);
      } on FormatException catch (error) {
        throw FormatException('${i + 1}번째 단어: ${error.message}');
      }
    }
    return List.unmodifiable(words);
  }
}
