import 'dart:convert';

class JapaneseWord {
  final String? id;
  final List<String> alternateReadings;
  final String? kanji;
  final String hiragana;
  final String korean;
  final WordExample? example;
  final String? connection;

  const JapaneseWord({
    this.id,
    this.alternateReadings = const [],
    this.kanji,
    required this.hiragana,
    required this.korean,
    this.example,
    this.connection,
  });

  bool get hasKanji => kanji != null && kanji!.trim().isNotEmpty;
  String get prompt => hasKanji ? kanji! : hiragana;
  String get answerReading => [hiragana, ...alternateReadings].join('・');

  // Source spellings are preserved; insignificant whitespace is not identity.
  String get progressKey {
    if (id != null) return id!;
    String normalize(String value) =>
        value.replaceAll(RegExp(r'\s+'), '').trim();
    return jsonEncode([normalize(prompt), normalize(hiragana)]);
  }

  factory JapaneseWord.fromJson(Map<String, dynamic> json) {
    String requiredText(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('$key 값은 비어 있지 않은 문자열이어야 합니다.');
      }
      return value.trim();
    }

    final kanji = json['kanji'];
    if (kanji != null && kanji is! String) {
      throw const FormatException('kanji 값은 문자열 또는 null이어야 합니다.');
    }
    final spelling = (kanji as String?)?.trim();
    final id = json['id'];
    if (id != null && (id is! String || id.trim().isEmpty)) {
      throw const FormatException('학습 항목 ID가 올바르지 않습니다.');
    }
    final alternatives = json['alternateReadings'] ?? <String>[];
    if (alternatives is! List ||
        alternatives.any(
          (v) => v is! String || !RegExp(r'^[ぁ-ゖー]+$').hasMatch(v),
        )) {
      throw const FormatException('대체 읽기가 올바르지 않습니다.');
    }
    return JapaneseWord(
      id: id,
      alternateReadings: List<String>.unmodifiable(alternatives),
      kanji: spelling == null || spelling.isEmpty ? null : spelling,
      hiragana: requiredText('hiragana'),
      korean: requiredText('korean'),
      connection: json['connection'] == null
          ? null
          : requiredText('connection'),
      example: json['example'] == null
          ? null
          : WordExample.fromJson(json['example']),
    );
  }
}

class RubySegment {
  const RubySegment(this.text, [this.reading]);
  final String text;
  final String? reading;
}

class WordExample {
  const WordExample({required this.segments, required this.korean});
  final List<RubySegment> segments;
  final String korean;
  String get japanese => segments.map((part) => part.text).join();
  String get reading =>
      segments.map((part) => part.reading ?? part.text).join();

  factory WordExample.fromJson(dynamic value) {
    if (value is! Map<String, dynamic> ||
        value['segments'] is! List ||
        value['korean'] is! String ||
        (value['korean'] as String).trim().isEmpty) {
      throw const FormatException('예문에는 문장과 한국어 해석이 필요합니다.');
    }
    final segments = <RubySegment>[];
    for (final part in value['segments'] as List) {
      if (part is! Map<String, dynamic> ||
          part['text'] is! String ||
          (part['text'] as String).trim().isEmpty) {
        throw const FormatException('예문 표기가 비어 있습니다.');
      }
      final text = part['text'] as String;
      final reading = part['reading'];
      if (reading != null &&
          (reading is! String || !RegExp(r'^[ぁ-ゖァ-ヺー・]+$').hasMatch(reading))) {
        throw const FormatException('예문 후리가나가 올바르지 않습니다.');
      }
      if (RegExp(r'[一-鿿々〆ヶ]').hasMatch(text) && reading == null) {
        throw const FormatException('예문 한자에 후리가나가 필요합니다.');
      }
      segments.add(RubySegment(text, reading as String?));
    }
    if (segments.isEmpty) throw const FormatException('예문이 비어 있습니다.');
    return WordExample(
      segments: List.unmodifiable(segments),
      korean: (value['korean'] as String).trim(),
    );
  }
}

class WordGroup {
  final int startIndex;
  final List<JapaneseWord> words;

  WordGroup(this.startIndex, Iterable<JapaneseWord> words)
    : words = List.unmodifiable(words);

  String get label => '${startIndex + 1}~${startIndex + words.length}';

  static List<WordGroup> fromWords(List<JapaneseWord> words) => [
    for (var start = 0; start < words.length; start += 30)
      WordGroup(start, words.skip(start).take(30)),
  ];
}
