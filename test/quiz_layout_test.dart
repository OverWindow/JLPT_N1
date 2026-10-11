import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/models/japanese_word.dart';
import 'package:jlpt/screens/quiz_screen.dart';
import 'package:jlpt/services/progress_store.dart';

const exampleWord = JapaneseWord(
  kanji: '心地よい',
  hiragana: 'ここちよい',
  korean: '상쾌하다',
  example: WordExample(
    segments: [
      RubySegment('朝', 'あさ'),
      RubySegment('の'),
      RubySegment('風', 'かぜ'),
      RubySegment('が'),
      RubySegment('心地よい', 'ここちよい'),
      RubySegment('。'),
    ],
    korean: '아침 바람이 상쾌하다.',
  ),
);

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(320, 568),
    const Size(640, 320),
  ]) {
    for (final label in ['알고 있음', '모름']) {
      testWidgets('fixed prompt before/after $label with furigana at $size', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
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
            home: QuizScreen(
              group: WordGroup(0, [exampleWord]),
              progressStore: store,
            ),
          ),
        );
        final prompt = find.byKey(const ValueKey('question-prompt'));
        final before = tester.getRect(prompt);
        final known = find.byKey(const ValueKey('known'));
        final unknown = find.byKey(const ValueKey('unknown'));
        final knownBefore = tester.getRect(known);
        final unknownBefore = tester.getRect(unknown);
        if (size.width == 390) {
          expect(
            before.center.dy,
            inInclusiveRange(size.height * .4, size.height * .55),
          );
        }
        expect(find.text(exampleWord.example!.korean), findsNothing);
        expect(find.text('다음 단어'), findsNothing);
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(tester.getRect(prompt), before);
        expect(tester.getRect(known), knownBefore);
        expect(tester.getRect(unknown), unknownBefore);
        expect(knownBefore.left, greaterThan(unknownBefore.left));
        expect(find.byType(Scrollable), findsNothing);
        for (final target in [
          known,
          unknown,
          find.text('다음 단어'),
          find.byKey(const ValueKey('word-example')),
        ]) {
          final bounds = tester.getRect(target);
          expect(bounds.top, greaterThanOrEqualTo(0));
          expect(bounds.bottom, lessThanOrEqualTo(size.height));
          expect(target.hitTestable(), findsOneWidget);
        }
        expect(find.text(exampleWord.example!.korean), findsOneWidget);
        expect(find.text('예문'), findsNothing);
        expect(find.text('이번 학습 종료'), findsNothing);
        expect(find.text('1 / 1'), findsOneWidget);
        expect(
          tester.getBottomLeft(find.text('あさ')).dy,
          lessThanOrEqualTo(tester.getTopLeft(find.text('朝')).dy),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(prompt),
          before,
          reason: 'Answer layout must not move the prompt',
        );
        await tester.tap(find.text('다음 단어'));
        await tester.pumpAndSettle();
        expect(find.text('이번 학습 종료'), findsOneWidget);
        await tester.ensureVisible(find.text('다시 학습하기'));
        await tester.tap(find.text('다시 학습하기'));
        await tester.pumpAndSettle();
        expect(find.text(exampleWord.example!.korean), findsNothing);
        expect(tester.getRect(prompt), before);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
