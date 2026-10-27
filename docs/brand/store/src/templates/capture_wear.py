#!/usr/bin/env python3
"""Real Wear OS store screenshots from the Wear emulator (AVD «Tibyan_Wear», 454x454).

Needs the debug wear APK installed (its debug-only SampleData receiver writes the sample
phone data; this script passes the values as extras, which needs the receiver to read
them; that tweak stays local and never ships). Content is masked to the round display
(black outside). Output: docs/brand/store/screenshots/wear_os/{ar,en}/<WxH>/NN_<slug>.png
"""
import os, subprocess, time
from PIL import Image, ImageDraw
from common import STORE

ADB = os.path.expanduser('~/Library/Android/sdk/platform-tools/adb')
PKG = 'app.tibyan.tibyan'
ACT = f'{PKG}/app.tibyan.tibyan.wear.TasbihActivity'
OUT = os.path.join(STORE, 'screenshots', 'wear_os')
SIZES = [454, 384]

DATA = {
    'ar': dict(title='ختمة رمضان', progress='38', portion='الجزء ١٢', surah='هود', from_='222', to='241',
               dhikr='سبحان الله', texts='سبحان الله|الحمد لله|الله أكبر'),
    'en': dict(title='Ramadan khatma', progress='38', portion='Juz 12', surah='Hud', from_='222', to='241',
               dhikr='SubhanAllah', texts='SubhanAllah|Alhamdulillah|Allahu Akbar'),
}
# slug, what, session, stages
SHOTS = [('01_wird', 'wird', 0, ''), ('02_misbaha', 'misbaha', 21, ''),
         ('03_misbaha_staged', 'misbaha', 47, '33,33,34'), ('04_tile', 'tile', 0, '')]


def adb(*a, check=True):
    return subprocess.run([ADB, *a], check=check, capture_output=True).stdout


def seed(lang, session, stages):
    d = DATA[lang]
    ex = []
    for k, v in [('title', d['title']), ('progress', d['progress']), ('portion', d['portion']),
                 ('surah', d['surah']), ('from', d['from_']), ('to', d['to']), ('dhikr', d['dhikr']),
                 ('target', '33'), ('stages', stages), ('texts', d['texts'] if stages else '')]:
        ex += ['--es', k, "'" + v.replace("'", "") + "'"]
    adb('shell', ' '.join(['am', 'broadcast', '-f', '32', '-n', f'{PKG}/app.tibyan.tibyan.wear.SampleData',
                           *ex, '--ei', 'session', str(session)]))


def shot(path):
    raw = adb('exec-out', 'screencap', '-p')
    tmp = os.path.join(OUT, '_raw.png')
    os.makedirs(OUT, exist_ok=True)
    open(tmp, 'wb').write(raw)
    im = Image.open(tmp).convert('RGB')
    os.remove(tmp)
    n = im.width
    m = Image.new('L', (n * 4, n * 4), 0)
    ImageDraw.Draw(m).ellipse((0, 0, n * 4 - 1, n * 4 - 1), fill=255)
    m = m.resize((n, n), Image.LANCZOS)
    out = Image.new('RGB', im.size, 'black')
    out.paste(im, (0, 0), m)
    for s in SIZES:
        p = path.replace('{S}', f'{s}x{s}')
        os.makedirs(os.path.dirname(p), exist_ok=True)
        (out if s == n else out.resize((s, s), Image.LANCZOS)).save(p)
        print(p)


def main():
    adb('shell', 'settings', 'put', 'system', 'screen_off_timeout', '1800000')
    adb('shell', 'am', 'broadcast', '-a', 'com.google.android.wearable.app.DEBUG_SURFACE',
        '--es', 'operation', 'add-tile', '--ecn', 'component',
        f'{PKG}/app.tibyan.tibyan.wear.WirdTileService', '--ei', 'index', '0', check=False)
    for lang in DATA:
        adb('shell', 'cmd', 'locale', 'set-app-locales', PKG, '--locales', lang, check=False)
        for slug, what, session, stages in SHOTS:
            adb('shell', 'am', 'force-stop', PKG)
            seed(lang, session, stages)
            time.sleep(1)
            if what == 'tile':
                adb('shell', 'input', 'keyevent', 'KEYCODE_HOME')
                time.sleep(2)
                adb('shell', 'input', 'swipe', '400', '227', '50', '227', '200')
                time.sleep(4)
            else:
                adb('shell', 'am', 'start', '-n', ACT, '--ez', 'misbaha', 'true' if what == 'misbaha' else 'false')
                time.sleep(3)
            shot(os.path.join(OUT, lang, '{S}', slug + '.png'))


if __name__ == '__main__':
    main()
