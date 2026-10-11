import 'dart:math';

import 'package:flutter/material.dart';

import '../models/japanese_word.dart';
import '../services/progress_store.dart';
import '../widgets/example_sentence.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.group,
    required this.progressStore,
    this.random,
  });
  final WordGroup group;
  final ProgressStore progressStore;
  final Random? random;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _index = 0;
  bool _revealed = false;
  bool _saving = false;
  bool? _choice;
  bool _saveFailed = false;
  late List<JapaneseWord> _words;

  @override
  void initState() {
    super.initState();
    _shuffle();
  }

  void _shuffle() {
    _words = [...widget.group.words]..shuffle(widget.random);
  }

  Future<void> _answer(bool known) async {
    if (_saving) return;
    setState(() {
      _revealed = true;
      _saving = true;
      _choice = known;
      _saveFailed = false;
    });
    try {
      await widget.progressStore.setKnown(_words[_index], known);
    } catch (_) {
      if (mounted) setState(() => _saveFailed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _move(int index) {
    setState(() {
      _index = index;
      _revealed = false;
      _choice = null;
      _saveFailed = false;
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: Text('단어 ${widget.group.label}')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (_index >= _words.length) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (constraints.maxHeight - 48).clamp(
                          0,
                          double.infinity,
                        ),
                      ),
                      child: _completion(_words.length),
                    ),
                  );
                }
                final word = _words[_index];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 24,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${_index + 1} / ${_words.length}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: (_index + 1) / _words.length,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, area) {
                            final landscape =
                                constraints.maxWidth > constraints.maxHeight;
                            if (landscape) {
                              return Row(
                                children: [
                                  Expanded(
                                    child: _prompt(word, area.maxWidth / 2 - 8),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _answerDetails(
                                      word,
                                      area.maxWidth / 2 - 8,
                                    ),
                                  ),
                                ],
                              );
                            }
                            // Reserve the same space before/after revealing the answer.
                            // Content scales down to fit; nothing scrolls or pushes controls.
                            return Column(
                              children: [
                                SizedBox(height: area.maxHeight * .32),
                                SizedBox(
                                  height: area.maxHeight * .18,
                                  child: _prompt(word, area.maxWidth),
                                ),
                                Expanded(
                                  child: _answerDetails(word, area.maxWidth),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: (constraints.maxHeight * .22).clamp(
                          112.0,
                          144.0,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.bottomCenter,
                          child: SizedBox(
                            width: constraints.maxWidth - 32,
                            child: _controls(),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );

  Widget _prompt(JapaneseWord word, double width) => Center(
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: width,
        child: Text(
          word.prompt,
          key: const ValueKey('question-prompt'),
          locale: const Locale('ja'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
      ),
    ),
  );

  Widget _answerDetails(JapaneseWord word, double width) => SizedBox.expand(
    child: !_revealed
        ? const SizedBox.shrink()
        : FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (word.hasKanji) ...[
                    Text(
                      word.hiragana,
                      key: const ValueKey('word-reading'),
                      locale: const Locale('ja'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, height: 1.4),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    word.korean,
                    key: const ValueKey('word-meaning'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, height: 1.4),
                  ),
                  if (word.example != null) ...[
                    const SizedBox(height: 10),
                    ExampleSentence(
                      key: const ValueKey('word-example'),
                      example: word.example!,
                      maxWidth: width,
                    ),
                  ],
                ],
              ),
            ),
          ),
  );

  Widget _controls() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // Saving and retry status have a reserved slot so controls never shift.
      SizedBox(
        height: 28,
        child: _saveFailed
            ? Row(
                children: [
                  const Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('저장하지 못했습니다. 다시 시도해 주세요.'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _answer(_choice!),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('저장 다시 시도'),
                  ),
                ],
              )
            : _saving
            ? const Center(child: Text('저장 중…'))
            : null,
      ),
      Row(
        children: [
          Expanded(child: _answerButton(false, '모름')),
          const SizedBox(width: 12),
          Expanded(child: _answerButton(true, '알고 있음')),
        ],
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 56,
        child: _revealed
            ? FilledButton(
                onPressed: _saving || _saveFailed
                    ? null
                    : () => _move(_index + 1),
                child: const Text('다음 단어'),
              )
            : null,
      ),
    ],
  );

  Widget _answerButton(bool known, String label) => Semantics(
    selected: _choice == known,
    child: OutlinedButton(
      key: ValueKey(known ? 'known' : 'unknown'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        backgroundColor: _choice == known
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
        side: BorderSide(
          color: _choice == known
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
          width: _choice == known ? 2 : 1,
        ),
      ),
      onPressed: _saving ? null : () => _answer(known),
      child: Text(label, textAlign: TextAlign.center),
    ),
  );

  Widget _completion(int count) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Icon(
        Icons.check_circle_outline,
        size: 64,
        color: Color(0xFF455C48),
      ),
      const SizedBox(height: 24),
      Text(
        '이번 학습 종료',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 16),
      Text(
        '알고 있음 ${widget.progressStore.knownCount(_words)} / $count',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 18),
      ),
      const SizedBox(height: 40),
      FilledButton(
        onPressed: () {
          _shuffle();
          _move(0);
        },
        child: const Text('다시 학습하기'),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('단어 목록으로'),
      ),
    ],
  );
}
