import 'package:flutter/material.dart';

import '../models/japanese_word.dart';
import '../services/adverb_loader.dart';
import '../services/progress_store.dart';
import 'quiz_screen.dart';

class AdverbScreen extends StatefulWidget {
  const AdverbScreen({
    super.key,
    required this.progressStore,
    this.loadDecks = AdverbLoader.load,
  });
  final ProgressStore progressStore;
  final Future<List<AdverbDeck>> Function() loadDecks;
  @override
  State<AdverbScreen> createState() => _AdverbScreenState();
}

class _AdverbScreenState extends State<AdverbScreen> {
  late Future<List<AdverbDeck>> _decks = _load();
  Future<List<AdverbDeck>> _load() async {
    await widget.progressStore.load();
    return widget.loadDecks();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('부사 특집')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: FutureBuilder<List<AdverbDeck>>(
            future: _decks,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('부사 특집 또는 학습 기록을 불러오지 못했습니다.'),
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
                return const Center(child: Text('아직 등록된 부사 특집가 없습니다.'));
              }
              return ListenableBuilder(
                listenable: widget.progressStore,
                builder: (context, _) => ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      '부사와 접속 표현 익히기',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${decks.length}개 세트 · ${decks.fold<int>(0, (n, d) => n + d.words.length)}개 표현',
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

  Widget _deck(AdverbDeck deck) {
    final known = widget.progressStore.knownCount(deck.words);
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
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => QuizScreen(
              group: WordGroup(0, deck.words),
              progressStore: widget.progressStore,
              title: deck.quizTitle,
              nextLabel: '다음 단어',
              returnLabel: '부사 특집 목록으로',
            ),
          ),
        ),
      ),
    );
  }
}
