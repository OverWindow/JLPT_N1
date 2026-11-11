"""Check delivered APK data, identities, signer, ABI and permissions."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import zipfile

root = Path(__file__).resolve().parent.parent
sdk_dir = next(line.split('=', 1)[1] for line in
               (root/'android/local.properties').read_text().splitlines()
               if line.startswith('sdk.dir=')).replace('\\\\', '\\').replace('\\:', ':')
sdk = Path(sdk_dir)/'build-tools/36.1.0'
java = Path('C:/Program Files/Android/Android Studio/jbr/bin/java.exe')
version, build = re.search(r'^version: (\S+)', (root/'pubspec.yaml').read_text(), re.M).group(1).split('+')
apk = root/f'releases/jlpt-{version}.apk'
old = root/'releases/jlpt-1.6.0.apk'
out = root / ('verification/v' + version)
out.mkdir(parents=True, exist_ok=True)

def run(*args):
    return subprocess.check_output([str(x) for x in args], text=True, encoding='utf-8', errors='replace')

badging = run(sdk/'aapt.exe', 'dump', 'badging', apk)
permissions = run(sdk/'aapt.exe', 'dump', 'permissions', apk)
assert f"package: name='com.example.jlpt' versionCode='{build}' versionName='{version}'" in badging
assert 'android.permission.INTERNET' not in permissions
assert "sdkVersion:'24'" in badging
certs = [run(java, '-jar', sdk/'lib/apksigner.jar', 'verify', '--print-certs', f) for f in [old, apk]]
fingerprints = [re.search(r'certificate SHA-256 digest: (\w+)', c).group(1) for c in certs]
assert fingerprints[0] == fingerprints[1]
with zipfile.ZipFile(apk) as z:
    bundled = json.loads(z.read('assets/flutter_assets/assets/words/words.json'))
    assert bundled == json.loads((root/'assets/words/words.json').read_text(encoding='utf-8'))
    audit = json.loads((root/'data/import-v1.6.json').read_text(encoding='utf-8'))
    assert len(bundled) == audit['total']
    assert all(w.get('example', {}).get('segments') and w['example'].get('korean') for w in bundled)
    counters = json.loads(z.read('assets/flutter_assets/assets/counters/counters.json'))
    assert counters == json.loads((root/'assets/counters/counters.json').read_text(encoding='utf-8'))
    assert len(counters['decks']) == 17
    items = [w for deck in counters['decks'] for w in deck['items']]
    assert len(items) == 270 and len({w['id'] for w in items}) == 270
    assert all(w['example']['segments'] and w['example']['korean'] for w in items)
    adverbs = json.loads(z.read('assets/flutter_assets/assets/adverbs/adverbs.json'))
    assert adverbs == json.loads((root/'assets/adverbs/adverbs.json').read_text(encoding='utf-8'))
    special_items = [w for d in adverbs['decks'] for w in d['items']]
    assert [len(d['items']) for d in adverbs['decks']] == [30,30,4,7,4,7,6,11]
    assert len(special_items) == len({w['id'] for w in special_items}) == 99
    assert all(w['example']['segments'] and w['example']['korean'] for w in special_items)
    grammar = json.loads(z.read('assets/flutter_assets/assets/grammar/grammar.json'))
    assert grammar == json.loads((root/'assets/grammar/grammar.json').read_text(encoding='utf-8'))
    grammar_items = [w for d in grammar['decks'] for w in d['items']]
    assert [len(d['items']) for d in grammar['decks']] == [29,29,29,26,25,25,16,16,30,29]
    assert len(grammar_items) == len({w['id'] for w in grammar_items}) == 254
    assert all(w['connection'] and w['example']['segments'] and w['example']['korean'] for w in grammar_items)
    for item in grammar_items:
        for part in item['example']['segments']:
            assert not re.search(r'[一-鿿々〆ヶ]', part['text']) or part.get('reading')
    abis = sorted({n.split('/')[1] for n in z.namelist() if n.startswith('lib/')})
    assert abis == ['arm64-v8a','armeabi-v7a','x86_64']
with zipfile.ZipFile(old) as z:
    previous = json.loads(z.read('assets/flutter_assets/assets/words/words.json'))
    assert counters == json.loads(z.read('assets/flutter_assets/assets/counters/counters.json'))
    assert adverbs == json.loads(z.read('assets/flutter_assets/assets/adverbs/adverbs.json'))
assert len(previous) == 1342
assert bundled == previous
resources = run(sdk/'aapt.exe', 'dump', 'resources', apk)
assert 'drawable/ic_launcher_foreground' in resources
assert 'mipmap/ic_launcher' in resources
sha = hashlib.sha256(apk.read_bytes()).hexdigest()
assert hashlib.sha256(old.read_bytes()).hexdigest() == old.with_suffix('.apk.sha256').read_text().split()[0]
apk.with_suffix('.apk.sha256').write_text(f'{sha}  {apk.name}\n')
(out/'apk-badging.txt').write_text(badging,encoding='utf-8')
(out/'apk-permissions.txt').write_text(permissions,encoding='utf-8')
(out/'apk-certificate.txt').write_text(certs[1],encoding='utf-8')
report = dict(apk=f'releases/jlpt-{version}.apk', bytes=apk.stat().st_size, sha256=sha,
              abis=abis, word_count=len(bundled), internet_permission=False,
              package='com.example.jlpt',version=version,version_code=int(build),example_count=len(bundled),
              counter_decks=len(counters['decks']),counter_count=len(items),counter_example_count=len(items),
              special_decks=8,special_count=len(special_items),special_example_count=len(special_items),
              grammar_decks=len(grammar['decks']),grammar_count=len(grammar_items),grammar_example_count=len(grammar_items),
              original_counters_preserved=True,
              original_adverbs_preserved=True,
              original_signer_preserved=True,original_apk_unchanged=True,
              original_identities_and_examples_preserved=True)
(out/'apk-check.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
