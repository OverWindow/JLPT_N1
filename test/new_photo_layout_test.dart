import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/models/japanese_word.dart';
import 'package:jlpt/screens/quiz_screen.dart';
import 'package:jlpt/services/progress_store.dart';
import 'package:jlpt/services/word_loader.dart';

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(320, 568),
    const Size(640, 320),
  ]) {
    testWidgets('longest new photo phrases fit without scrolling at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final words = WordLoader.parse(
        File('assets/words/words.json').readAsStringSync(),
      );
      final additions = words.skip(822).toList();
      final byPrompt = [...additions]
        ..sort((a, b) => b.prompt.length.compareTo(a.prompt.length));
      int detailLength(JapaneseWord word) =>
          word.hiragana.length +
          word.korean.length +
          word.example!.reading.length +
          word.example!.korean.length;
      final byDetail = [...additions]
        ..sort((a, b) => detailLength(b).compareTo(detailLength(a)));
      final novemberPrompt = words.skip(1130).toList()
        ..sort((a, b) => b.prompt.length.compareTo(a.prompt.length));
      final novemberDetail = words.skip(1130).toList()
        ..sort((a, b) => detailLength(b).compareTo(detailLength(a)));
      final cases = {
        byPrompt.first,
        byDetail.first,
        novemberPrompt.first,
        novemberDetail.first,
      }.toList();
      final store = ProgressStore(read: () async => [], write: (_) async {});
      await store.load();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(size.width == 390 ? 1 : 2),
            ),
            child: child!,
          ),
          home: QuizScreen(group: WordGroup(822, cases), progressStore: store),
        ),
      );
      for (var i = 0; i < cases.length; i++) {
        final prompt = find.byKey(const ValueKey('question-prompt'));
        final known = find.byKey(const ValueKey('known'));
        final before = tester.getRect(prompt);
        final buttonBefore = tester.getRect(known);
        await tester.tap(known);
        await tester.pumpAndSettle();
        expect(tester.getRect(prompt), before);
        expect(tester.getRect(known), buttonBefore);
        expect(find.byType(Scrollable), findsNothing);
        for (final target in [
          prompt,
          find.byKey(const ValueKey('word-example')),
          find.byKey(const ValueKey('example-translation')),
          find.text('다음 단어'),
        ]) {
          final rect = tester.getRect(target);
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.bottom, lessThanOrEqualTo(size.height));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
          expect(target.hitTestable(), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('다음 단어'));
        await tester.pumpAndSettle();
      }
      expect(find.text('이번 학습 종료'), findsOneWidget);
    });
  }
}
