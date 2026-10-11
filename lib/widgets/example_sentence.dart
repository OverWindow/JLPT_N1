import 'package:flutter/material.dart';

import '../models/japanese_word.dart';

/// Each annotated word keeps its reading above its spelling when lines wrap.
class ExampleSentence extends StatelessWidget {
  const ExampleSentence({
    super.key,
    required this.example,
    required this.maxWidth,
  });
  final WordExample example;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final rubyHeight = MediaQuery.textScalerOf(context).scale(11) * 1.3;
    final segments = [
      for (final part in example.segments)
        if (part.reading != null)
          part
        else
          ...part.text.runes.map(
            (rune) => RubySegment(String.fromCharCode(rune)),
          ),
    ];
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: example.reading,
              child: ExcludeSemantics(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  runSpacing: 6,
                  children: [
                    for (final part in segments)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: (maxWidth - 24).clamp(1, double.infinity),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: rubyHeight,
                                child: Text(
                                  part.reading ?? '',
                                  locale: const Locale('ja'),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                              Text(
                                part.text,
                                locale: const Locale('ja'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              example.korean,
              key: const ValueKey('example-translation'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
