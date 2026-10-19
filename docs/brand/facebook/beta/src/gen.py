#!/usr/bin/env python3
"""Tibyan beta-testers Facebook post (4:5 + 1:1) and Reel (9:16) — cover C style."""
import math, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.dirname(HERE)
FONTS = os.path.abspath(os.path.join(HERE, '../../../../../assets/fonts/ofl'))
CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
JOIN = 'altibyan.app/beta'

TEAL, CREAM, GOLD, MINT = '#0F6660', '#F6F1E8', '#D9B266', '#CFE3DF'


def head(w, h):
    return f"""<!doctype html><html dir="rtl" lang="ar"><head><meta charset="utf-8"><style>
@font-face{{font-family:Plex;src:url('file://{FONTS}/ibmplexsansarabic/IBMPlexSansArabic-Regular.ttf');font-weight:400}}
@font-face{{font-family:Plex;src:url('file://{FONTS}/ibmplexsansarabic/IBMPlexSansArabic-Medium.ttf');font-weight:500}}
@font-face{{font-family:Plex;src:url('file://{FONTS}/ibmplexsansarabic/IBMPlexSansArabic-SemiBold.ttf');font-weight:600}}
@font-face{{font-family:Plex;src:url('file://{FONTS}/ibmplexsansarabic/IBMPlexSansArabic-Bold.ttf');font-weight:700}}
@font-face{{font-family:Changa;src:url('file://{FONTS}/changa/Changa[wght].ttf')}}
*{{margin:0;padding:0;box-sizing:border-box}}
html,body{{width:{w}px;height:{h}px;overflow:hidden;background:{TEAL}}}
body{{position:relative;font-family:Changa,Plex,sans-serif;color:{CREAM};-webkit-font-smoothing:antialiased}}
.abs{{position:absolute}}
.n{{font-family:Plex!important;font-weight:600}}
.logo{{position:absolute;background:url(logo_F6F1E8.svg) center/contain no-repeat}}
.ltr{{direction:ltr;unicode-bidi:isolate;font-family:Plex;font-weight:500}}
.badge{{display:inline-flex;align-items:center;justify-content:center;width:46px;height:46px;border-radius:50%;
 background:{GOLD};color:#0A3F3B;font-size:25px;flex:none}}
</style></head><body>"""


# digits always in IBM Plex (Changa ٢/٣ read badly)
WRAP_JS = r"""<script>
(function(){const w=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT);const ns=[];
while(w.nextNode())ns.push(w.currentNode);
for(const n of ns){if(!/[0-9٠-٩]/.test(n.nodeValue)||n.parentNode.closest('script,.n,svg'))continue;
const f=document.createDocumentFragment();n.nodeValue.split(/([0-9٠-٩]+)/).forEach((p,i)=>{
if(!p)return;if(i%2){const s=document.createElement('span');s.className='n';s.textContent=p;f.appendChild(s)}
else f.appendChild(document.createTextNode(p))});n.parentNode.replaceChild(f,n)}})();
</script>"""


def star_pts(cx, cy, r, inner=0.7654):
    pts = []
    for i in range(16):
        a = math.pi / 8 * i - math.pi / 2
        rr = r if i % 2 == 0 else r * inner
        pts.append(f"{cx + rr * math.cos(a):.2f},{cy + rr * math.sin(a):.2f}")
    return ' '.join(pts)


def bg(w, h, star=None):
    s = 104; r = s * .36
    corners = ''.join(f'<polygon points="{star_pts(x, y, r)}"/>' for x, y in [(0, 0), (s, 0), (0, s), (s, s)])
    big = ''
    if star:
        cx, cy, R = star
        big = (f'<polygon points="{star_pts(cx, cy, R, .7654)}" fill="{CREAM}" fill-opacity=".045" stroke="{GOLD}" stroke-opacity=".5" stroke-width="1.4"/>'
               f'<polygon points="{star_pts(cx, cy, R*.94, .7654)}" fill="none" stroke="{GOLD}" stroke-opacity=".22" stroke-width="1"/>')
    return (f'<svg class="abs" style="left:0;top:0" width="{w}" height="{h}"><defs>'
            f'<pattern id="kh" width="{s}" height="{s}" patternUnits="userSpaceOnUse"><g fill="none" stroke="{CREAM}" stroke-opacity=".06" stroke-width="1.2">'
            f'<polygon points="{star_pts(s/2, s/2, r)}"/>{corners}<circle cx="{s/2}" cy="{s/2}" r="{r*.42:.2f}"/></g></pattern>'
            f'<linearGradient id="t" x1="1" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#11706A"/><stop offset="1" stop-color="#0A4F4A"/></linearGradient>'
            f'<radialGradient id="hl" cx="70%" cy="25%" r="55%"><stop offset="0" stop-color="#55BDB2" stop-opacity=".22"/><stop offset="1" stop-color="#55BDB2" stop-opacity="0"/></radialGradient></defs>'
            f'<rect width="{w}" height="{h}" fill="url(#t)"/><rect width="{w}" height="{h}" fill="url(#kh)"/><rect width="{w}" height="{h}" fill="url(#hl)"/>{big}</svg>')


def logo(x, y, w):
    return f'<div class="logo" style="left:{x}px;top:{y}px;width:{w}px;height:{w*1019/1392:.1f}px"></div>'


ICON = {
    'android': '<path d="M7 9h10v8a1.5 1.5 0 0 1-1.5 1.5h-7A1.5 1.5 0 0 1 7 17z M7 8.2a5 5 0 0 1 10 0z M8.5 4.5l1.2 1.8 M15.5 4.5l-1.2 1.8 M4.8 10v5 M19.2 10v5 M10 18.5v2.5 M14 18.5v2.5"/>',
    'apple': '<path d="M16.4 12.6c0-2.4 2-3.5 2-3.6-1.1-1.6-2.8-1.8-3.4-1.8-1.4-.1-2.8.9-3.5.9s-1.9-.9-3.1-.8C6.8 7.3 5.3 8.2 4.5 9.6c-1.7 2.9-.4 7.2 1.2 9.6.8 1.1 1.7 2.4 3 2.4 1.2-.1 1.6-.8 3.1-.8s1.8.8 3.1.8c1.3 0 2.1-1.2 2.9-2.3.9-1.3 1.3-2.6 1.3-2.7-.1 0-2.6-1-2.7-4z M14.2 5.4c.6-.8 1.1-1.9 1-3-1 .1-2.1.7-2.8 1.5-.6.7-1.2 1.8-1 2.9 1.1.1 2.1-.6 2.8-1.4z"/>',
    'flag': '<path d="M5 21V4 M5 4h11l-2 4 2 4H5"/>',
    'link': '<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1 M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>',
}


def icon(name, color, size, sw=1.7):
    fill = color if name == 'apple' else 'none'
    stroke = 'none' if name == 'apple' else color
    return (f'<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" '
            f'stroke-linecap="round" stroke-linejoin="round" style="flex:none">{ICON[name]}</svg>')


def phone(x, y, w, inner, frame='#0A2422', extra=''):
    h = w * 2.06; r = w * .15; bz = w * .035
    return (f'<div class="abs phone" style="left:{x}px;top:{y}px;width:{w}px;height:{h:.0f}px;border-radius:{r:.0f}px;background:{frame};padding:{bz:.1f}px;'
            f'box-shadow:0 40px 80px -24px rgba(5,25,23,.6),0 10px 22px -8px rgba(5,25,23,.4);{extra}">'
            f'<div class="scr" style="position:relative;width:100%;height:100%;border-radius:{r-bz:.0f}px;overflow:hidden;background:#fff">{inner}</div></div>')


def img_screen(src, crop=0):
    return f'<div style="position:absolute;inset:0;background:url({src}) center -{crop}px/100% auto no-repeat"></div>'


# ---------------------------------------------------------------- post
def steps_card(title, ico, items, w):
    rows = ''.join(
        f'<div style="display:flex;gap:18px;align-items:flex-start;margin-top:20px"><span class="badge">{"١٢٣"[i]}</span>'
        f'<div style="font-size:27px;line-height:1.45;font-weight:500;padding-top:2px">{t}</div></div>'
        for i, t in enumerate(items))
    return (f'<div style="width:{w}px;background:rgba(246,241,232,.07);border:1.3px solid rgba(217,178,102,.45);border-radius:28px;padding:28px 32px 32px">'
            f'<div style="display:flex;align-items:center;gap:14px;color:{GOLD};font-size:31px;font-weight:600">{icon(ico, GOLD, 36)}<span>{title}</span></div>'
            f'{rows}</div>')


ANDROID = ['افتح رابط الاختبار من هاتفك بنفس حساب <span class="ltr">Google</span>',
           'اضغط «أصبح مختبِرًا»',
           'نزّل «تبيان» من <span class="ltr">Google Play</span>']
APPLE = ['ثبّت تطبيق <span class="ltr">TestFlight</span> من <span class="ltr">App Store</span>',
         'افتح رابط الدعوة واضغط <span class="ltr">Accept</span>',
         'ثم <span class="ltr">Install</span> — وجاهز']


def cta(fs=30):
    return (f'<div style="display:inline-flex;align-items:center;gap:16px;background:{GOLD};color:#0A3F3B;border-radius:999px;padding:16px 34px;font-size:{fs}px;font-weight:600">'
            f'{icon("link", "#0A3F3B", fs+4, 2)}<span>الروابط كلها في</span><span class="ltr" style="font-weight:700">{JOIN}</span></div>')


def post():
    W, H = 1080, 1350
    body = bg(W, H, star=(860, 250, 330))
    body += logo(W - 64 - 190, 64, 190)
    body += phone(74, 120, 250, img_screen('mushaf.jpg'), extra='transform:rotate(-4deg)')
    body += (f'<div class="abs" style="right:64px;top:250px;width:640px">'
             f'<div style="font-size:24px;color:{GOLD};font-weight:500;letter-spacing:.3px">النسخة التجريبية مفتوحة الآن</div>'
             f'<div style="font-size:66px;font-weight:700;line-height:1.18;margin-top:10px">كن من أوائل<br>مختبري تبيان</div>'
             f'<div style="font-size:28px;color:{MINT};margin-top:16px;line-height:1.5">مصحف مجاني وغير ربحي، بلا إعلانات.<br>جرّبه قبل الجميع، وساعدنا نُتقنه.</div></div>')
    body += f'<div class="abs" style="left:64px;right:64px;top:700px;display:flex;gap:28px">{steps_card("أندرويد", "android", ANDROID, 462)}{steps_card("آيفون · آيباد · ماك", "apple", APPLE, 462)}</div>'
    body += (f'<div class="abs" style="left:0;right:0;top:1150px;text-align:center">{cta()}'
             f'<div style="margin-top:22px;font-size:24px;color:{MINT}">اضغط زر «انضم لاختبار النسخة التجريبية» · ملاحظاتك عبر «الإبلاغ عن مشكلة» داخل التطبيق</div></div>')
    return W, H, body


def square():
    W, H = 1080, 1080
    body = bg(W, H, star=(540, 430, 380))
    body += logo((W - 170) / 2, 60, 170)
    body += (f'<div class="abs" style="left:0;right:0;top:200px;text-align:center">'
             f'<div style="font-size:24px;color:{GOLD};font-weight:500">النسخة التجريبية مفتوحة الآن</div>'
             f'<div style="font-size:64px;font-weight:700;line-height:1.2;margin-top:6px">كن من أوائل مختبري تبيان</div>'
             f'<div style="font-size:27px;color:{MINT};margin-top:10px">مصحف مجاني وغير ربحي · أندرويد وآيفون وآيباد وماك</div></div>')
    body += phone(300, 420, 200, img_screen('home.jpg', 10), extra='transform:rotate(-5deg)')
    body += phone(580, 420, 200, img_screen('mushaf.jpg'), extra='transform:rotate(5deg)')
    chips = ''.join(
        f'<div style="display:flex;align-items:center;gap:12px;font-size:25px;font-weight:500">{icon(i, GOLD, 30)}<span>{t}</span></div>'
        for i, t in [('android', 'أندرويد: رابط الاختبار ← «أصبح مختبِرًا»'), ('apple', 'آبل: <span class="ltr">TestFlight</span> ← <span class="ltr">Accept</span> ← <span class="ltr">Install</span>')])
    body += f'<div class="abs" style="left:0;right:0;top:868px;display:flex;justify-content:center;gap:40px">{chips}</div>'
    body += f'<div class="abs" style="left:0;right:0;top:944px;text-align:center">{cta(28)}</div>'
    return W, H, body


# ---------------------------------------------------------------- reel
PX, PY, PW = 300, 360, 480        # phone geometry in reel (screen ≈ 446 × 955)
SW = PW - 2 * PW * .035

def ui_btn(txt, bgc, fg, cls='', extra=''):
    return f'<div class="btn {cls}" style="background:{bgc};color:{fg};border-radius:22px;padding:13px 0;text-align:center;font-family:Plex;font-weight:600;font-size:19px;{extra}">{txt}</div>'


def app_icon(size=74):
    return f'<div style="width:{size}px;height:{size}px;border-radius:{size*.23:.0f}px;background:{TEAL} url(logo_F6F1E8.svg) center/66% no-repeat;flex:none"></div>'


def tf_icon(size=74):
    return (f'<div style="width:{size}px;height:{size}px;border-radius:{size*.23:.0f}px;background:linear-gradient(#5ab0ff,#1f6fe5);flex:none;display:flex;align-items:center;justify-content:center">'
            f'<svg width="{size*.6}" height="{size*.6}" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="1.8" stroke-linecap="round"><circle cx="12" cy="12" r="3"/><path d="M12 3v6 M12 15v6 M4.2 7.5l5.2 3 M14.6 13.5l5.2 3 M4.2 16.5l5.2-3 M14.6 10.5l5.2-3"/></svg></div>')


def bar(title, dark='#202124'):
    return (f'<div style="height:64px;padding:26px 22px 0;font-family:Plex;font-size:14px;color:{dark};display:flex;justify-content:space-between;direction:ltr"><span class="n">9:41</span><span>●●● ▮</span></div>'
            f'<div style="padding:6px 18px 10px"><div style="background:#eef0f1;border-radius:18px;padding:9px 16px;font-family:Plex;font-size:15px;color:#3c4043;direction:ltr;text-align:center">🔒 {title}</div></div>')


def screens():
    s = {}
    # 1 — join page on the website
    s['web'] = (bar(JOIN) +
        f'<div style="background:{TEAL};margin:0 14px;border-radius:24px;padding:34px 24px 30px;text-align:center;color:{CREAM};position:relative;overflow:hidden">'
        f'<div style="width:150px;height:110px;margin:0 auto;background:url(logo_F6F1E8.svg) center/contain no-repeat"></div>'
        f'<div style="font-size:30px;font-weight:700;margin-top:14px">النسخة التجريبية</div>'
        f'<div style="font-size:17px;color:{MINT};margin-top:6px;line-height:1.5">مصحف مجاني وغير ربحي.<br>جرّبه وساعدنا نُحسّنه.</div></div>'
        f'<div style="padding:26px 30px 0">{ui_btn("انضم لاختبار النسخة التجريبية", GOLD, "#0A3F3B", "b-web")}'
        f'<div style="display:flex;gap:12px;margin-top:22px;opacity:.9">'
        f'<div style="flex:1;border:1px solid #dadce0;border-radius:16px;padding:12px;font-family:Plex;font-size:14px;color:#3c4043;text-align:center">Android</div>'
        f'<div style="flex:1;border:1px solid #dadce0;border-radius:16px;padding:12px;font-family:Plex;font-size:14px;color:#3c4043;text-align:center">iPhone · iPad · Mac</div></div>'
        f'<div style="height:12px;background:#eceae4;border-radius:6px;margin-top:30px;width:80%"></div><div style="height:12px;background:#eceae4;border-radius:6px;margin-top:12px;width:60%"></div></div>')
    # 2 — Play internal testing opt-in page
    s['optin'] = (bar('play.google.com/apps/internaltest') +
        f'<div style="padding:26px 30px;color:#202124;font-family:Plex">'
        f'<div style="display:flex;gap:16px;align-items:center">{app_icon(70)}<div><div style="font-size:22px;font-weight:600">تبيان</div><div style="font-size:14px;color:#5f6368">اختبار داخلي</div></div></div>'
        f'<div style="font-size:22px;font-weight:600;margin-top:34px">انضم إلى الاختبار</div>'
        f'<div style="font-size:15px;color:#5f6368;margin-top:10px;line-height:1.7">سجّل الدخول بحساب Google نفسه الذي تستخدمه على هاتفك، ثم اقبل الدعوة.</div>'
        f'<div style="margin-top:30px" class="optin-btn">{ui_btn("أصبح مختبِرًا", "#01875f", "#fff", "b-optin")}</div>'
        f'<div class="optin-ok" style="margin-top:30px;opacity:0;border-radius:18px;background:#e6f4ea;color:#137333;padding:16px;font-size:16px;font-weight:600;text-align:center">✓ أنت الآن مختبِر</div>'
        f'<div style="margin-top:18px;font-size:15px;color:#01875f;font-weight:600;text-align:center" class="optin-ok">التنزيل من Google Play ←</div></div>')
    # 3 — Play store listing
    s['play'] = (bar('Google Play') +
        f'<div style="padding:20px 30px;color:#202124;font-family:Plex">'
        f'<div style="display:flex;gap:18px;align-items:center">{app_icon(86)}<div><div style="font-size:24px;font-weight:600">تبيان (إصدار تجريبي)</div><div style="font-size:14px;color:#01875f;margin-top:4px">برنامج الاختبار</div></div></div>'
        f'<div style="margin-top:28px;position:relative">{ui_btn("تثبيت", "#01875f", "#fff", "b-play")}'
        f'<div class="prog" style="position:absolute;inset:0;border-radius:22px;background:#e6f4ea;opacity:0;overflow:hidden"><div class="progfill" style="height:100%;width:0;background:#01875f;opacity:.35"></div>'
        f'<div style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center;font-weight:600;color:#137333;font-size:18px" class="progtxt">جارٍ التنزيل…</div></div></div>'
        f'<div style="display:flex;gap:10px;margin-top:26px;height:300px">'
        f'<div style="flex:1;border-radius:14px;background:url(home.jpg) center top/cover"></div><div style="flex:1;border-radius:14px;background:url(mushaf.jpg) center top/cover"></div></div></div>')
    # 4 — App Store: TestFlight
    s['tf'] = (bar('App Store', '#111') +
        f'<div style="padding:20px 30px;color:#111;font-family:Plex">'
        f'<div style="display:flex;gap:18px;align-items:center">{tf_icon(92)}<div style="flex:1"><div style="font-size:24px;font-weight:600;direction:ltr;text-align:right">TestFlight</div><div style="font-size:14px;color:#6e6e73">Apple</div>'
        f'<div style="margin-top:10px;width:110px" class="tfget">{ui_btn("تحميل", "#0a84ff", "#fff", "b-tf", "padding:8px 0;font-size:16px")}</div></div></div>'
        f'<div style="margin-top:34px;font-size:15px;color:#6e6e73;line-height:1.8">تطبيق Apple الرسمي لتجربة النسخ التجريبية على iPhone وiPad وMac.</div>'
        f'<div class="tfok" style="margin-top:26px;opacity:0;border-radius:16px;background:#eaf3ff;color:#0a60d0;padding:14px;text-align:center;font-weight:600">✓ تم التثبيت</div></div>')
    # 5 — TestFlight invite: Accept → Install
    s['inv'] = (bar('testflight.apple.com/join', '#111') +
        f'<div style="padding:30px 30px;color:#111;font-family:Plex;text-align:center">'
        f'<div style="display:flex;justify-content:center">{app_icon(104)}</div>'
        f'<div style="font-size:26px;font-weight:600;margin-top:18px">تبيان</div>'
        f'<div style="font-size:15px;color:#6e6e73;margin-top:6px">دعوة لاختبار النسخة التجريبية</div>'
        f'<div style="margin-top:34px;position:relative;height:50px">'
        f'<div class="inv-a" style="position:absolute;inset:0">{ui_btn("Accept", "#0a84ff", "#fff", "b-acc")}</div>'
        f'<div class="inv-i" style="position:absolute;inset:0;opacity:0">{ui_btn("Install", "#0a84ff", "#fff", "b-ins")}</div>'
        f'<div class="inv-o" style="position:absolute;inset:0;opacity:0">{ui_btn("Open", "#34c759", "#fff")}</div></div></div>')
    # 6 — app + report sheet
    s['app'] = (img_screen('mushaf.jpg') +
        f'<div class="shade" style="position:absolute;inset:0;background:rgba(0,0,0,.35);opacity:0"></div>'
        f'<div class="sheet" style="position:absolute;left:0;right:0;bottom:0;background:{CREAM};border-radius:26px 26px 0 0;padding:16px 24px 40px;transform:translateY(100%);color:#16302d">'
        f'<div style="width:46px;height:5px;border-radius:3px;background:#c9c2b4;margin:0 auto 18px"></div>'
        + ''.join(f'<div style="padding:15px 6px;border-bottom:1px solid #e3dccd;font-size:19px;color:#5b6b68">{t}</div>' for t in ['الإعدادات', 'عن التطبيق']) +
        f'<div class="rep" style="padding:15px 12px;font-size:20px;font-weight:600;display:flex;gap:12px;align-items:center;border-radius:14px;margin-top:6px">{icon("flag", TEAL, 24, 2)}<span>الإبلاغ عن مشكلة</span></div></div>')
    return s


SCENES = [  # id, start, end, top label, caption
    ('hook', 0.0, 3.2, '', 'تبيان مصحف مجاني وغير ربحي — ونحتاج مساعدتك'),
    ('web', 3.2, 6.6, 'الخطوة ١ · الموقع', 'ادخل altibyan.app/beta واضغط «انضم لاختبار النسخة التجريبية»'),
    ('optin', 6.6, 10.6, 'أندرويد · الخطوة ٢', 'افتح رابط الاختبار بنفس حساب Google ← «أصبح مختبِرًا»'),
    ('play', 10.6, 13.8, 'أندرويد · الخطوة ٣', 'ثم نزّل «تبيان» من Google Play'),
    ('tf', 13.8, 17.0, 'آيفون · آيباد · ماك · الخطوة ٢', 'ثبّت تطبيق TestFlight من App Store'),
    ('inv', 17.0, 21.2, 'آيفون · آيباد · ماك · الخطوة ٣', 'افتح رابط الدعوة ← Accept ← Install'),
    ('app', 21.2, 24.8, 'شاركنا ملاحظتك', 'لاحظت شيئًا؟ «الإبلاغ عن مشكلة» من داخل التطبيق'),
    ('end', 24.8, 30.0, '', 'الروابط كلها في altibyan.app/beta'),
]
# taps: scene, time, selector of button inside screen
TAPS = [(4.9, '.b-web'), (8.2, '.b-optin'), (11.7, '.b-play'), (15.0, '.b-tf'), (18.4, '.b-acc'), (19.9, '.b-ins'), (22.9, '.rep')]


def reel():
    W, H = 1080, 1920
    sc = screens()
    body = bg(W, H, star=(540, 840, 470))
    # hook
    body += (f'<div id="hook" class="abs" style="left:0;right:0;top:420px;text-align:center">'
             f'<div style="width:300px;height:219px;margin:0 auto;background:url(logo_F6F1E8.svg) center/contain no-repeat"></div>'
             f'<div style="font-size:30px;color:{GOLD};font-weight:500;margin-top:40px">النسخة التجريبية مفتوحة</div>'
             f'<div style="font-size:84px;font-weight:700;line-height:1.15;margin-top:10px">كن من أوائل<br>مختبري تبيان</div>'
             f'<div style="font-size:32px;color:{MINT};margin-top:24px">أندرويد · آيفون · آيباد · ماك</div></div>')
    # end card
    body += (f'<div id="end" class="abs" style="left:0;right:0;top:380px;text-align:center;opacity:0">'
             f'<div style="width:260px;height:190px;margin:0 auto;background:url(logo_F6F1E8.svg) center/contain no-repeat"></div>'
             f'<div style="font-size:70px;font-weight:700;margin-top:44px;line-height:1.2">انضم الآن</div>'
             f'<div style="font-size:32px;color:{MINT};margin-top:14px">مجاني · غير ربحي · بلا إعلانات</div>'
             f'<div style="margin-top:56px">{cta(40)}</div>'
             f'<div style="font-size:28px;color:{MINT};margin-top:30px">ثم زر «انضم لاختبار النسخة التجريبية»</div></div>')
    # label above phone
    body += f'<div id="lbl" class="abs" style="left:0;right:0;top:262px;text-align:center"><span id="lbltxt" style="display:inline-block;padding:10px 30px;border-radius:999px;border:1.4px solid rgba(217,178,102,.6);color:{GOLD};font-size:32px;font-weight:600;background:rgba(10,63,59,.55)"></span></div>'
    inner = ''.join(f'<div class="screen" id="s-{k}" style="position:absolute;inset:0;opacity:0;background:{"#fff" if k!="web" else "#fbfaf6"}">{v}</div>' for k, v in sc.items())
    inner += '<div id="tap" style="position:absolute;width:90px;height:90px;margin:-45px 0 0 -45px;border-radius:50%;border:5px solid #D9B266;background:rgba(217,178,102,.28);opacity:0;pointer-events:none"></div>'
    inner += '<div id="dot" style="position:absolute;width:40px;height:40px;margin:-20px 0 0 -20px;border-radius:50%;background:rgba(15,40,38,.45);border:3px solid #fff;opacity:0;pointer-events:none"></div>'
    body += phone(PX, PY, PW, inner).replace('class="abs phone"', 'id="ph" class="abs phone"')
    # captions
    body += f'<div id="cap" class="abs" style="left:70px;right:70px;top:1330px;height:170px;display:flex;align-items:center;justify-content:center"><div id="captxt" style="background:rgba(6,30,28,.82);border-radius:22px;padding:18px 30px;font-size:38px;font-weight:600;line-height:1.4;text-align:center;color:#fff"></div></div>'
    scenes_js = ','.join(f"['{a}',{b},{c},'{d}','{e}']" for a, b, c, d, e in SCENES)
    taps_js = ','.join(f"[{t},'{s}']" for t, s in TAPS)
    body += WRAP_JS + f"""<script>
const SC=[{scenes_js}],TP=[{taps_js}];
const eo=x=>1-Math.pow(1-Math.min(1,Math.max(0,x)),3), cl=x=>Math.min(1,Math.max(0,x));
const $=q=>document.querySelector(q);
function wrap(t){{return t.replace(/([0-9٠-٩]+)/g,'<span class="n">$1</span>').replace(/(altibyan\\.app(?:\\/beta)?|Google Play|Google|TestFlight|App Store|Accept|Install)/g,'<span class="ltr">$1</span>')}}
function fade(t,a,b,d){{return cl((t-a)/d)*cl((b-t)/d)}}
window.render=function(t){{
  let cur=SC.find(s=>t>=s[1]&&t<s[2])||SC[SC.length-1];
  // hook / end
  $('#hook').style.opacity=fade(t,-1,3.2,.45); $('#hook').style.transform=`translateY(${{(1-eo(t/0.8))*30}}px)`;
  const e=eo((t-24.8)/0.6); $('#end').style.opacity=e; $('#end').style.transform=`translateY(${{(1-e)*30}}px)`;
  // phone: slides up after hook, leaves before end
  const pin=eo((t-2.9)/0.7), pout=cl((t-24.5)/0.4);
  $('#ph').style.transform=`translateY(${{(1-pin)*1750+pout*pout*1750}}px)`;
  // screens crossfade
  for(const s of SC){{const el=document.getElementById('s-'+s[0]);if(el)el.style.opacity=fade(t,s[1]-(s[0]=='web'?1:0),s[2]+.3,.3);}}
  // label + caption (crossfade with scene)
  const fo=fade(t,cur[1],cur[2],.3);
  if($('#lbltxt').dataset.k!=cur[0]){{$('#lbltxt').innerHTML=wrap(cur[3]);$('#captxt').innerHTML=wrap(cur[4]);$('#lbltxt').dataset.k=cur[0];}}
  $('#lbl').style.opacity=cur[3]?fo:0; $('#cap').style.opacity=cur[0]=='hook'?fade(t,.6,3.2,.3):fo;
  // taps
  $('#tap').style.opacity=0; $('#dot').style.opacity=0;
  document.querySelectorAll('.btn,.rep').forEach(b=>{{b.style.transform='';b.style.filter='';}});
  for(const [tt,sel] of TP){{const d=t-tt; if(d<-0.7||d>0.6)continue;
    const b=document.querySelector(sel),scr=$('.scr').getBoundingClientRect(),r=b.getBoundingClientRect();
    const k=1/($('#ph').getBoundingClientRect().width/{PW});
    const x=(r.left+r.width/2-scr.left)*k,y=(r.top+r.height/2-scr.top)*k;
    $('#dot').style.left=x+'px';$('#dot').style.top=y+'px';$('#dot').style.opacity=d<0?cl((d+.7)/.25):cl(1-d/.25);
    $('#dot').style.transform=`scale(${{d<0&&d>-.12?0.8:1}})`;
    if(d>=0){{$('#tap').style.left=x+'px';$('#tap').style.top=y+'px';$('#tap').style.opacity=1-d/.6;$('#tap').style.transform=`scale(${{.4+eo(d/.6)*1.1}})`;}}
    if(d>-.1&&d<.15){{b.style.transform='scale(.96)';b.style.filter='brightness(.88)';}}
  }}
  // per-screen state
  const ok=cl((t-8.35)/.3); $('.optin-btn').style.opacity=1-ok; document.querySelectorAll('.optin-ok').forEach(x=>x.style.opacity=ok);
  const pg=cl((t-11.85)/.2); $('.prog').style.opacity=pg; $('.progfill').style.width=(eo((t-11.9)/1.6)*100)+'%';
  if(t>13.5)$('.progtxt').textContent='فتح'; else $('.progtxt').textContent='جارٍ التنزيل…';
  const tf=cl((t-15.2)/.3); $('.tfok').style.opacity=tf; $('.tfget').style.opacity=1-tf*.4;
  const a=cl((t-18.55)/.25), i2=cl((t-20.05)/.25)*cl(1);
  $('.inv-a').style.opacity=1-a; $('.inv-i').style.opacity=a*(1-i2); $('.inv-o').style.opacity=i2;
  const sh=eo((t-22.0)/.45); $('.sheet').style.transform=`translateY(${{(1-sh)*100}}%)`; $('.shade').style.opacity=sh;
  $('.rep').style.background=t>22.9?'rgba(15,102,96,.14)':'transparent';
}};
window.render(0);
</script>"""
    return W, H, body


def render_static(name, fn):
    w, h, b = fn()
    p = os.path.join(HERE, name + '.html')
    open(p, 'w').write(head(w, h) + b + WRAP_JS + '</body></html>')
    subprocess.run([CHROME, '--headless=new', '--hide-scrollbars', '--force-device-scale-factor=1', '--allow-file-access-from-files',
                    f'--window-size={w},{h}', '--virtual-time-budget=3000', f'--screenshot={os.path.join(OUT, name + ".png")}', 'file://' + p],
                   check=True, capture_output=True)


if __name__ == '__main__':
    render_static('post_1080x1350', post)
    render_static('post_1080x1080', square)
    w, h, b = reel()
    open(os.path.join(HERE, 'reel.html'), 'w').write(head(w, h) + b + '</body></html>')
    print('ok')
