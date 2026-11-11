import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/models/japanese_word.dart';
import 'package:jlpt/screens/grammar_screen.dart';
import 'package:jlpt/screens/quiz_screen.dart';
import 'package:jlpt/services/grammar_loader.dart';
import 'package:jlpt/services/progress_store.dart';

final source = File('assets/grammar/grammar.json').readAsStringSync();
final decks = GrammarLoader.parse(source);
final words = decks.expand((d) => d.words).toList();
ProgressStore memory() =>
    ProgressStore(read: () async => [], write: (_) async {});

void main() {
  test(
    '254 exact photo headings, complete answers, stable IDs and balanced sets',
    () {
      expect(decks.map((d) => d.words.length), [
        29,
        29,
        29,
        26,
        25,
        25,
        16,
        16,
        30,
        29,
      ]);
      expect(words.length, 254);
      expect(words.map((w) => w.id).toSet().length, 254);
      final review = jsonDecode(
        File('data/grammar/photo-review-2026-11-08.json').readAsStringSync(),
      );
      final headings = <String>[];
      for (final photo in review['photos']) {
        for (final heading in photo['headings']) {
          headings.add(heading['pattern'] as String);
        }
      }
      expect(words.map((w) => w.prompt), unorderedEquals(headings));
      for (final word in words) {
        expect(word.connection, isNotEmpty, reason: word.id);
        expect(word.korean, isNotEmpty);
        expect(word.example!.korean, isNotEmpty);
        expect(word.example!.segments.any((s) => s.reading != null), true);
        expect(RegExp(r'[一-鿿]').hasMatch(word.hiragana), false);
      }
      expect(
        {
          ProgressStore.storageKey,
          ProgressStore.counterStorageKey,
          ProgressStore.adverbStorageKey,
          ProgressStore.grammarStorageKey,
        }.length,
        4,
      );
    },
  );

  test(
    'grammar rejects missing connection, missing ruby and duplicate IDs',
    () {
      for (final mutation in <void Function(dynamic)>[
        (d) => d['decks'][0]['items'][0].remove('connection'),
        (d) => d['decks'][0]['items'][0]['example']['segments'][0].remove(
          'reading',
        ),
        (d) =>
            d['decks'][0]['items'][1]['id'] = d['decks'][0]['items'][0]['id'],
      ]) {
        final data = jsonDecode(source);
        mutation(data);
        expect(
          () => GrammarLoader.parse(jsonEncode(data)),
          throwsFormatException,
        );
      }
    },
  );

  for (final size in [
    const Size(390, 844),
    const Size(320, 568),
    const Size(640, 320),
  ]) {
    testWidgets(
      'all 254 grammar answers scroll without moving controls at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = memory();
        await store.load();
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: QuizScreen(
              group: WordGroup(0, words),
              progressStore: store,
              random: Random(7),
              nextLabel: '다음 문형',
              returnLabel: 'N1 문법 목록으로',
            ),
          ),
        );
        final seen = <String>{};
        for (var i = 0; i < words.length; i++) {
          final prompt = find.byKey(const ValueKey('question-prompt'));
          final word = words.singleWhere(
            (w) => w.prompt == tester.widget<Text>(prompt).data,
          );
          expect(seen.add(word.id!), true);
          expect(
            find.byKey(const ValueKey('grammar-connection')),
            findsNothing,
          );
          final button = find.byKey(const ValueKey('known'));
          final before = [tester.getRect(prompt), tester.getRect(button)];
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<Text>(find.byKey(const ValueKey('grammar-connection')))
                .data,
            word.connection,
          );
          expect([tester.getRect(prompt), tester.getRect(button)], before);
          await Scrollable.ensureVisible(
            tester.element(find.byKey(const ValueKey('example-translation'))),
            alignment: .5,
          );
          await tester.pumpAndSettle();
          expect(find.text(word.example!.korean).hitTestable(), findsOneWidget);
          expect(tester.getRect(button), before[1]);
          expect(tester.takeException(), isNull, reason: word.id);
          await tester.tap(find.text('다음 문형'));
          await tester.pumpAndSettle();
          if (i < words.length - 1) {
            expect(find.byType(Scrollable), findsNothing);
          }
        }
        expect(seen.length, 254);
        expect(store.knownCount(words), 254);
        expect(find.text('이번 학습 종료'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'review filter excludes known items and disables an empty review',
    (tester) async {
      final store = memory();
      await store.load();
      final deck = decks.first;
      for (final word in deck.words.skip(1)) {
        await store.setKnown(word, true);
      }
      await tester.pumpWidget(
        MaterialApp(
          home: GrammarScreen(
            progressStore: store,
            loadDecks: () async => [deck],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(find.text('복습할 문형 1개'), findsOneWidget);
      await tester.tap(find.text(deck.title));
      await tester.pumpAndSettle();
      expect(find.text(deck.words.first.prompt), findsOneWidget);
      expect(find.text('1 / 1'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('known')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음 문형'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('N1 문법 목록으로'));
      await tester.pumpAndSettle();
      expect(find.text('복습할 문형 0개'), findsOneWidget);
      expect(
        tester
            .widget<ListTile>(
              find.descendant(
                of: find.byKey(ValueKey(deck.id)),
                matching: find.byType(ListTile),
              ),
            )
            .enabled,
        false,
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text(deck.title));
      await tester.pumpAndSettle();
      expect(find.text('1 / 29'), findsOneWidget);
    },
  );

  testWidgets('grammar loading errors can retry', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: GrammarScreen(
          progressStore: memory(),
          loadDecks: () async {
            if (calls++ == 0) throw const FormatException('test');
            return [];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('N1 문법 또는 학습 기록을 불러오지 못했습니다.'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('아직 등록된 문형이 없습니다.'), findsOneWidget);
  });
}
