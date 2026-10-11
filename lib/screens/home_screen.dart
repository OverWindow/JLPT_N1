import 'package:flutter/material.dart';

import '../models/japanese_word.dart';
import '../services/word_loader.dart';
import '../services/progress_store.dart';
import 'quiz_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.loadWords = WordLoader.load,
    this.progressStore,
  });
  final Future<List<JapaneseWord>> Function() loadWords;
  final ProgressStore? progressStore;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<JapaneseWord>> _words;
  late final ProgressStore _progress;

  @override
  void initState() {
    super.initState();
    _progress = widget.progressStore ?? ProgressStore();
    _words = _load();
  }

  Future<List<JapaneseWord>> _load() async {
    await _progress.load();
    return widget.loadWords();
  }

  @override
  void dispose() {
    if (widget.progressStore == null) _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('일본어 단어장')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: _progress,
        builder: (context, _) => FutureBuilder<List<JapaneseWord>>(
          future: _words,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('단어 또는 학습 기록을 불러오지 못했습니다.'),
                      const SizedBox(height: 12),
                      Text('${snapshot.error}', textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => setState(() {
                          _words = _load();
                        }),
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final words = snapshot.data!;
            if (words.isEmpty) {
              return const Center(child: Text('아직 등록된 단어가 없습니다.'));
            }
            final groups = WordGroup.fromWords(words);
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '오늘도 30개씩',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text('총 ${words.length}개 단어 · ${groups.length}개 그룹'),
                          const SizedBox(height: 8),
                          const Text('그룹을 선택하고 발음과 뜻을 떠올려 보세요.'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        itemCount: groups.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          final known = _progress.knownCount(group.words);
                          return Card(
                            margin: EdgeInsets.zero,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              title: Text('단어 ${index + 1}  ·  ${group.label}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  Text('알고 있음 $known / ${group.words.length}'),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: known / group.words.length,
                                    semanticsLabel: '단어 ${index + 1} 학습 진행도',
                                  ),
                                  if (known == group.words.length)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text(
                                        '학습 완료',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => QuizScreen(
                                    group: group,
                                    progressStore: _progress,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
