"""Compile authored examples with ruby segments into the offline word asset."""
import csv
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
asset = ROOT/'assets/words/words.json'
words = json.loads(asset.read_text(encoding='utf-8'))
examples = {}
kanji = re.compile(r'[一-鿿々〆ヶ]')

def parts(markup):
    result = []
    for chunk in re.split(r'(\[[^\[\]]+\|[^\[\]]+\])', markup):
        if not chunk:
            continue
        if chunk.startswith('['):
            text, reading = chunk[1:-1].split('|')
            assert re.fullmatch(r'[ぁ-ゖァ-ヺー・]+', reading), chunk
            result.append({'text': text, 'reading': reading})
        else:
            assert not kanji.search(chunk), f'Missing furigana: {chunk}'
            assert not any(c in chunk for c in '{}[]|'), chunk
            result.append({'text': chunk})
    return result

for file in sorted((ROOT/'data/examples').glob('*.tsv')):
    with file.open(encoding='utf-8-sig', newline='') as stream:
        for row in csv.reader(stream, delimiter='\t'):
            if not row: continue
            assert len(row) == 3, (file, row)
            number, japanese, korean = row
            i = int(number)-1
            assert 0 <= i < len(words) and i not in examples, number
            word = words[i]
            spelling = word['kanji'] or word['hiragana']
            reading = word['hiragana'].split('・')[0]
            target = f'[{spelling}|{reading}]' if kanji.search(spelling) else spelling
            japanese = japanese.replace('{w}', target)
            ruby = parts(japanese)
            assert korean.strip() and ruby
            examples[i] = {'segments': ruby, 'korean': korean.strip()}

assert len(examples) == len(words), f'Missing: {[i+1 for i in range(len(words)) if i not in examples]}'
for i, word in enumerate(words):
    word['example'] = examples[i]
asset.write_text(json.dumps(words, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(f'Validated and compiled {len(examples)} examples with furigana and Korean')
