import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/models/japanese_word.dart';
import 'package:jlpt/services/counter_loader.dart';
import 'package:jlpt/services/progress_store.dart';

void main() {
  final source = File('assets/counters/counters.json').readAsStringSync();
  final decks = CounterLoader.parse(source);
  final all = decks.expand((d) => d.words).toList();
  JapaneseWord word(String id) => all.singleWhere((w) => w.id == id);

  test('17 decks cover exact agreed numeric ranges, including questions', () {
    expect(decks.length, 17);
    expect(all.length, 270);
    expect(decks.map((d) => d.category).toSet(), {
      '동물',
      '날짜',
      '기간',
      '사람',
      '물건',
      '시간',
    });
    final basic = <int?>[...List.generate(10, (i) => i + 1), 20, 30, 100, null];
    final ranges = <String, List<int?>>{
      'objects.tsu': [...List.generate(10, (i) => i + 1), null],
      'calendar.month': [...List.generate(12, (i) => i + 1), null],
      'calendar.day': [...List.generate(31, (i) => i + 1), null],
      'duration.day': [
        ...List.generate(10, (i) => i + 1),
        14,
        20,
        24,
        30,
        100,
        null,
      ],
      'time.hour': [...List.generate(24, (i) => i), null],
      'time.minute': [
        ...List.generate(11, (i) => i),
        15,
        20,
        30,
        40,
        45,
        50,
        59,
        null,
      ],
    };
    final data = jsonDecode(source) as Map<String, dynamic>;
    for (final deck in data['decks']) {
      final expected = ranges[deck['id']] ?? basic;
      expect(
        [for (final item in deck['items']) item['number']],
        expected,
        reason: deck['id'],
      );
    }
    expect(all.map((w) => w.progressKey).toSet().length, all.length);
  });

  test('readings, special dates, context and representative example ruby', () {
    final cases = {
      'animal.hiki.1': 'いっぴき',
      'animal.hiki.3': 'さんびき',
      'animal.hiki.6': 'ろっぴき',
      'animal.hiki.100': 'ひゃっぴき',
      'animal.tou.100': 'ひゃくとう',
      'animal.wa.3': 'さんわ',
      'calendar.day.1': 'ついたち',
      'duration.day.1': 'いちにち',
      'calendar.day.14': 'じゅうよっか',
      'calendar.day.19': 'じゅうくにち',
      'calendar.day.20': 'はつか',
      'calendar.day.24': 'にじゅうよっか',
      'calendar.day.29': 'にじゅうくにち',
      'calendar.day.31': 'さんじゅういちにち',
      'calendar.month.4': 'しがつ',
      'calendar.month.7': 'しちがつ',
      'calendar.month.9': 'くがつ',
      'people.nin.1': 'ひとり',
      'people.nin.2': 'ふたり',
      'people.nin.4': 'よにん',
      'objects.tsu.10': 'とお',
      'objects.tsu.question': 'いくつ',
      'objects.hon.6': 'ろっぽん',
      'objects.ko.8': 'はっこ',
      'objects.satsu.8': 'はっさつ',
      'duration.week.8': 'はっしゅうかん',
      'duration.month.6': 'ろっかげつ',
      'duration.month.100': 'ひゃっかげつ',
      'time.hour.0': 'れいじ',
      'time.hour.4': 'よじ',
      'time.hour.9': 'くじ',
      'time.hour.14': 'じゅうよじ',
      'time.hour.19': 'じゅうくじ',
      'time.minute.4': 'よんぷん',
      'time.minute.30': 'さんじゅっぷん',
      'time.minute.59': 'ごじゅうきゅうふん',
      'time.duration.4': 'よじかん',
    };
    for (final entry in cases.entries) {
      expect(word(entry.key).hiragana, entry.value, reason: entry.key);
    }
    expect(word('objects.tsu.10').prompt, '十');
    expect(word('animal.wa.3').alternateReadings, contains('さんば'));
    expect(word('objects.hon.10').alternateReadings, contains('じっぽん'));
    expect(word('calendar.day.1').prompt, word('duration.day.1').prompt);
    expect(
      word('calendar.day.1').progressKey,
      isNot(word('duration.day.1').progressKey),
    );
    for (final w in all) {
      expect(w.prompt, isNot(matches(r'[0-9０-９]')));
      expect(w.hiragana, matches(r'^[ぁ-ゖー]+$'));
      expect(w.example!.korean, isNotEmpty);
      expect(
        w.example!.segments.any(
          (s) => s.text == w.prompt && s.reading == w.hiragana,
        ),
        true,
      );
      expect(w.alternateReadings.toSet().length, w.alternateReadings.length);
      expect(w.alternateReadings, isNot(contains(w.hiragana)));
    }
  });

  test('invalid IDs, duplicate items, missing examples and readings fail', () {
    for (final mutation in <void Function(Map<String, dynamic>)>[
      (d) => d['decks'][0]['items'][0]['id'] = 'wrong',
      (d) => d['decks'][0]['items'].add(d['decks'][0]['items'][0]),
      (d) => d['decks'][0]['items'][0].remove('example'),
      (d) => d['decks'][0]['items'][0]['hiragana'] = '',
      (d) => d['decks'][0]['items'][0]['kanji'] = '1匹',
      (d) => d['decks'][0]['items'][0]['alternateReadings'] = ['bad'],
    ]) {
      final data = jsonDecode(source) as Map<String, dynamic>;
      mutation(data);
      expect(
        () => CounterLoader.parse(jsonEncode(data)),
        throwsFormatException,
      );
    }
  });

  test(
    'fixed IDs survive reading edits and calendar/duration persist separately',
    () async {
      final date = word('calendar.day.1');
      final duration = word('duration.day.1');
      List<String>? disk;
      ProgressStore create() => ProgressStore(
        read: () async => disk,
        write: (keys) async => disk = keys,
      );
      final store = create();
      await store.load();
      await store.setKnown(date, true);
      await store.setKnown(date, true);
      expect(store.knownCount([date, duration]), 1);
      final restored = create();
      await restored.load();
      expect(restored.isKnown(date), true);
      expect(restored.isKnown(duration), false);
      const edited = JapaneseWord(
        id: 'calendar.day.1',
        kanji: '一日',
        hiragana: '別の読み',
        korean: '수정',
      );
      expect(restored.isKnown(edited), true);
      await restored.setKnown(date, false);
      expect(restored.knownCount([date, duration]), 0);
      expect(
        const JapaneseWord(
          kanji: '一日',
          hiragana: 'ついたち',
          korean: '1일',
        ).progressKey,
        '["一日","ついたち"]',
      );
    },
  );
}
