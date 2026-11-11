"""Rebuild the independent special collection and its source/overlap audit."""
import csv
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'data/adverbs/entries.tsv'
PAGE_FILES = {130: '', 131: '_01', 132: '_04', 133: '_02', 134: '_03',
              135: '_06', 136: '_07', 137: '_05', 138: '_08', 139: '_09', 140: '_10'}
COUNTS = {130: 4, 131: 10, 132: 15, 133: 10, 134: 15, 135: 10,
          136: 5, 137: 6, 138: 11, 139: 2, 140: 11}
SECTIONS = [('sequence', '순접', 7), ('choice', '병렬·선택', 4),
            ('contrast', '역접', 7), ('transition', '전환·환언', 6),
            ('addition', '첨가·보충', 11)]
KANJI = re.compile(r'[一-鿿々〆ヶ]')
RUBY = re.compile(r'\[([^\[\]|]+)\|([ぁ-ゖァ-ヺー]+)\]')


def example(markup, korean):
    parts, pos = [], 0
    for match in RUBY.finditer(markup):
        if match.start() > pos:
            parts.append({'text': markup[pos:match.start()]})
        parts.append({'text': match[1], 'reading': match[2]})
        pos = match.end()
    if pos < len(markup):
        parts.append({'text': markup[pos:]})
    assert parts and korean
    for part in parts:
        assert not any(c in part['text'] for c in '[]|'), markup
        assert not KANJI.search(part['text']) or part.get('reading'), markup
    return {'segments': parts, 'korean': korean}


def build():
    rows = list(csv.DictReader(SOURCE.open(encoding='utf-8'), delimiter='\t'))
    assert len(rows) == 99 and len({r['id'] for r in rows}) == 99
    assert [(int(r['page']), int(r['row'])) for r in rows] == [
        (p, i) for p, n in COUNTS.items() for i in range(1, n + 1)]
    words = []
    for row in rows:
        assert all(row.values()), row
        assert re.fullmatch(r'[ぁ-ゖー～]+', row['reading']), row
        assert re.fullmatch(r'special\.[a-z]+\.[0-9]{3}', row['id'])
        words.append(dict(id=row['id'],
                          kanji=row['spelling'] if KANJI.search(row['spelling']) else None,
                          hiragana=row['reading'], korean=row['korean'],
                          example=example(row['example'], row['example_korean'])))
        assert (words[-1]['kanji'] or words[-1]['hiragana']) == row['spelling']
    decks = []
    adverbs = words[:64]
    for start in range(0, len(adverbs), 30):
        part = adverbs[start:start + 30]
        decks.append(dict(id=f'adverb.{start // 30 + 1}', category='부사',
                          title=f'부사 {start // 30 + 1}', description=f'{start + 1}~{start + len(part)}',
                          items=part))
    for section, title, count in SECTIONS:
        items = [w for w in words if w['id'].startswith(f'special.{section}.')]
        assert len(items) == count
        decks.append(dict(id=f'connective.{section}', category='접속 표현',
                          title=title, description=f'{count}개 표현', items=items))
    assert [len(d['items']) for d in decks] == [30, 30, 4, 7, 4, 7, 6, 11]
    target = ROOT / 'assets/adverbs/adverbs.json'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps({'decks': decks}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    n1 = json.loads((ROOT / 'assets/words/words.json').read_text(encoding='utf-8'))
    audit_rows = []
    for row in rows:
        # Reading matches flag both alternate spellings and different senses for review.
        candidates = [dict(number=i + 1, spelling=w['kanji'] or w['hiragana'], meaning=w['korean'])
                      for i, w in enumerate(n1)
                      if w['hiragana'] == row['reading'].replace('～ない', '')]
        audit_rows.append(dict(id=row['id'], page=int(row['page']), row=int(row['row']),
                               spelling=row['spelling'], n1_reading_matches=candidates,
                               action='preserve_as_independent_special_item'))
    audit = dict(total=99, adverbs=64, connectives=35, decks=8,
                 source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
                 photos=[dict(file=f'KakaoTalk_20261031_011108945{suffix}.jpg', page=p,
                              count=COUNTS[p]) for p, suffix in PAGE_FILES.items()],
                 items=audit_rows)
    (ROOT / 'data/adverbs/import-v1.5.json').write_text(
        json.dumps(audit, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'{len(words)} items / {len(decks)} decks; N1 reading overlaps: '
          f'{sum(bool(r["n1_reading_matches"]) for r in audit_rows)}')


if __name__ == '__main__':
    build()
