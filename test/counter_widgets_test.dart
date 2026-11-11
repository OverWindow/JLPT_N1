import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/main.dart';
import 'package:jlpt/models/japanese_word.dart';
import 'package:jlpt/screens/counter_screen.dart';
import 'package:jlpt/screens/quiz_screen.dart';
import 'package:jlpt/services/counter_loader.dart';
import 'package:jlpt/services/progress_store.dart';

final decks = CounterLoader.parse(
  File('assets/counters/counters.json').readAsStringSync(),
);
ProgressStore memory() =>
    ProgressStore(read: () async => [], write: (_) async {});
Future<void> tap(WidgetTester tester, String label) async {
  await Scrollable.ensureVisible(
    tester.element(find.text(label)),
    alignment: .5,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'entry opens each collection and returns with independent stores',
    (tester) async {
      final n1 = memory();
      final counters = memory();
      // Large bundled assets decode on a real isolate, outside the fake clock.
      Future<void> openCollection(String label, String loadedText) async {
        await tester.runAsync(() async {
          await tester.tap(find.text(label));
          for (var i = 0; i < 200; i++) {
            await tester.pump();
            if (find.text(loadedText).evaluate().isNotEmpty) return;
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
          fail('Asset loading timed out: $label');
        });
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(
        WordApp(progressStore: n1, counterProgressStore: counters),
      );
      expect(find.text('N1 단어'), findsOneWidget);
      expect(find.text('조수사'), findsOneWidget);
      await openCollection('조수사', '17개 세트 · 270개 표현');
      await tester.pumpAndSettle();
      expect(find.text('17개 세트 · 270개 표현'), findsOneWidget);
      await tap(tester, decks.first.title);
      expect(find.text(decks.first.quizTitle), findsOneWidget);
      final word = decks.first.words.singleWhere(
        (w) => find.text(w.prompt).evaluate().isNotEmpty,
      );
      await tap(tester, '알고 있음');
      expect(counters.isKnown(word), true);
      expect(n1.isKnown(word), false);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await openCollection('N1 단어', '총 1342개 단어 · 45개 그룹');
      await tester.pumpAndSettle();
      expect(find.text('총 1342개 단어 · 45개 그룹'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('오늘은 무엇을 공부할까요?'), findsOneWidget);
    },
  );

  testWidgets(
    'counter round reveals, corrects, completes and revokes completion',
    (tester) async {
      final store = memory();
      final deck = decks.first;
      await tester.pumpWidget(
        MaterialApp(
          home: CounterScreen(
            progressStore: store,
            loadDecks: () async => [deck],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, deck.title);
      final seen = <String>{};
      for (var i = 0; i < deck.words.length; i++) {
        final word = deck.words.singleWhere(
          (w) => find.text(w.prompt).evaluate().isNotEmpty,
        );
        expect(seen.add(word.id!), true);
        expect(find.text(word.answerReading), findsNothing);
        expect(find.text(word.korean), findsNothing);
        expect(find.text(word.example!.korean), findsNothing);
        await tap(tester, '모름');
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('word-reading'))).data,
          word.answerReading,
        );
        expect(find.text(word.korean), findsOneWidget);
        expect(find.text(word.example!.korean), findsOneWidget);
        expect(find.text('${i + 1} / 14'), findsOneWidget);
        await tap(tester, '알고 있음');
        await tap(tester, '알고 있음');
        expect(store.knownCount(deck.words), i + 1);
        await tap(tester, '다음 문제');
      }
      expect(seen.length, 14);
      expect(find.text('이번 학습 종료'), findsOneWidget);
      await tap(tester, '다시 학습하기');
      expect(store.knownCount(deck.words), 14);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('학습 완료'), findsOneWidget);
      await tap(tester, deck.title);
      await tap(tester, '모름');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('학습 완료'), findsNothing);
      expect(find.text('알고 있음 13 / 14'), findsOneWidget);
    },
  );

  testWidgets('counter failed loading retries and empty state works', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CounterScreen(
          progressStore: memory(),
          loadDecks: () async {
            if (calls++ == 0) throw const FormatException('bad data');
            return [];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('조수사 또는 학습 기록을 불러오지 못했습니다.'), findsOneWidget);
    await tap(tester, '다시 시도');
    expect(find.text('아직 등록된 조수사가 없습니다.'), findsOneWidget);
  });

  for (final size in [
    const Size(390, 844),
    const Size(320, 568),
    const Size(640, 320),
  ]) {
    testWidgets('counter details and controls stay fixed and fit at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final all = decks.expand((d) => d.words).toList();
      final longestPrompt = [...all]
        ..sort((a, b) => b.prompt.length.compareTo(a.prompt.length));
      int details(JapaneseWord w) =>
          w.answerReading.length +
          w.korean.length +
          w.example!.reading.length +
          w.example!.korean.length;
      final longestDetail = [...all]
        ..sort((a, b) => details(b).compareTo(details(a)));
      final words = {
        longestPrompt.first,
        longestDetail.first,
        all.singleWhere((w) => w.id == 'animal.wa.10'),
      }.toList();
      final store = memory();
      await store.load();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(size.width == 390 ? 1 : 2),
            ),
            child: child!,
          ),
          home: QuizScreen(
            group: WordGroup(0, words),
            progressStore: store,
            title: '기간 · 개월 · ヶ月',
            nextLabel: '다음 문제',
            returnLabel: '조수사 목록으로',
            random: Random(7),
          ),
        ),
      );
      for (var i = 0; i < words.length; i++) {
        final prompt = find.byKey(const ValueKey('question-prompt'));
        final known = find.byKey(const ValueKey('known'));
        final unknown = find.byKey(const ValueKey('unknown'));
        final before = [
          tester.getRect(prompt),
          tester.getRect(known),
          tester.getRect(unknown),
        ];
        await tap(tester, '알고 있음');
        expect([
          tester.getRect(prompt),
          tester.getRect(known),
          tester.getRect(unknown),
        ], before);
        expect(
          tester.getRect(unknown).left,
          lessThan(tester.getRect(known).left),
        );
        expect(find.byType(Scrollable), findsNothing);
        for (final f in [
          prompt,
          find.byKey(const ValueKey('word-reading')),
          find.byKey(const ValueKey('word-example')),
          find.text('다음 문제'),
        ]) {
          final rect = tester.getRect(f);
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.bottom, lessThanOrEqualTo(size.height));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
          expect(f.hitTestable(), findsOneWidget);
        }
        expect(find.text('예문'), findsNothing);
        expect(find.text('이전 단어'), findsNothing);
        expect(tester.takeException(), isNull);
        await tap(tester, '다음 문제');
      }
      expect(find.text('이번 학습 종료'), findsOneWidget);
    });
  }
}
