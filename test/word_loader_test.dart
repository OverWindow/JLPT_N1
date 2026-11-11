import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/models/japanese_word.dart';
import 'package:jlpt/services/word_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'all photos map to bundled words; original identities keep order',
    () async {
      final words = await WordLoader.load();
      final audit = jsonDecode(
        File('data/import-v1.1.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final latest = jsonDecode(
        File('data/import-v1.3.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final updates = {
        for (final row in latest['meaningUpdates'] as List)
          row['wordNumber']: row['after'],
      };
      final current = jsonDecode(
        File('data/import-v1.6.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(audit['total'], 822);
      expect(latest['total'], 1130);
      expect(words.length, current['total']);
      expect(words.length, 1342);
      expect(words.first.prompt, '心地よい');
      expect(words[537].prompt, '排除');
      expect(words[538].prompt, '愛着');
      expect(words[539].prompt, '跡継');
      expect(words[821].prompt, '情報網');
      expect(words[822].prompt, 'なかなかしようとしない');
      expect(words[1129].prompt, 'アドバイス');
      expect(words[1130].prompt, 'ふんだんだ');
      expect(words.last.prompt, '交錯');
      final rows = File('data/photo-transcription.tsv')
          .readAsLinesSync()
          .skip(1)
          .toList();
      expect(rows.length, 538);
      for (var i = 0; i < rows.length; i++) {
        final cells = rows[i].split('\t');
        expect([words[i].kanji, words[i].hiragana], cells.sublist(1, 3));
      }
      for (var i = 0; i < words.length; i++) {
        expect(
          RegExp(r'^[ぁ-ゖァ-ヺー・]+$').hasMatch(words[i].hiragana),
          isTrue,
          reason: 'Invalid reading at ${i + 1}',
        );
      }
      final groups = WordGroup.fromWords(words);
      expect(groups.length, (words.length / 30).ceil());
      expect(groups[17].words.length, 30);
      expect(groups[27].label, '811~840');
      expect(groups[27].words.length, 30);
      expect(groups[37].label, '1111~1140');
      expect(groups[37].words.length, 30);
      expect(groups.length, 45);
      expect(groups.last.label, '1321~1342');
      expect(groups.last.words.length, 22);
      final newRows = File('data/photo-transcription-v1.1.tsv')
          .readAsLinesSync()
          .skip(1)
          .toList();
      final mappings = audit['rows'] as List;
      expect(newRows.length, 301);
      expect(mappings.length, newRows.length);
      expect((audit['photoCounts'] as Map).length, 18);
      expect(audit['added'], 284);
      expect(audit['merged'], 17);
      for (var i = 0; i < newRows.length; i++) {
        final cells = newRows[i].split('\t');
        final row = mappings[i];
        expect([
          row['source'],
          row['kanji'],
          row['hiragana'],
          row['korean'],
        ], cells);
        final word = words[(row['wordNumber'] as int) - 1];
        expect(word.prompt, row['canonicalSpelling']);
        if (row['action'] == 'added') {
          expect(word.hiragana, row['hiragana']);
          expect(word.korean, updates[row['wordNumber']] ?? row['korean']);
          expect(word.kanji ?? '', row['kanji']);
        }
      }
      final addedRows = File('data/photo-transcription-v1.3.tsv')
          .readAsLinesSync()
          .skip(1)
          .toList();
      final additions = latest['rows'] as List;
      expect(addedRows.length, 331);
      expect(additions.length, 331);
      expect(latest['photoCounts'], {
        '00': 26,
        '01': 39,
        '02': 27,
        '03': 38,
        '04': 23,
        '05': 38,
        '06': 29,
        '07': 42,
        '08': 30,
        '09': 39,
      });
      expect(latest['added'], 308);
      expect(latest['merged'], 23);
      for (var i = 0; i < additions.length; i++) {
        final row = additions[i];
        expect([
          row['source'],
          row['kanji'],
          row['hiragana'],
          row['korean'],
        ], addedRows[i].split('\t'));
        final word = words[(row['wordNumber'] as int) - 1];
        expect(word.prompt, row['canonicalSpelling']);
        expect(word.hiragana, row['hiragana']);
        if (row['action'] == 'added') {
          expect(word.kanji ?? '', row['kanji']);
          expect(word.korean, updates[row['wordNumber']] ?? row['korean']);
        }
      }
      final novemberRows = File('data/photo-transcription-v1.6.tsv')
          .readAsLinesSync()
          .skip(1)
          .toList();
      final novemberMappings = current['rows'] as List;
      final clarified = {
        for (final row in current['meaningUpdates'] as List)
          row['wordNumber']: row['after'],
      };
      expect(novemberRows.length, 240);
      expect(novemberMappings.length, novemberRows.length);
      expect(current['photoCounts'], {
        '00': 14,
        '01': 20,
        '02': 15,
        '03': 18,
        '04': 14,
        '05': 19,
        '06': 14,
        '07': 20,
        '08': 15,
        '09': 20,
        '10': 15,
        '11': 20,
        '12': 15,
        '13': 21,
      });
      expect(current['original'], 1130);
      expect(current['added'], 212);
      expect(current['merged'], 28);
      final newNumbers = <int>{};
      for (var i = 0; i < novemberMappings.length; i++) {
        final row = novemberMappings[i];
        expect([
          row['source'],
          row['kanji'],
          row['hiragana'],
          row['korean'],
        ], novemberRows[i].split('\t'));
        final number = row['wordNumber'] as int;
        final word = words[number - 1];
        expect(word.prompt, row['canonicalSpelling']);
        expect(word.hiragana, row['hiragana']);
        if (row['action'] == 'added') {
          expect(newNumbers.add(number), isTrue);
          expect(word.kanji ?? '', row['kanji']);
          expect(word.korean, clarified[number] ?? row['korean']);
        } else {
          expect(number, lessThanOrEqualTo(1130));
        }
      }
      expect(newNumbers, Set.of(List.generate(212, (i) => i + 1131)));
      expect(
        words.singleWhere((w) => w.prompt == '重複').hiragana,
        'じゅうふく・ちょうふく',
      );
      expect(words.singleWhere((w) => w.prompt == '解ける').hiragana, 'ほどける');
      // Identical readings with different meanings must remain separate.
      for (final pair in [
        ['謝る', '誤る'],
        ['不審だ', '不振だ'],
        ['終始', '収支'],
        ['人手', '人出'],
        ['交錯', '耕作'],
      ]) {
        final a = words.singleWhere((w) => w.prompt == pair[0]);
        final b = words.singleWhere((w) => w.prompt == pair[1]);
        expect(a.hiragana, b.hiragana);
        expect(a.progressKey, isNot(b.progressKey));
      }
    },
  );

  for (final count in [0, 1, 29, 30, 31, 60, 107]) {
    test('$count words split into 30 without loss or reordering', () {
      final words = List.generate(
        count,
        (i) => JapaneseWord(hiragana: '$i', korean: '$i'),
      );
      final groups = WordGroup.fromWords(words);
      expect(groups.length, (count / 30).ceil());
      expect(groups.expand((group) => group.words).toList(), words);
      expect(
        groups.every(
          (group) => group.words.isNotEmpty && group.words.length <= 30,
        ),
        isTrue,
      );
      if (count == 107) expect(groups.last.label, '91~107');
    });
  }

  test('missing, null or blank kanji falls back to hiragana', () {
    for (final kanji in [null, '', '  ']) {
      final word = WordLoader.parse(
        jsonEncode([
          {'kanji': kanji, 'hiragana': 'ありがとう', 'korean': '고마워'},
        ]),
      ).single;
      expect(word.hasKanji, isFalse);
      expect(word.prompt, 'ありがとう');
    }
    expect(
      WordLoader.parse('[{"hiragana":"ありがとう","korean":"고마워"}]').single.hasKanji,
      isFalse,
    );
  });

  test(
    'invalid JSON, wrong types, missing fields and duplicates fail clearly',
    () {
      for (final input in [
        'broken',
        '{}',
        '[null]',
        '[{}]',
        '[{"hiragana":" ","korean":"뜻"}]',
        '[{"hiragana":"よみ","korean":""}]',
        '[{"kanji":123,"hiragana":"よみ","korean":"뜻"}]',
        '[{"hiragana":2,"korean":"뜻"}]',
        '[{"hiragana":"よみ","korean":false}]',
        '[{"hiragana":"よみ","korean":"뜻"},{"hiragana":" よみ ","korean":"다른 뜻"}]',
      ]) {
        expect(
          () => WordLoader.parse(input),
          throwsFormatException,
          reason: input,
        );
      }
      // Homophones with different written forms remain distinct.
      expect(
        WordLoader.parse(
          '[{"kanji":"非難","hiragana":"ひなん","korean":"비난"},{"kanji":"避難","hiragana":"ひなん","korean":"피난"}]',
        ).length,
        2,
      );
    },
  );
}
