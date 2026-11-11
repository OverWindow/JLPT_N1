"""Build reviewed counter readings and original example templates, offline.

Only writes assets/counters/counters.json; N1 data is never regenerated here.
Reading references and selection notes are in counters/README.md.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BASIC = [*range(1, 11), 20, 30, 100, None]
DIGITS = ['', 'いち', 'に', 'さん', 'よん', 'ご', 'ろく', 'なな', 'はち', 'きゅう']
KANJI = '零一二三四五六七八九'


def numeral(n):
    if n is None:
        return '何'
    if n < 10:
        return KANJI[n]
    if n == 100:
        return '百'
    return (KANJI[n // 10] if n >= 20 else '') + '十' + (KANJI[n % 10] if n % 10 else '')


def number_reading(n):
    if n is None:
        return 'なん'
    if n == 0:
        return 'れい'
    if n == 100:
        return 'ひゃく'
    if n < 10:
        return DIGITS[n]
    return (DIGITS[n // 10] if n >= 20 else '') + 'じゅう' + DIGITS[n % 10]


def basic_readings(first_ten, twenty, thirty, hundred, question):
    values = first_ten.split() + [twenty, thirty, hundred, question]
    assert len(values) == len(BASIC)
    return dict(zip(BASIC, values))


TABLES = {
    'hiki': basic_readings('いっぴき にひき さんびき よんひき ごひき ろっぴき ななひき はっぴき きゅうひき じゅっぴき',
        'にじゅっぴき', 'さんじゅっぴき', 'ひゃっぴき', 'なんびき'),
    'tou': basic_readings('いっとう にとう さんとう よんとう ごとう ろくとう ななとう はっとう きゅうとう じゅっとう',
        'にじゅっとう', 'さんじゅっとう', 'ひゃくとう', 'なんとう'),
    'wa': {n: number_reading(n) + 'わ' for n in BASIC},
    'week': basic_readings('いっしゅうかん にしゅうかん さんしゅうかん よんしゅうかん ごしゅうかん ろくしゅうかん ななしゅうかん はっしゅうかん きゅうしゅうかん じゅっしゅうかん',
        'にじゅっしゅうかん', 'さんじゅっしゅうかん', 'ひゃくしゅうかん', 'なんしゅうかん'),
    'month_duration': basic_readings('いっかげつ にかげつ さんかげつ よんかげつ ごかげつ ろっかげつ ななかげつ はっかげつ きゅうかげつ じゅっかげつ',
        'にじゅっかげつ', 'さんじゅっかげつ', 'ひゃっかげつ', 'なんかげつ'),
    'nin': basic_readings('ひとり ふたり さんにん よにん ごにん ろくにん ななにん はちにん きゅうにん じゅうにん',
        'にじゅうにん', 'さんじゅうにん', 'ひゃくにん', 'なんにん'),
    'ko': basic_readings('いっこ にこ さんこ よんこ ごこ ろっこ ななこ はっこ きゅうこ じゅっこ',
        'にじゅっこ', 'さんじゅっこ', 'ひゃっこ', 'なんこ'),
    'tsu': dict(zip([*range(1, 11), None], 'ひとつ ふたつ みっつ よっつ いつつ むっつ ななつ やっつ ここのつ とお いくつ'.split())),
    'hon': basic_readings('いっぽん にほん さんぼん よんほん ごほん ろっぽん ななほん はっぽん きゅうほん じゅっぽん',
        'にじゅっぽん', 'さんじゅっぽん', 'ひゃっぽん', 'なんぼん'),
    'mai': {n: number_reading(n) + 'まい' for n in BASIC},
    'satsu': basic_readings('いっさつ にさつ さんさつ よんさつ ごさつ ろくさつ ななさつ はっさつ きゅうさつ じゅっさつ',
        'にじゅっさつ', 'さんじゅっさつ', 'ひゃくさつ', 'なんさつ'),
    'hour_duration': basic_readings('いちじかん にじかん さんじかん よじかん ごじかん ろくじかん しちじかん はちじかん くじかん じゅうじかん',
        'にじゅうじかん', 'さんじゅうじかん', 'ひゃくじかん', 'なんじかん'),
}

DAY_SPECIAL = {1: 'ついたち', 2: 'ふつか', 3: 'みっか', 4: 'よっか', 5: 'いつか',
    6: 'むいか', 7: 'なのか', 8: 'ようか', 9: 'ここのか', 10: 'とおか',
    14: 'じゅうよっか', 19: 'じゅうくにち', 20: 'はつか', 24: 'にじゅうよっか', 29: 'にじゅうくにち'}
TABLES['date'] = {n: DAY_SPECIAL.get(n, number_reading(n) + 'にち') for n in [*range(1, 32), None]}
TABLES['day_duration'] = {n: DAY_SPECIAL.get(n, number_reading(n) + 'にち') for n in [*range(1, 11), 14, 20, 24, 30, 100, None]}
TABLES['day_duration'][1] = 'いちにち'
TABLES['month'] = {n: {4: 'しがつ', 7: 'しちがつ', 9: 'くがつ'}.get(n, number_reading(n) + 'がつ')
    for n in [*range(1, 13), None]}


def clock_hour(n):
    if n is None or n < 10:
        return {4: 'よじ', 7: 'しちじ', 9: 'くじ'}.get(n, number_reading(n) + 'じ')
    return (DIGITS[n // 10] if n >= 20 else '') + 'じゅう' + (clock_hour(n % 10) if n % 10 else 'じ')


TABLES['hour'] = {n: clock_hour(n) for n in [*range(24), None]}
MINUTES = [*range(11), 15, 20, 30, 40, 45, 50, 59, None]


def minute(n):
    small = ['れいふん', 'いっぷん', 'にふん', 'さんぷん', 'よんぷん', 'ごふん', 'ろっぷん', 'ななふん', 'はっぷん', 'きゅうふん']
    if n is None:
        return 'なんぷん'
    if n < 10:
        return small[n]
    prefix = DIGITS[n // 10] if n >= 20 else ''
    return prefix + ('じゅっぷん' if n % 10 == 0 else 'じゅう' + small[n % 10])


TABLES['minute'] = {n: minute(n) for n in MINUTES}

# Selective, verified alternatives, not an exhaustive list of historical readings.
ALTERNATIVES = {
    ('wa', 3): ['さんば'], ('wa', 10): ['じっぱ', 'じゅっぱ'],
    ('wa', 20): ['にじっぱ', 'にじゅっぱ'], ('wa', 30): ['さんじっぱ', 'さんじゅっぱ'],
    ('wa', 100): ['ひゃっぱ'],
    ('nin', 7): ['しちにん'], ('nin', 9): ['くにん'],
    ('ko', 8): ['はちこ'], ('mai', 7): ['しちまい'],
    ('month_duration', 8): ['はちかげつ'],
    ('minute', 4): ['よんふん'], ('minute', 8): ['はちふん'],
}
for table in ['hiki', 'tou', 'week', 'month_duration', 'ko', 'hon', 'satsu', 'minute']:
    for n, reading in TABLES[table].items():
        if 'じゅっ' in reading:
            ALTERNATIVES.setdefault((table, n), []).append(reading.replace('じゅっ', 'じっ'))


def ruby(markup):
    segments = []
    for chunk in re.split(r'(\[[^\[\]]+\|[^\[\]]+\])', markup):
        if not chunk:
            continue
        if chunk.startswith('['):
            text, reading = chunk[1:-1].split('|')
            assert re.fullmatch('[ぁ-ゖー]+', reading), chunk
            segments.append(dict(text=text, reading=reading))
        else:
            assert not re.search(r'[一-鿿々〆ヶ{}\[\]|]', chunk), chunk
            segments.append(dict(text=chunk))
    return segments


def counted(n, unit):
    return f'{"몇" if n is None else n}{" " if n is None else ""}{unit}'


DECKS = []


def deck(id, category, title, description, table, suffix, unit, jp, ko, question_jp=None, question_ko=None):
    items = []
    for n, reading in TABLES[table].items():
        spelling = numeral(n) + suffix
        if table == 'tsu':
            spelling = '幾つ' if n is None else ('十' if n == 10 else numeral(n) + 'つ')
        meaning = counted(n, unit)
        if table == 'day_duration':
            meaning = '하루' if n == 1 else ('며칠' if n is None else f'{n}일간')
        if table == 'date':
            meaning = ('며칠' if n is None else f'{n}일') + ' (날짜)'
        example_jp = (question_jp if n is None else jp).replace('{w}', f'[{spelling}|{reading}]')
        example_ko = (question_ko if n is None else ko).replace('{n}', str(n))
        items.append(dict(id=f'{id}.{n if n is not None else "question"}', number=n,
            kanji=spelling, hiragana=reading, alternateReadings=ALTERNATIVES.get((table, n), []),
            korean=meaning, example=dict(segments=ruby(example_jp), korean=example_ko)))
    DECKS.append(dict(id=id, category=category, title=title, description=description, items=items))


deck('animal.hiki', '동물', '작은 동물 · 匹', '고양이·강아지 등 작은 동물', 'hiki', '匹', '마리',
    '[猫|ねこ]が{w}います。', '고양이가 {n}마리 있습니다.',
    '[猫|ねこ]が{w}いますか。', '고양이가 몇 마리 있나요?')
deck('animal.tou', '동물', '큰 동물 · 頭', '소·말·코끼리 등 큰 동물', 'tou', '頭', '마리',
    '[牧場|ぼくじょう]に[牛|うし]が{w}います。', '목장에 소가 {n}마리 있습니다.',
    '[牧場|ぼくじょう]に[牛|うし]が{w}いますか。', '목장에 소가 몇 마리 있나요?')
deck('animal.wa', '동물', '새 · 羽', '새의 수', 'wa', '羽', '마리',
    '[池|いけ]に[鳥|とり]が{w}います。', '연못에 새가 {n}마리 있습니다.',
    '[池|いけ]に[鳥|とり]が{w}いますか。', '연못에 새가 몇 마리 있나요?')
deck('calendar.month', '날짜', '월 · 月', '1월부터 12월까지', 'month', '月', '월',
    '[旅行|りょこう]は{w}です。', '여행은 {n}월입니다.',
    '[旅行|りょこう]は{w}ですか。', '여행은 몇 월인가요?')
deck('calendar.day', '날짜', '달력 날짜 · 日', '달력의 1일부터 31일까지', 'date', '日', '일',
    '[次|つぎ]の[予約|よやく]は{w}です。', '다음 예약은 {n}일입니다.',
    '[次|つぎ]の[予約|よやく]は{w}ですか。', '다음 예약은 며칠인가요?')
deck('duration.day', '기간', '일수 · 日', '얼마나 오래 걸리는지 세는 일수', 'day_duration', '日', '일간',
    '[工事|こうじ]は{w}かかります。', '공사는 {n}일 걸립니다.',
    '[工事|こうじ]は{w}かかりますか。', '공사는 며칠 걸리나요?')
deck('duration.week', '기간', '주간 · 週間', '몇 주 동안의 기간', 'week', '週間', '주간',
    '[修理|しゅうり]は{w}かかります。', '수리는 {n}주 걸립니다.',
    '[修理|しゅうり]は{w}かかりますか。', '수리는 몇 주 걸리나요?')
deck('duration.month', '기간', '개월 · ヶ月', '몇 개월 동안의 기간', 'month_duration', 'ヶ月', '개월',
    '[完成|かんせい]まで{w}かかります。', '완성까지 {n}개월 걸립니다.',
    '[完成|かんせい]まで{w}かかりますか。', '완성까지 몇 개월 걸리나요?')
deck('people.nin', '사람', '사람 · 人', '사람의 수', 'nin', '人', '명',
    '[会場|かいじょう]に{w}います。', '행사장에 {n}명 있습니다.',
    '[会場|かいじょう]に{w}いますか。', '행사장에 몇 명 있나요?')
deck('objects.ko', '물건', '작은 물건 · 個', '달걀·상자 등 물건의 개수', 'ko', '個', '개',
    '[箱|はこ]に[卵|たまご]が{w}あります。', '상자에 달걀이 {n}개 있습니다.',
    '[箱|はこ]に[卵|たまご]が{w}ありますか。', '상자에 달걀이 몇 개 있나요?')
deck('objects.tsu', '물건', '일반 물건 · つ', '여러 물건을 세는 기본 표현', 'tsu', 'つ', '개',
    'りんごが{w}あります。', '사과가 {n}개 있습니다.',
    'りんごが{w}ありますか。', '사과가 몇 개 있나요?')
deck('objects.hon', '물건', '긴 물건 · 本', '우산·연필·병 등 길쭉한 물건', 'hon', '本', '개',
    '[店|みせ]に[傘|かさ]が{w}あります。', '가게에 우산이 {n}개 있습니다.',
    '[店|みせ]に[傘|かさ]が{w}ありますか。', '가게에 우산이 몇 개 있나요?')
deck('objects.mai', '물건', '납작한 물건 · 枚', '종이·표 등 얇고 납작한 물건', 'mai', '枚', '장',
    '[紙|かみ]を{w}[用意|ようい]しました。', '종이를 {n}장 준비했습니다.',
    '[紙|かみ]を{w}[用意|ようい]しましたか。', '종이를 몇 장 준비했나요?')
deck('objects.satsu', '물건', '책 · 冊', '책·공책 등 묶인 책자의 수', 'satsu', '冊', '권',
    '[棚|たな]に[本|ほん]が{w}あります。', '책장에 책이 {n}권 있습니다.',
    '[棚|たな]に[本|ほん]が{w}ありますか。', '책장에 책이 몇 권 있나요?')
deck('time.hour', '시간', '시각 · 時', '0시부터 23시까지', 'hour', '時', '시',
    '[今|いま]は{w}です。', '지금은 {n}시입니다.',
    '[今|いま]は{w}ですか。', '지금은 몇 시인가요?')
deck('time.minute', '시간', '시각의 분 · 分', '시계에서 몇 분인지 읽기', 'minute', '分', '분',
    '[今|いま]は[三時|さんじ]{w}です。', '지금은 3시 {n}분입니다.',
    '[今|いま]、[三時|さんじ]{w}ですか。', '지금 3시 몇 분인가요?')
deck('time.duration', '시간', '소요 시간 · 時間', '몇 시간 동안의 길이', 'hour_duration', '時間', '시간',
    '[作業|さぎょう]に{w}かかります。', '작업에 {n}시간 걸립니다.',
    '[作業|さぎょう]に{w}かかりますか。', '작업에 몇 시간 걸리나요?')

if __name__ == '__main__':
    assert len(DECKS) == 17
    ids = set()
    for group in DECKS:
        for word in group['items']:
            assert word['id'] not in ids
            ids.add(word['id'])
            assert word['kanji'] and re.fullmatch('[ぁ-ゖー]+', word['hiragana'])
            assert word['korean'] and word['example']['korean']
            assert word['hiragana'] not in word['alternateReadings']
            assert len(word['alternateReadings']) == len(set(word['alternateReadings']))
    asset = ROOT / 'assets/counters/counters.json'
    asset.parent.mkdir(parents=True, exist_ok=True)
    asset.write_text(json.dumps(dict(decks=DECKS), ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'{len(DECKS)} counter decks; {len(ids)} expressions with examples')
