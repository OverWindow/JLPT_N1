import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jlpt/main.dart';
import 'package:jlpt/services/grammar_loader.dart';
import 'package:jlpt/services/progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('grammar menu, ruby, review and independent durable storage', (
    tester,
  ) async {
    final prefs = SharedPreferencesAsync();
    final keys = [
      ProgressStore.storageKey,
      ProgressStore.counterStorageKey,
      ProgressStore.adverbStorageKey,
      ProgressStore.grammarStorageKey,
    ];
    final before = <String, List<String>?>{};
    for (final key in keys) {
      before[key] = await prefs.getStringList(key);
    }
    addTearDown(() async {
      final previous = before[ProgressStore.grammarStorageKey];
      if (previous == null) {
        await prefs.remove(ProgressStore.grammarStorageKey);
      } else {
        await prefs.setStringList(ProgressStore.grammarStorageKey, previous);
      }
    });
    await prefs.remove(ProgressStore.grammarStorageKey);
    final decks = await GrammarLoader.load();
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
    await tap('N1 문법');
    expect(find.text('10개 세트 · 254개 문형'), findsOneWidget);
    await tap(decks.first.title);
    for (var i = 0; i < decks.first.words.length; i++) {
      final word = decks.first.words.singleWhere(
        (w) => find.text(w.prompt).evaluate().isNotEmpty,
      );
      await tap('모름');
      expect(find.text(word.connection!), findsOneWidget);
      await Scrollable.ensureVisible(
        tester.element(find.text(word.example!.korean)),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      expect(find.text(word.example!.korean).hitTestable(), findsOneWidget);
      await tap('알고 있음');
      await tap('다음 문형');
    }
    expect(find.text('알고 있음 29 / 29'), findsOneWidget);
    await tap('N1 문법 목록으로');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    final restored = ProgressStore(
      preferenceKey: ProgressStore.grammarStorageKey,
    );
    await restored.load();
    expect(restored.knownCount(decks.first.words), 29);
    restored.dispose();
    for (final key in keys.take(3)) {
      expect(await prefs.getStringList(key), before[key]);
    }
    await tester.pumpWidget(const WordApp());
    await tester.pumpAndSettle();
    await tap('N1 문법');
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(find.text('복습할 문형 0개'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
