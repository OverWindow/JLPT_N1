"""Append the ten October 11 photos using reviewed, explicit spelling aliases."""
import csv
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PHOTO_COUNTS = [26, 39, 27, 38, 23, 38, 29, 42, 30, 39]
ALIASES = {
    ('', 'つぶやく'): ('呟く', 'つぶやく'),
    ('強いて', 'しいて'): ('', 'しいて'),
    ('', 'ひそかだ'): ('密かだ', 'ひそかだ'),
    ('凄まじい', 'すさまじい'): ('', 'すさまじい'),
    ('', 'すがすがしい'): ('清々しい', 'すがすがしい'),
    ('', 'おびえる'): ('怯える', 'おびえる'),
    ('仕組み', 'しくみ'): ('仕組', 'しくみ'),
}
MEANINGS = {
    ('', 'すさまじい'): '무섭다, 무시무시하다',
    ('頑固だ', 'がんこだ'): '끈질기다, 완고하다',
    ('珍しい', 'めずらしい'): '드물다, 희귀하다',
}


def extend(words, save):
    assert len(words) == 822
    old_keys = [(w['kanji'], w['hiragana']) for w in words]
    index = {(w['kanji'] or '', w['hiragana']): i for i, w in enumerate(words)}
    with (ROOT/'data/photo-transcription-v1.3.tsv').open(encoding='utf-8', newline='') as f:
        incoming = list(csv.DictReader(f, delimiter='\t'))
    counts, audit, updates = Counter(), [], []
    for row in incoming:
        key = (row['kanji'], row['hiragana'])
        target = ALIASES.get(key, key)
        existing = target in index
        if existing:
            i = index[target]
        else:
            i = len(words)
            index[target] = i
            words.append({k: row[k] or None for k in ('kanji', 'hiragana', 'korean')})
        if target in MEANINGS and words[i]['korean'] != MEANINGS[target]:
            updates.append({'wordNumber': i+1, 'before': words[i]['korean'], 'after': MEANINGS[target]})
            words[i]['korean'] = MEANINGS[target]
        counts[row['source']] += 1
        audit.append({**row, 'wordNumber': i+1,
                      'action': 'merged' if existing else 'added',
                      'canonicalSpelling': words[i]['kanji'] or words[i]['hiragana'],
                      'match': 'reviewed_alias' if key != target else 'exact'})
    assert list(counts) == [f'{i:02d}' for i in range(10)]
    assert list(counts.values()) == PHOTO_COUNTS
    assert len(index) == len(words)
    assert [(w['kanji'], w['hiragana']) for w in words[:822]] == old_keys
    report = {'photoPrefix': 'KakaoTalk_20261011_213033981', 'photoCounts': counts,
              'original': 822, 'transcribed': len(incoming),
              'added': sum(r['action'] == 'added' for r in audit),
              'merged': sum(r['action'] == 'merged' for r in audit),
              'total': len(words), 'meaningUpdates': updates, 'rows': audit}
    save('data/import-v1.3.json', report)
    print(f"1.3: {len(incoming)} transcribed; {report['added']} added; {len(words)} total")
