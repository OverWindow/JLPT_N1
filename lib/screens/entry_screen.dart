import 'package:flutter/material.dart';

import '../services/progress_store.dart';
import 'home_screen.dart';
import 'counter_screen.dart';
import 'adverb_screen.dart';
import 'grammar_screen.dart';

class EntryScreen extends StatefulWidget {
  const EntryScreen({
    super.key,
    this.progressStore,
    this.counterProgressStore,
    this.adverbProgressStore,
    this.grammarProgressStore,
  });
  final ProgressStore? progressStore;
  final ProgressStore? counterProgressStore;
  final ProgressStore? adverbProgressStore;
  final ProgressStore? grammarProgressStore;
  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  late final ProgressStore _words = widget.progressStore ?? ProgressStore();
  late final ProgressStore _counters =
      widget.counterProgressStore ??
      ProgressStore(preferenceKey: ProgressStore.counterStorageKey);

  late final ProgressStore _adverbs =
      widget.adverbProgressStore ??
      ProgressStore(preferenceKey: ProgressStore.adverbStorageKey);

  late final ProgressStore _grammar =
      widget.grammarProgressStore ??
      ProgressStore(preferenceKey: ProgressStore.grammarStorageKey);

  @override
  void dispose() {
    if (widget.progressStore == null) _words.dispose();
    if (widget.counterProgressStore == null) _counters.dispose();
    if (widget.adverbProgressStore == null) _adverbs.dispose();
    if (widget.grammarProgressStore == null) _grammar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('일본어 단어장')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            children: [
              Text(
                '오늘은 무엇을 공부할까요?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text('뜻을 떠올리고, 예문으로 익혀 보세요.'),
              const SizedBox(height: 32),
              _entry(
                'N1 단어',
                '30개씩 배우는 일본어 단어와 표현',
                Icons.menu_book,
                () => HomeScreen(progressStore: _words),
              ),
              const SizedBox(height: 16),
              _entry(
                'N1 문법',
                '254개 문형 · 뜻·접속·후리가나 예문',
                Icons.school_outlined,
                () => GrammarScreen(progressStore: _grammar),
              ),
              const SizedBox(height: 16),
              _entry(
                '조수사',
                '동물·날짜·기간·사람·물건·시간 세기',
                Icons.format_list_numbered,
                () => CounterScreen(progressStore: _counters),
              ),
              const SizedBox(height: 16),
              _entry(
                '부사 특집',
                '부사 64개 · 접속 표현 35개',
                Icons.auto_stories,
                () => AdverbScreen(progressStore: _adverbs),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _entry(
    String title,
    String subtitle,
    IconData icon,
    Widget Function() page,
  ) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () =>
          Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => page())),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(subtitle),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );
}
