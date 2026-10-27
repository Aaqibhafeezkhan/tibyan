#!/usr/bin/env python3
"""Real Apple Watch store screenshots from the watchOS simulator («ليل هندسي» design).

Usage: capture_apple_watch.py <path to TibyanWatch.app built for watchsimulator>

The watch app opens on the wird page. For the misbaha shots the app must be built with a
local, uncommitted tweak that reads the start tab from the SHOT_TAB environment variable
(TabView(selection:) with tags 0/1); nothing of it ships. Sample data is written straight
into the simulator app's preferences (the same keys the phone sends over WatchConnectivity).
Output: docs/brand/store/screenshots/apple_watch/{ar,en}/<WxH>/NN_<slug>.png (RGB, no alpha).
"""
import datetime, os, plistlib, subprocess, sys, time
from PIL import Image
from common import STORE

BUNDLE = 'app.tibyan.tibyan.watchkitapp'
OUT = os.path.join(STORE, 'screenshots', 'apple_watch')
# Apple size -> simulator device type (None: resized from the largest capture)
DEVICES = [
    ((422, 514), 'Apple-Watch-Ultra-3-49mm'),
    ((410, 502), 'Apple-Watch-Ultra-2-49mm'),
    ((416, 496), 'Apple-Watch-Series-11-46mm'),
    ((396, 484), 'Apple-Watch-Series-9-45mm'),
    ((368, 448), 'Apple-Watch-SE-3-44mm'),
    ((312, 390), None),
]
TODAY = datetime.date.today().isoformat()

DATA = {
    'ar': dict(title='ختمة رمضان', idle='', portion='الجزء ١٢', ref='هود ٦ – يوسف ٥٢', progress='38',
               dhikr='سبحان الله', staged='الحمد لله', lang='ar', locale='ar_SA@numbers=arab'),
    'en': dict(title='Ramadan khatma', idle='', portion='Juz 12', ref='Hud 6 – Yusuf 52', progress='38',
               dhikr='SubhanAllah', staged='Alhamdulillah', lang='en', locale='en_US'),
}
# (file slug, tab, dhikr key, session count, target, stages)
SHOTS = [
    ('01_wird', 0, 'dhikr', 0, 33, ''),
    ('02_misbaha', 1, 'dhikr', 21, 33, ''),
    ('03_misbaha_staged', 1, 'staged', 47, 33, '33,33,34'),
]


def sh(*a, check=True):
    return subprocess.run(a, check=check, capture_output=True, text=True).stdout.strip()


def device(dtype):
    name = f'Tibyan-Shot-{dtype}'
    for line in sh('xcrun', 'simctl', 'list', 'devices').splitlines():
        if name in line:
            return line.split('(')[1].split(')')[0]
    rt = [l.split(' - ')[-1] for l in sh('xcrun', 'simctl', 'list', 'runtimes').splitlines() if 'watchOS' in l][-1]
    return sh('xcrun', 'simctl', 'create', name, f'com.apple.CoreSimulator.SimDeviceType.{dtype}', rt)


def shoot(udid, lang, shot, out):
    d = DATA[lang]
    slug, tab, dk, session, target, stages = shot
    sh('xcrun', 'simctl', 'terminate', udid, BUNDLE, check=False)
    cont = sh('xcrun', 'simctl', 'get_app_container', udid, BUNDLE, 'data')
    ctx = {'title': d['title'], 'idle': d['idle'], 'progress': d['progress'], 'days': TODAY,
           f'portion_{TODAY}': d['portion'], f'ref_{TODAY}': d['ref'],
           'tasbih_dhikr': d[dk], 'tasbih_target': str(target), 'tasbih_stages': stages}
    prefs = os.path.join(cont, 'Library/Preferences')
    os.makedirs(prefs, exist_ok=True)
    tmp = os.path.join(os.path.dirname(OUT), '_prefs.plist')
    with open(tmp, 'wb') as fh:
        plistlib.dump({'context': ctx, 'session': session}, fh)
    # Through cfprefsd (it caches; writing the plist file directly is not seen).
    for dom in ('group.app.tibyan.tibyan', BUNDLE):
        sh('xcrun', 'simctl', 'spawn', udid, 'defaults', 'import', os.path.join(prefs, dom), tmp)
    os.remove(tmp)
    env = dict(os.environ, SIMCTL_CHILD_SHOT_TAB=str(tab))
    subprocess.run(['xcrun', 'simctl', 'launch', udid, BUNDLE, '-AppleLanguages', f'({d["lang"]})',
                    '-AppleLocale', d['locale']], check=True, env=env, capture_output=True)
    time.sleep(4)
    sh('xcrun', 'simctl', 'status_bar', udid, 'override', '--time', '9:41', check=False)
    time.sleep(1)
    raw = out + '.raw.png'
    sh('xcrun', 'simctl', 'io', udid, 'screenshot', raw)
    Image.open(raw).convert('RGB').save(out)
    os.remove(raw)


def main(app):
    sh('xcrun', 'simctl', 'shutdown', 'all', check=False)
    largest = {}
    for (w, h), dtype in DEVICES:
        if dtype is None:
            continue
        udid = device(dtype)
        sh('xcrun', 'simctl', 'boot', udid, check=False)
        sh('xcrun', 'simctl', 'bootstatus', udid, '-b')
        sh('xcrun', 'simctl', 'status_bar', udid, 'override', '--time', '9:41', check=False)
        sh('xcrun', 'simctl', 'install', udid, app)
        time.sleep(3)
        for lang in DATA:
            for shot in SHOTS:
                out = os.path.join(OUT, lang, f'{w}x{h}', shot[0] + '.png')
                os.makedirs(os.path.dirname(out), exist_ok=True)
                shoot(udid, lang, shot, out)
                im = Image.open(out)
                if im.size != (w, h):  # device not at the expected size: fit it
                    im.resize((w, h), Image.LANCZOS).save(out)
                print(out, im.size)
        sh('xcrun', 'simctl', 'shutdown', udid, check=False)
        largest.setdefault('dir', (w, h))
    W, H = largest['dir']
    for (w, h), dtype in DEVICES:
        if dtype is not None:
            continue
        for lang in DATA:
            for shot in SHOTS:
                src = Image.open(os.path.join(OUT, lang, f'{W}x{H}', shot[0] + '.png'))
                s = max(w / W, h / H)
                im = src.resize((round(W * s), round(H * s)), Image.LANCZOS)
                l, t = (im.width - w) // 2, (im.height - h) // 2
                out = os.path.join(OUT, lang, f'{w}x{h}', shot[0] + '.png')
                os.makedirs(os.path.dirname(out), exist_ok=True)
                im.crop((l, t, l + w, t + h)).convert('RGB').save(out)


if __name__ == '__main__':
    main(sys.argv[1])
