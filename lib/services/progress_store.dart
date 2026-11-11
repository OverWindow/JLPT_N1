import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/japanese_word.dart';

class ProgressStore extends ChangeNotifier {
  ProgressStore({
    String preferenceKey = storageKey,
    Future<List<String>?> Function()? read,
    Future<void> Function(List<String>)? write,
  }) : _read =
           read ??
           (() => SharedPreferencesAsync().getStringList(preferenceKey)),
       _write =
           write ??
           ((keys) =>
               SharedPreferencesAsync().setStringList(preferenceKey, keys));

  static const storageKey = 'known_word_keys_v1';
  static const adverbStorageKey = 'known_adverb_keys_v1';
  static const grammarStorageKey = 'known_grammar_keys_v1';
  static const counterStorageKey = 'known_counter_keys_v1';
  final Future<List<String>?> Function() _read;
  final Future<void> Function(List<String>) _write;
  Set<String> _known = {};
  bool _loaded = false;
  bool _saving = false;

  Future<void> load() async {
    if (_loaded) return;
    final keys = await _read();
    _known = (keys ?? []).toSet();
    _loaded = true;
    notifyListeners();
  }

  bool isKnown(JapaneseWord word) => _known.contains(word.progressKey);
  int knownCount(Iterable<JapaneseWord> words) => words.where(isKnown).length;

  Future<void> setKnown(JapaneseWord word, bool known) async {
    if (!_loaded || _saving) throw StateError('Progress store is not ready');
    _saving = true;
    try {
      final updated = {..._known};
      known ? updated.add(word.progressKey) : updated.remove(word.progressKey);
      // Publish only after a successful save. Failed writes can be retried.
      await _write(updated.toList()..sort());
      _known = updated;
      notifyListeners();
    } finally {
      _saving = false;
    }
  }
}
