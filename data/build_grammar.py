"""Build all 254 numbered photo headings with original study examples."""
import csv
import hashlib
import json
import re
from pathlib import Path

from build_adverbs import KANJI, example

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / 'data/grammar'
SECTIONS = [
    ('noun', '명사 뒤에 접속하는 문형', '명사', 87, [29, 29, 29]),
    ('verb', '동사 뒤에 접속하는 문형', '동사', 76, [26, 25, 25]),
    ('mixed', '명사와 동사 모두에 접속하는 문형', '명사·동사', 32, [16, 16]),
    ('multi', '여러 품사 뒤에 접속하는 문형', '여러 품사', 59, [30, 29]),
]
READINGS = dict(pair.split(':') for pair in '''
応じ:おうじ 応え:こたえ 上:うえ 他:ほか 以上:いじょう 以来:いらい
余儀:よぎ 先立:さきだ 出:だ 切:き 即:そく 及:およ 同然:どうぜん
否:いな 問:と 基:もと 境:さかい 契機:けいき 始:はじ 始末:しまつ
対:たい 差:さ 得:え 思:おも 手前:てまえ 抜:ぬ 振:ふ 控:ひか
支:つか 早:はや 最後:さいご 極:きわ 機:き 次第:しだい 沿:そ
皮切:かわき 相:あい 相違:そうい 禁:きん 経:へ 至:いた 言:い
越:こ 足:た 踏:ふ 込:こ 限:かぎ 除:のぞ 顧:かえり
'''.split())


def reading(pattern):
    for text in sorted(READINGS, key=len, reverse=True):
        pattern = pattern.replace(text, READINGS[text])
    assert not KANJI.search(pattern), pattern
    assert re.fullmatch(r'[ぁ-ゖー～／…（）]+', pattern), pattern
    return pattern


def build():
    review = json.loads((DATA / 'photo-review-2026-11-08.json').read_text(encoding='utf-8'))
    headings = {}
    for photo in review['photos']:
        for heading in photo['headings']:
            key = (photo['section'], heading['number'])
            assert key not in headings, key
            headings[key] = (heading, photo)
    assert len(headings) == 254
    decks, audit_items, hashes = [], [], {}
    for slug, section, title, count, sizes in SECTIONS:
        path = DATA / f'{slug}.tsv'
        rows = list(csv.DictReader(path.open(encoding='utf-8'), delimiter='\t'))
        hashes[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
        assert [int(row['number']) for row in rows] == list(range(1, count + 1))
        words = []
        for row in rows:
            assert all(value and value.strip() for value in row.values()), row
            number = int(row['number'])
            heading, photo = headings[(section, number)]
            pattern = heading['pattern']
            uid = f'grammar.{slug}.{number:03d}'
            word = dict(id=uid, kanji=pattern if KANJI.search(pattern) else None,
                        hiragana=reading(pattern), korean=row['korean'],
                        connection=row['connection'],
                        example=example(row['example'], row['example_korean']))
            assert (word['kanji'] or word['hiragana']) == pattern
            words.append(word)
            audit_items.append(dict(id=uid, number=number, pattern=pattern, source=photo['file'],
                                    source_partial=photo['partialContent'],
                                    number_inferred=heading.get('numberInferredFromAdjacentPages', False)))
        assert sum(sizes) == count
        start = 0
        for index, size in enumerate(sizes, 1):
            decks.append(dict(id=f'grammar.{slug}.{index}', category=title,
                              title=f'{title} {index}',
                              description=f'{start + 1}~{start + size}번 · {size}개 문형',
                              items=words[start:start + size]))
            start += size
    assert len(audit_items) == len({item['id'] for item in audit_items}) == 254
    target = ROOT / 'assets/grammar/grammar.json'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps({'decks': decks}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    audit = dict(total=254, decks=len(decks), unique_source_photos=68,
                 duplicate_photo_copies_excluded=30, examples='original study sentences',
                 source_sha256=hashes, items=audit_items)
    (DATA / 'import-v1.7.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'{len(audit_items)} grammar items / {len(decks)} decks; all photo headings covered')


if __name__ == '__main__':
    build()
