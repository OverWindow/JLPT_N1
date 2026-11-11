import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/main.dart';
import 'package:jlpt/models/japanese_word.dart';
import 'package:jlpt/screens/home_screen.dart';
import 'package:jlpt/screens/quiz_screen.dart';
import 'package:jlpt/services/progress_store.dart';
import 'package:jlpt/services/word_loader.dart';

const sample = [
  JapaneseWord(kanji: '学校', hiragana: 'がっこう', korean: '학교'),
  JapaneseWord(hiragana: 'ありがとう', korean: '고마워'),
  JapaneseWord(kanji: '本', hiragana: 'ほん', korean: '책'),
];
ProgressStore memory() =>
    ProgressStore(read: () async => [], write: (_) async {});
Future<void> tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

JapaneseWord current(WidgetTester tester, List<JapaneseWord> words) =>
    words.singleWhere((word) => find.text(word.prompt).evaluate().isNotEmpty);

void main() {
  testWidgets('bundled data loads; random question initially hides answer', (
    tester,
  ) async {
    final store = memory();
    await store.load();
    late List<JapaneseWord> words;
    await tester.runAsync(() async {
      await tester.pumpWidget(WordApp(progressStore: store));
      words = await WordLoader.load();
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tap(tester, 'N1 단어');
    });
    await tester.pumpAndSettle();
    expect(
      find.text(
        '총 ${words.length}개 단어 · ${WordGroup.fromWords(words).length}개 그룹',
      ),
      findsOneWidget,
    );
    await tap(tester, '단어 1  ·  1~30');
    final word = current(tester, words.take(30).toList());
    expect(find.text(word.korean), findsNothing);
    if (word.hasKanji) expect(find.text(word.hiragana), findsNothing);
    expect(find.text('1 / 30'), findsOneWidget);
  });
  testWidgets(
    'shuffle no loss; next hides answer; restart reshuffles without reset',
    (tester) async {
      final store = memory();
      await store.load();
      final words = List.generate(
        8,
        (i) => JapaneseWord(kanji: '問題$i', hiragana: 'よみ$i', korean: '뜻$i'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: QuizScreen(
            group: WordGroup(0, words),
            progressStore: store,
            random: Random(12),
          ),
        ),
      );
      final first = current(tester, words);
      await tap(tester, '알고 있음');
      await tap(tester, '다음 단어');
      expect(current(tester, words), isNot(first));
      expect(find.text(first.korean), findsNothing);
      final order = [first];
      for (var i = 1; i < words.length; i++) {
        order.add(current(tester, words));
        await tap(tester, '알고 있음');
        await tap(tester, '다음 단어');
      }
      expect(order.toSet(), words.toSet());
      expect(order, isNot(words));
      expect(find.text('이번 학습 종료'), findsOneWidget);
      expect(find.text('알고 있음 8 / 8'), findsOneWidget);
      await tap(tester, '다시 학습하기');
      final nextOrder = <JapaneseWord>[];
      for (var i = 0; i < words.length; i++) {
        nextOrder.add(current(tester, words));
        await tap(tester, '알고 있음');
        await tap(tester, '다음 단어');
      }
      expect(nextOrder.toSet(), words.toSet());
      expect(nextOrder, isNot(order));
      expect(store.knownCount(words), 8);
    },
  );
  testWidgets(
    'answers reveal; correction changes counts; home completion revokes',
    (tester) async {
      final store = memory();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            loadWords: () async => [sample.first],
            progressStore: store,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('알고 있음 0 / 1'), findsOneWidget);
      await tap(tester, '단어 1  ·  1~1');
      await tap(tester, '모름');
      expect(find.text('がっこう'), findsOneWidget);
      expect(find.text('학교'), findsOneWidget);
      expect(store.knownCount(sample), 0);
      await tap(tester, '알고 있음');
      await tap(tester, '알고 있음');
      expect(store.knownCount(sample), 1);
      await tap(tester, '다음 단어');
      await tap(tester, '단어 목록으로');
      expect(find.text('학습 완료'), findsOneWidget);
      expect(find.text('알고 있음 1 / 1'), findsOneWidget);
      await tap(tester, '단어 1  ·  1~1');
      await tap(tester, '모름');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('학습 완료'), findsNothing);
      expect(find.text('알고 있음 0 / 1'), findsOneWidget);
    },
  );
  testWidgets('kana fallback; save failure retries; pending disables buttons', (
    tester,
  ) async {
    var attempts = 0;
    final pending = Completer<void>();
    final store = ProgressStore(
      read: () async => [],
      write: (_) async {
        if (attempts++ == 0) throw StateError('disk');
        await pending.future;
      },
    );
    await store.load();
    await tester.pumpWidget(
      MaterialApp(
        home: QuizScreen(
          group: WordGroup(0, [sample[1]]),
          progressStore: store,
        ),
      ),
    );
    expect(find.text('ありがとう'), findsOneWidget);
    expect(find.text('고마워'), findsNothing);
    await tap(tester, '알고 있음');
    expect(find.text('고마워'), findsOneWidget);
    expect(find.text('저장 다시 시도'), findsOneWidget);
    expect(store.knownCount(sample), 0);
    await tester.tap(find.text('저장 다시 시도'));
    await tester.pump();
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('known')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '다음 단어'))
          .onPressed,
      isNull,
    );
    pending.complete();
    await tester.pumpAndSettle();
    expect(store.knownCount(sample), 1);
    expect(find.text('저장 다시 시도'), findsNothing);
    await tap(tester, '다음 단어');
    expect(find.text('이번 학습 종료'), findsOneWidget);
  });
  testWidgets('empty data, failed loading and retry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(loadWords: () async => [], progressStore: memory()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('아직 등록된 단어가 없습니다.'), findsOneWidget);
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          key: const ValueKey('retry'),
          progressStore: memory(),
          loadWords: () async {
            if (attempts++ == 0) throw const FormatException('invalid');
            return sample;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('단어 또는 학습 기록을 불러오지 못했습니다.'), findsOneWidget);
    await tap(tester, '다시 시도');
    expect(find.text('총 3개 단어 · 1개 그룹'), findsOneWidget);
  });
  for (final size in [const Size(320, 568), const Size(640, 320)]) {
    testWidgets('large text and long word fit $size', (tester) async {
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
            progressStore: store,
            group: WordGroup(0, const [
              JapaneseWord(
                kanji: '馬鹿馬鹿しい',
                hiragana: 'ばかばかしい',
                korean: '어처구니없다',
              ),
            ]),
          ),
        ),
      );
      await tap(tester, '알고 있음');
      expect(tester.takeException(), isNull);
      await tap(tester, '다음 단어');
      expect(find.text('이번 학습 종료'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
