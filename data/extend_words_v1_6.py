"""Append the fourteen November 8 photos while preserving existing word identities."""
import csv
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PHOTO_COUNTS = [14, 20, 15, 18, 14, 19, 14, 20, 15, 20, 15, 20, 15, 21]
# Reviewed spelling variants only. Homophones and different study forms stay separate.
ALIASES = {
    ('', 'おおげさだ'): ('大げさだ', 'おおげさだ'),
    ('', 'かばう'): ('庇う', 'かばう'),
}
# The TSV preserves the photographed Korean; clarified meanings are audited here.
MEANINGS = {
    ('一概に', 'いちがいに'): '일률적으로, 단정하여',
    ('煌々と', 'こうこうと'): '반짝반짝, 환하게',
    ('安静だ', 'あんせいだ'): '평온하다, 조용히 쉬는 상태이다',
    ('安静', 'あんせい'): '안정(安靜), 편히 쉼',
    ('交錯', 'こうさく'): '교차, 뒤얽힘',
}


def extend(words, save):
    assert len(words) == 1130
    old_words = [dict(w) for w in words]
    index = {(w['kanji'] or '', w['hiragana']): i for i, w in enumerate(words)}
    with (ROOT / 'data/photo-transcription-v1.6.tsv').open(encoding='utf-8', newline='') as f:
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
            if target in MEANINGS:
                updates.append({'wordNumber': i + 1, 'before': row['korean'], 'after': MEANINGS[target]})
                words[i]['korean'] = MEANINGS[target]
        counts[row['source']] += 1
        audit.append({**row, 'wordNumber': i + 1,
                      'action': 'merged' if existing else 'added',
                      'canonicalSpelling': words[i]['kanji'] or words[i]['hiragana'],
                      'match': 'reviewed_alias' if key != target else 'exact'})
    assert list(counts) == [f'{i:02d}' for i in range(14)]
    assert list(counts.values()) == PHOTO_COUNTS
    assert len(index) == len(words)
    assert words[:1130] == old_words
    report = {'photoPrefix': 'KakaoTalk_20261108_190033576', 'photoCounts': counts,
              'original': 1130, 'transcribed': len(incoming),
              'added': sum(r['action'] == 'added' for r in audit),
              'merged': sum(r['action'] == 'merged' for r in audit),
              'total': len(words), 'meaningUpdates': updates, 'rows': audit}
    save('data/import-v1.6.json', report)
    print(f"1.6: {len(incoming)} transcribed; {report['added']} added; {len(words)} total")
