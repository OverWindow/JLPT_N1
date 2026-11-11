import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/services/adverb_loader.dart';
import 'package:jlpt/services/progress_store.dart';
import 'package:jlpt/services/word_loader.dart';

void main() {
  final source = File('assets/adverbs/adverbs.json').readAsStringSync();
  final decks = AdverbLoader.parse(source);
  final all = decks.expand((d) => d.words).toList();

  test('eleven photos map to 99 unique items and eight complete decks', () {
    expect(decks.map((d) => d.words.length), [30, 30, 4, 7, 4, 7, 6, 11]);
    expect(all.length, 99);
    expect(all.map((w) => w.id).toSet().length, 99);
    final audit = jsonDecode(
      File('data/adverbs/import-v1.5.json').readAsStringSync(),
    );
    expect(audit['photos'].length, 11);
    expect((audit['items'] as List).map((r) => r['id']), all.map((w) => w.id));
    expect(
      (audit['photos'] as List).fold<int>(0, (n, p) => n + p['count'] as int),
      99,
    );
    for (final w in all) {
      expect(w.korean, isNotEmpty);
      expect(w.example!.korean, isNotEmpty);
      expect(w.example!.segments, isNotEmpty);
      for (final segment in w.example!.segments) {
        if (RegExp(r'[一-鿿々〆ヶ]').hasMatch(segment.text)) {
          expect(segment.reading, isNotEmpty, reason: w.id);
        }
      }
      if (w.prompt.contains('～ない')) {
        expect(w.hiragana, endsWith('～ない'));
        expect(
          w.example!.japanese.contains('ない') ||
              w.example!.japanese.contains('なかった'),
          true,
          reason: w.id,
        );
      }
    }
  });

  test('same spelling retains distinct senses and kana stays kana', () {
    final senses = all.where((w) => w.prompt == 'あるいは').toList();
    expect(senses.length, 2);
    expect(senses.map((w) => w.progressKey).toSet().length, 2);
    expect(senses.map((w) => w.korean), ['어쩌면, 혹', '또는, 혹은']);
    expect(all.first.hasKanji, false);
    expect(
      all.singleWhere((w) => w.id == 'special.adverb.014').prompt,
      '必ずしも～ない',
    );
  });

  test(
    'loader rejects duplicate IDs, missing example and invalid readings',
    () {
      for (final mutation in [
        (Map<String, dynamic> data) =>
            data['decks'][1]['items'][0]['id'] = all.first.id,
        (Map<String, dynamic> data) =>
            data['decks'][0]['items'][0]['example'] = null,
        (Map<String, dynamic> data) =>
            data['decks'][0]['items'][0]['hiragana'] = '漢字',
        (Map<String, dynamic> data) => data['decks'][0]['items'] = [],
      ]) {
        final data = jsonDecode(source) as Map<String, dynamic>;
        mutation(data);
        expect(
          () => AdverbLoader.parse(jsonEncode(data)),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'three persistence keys restore independently including overlapping words',
    () async {
      final disk = <String, List<String>>{};
      ProgressStore store(String key) => ProgressStore(
        preferenceKey: key,
        read: () async => disk[key],
        write: (keys) async {
          disk[key] = List.of(keys);
        },
      );
      final n1 = store(ProgressStore.storageKey);
      final counters = store(ProgressStore.counterStorageKey);
      final special = store(ProgressStore.adverbStorageKey);
      await n1.load();
      await counters.load();
      await special.load();
      final original = WordLoader.parse(
        File('assets/words/words.json').readAsStringSync(),
      ).singleWhere((w) => w.hiragana == 'あらかじめ');
      await n1.setKnown(original, true);
      await special.setKnown(all.first, true);
      await special.setKnown(all.first, false);
      expect(n1.isKnown(original), true);
      expect(counters.knownCount(all), 0);
      await special.setKnown(all[1], true);
      final restored = store(ProgressStore.adverbStorageKey);
      await restored.load();
      expect(restored.isKnown(all[1]), true);
      expect(restored.isKnown(all.first), false);
      expect(disk[ProgressStore.storageKey], [original.progressKey]);
      n1.dispose();
      counters.dispose();
      special.dispose();
      restored.dispose();
    },
  );
}
