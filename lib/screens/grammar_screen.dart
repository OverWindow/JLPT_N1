import 'package:flutter/material.dart';

import '../models/japanese_word.dart';
import '../services/grammar_loader.dart';
import '../services/progress_store.dart';
import 'quiz_screen.dart';

class GrammarScreen extends StatefulWidget {
  const GrammarScreen({
    super.key,
    required this.progressStore,
    this.loadDecks = GrammarLoader.load,
  });
  final ProgressStore progressStore;
  final Future<List<GrammarDeck>> Function() loadDecks;
  @override
  State<GrammarScreen> createState() => _GrammarScreenState();
}

class _GrammarScreenState extends State<GrammarScreen> {
  late Future<List<GrammarDeck>> _decks = _load();
  bool _reviewOnly = false;
  Future<List<GrammarDeck>> _load() async {
    await widget.progressStore.load();
    return widget.loadDecks();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('N1 문법')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: FutureBuilder<List<GrammarDeck>>(
            future: _decks,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('N1 문법 또는 학습 기록을 불러오지 못했습니다.'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => setState(() {
                          _decks = _load();
                        }),
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final decks = snapshot.data!;
              if (decks.isEmpty) {
                return const Center(child: Text('아직 등록된 문형이 없습니다.'));
              }
              return ListenableBuilder(
                listenable: widget.progressStore,
                builder: (context, _) => ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      '뜻과 접속 방법 익히기',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${decks.length}개 세트 · ${decks.fold<int>(0, (n, d) => n + d.words.length)}개 문형',
                    ),
                    const SizedBox(height: 8),
                    const Text('N2 복습 문형 포함 · 예문의 한자 위에 읽기를 표시합니다.'),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('아직 모르는 문형만 복습'),
                      subtitle: const Text('미학습 문형과 ‘모름’으로 표시한 문형을 포함합니다.'),
                      value: _reviewOnly,
                      onChanged: (value) => setState(() => _reviewOnly = value),
                    ),
                    for (var i = 0; i < decks.length; i++) ...[
                      if (i == 0 || decks[i].category != decks[i - 1].category)
                        Padding(
                          padding: const EdgeInsets.only(top: 24, bottom: 12),
                          child: Text(
                            decks[i].category,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      _deck(decks[i]),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );

  Widget _deck(GrammarDeck deck) {
    final known = widget.progressStore.knownCount(deck.words);
    final remaining = deck.words
        .where((w) => !widget.progressStore.isKnown(w))
        .toList();
    final words = _reviewOnly ? remaining : deck.words;
    return Card(
      key: ValueKey(deck.id),
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        title: Text(deck.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text(deck.description),
            const SizedBox(height: 8),
            Text('알고 있음 $known / ${deck.words.length}'),
            if (_reviewOnly) Text('복습할 문형 ${remaining.length}개'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: known / deck.words.length,
              semanticsLabel: '${deck.title} 학습 진행도',
            ),
            if (known == deck.words.length)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('학습 완료'),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        enabled: words.isNotEmpty,
        onTap: words.isEmpty
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => QuizScreen(
                    group: WordGroup(0, words),
                    progressStore: widget.progressStore,
                    title: '${deck.quizTitle}${_reviewOnly ? ' · 복습' : ''}',
                    nextLabel: '다음 문형',
                    returnLabel: 'N1 문법 목록으로',
                  ),
                ),
              ),
      ),
    );
  }
}
