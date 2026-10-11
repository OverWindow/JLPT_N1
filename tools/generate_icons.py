"""Font-free vector book/日 mark, rasterized at 4x for launcher sizes."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
GREEN = '#294C3B'
IVORY = '#FFF5DD'
# All foreground coordinates fit the Android 66dp safe circle.
SHAPES = [
    ('polygon', [(34,29),(70,29),(74,33),(74,79),(34,79)], IVORY),
    ('rect', (38,32,40,74), GREEN),
    ('rect', (46,40,65,65), GREEN),
    ('rect', (50,44,61,50), IVORY),
    ('rect', (50,54,61,61), IVORY),
    ('rect', (40,73,70,75), GREEN),
]

def icon(size, adaptive=False):
    scale = size * 4 / 108
    zoom = 1 if adaptive else 1.35
    im = Image.new('RGBA', (size*4,size*4), (0,0,0,0) if adaptive else GREEN)
    draw = ImageDraw.Draw(im)
    def point(x,y):
        return ((54+(x-54)*zoom)*scale, (54+(y-54)*zoom)*scale)
    for kind, xy, color in SHAPES:
        if kind == 'polygon': draw.polygon([point(x,y) for x,y in xy], fill=color)
        else: draw.rectangle((*point(xy[0],xy[1]),*point(xy[2],xy[3])), fill=color)
    im = im.resize((size,size), Image.Resampling.LANCZOS)
    return im if adaptive else im.convert('RGB')

def save(path, im):
    path = ROOT / path
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path)

parts = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108"><rect width="108" height="108" fill="{GREEN}"/><g transform="translate(54 54) scale(1.35) translate(-54 -54)">']
paths = []
for kind, xy, color in SHAPES:
    if kind == 'rect':
        x,y,r,b = xy
        points = [(x,y),(r,y),(r,b),(x,b)]
    else: points = xy
    path = 'M'+' L'.join(f'{x},{y}' for x,y in points)+' Z'
    parts.append(f'<path d="{path}" fill="{color}"/>')
    paths.append(f'    <path android:fillColor="{color}" android:pathData="{path}"/>')
parts.append('</g></svg>')
(ROOT/'assets/icon').mkdir(exist_ok=True)
(ROOT/'assets/icon/app-icon.svg').write_text('\n'.join(parts), encoding='utf-8')
save('assets/icon/app-icon.png', icon(1024))
for density, size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
    save(f'android/app/src/main/res/mipmap-{density}/ic_launcher.png', icon(size))
res = ROOT/'android/app/src/main/res'
(res/'drawable').mkdir(exist_ok=True)
(res/'drawable/ic_launcher_foreground.xml').write_text(
    '<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">\n'+'\n'.join(paths)+'\n</vector>\n', encoding='utf-8')
(res/'values/icon_colors.xml').write_text(f'<resources><color name="icon_background">{GREEN}</color></resources>\n', encoding='utf-8')
(res/'mipmap-anydpi-v26').mkdir(exist_ok=True)
(res/'mipmap-anydpi-v26/ic_launcher.xml').write_text('''<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/icon_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
''', encoding='utf-8')
catalog = ROOT/'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for item in json.loads((catalog/'Contents.json').read_text())['images']:
    size = round(float(item['size'].split('x')[0])*float(item['scale'][:-1]))
    save(catalog/item['filename'], icon(size))

preview = Image.new('RGB',(640,320),'#FAFAF7')
preview.paste(icon(256),(24,32))
circle = Image.new('RGBA',(256,256),GREEN)
circle.alpha_composite(icon(256,True))
mask = Image.new('L',(256,256))
ImageDraw.Draw(mask).ellipse((0,0,255,255),fill=255)
preview.paste(circle,(320,32),mask)
preview.paste(icon(48),(580,136))
save('verification/v1.1/icon-preview.png',preview)
print('Generated SVG, Android legacy/adaptive and all iOS icon sizes')
