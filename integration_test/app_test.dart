import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jlpt/main.dart';
import 'package:jlpt/models/japanese_word.dart';
import 'package:jlpt/services/progress_store.dart';
import 'package:jlpt/services/word_loader.dart';
import 'package:jlpt/services/counter_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('offline Android random rounds and durable progress', (
    tester,
  ) async {
    await SharedPreferencesAsync().remove(ProgressStore.storageKey);
    final words = await WordLoader.load();
    final groups = WordGroup.fromWords(words);
    final last = groups.last;
    final lastLabel = '단어 ${groups.length}  ·  ${last.label}';
    final lastCount = last.words.length;
    final lastKnown = (lastCount / 2).ceil();
    // Simulate saved completion of the old 20-word final set.
    await SharedPreferencesAsync().setStringList(
      ProgressStore.storageKey,
      words.skip(1110).take(20).map((w) => w.progressKey).toList(),
    );
    Future<void> tap(String label) async {
      await Scrollable.ensureVisible(
        tester.element(find.text(label)),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      expect(find.text(label).hitTestable(), findsOneWidget);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(const WordApp());
    await tester.pumpAndSettle();
    await tap('N1 단어');
    expect(
      find.text('총 ${words.length}개 단어 · ${groups.length}개 그룹'),
      findsOneWidget,
    );
    await tap('단어 1  ·  1~30');
    final seen = <String>{};
    for (var i = 1; i <= 30; i++) {
      expect(find.text('$i / 30'), findsOneWidget);
      final word = words
          .take(30)
          .singleWhere((w) => find.text(w.prompt).evaluate().isNotEmpty);
      expect(seen.add(word.progressKey), true);
      expect(find.text(word.korean), findsNothing);
      expect(find.text(word.example!.korean), findsNothing);
      final promptRect = tester.getRect(
        find.byKey(const ValueKey('question-prompt')),
      );
      await tap('알고 있음');
      expect(
        tester.getRect(find.byKey(const ValueKey('question-prompt'))),
        promptRect,
      );
      expect(find.text(word.example!.korean), findsOneWidget);
      expect(find.byKey(const ValueKey('word-example')), findsOneWidget);
      expect(find.text(word.korean), findsOneWidget);
      if (word.hasKanji) {
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('word-reading'))).data,
          word.hiragana,
        );
      }
      await tap('다음 단어');
    }
    expect(seen.length, 30);
    expect(find.text('이번 학습 종료'), findsOneWidget);
    expect(find.text('알고 있음 30 / 30'), findsOneWidget);
    await tap('단어 목록으로');
    expect(find.text('학습 완료'), findsOneWidget);
    // Recreate the entire app/store and read the real Android preferences.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const WordApp());
    await tester.pumpAndSettle();
    await tap('N1 단어');
    expect(find.text('알고 있음 30 / 30'), findsOneWidget);
    await tap('단어 1  ·  1~30');
    await tap('모름');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('알고 있음 29 / 30'), findsOneWidget);
    expect(find.text('학습 완료'), findsNothing);
    final restored = ProgressStore();
    await restored.load();
    expect(restored.knownCount(words.take(30)), 29);
    final expanded = groups[37];
    final expandedLabel = '단어 38  ·  ${expanded.label}';
    await tester.scrollUntilVisible(
      find.text(expandedLabel),
      500,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('알고 있음 20 / 30'), findsOneWidget);
    await tap(expandedLabel);
    final expandedSeen = <String>{};
    for (var i = 0; i < expanded.words.length; i++) {
      final word = expanded.words.singleWhere(
        (w) => find.text(w.prompt).evaluate().isNotEmpty,
      );
      expect(expandedSeen.add(word.progressKey), true);
      final prompt = find.byKey(const ValueKey('question-prompt'));
      final known = find.byKey(const ValueKey('known'));
      final before = tester.getRect(prompt);
      final buttonBefore = tester.getRect(known);
      await tap('알고 있음');
      expect(tester.getRect(prompt), before);
      expect(tester.getRect(known), buttonBefore);
      expect(find.byType(Scrollable), findsNothing);
      expect(
        find.byKey(const ValueKey('example-translation')).hitTestable(),
        findsOneWidget,
      );
      expect(find.text('다음 단어').hitTestable(), findsOneWidget);
      await tap('다음 단어');
    }
    expect(expandedSeen.length, 30);
    expect(find.text('알고 있음 30 / 30'), findsOneWidget);
    await tap('단어 목록으로');
    await tester.scrollUntilVisible(
      find.text(lastLabel),
      500,
      scrollable: find.byType(Scrollable),
    );
    await tap(lastLabel);
    final lastSeen = <String>{};
    for (var i = 1; i <= lastCount; i++) {
      expect(find.text('$i / $lastCount'), findsOneWidget);
      final word = last.words.singleWhere(
        (w) => find.text(w.prompt).evaluate().isNotEmpty,
      );
      expect(lastSeen.add(word.progressKey), true);
      await tap(i.isOdd ? '알고 있음' : '모름');
      await tap('다음 단어');
    }
    expect(find.text('알고 있음 $lastKnown / $lastCount'), findsOneWidget);
    await tap('다시 학습하기');
    expect(find.text('1 / $lastCount'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('알고 있음 $lastKnown / $lastCount'), findsOneWidget);
  });

  testWidgets(
    'offline counters keep independent durable progress and calendar context',
    (tester) async {
      final prefs = SharedPreferencesAsync();
      final n1Before = await prefs.getStringList(ProgressStore.storageKey);
      await prefs.remove(ProgressStore.counterStorageKey);
      final decks = await CounterLoader.load();
      final animal = decks.first;
      final date = decks.singleWhere((d) => d.id == 'calendar.day');
      final duration = decks.singleWhere((d) => d.id == 'duration.day');
      Future<void> tap(String label) async {
        await Scrollable.ensureVisible(
          tester.element(find.text(label)),
          alignment: .5,
        );
        await tester.pumpAndSettle();
        expect(find.text(label).hitTestable(), findsOneWidget);
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      Future<void> openDeck(CounterDeck deck) async {
        await tester.scrollUntilVisible(
          find.text(deck.title),
          400,
          scrollable: find.byType(Scrollable),
        );
        await tap(deck.title);
        expect(find.text(deck.quizTitle), findsOneWidget);
      }

      await tester.pumpWidget(const WordApp());
      await tester.pumpAndSettle();
      await tap('조수사');
      expect(find.text('17개 세트 · 270개 표현'), findsOneWidget);
      await openDeck(animal);
      final first = animal.words.singleWhere(
        (w) => find.text(w.prompt).evaluate().isNotEmpty,
      );
      await tap('모름');
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('word-reading'))).data,
        first.answerReading,
      );
      expect(find.text(first.example!.korean), findsOneWidget);
      await tap('알고 있음');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await openDeck(date);
      final seen = <String>{};
      for (var i = 0; i < date.words.length; i++) {
        final word = date.words.singleWhere(
          (w) => find.text(w.prompt).evaluate().isNotEmpty,
        );
        expect(seen.add(word.id!), true);
        expect(find.text(word.answerReading), findsNothing);
        final prompt = find.byKey(const ValueKey('question-prompt'));
        final button = find.byKey(const ValueKey('known'));
        final bounds = [tester.getRect(prompt), tester.getRect(button)];
        await tap('알고 있음');
        expect([tester.getRect(prompt), tester.getRect(button)], bounds);
        expect(find.byType(Scrollable), findsNothing);
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('word-reading'))).data,
          word.answerReading,
        );
        expect(find.text(word.example!.korean).hitTestable(), findsOneWidget);
        await tap('다음 문제');
      }
      expect(seen.length, 32);
      expect(find.text('알고 있음 32 / 32'), findsOneWidget);
      await tap('조수사 목록으로');
      await openDeck(duration);
      for (var i = 0; i < duration.words.length; i++) {
        final word = duration.words.singleWhere(
          (w) => find.text(w.prompt).evaluate().isNotEmpty,
        );
        await tap('모름');
        if (word.prompt == '一日') {
          expect(
            tester
                .widget<Text>(find.byKey(const ValueKey('word-reading')))
                .data,
            'いちにち',
          );
          expect(find.text('ついたち'), findsNothing);
          break;
        }
        await tap('다음 문제');
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      final restored = ProgressStore(
        preferenceKey: ProgressStore.counterStorageKey,
      );
      await restored.load();
      expect(restored.isKnown(first), true);
      expect(restored.knownCount(date.words), 32);
      expect(restored.knownCount(duration.words), 0);
      expect(await prefs.getStringList(ProgressStore.storageKey), n1Before);
      await tester.pumpWidget(const WordApp());
      await tester.pumpAndSettle();
      await tap('조수사');
      expect(find.text('알고 있음 1 / 14'), findsOneWidget);
      await openDeck(animal);
      await tap('알고 있음');
      await tap('모름');
      expect(await prefs.getStringList(ProgressStore.storageKey), n1Before);
    },
  );
}
