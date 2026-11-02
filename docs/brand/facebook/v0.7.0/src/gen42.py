#!/usr/bin/env python3
"""Facebook post for Tibyan 0.7.0 (build 42): feed image + 4-slide carousel. Reuses ../../src/gen.py and the update-teaser look."""
import os, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__)); OUT = os.path.dirname(HERE)
B = os.path.abspath(os.path.join(HERE, '../../..'))
sys.path.insert(0, B + '/facebook/src'); sys.path.insert(0, B + '/update-teaser/src')
from gen import HEAD, CHROME, khatam_tile, star_pts, logo  # noqa: E402
from gen_teaser import platforms, DIGITS, CREAM, GOLD, SOFT  # noqa: E402
W, H = 1080, 1350


def bg():
    return (f'<svg class="abs" width="{W}" height="{H}"><defs>{khatam_tile(104, CREAM, 0.06)}'
            '<linearGradient id="t" x1="1" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#11706A"/><stop offset="1" stop-color="#0A4F4A"/></linearGradient>'
            f'<radialGradient id="hl" cx="50%" cy="22%" r="55%"><stop offset="0" stop-color="{GOLD}" stop-opacity=".18"/><stop offset="1" stop-color="{GOLD}" stop-opacity="0"/></radialGradient></defs>'
            f'<rect width="{W}" height="{H}" fill="url(#t)"/><rect width="{W}" height="{H}" fill="url(#kh)"/><rect width="{W}" height="{H}" fill="url(#hl)"/>'
            + ''.join(f'<polygon points="{star_pts(x, y, r)}" fill="{GOLD}" fill-opacity="{o}"/>'
                      for x, y, r, o in [(120, 120, 14, .6), (W - 130, 200, 10, .5), (W - 90, 90, 7, .4), (90, 300, 7, .35)])
            + '</svg>')


def star(sz, c=GOLD):
    return f'<svg width="{sz}" height="{sz}" viewBox="0 0 40 40"><polygon points="{star_pts(20, 20, 18)}" fill="{c}"/></svg>'


def chip(t, sub=None, fs=30):
    s = f'<div style="font-size:{fs - 8}px;color:{SOFT};font-weight:400;margin-top:4px">{sub}</div>' if sub else ''
    return (f'<div style="display:flex;align-items:center;gap:16px;padding:26px 26px;border:1.5px solid rgba(217,178,102,.45);'
            f'border-radius:22px;background:rgba(10,36,34,.28)">{star(30)}<div><div style="font-family:Changa;font-weight:600;'
            f'font-size:{fs}px;color:{CREAM};line-height:1.25">{t}</div>{s}</div></div>')


def head(kicker, title, top=210, fs=84):
    return (logo('F6F1E8', (W - 140) / 2, 56, 140)
            + f'<div class="abs" style="left:60px;right:60px;top:{top}px;text-align:center;font-family:Changa;color:{CREAM}">'
            f'<div style="font-weight:600;font-size:32px;color:{GOLD}">{kicker}</div>'
            f'<div style="font-weight:700;font-size:{fs}px;line-height:1.15;margin-top:4px">{title}</div></div>')


def footer(withplat=True, line='حمّلوه الآن مجانًا'):
    fy = H - 140; s = ''
    if withplat:
        s += platforms(fy - 150, 1.0)
    s += (f'<div class="abs" style="left:80px;right:80px;top:{fy}px;height:1px;background:rgba(217,178,102,.35)"></div>'
          f'<div class="abs" style="left:80px;right:80px;top:{fy + 22}px;text-align:center"><div style="font-family:Plex;font-size:24px;color:{SOFT}">{line}</div>'
          f'<div dir="ltr" style="margin-top:6px;font-family:Plex;font-weight:700;font-size:42px;color:{CREAM}">altibyan<span style="color:{GOLD}">.app</span></div></div>')
    return s


def grid(items, top, cols=2, fs=30, gap=18):
    return (f'<div class="abs" style="left:60px;right:60px;top:{top}px;display:grid;grid-template-columns:repeat({cols},1fr);gap:{gap}px">'
            + ''.join(chip(*i, fs=fs) if isinstance(i, tuple) else chip(i, fs=fs) for i in items) + '</div>')


def main():
    f = ['أداء أسرع وتقليب أسلس', 'فواصل بشكلك ولونك', 'أشرطة في الهامش', 'ختمة جماعية برابط',
         'تطبيقات الساعة الذكية', 'تطبيقات لسطح المكتب', 'وضع ليلي وأسود خالص', 'تذكير الكهف يوم الجمعة']
    return bg() + head('تبيان <span style="font-family:TDig">0.7.0</span> — تحديث جديد', 'أهلًا بالجديد في تبيان') + grid(f, 470, fs=32, gap=24) + footer()


def slide(kicker, title, items, n):
    return bg() + head(kicker, title, fs=72) + grid(items, 430, cols=1, fs=34, gap=20) + footer(False, f'تبيان <span style="font-family:TDig">0.7.0</span> · {n} من 4')


S = [('الفواصل', 'فواصلك كما تحب', [('شكل وخامة ولون لكل فاصل', 'اختر لكل فاصل هيئته الخاصة'), ('حتى ثمانية فواصل', 'ونعرض عليك النقل أو الحذف عند التاسع'),
                                    ('أشرطة في الهامش', 'بجوار النص، ولا تغطي سطرًا أبدًا'), ('إدارتها من الفهرس', 'نقل وتسمية وترتيب وحذف مع التراجع')]),
     ('معًا وفي كل مكان', 'ختمة جماعية وأجهزة أكثر', [('ختمة جماعية برابط', 'يختار كلٌّ جزءه دون حساب'), ('Apple Watch و Wear OS', 'مع مضاعفات واجهة الساعة'),
                                                      ('تطبيقا Windows و Linux', 'تبيان على سطح المكتب'), ('المزامنة بين أجهزتك', 'عبر iCloud Drive و Google Drive')]),
     ('راحة القراءة', 'قراءة أهدأ ومتابعة أيسر', [('أداء أسرع وتقليب أسلس', None), ('وضع ليلي وأسود خالص', 'الأسود يناسب شاشات OLED'),
                                                  ('وضع الحفظ والتقرير الأسبوعي', None), ('مشاركة الآيات مقطعًا مرئيًا', 'مع التلاوة، دون موسيقى')]),
     ('في متناول يدك', 'تذكير واختصارات', [('تذكير سورة الكهف', 'كل جمعة، ويمكن إيقافه'), ('اختصارات Siri و Google Assistant', 'افتح المصحف أو الورد بصوتك'),
                                          ('التلاوة على شاشة القفل', 'نشاط مباشر وجزيرة ديناميكية على iPhone')])]


def render(name, body):
    html = (HEAD.replace('<style>', '<base href="file://' + B + '/facebook/src/"><style>', 1).replace('%W%', str(W)).replace('%H%', str(H))
            .replace('</style>', DIGITS + '</style>') + body + '</body></html>')
    p = os.path.join(HERE, name + '.html'); open(p, 'w').write(html); out = os.path.join(OUT, name + '.png')
    subprocess.run([CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--allow-file-access-from-files', '--force-device-scale-factor=1',
                    f'--window-size={W},{H}', '--virtual-time-budget=3000', f'--screenshot={out}', 'file://' + p], capture_output=True)
    print(out, os.path.exists(out))


if __name__ == '__main__':
    render('post_image', main())
    for i, (k, t, it) in enumerate(S, 1):
        render(f'carousel_{i}', slide(k, t, it, i))
