import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/models/japanese_word.dart';
import 'package:jlpt/services/progress_store.dart';
import 'package:jlpt/services/word_loader.dart';

const word = JapaneseWord(kanji: '学校', hiragana: 'がっこう', korean: '학교');

void main() {
  test('old final set keeps 12 known when 18 new words fill it', () async {
    final words = WordLoader.parse(
      File('assets/words/words.json').readAsStringSync(),
    );
    final previousLast = words.skip(810).take(12).toList();
    final saved = previousLast.map((w) => w.progressKey).toList();
    final store = ProgressStore(read: () async => saved, write: (_) async {});
    await store.load();
    final expanded = WordGroup.fromWords(words)[27];
    expect(store.knownCount(previousLast), 12);
    expect(expanded.words.length, 30);
    expect(store.knownCount(expanded.words), 12);
    expect(expanded.words.skip(12).any(store.isKnown), false);
  });
  test(
    'latest answer persists, duplicates count once, new store restores',
    () async {
      List<String>? disk;
      ProgressStore create() => ProgressStore(
        read: () async => disk,
        write: (keys) async => disk = keys,
      );
      final store = create();
      await store.load();
      expect(store.knownCount([word]), 0);
      await store.setKnown(word, true);
      await store.setKnown(word, true);
      expect(disk!.length, 1);
      final restarted = create();
      await restarted.load();
      expect(restarted.isKnown(word), true);
      await restarted.setKnown(word, false);
      final restored = create();
      await restored.load();
      expect(restored.knownCount([word]), 0);
    },
  );
  test('failed writes retain state, retry and concurrent guard work', () async {
    var fail = true;
    final pending = Completer<void>();
    final store = ProgressStore(
      read: () async => [],
      write: (_) async {
        if (fail) throw StateError('disk');
        await pending.future;
      },
    );
    await store.load();
    await expectLater(store.setKnown(word, true), throwsStateError);
    expect(store.isKnown(word), false);
    fail = false;
    final save = store.setKnown(word, true);
    await expectLater(store.setKnown(word, false), throwsStateError);
    expect(store.isKnown(word), false);
    pending.complete();
    await save;
    expect(store.isKnown(word), true);
  });
  test('identity ignores whitespace and meaning, distinguishes homophones', () {
    const edited = JapaneseWord(
      kanji: ' 学校 ',
      hiragana: ' がっこう ',
      korean: '다른 뜻',
    );
    expect(word.progressKey, edited.progressKey);
    const a = JapaneseWord(kanji: '非難', hiragana: 'ひなん', korean: '비난');
    const b = JapaneseWord(kanji: '避難', hiragana: 'ひなん', korean: '피난');
    expect(a.progressKey, isNot(b.progressKey));
  });
  test('failed read retries without overwriting existing progress', () async {
    var attempts = 0;
    final store = ProgressStore(
      read: () async {
        if (attempts++ == 0) throw StateError('read failed');
        return [word.progressKey];
      },
      write: (_) async {},
    );
    await expectLater(store.load(), throwsStateError);
    await expectLater(store.setKnown(word, false), throwsStateError);
    await store.load();
    expect(store.isKnown(word), true);
  });
}
