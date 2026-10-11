"""Rebuild bundled data and photo-to-word audit without changing existing order."""
import csv
import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

def rows(name):
    with (ROOT / 'data' / name).open(encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f, delimiter='\t'))

original = rows('photo-transcription.tsv')
incoming = rows('photo-transcription-v1.1.tsv')
# Explicitly reviewed variants only; never merge by reading alone.
aliases = {
    ('染みる', 'しみる'): ('滲みる', 'しみる'),
    ('', 'たどる'): ('辿る', 'たどる'),
    ('', 'ここちよい'): ('心地よい', 'ここちよい'),
    ('強硬だ', 'きょうこうだ'): ('強硬', 'きょうこう'),
}
meaning_merges = {
    '大筋': '줄거리, 요점, 대략',
    '本音': '속마음, 본심',
    '障る': '방해되다, 지장이 있다, 거슬리다',
    '日夜': '밤낮, 밤낮으로',
    '強硬': '강경, 강경하다',
}
words = [{k: r[k] or None for k in ('kanji', 'hiragana', 'korean')} for r in original]
index = {(w['kanji'] or '', w['hiragana']): i for i, w in enumerate(words)}
audit = []
counts = Counter()
for row in incoming:
    key = (row['kanji'], row['hiragana'])
    target = aliases.get(key, key)
    existing = target in index
    if existing:
        i = index[target]
        if words[i]['kanji'] in meaning_merges:
            words[i]['korean'] = meaning_merges[words[i]['kanji']]
    else:
        i = len(words)
        index[target] = i
        words.append({k: row[k] or None for k in ('kanji', 'hiragana', 'korean')})
    counts[row['source']] += 1
    audit.append({**row, 'wordNumber': i + 1, 'action': 'merged' if existing else 'added',
                  'canonicalSpelling': words[i]['kanji'] or words[i]['hiragana']})

assert len(original) == 538
assert list(counts.values()) == [20,15,20,15,20,15,20,15,19,13,19,13,19,13,20,11,21,13]
assert len(index) == len(words)
for w in words:
    assert w['hiragana'] and w['korean']
    assert re.fullmatch(r'[ぁ-ゖァ-ヺー・]+', w['hiragana']), w
for i, row in enumerate(original):
    assert (words[i]['kanji'], words[i]['hiragana']) == (row['kanji'], row['hiragana'])

def save(path, value):
    (ROOT / path).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

save('data/import-v1.1.json', {
    'photoPrefix': 'KakaoTalk_20261006_074406479',
    'photoCounts': counts,
    'original': len(original), 'transcribed': len(incoming),
    'added': sum(r['action'] == 'added' for r in audit),
    'merged': sum(r['action'] == 'merged' for r in audit),
    'total': len(words), 'rows': audit,
})
print(f'{len(incoming)} transcribed; {len(words)-538} added; {len(words)} total')

# Examples are authored separately and keyed to the preserved word order.
import runpy
runpy.run_path(str(ROOT / 'data/extend_words_v1_3.py'))['extend'](words, save)
for w in words:
    assert w['hiragana'] and w['korean']
    assert re.fullmatch(r'[ぁ-ゖァ-ヺー・]+', w['hiragana']), w
save('assets/words/words.json', words)
runpy.run_path(str(ROOT / "data/build_examples.py"))
