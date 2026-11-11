import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jlpt/main.dart';
import 'package:jlpt/services/adverb_loader.dart';
import 'package:jlpt/services/progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('offline all special items and independent durable records', (
    tester,
  ) async {
    final prefs = SharedPreferencesAsync();
    final n1Before = await prefs.getStringList(ProgressStore.storageKey);
    final countersBefore = await prefs.getStringList(
      ProgressStore.counterStorageKey,
    );
    final specialBefore = await prefs.getStringList(
      ProgressStore.adverbStorageKey,
    );
    addTearDown(() async {
      if (specialBefore == null) {
        await prefs.remove(ProgressStore.adverbStorageKey);
      } else {
        await prefs.setStringList(
          ProgressStore.adverbStorageKey,
          specialBefore,
        );
      }
    });
    await prefs.remove(ProgressStore.adverbStorageKey);
    final decks = await AdverbLoader.load();
    Future<void> tap(String label) async {
      await Scrollable.ensureVisible(
        tester.element(find.text(label)),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(const WordApp());
    await tester.pumpAndSettle();
    await tap('부사 특집');
    expect(find.text('8개 세트 · 99개 표현'), findsOneWidget);
    final seen = <String>{};
    for (final deck in decks) {
      await tester.scrollUntilVisible(
        find.text(deck.title),
        300,
        scrollable: find.byType(Scrollable),
      );
      await tap(deck.title);
      expect(find.text(deck.quizTitle), findsOneWidget);
      for (var i = 0; i < deck.words.length; i++) {
        final prompt = find.byKey(const ValueKey('question-prompt'));
        final word = deck.words.singleWhere(
          (w) => find.text(w.prompt).evaluate().isNotEmpty,
        );
        expect(seen.add(word.id!), true);
        expect(find.text(word.korean), findsNothing);
        final known = find.byKey(const ValueKey('known'));
        final bounds = [tester.getRect(prompt), tester.getRect(known)];
        await tap('모름');
        expect(find.text(word.korean), findsOneWidget);
        expect(find.text(word.example!.korean).hitTestable(), findsOneWidget);
        expect([tester.getRect(prompt), tester.getRect(known)], bounds);
        expect(find.byType(Scrollable), findsNothing);
        await tap('알고 있음');
        await tap('다음 단어');
      }
      expect(find.text('이번 학습 종료'), findsOneWidget);
      expect(
        find.text('알고 있음 ${deck.words.length} / ${deck.words.length}'),
        findsOneWidget,
      );
      await tap('부사 특집 목록으로');
    }
    expect(seen.length, 99);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    final restored = ProgressStore(
      preferenceKey: ProgressStore.adverbStorageKey,
    );
    await restored.load();
    expect(restored.knownCount(decks.expand((d) => d.words)), 99);
    restored.dispose();
    await tester.pumpWidget(const WordApp());
    await tester.pumpAndSettle();
    await tap('부사 특집');
    await tap('부사 1');
    await tap('모름');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('알고 있음 29 / 30'), findsOneWidget);
    expect(await prefs.getStringList(ProgressStore.storageKey), n1Before);
    expect(
      await prefs.getStringList(ProgressStore.counterStorageKey),
      countersBefore,
    );
  });
}
