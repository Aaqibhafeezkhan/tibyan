#!/usr/bin/env python3
"""Generate true DUO store screenshots showing BOTH phone states:
1. Closed phone (Portrait outer cover screen)
2. Open phone (Landscape unfolded showing two facing pages from vector SVGs)

Outputs to:
- iphone_duo/1398x2034 & 2007x2853 (Portrait canvas)
- iphone_duo/2034x1398 & 2853x2007 (Landscape canvas)
"""
import os, subprocess, zipfile, lzma, shutil
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../../..'))
STORE_TEMPLATES = os.path.join(ROOT, 'docs/brand/store/templates/iphone_duo')
FONTS = os.path.join(ROOT, 'assets/fonts/ofl')
CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
TMP_DIR = os.path.join(ROOT, 'docs/brand/store/src')
LOGO_SRC = os.path.join(TMP_DIR, 'logo_extracted.png')
SCREENS_DIR = os.path.join(TMP_DIR, 'screens')
PAGE_PACK = os.path.join(ROOT, 'tools/out/pages-hafs-1441-v1.zip')

GOLD = '#ECC87D'
CREAM = '#F6F1E8'
DEEP_BG = '#071F1D'

def render_vector_spread(page_r, page_l, out_png, w=2400, h=1600):
    with zipfile.ZipFile(PAGE_PACK) as z:
        svg_r = lzma.decompress(z.read(f"{page_r:03d}.svg.xz")).decode('utf-8').split('?>', 1)[-1]
        svg_l = lzma.decompress(z.read(f"{page_l:03d}.svg.xz")).decode('utf-8').split('?>', 1)[-1]
    
    html = f'''<!doctype html><html><head><meta charset="utf-8"><style>
    * {{ margin:0; padding:0; box-sizing:border-box; }}
    body {{ width: {w}px; height: {h}px; background: #FFFDF8; display: flex; align-items: center; justify-content: center; }}
    .spread {{ display: flex; width: 100%; height: 100%; padding: 40px 60px; gap: 40px; background: #FFFDF8; }}
    .page {{ flex: 1; height: 100%; display: flex; align-items: center; justify-content: center; }}
    .page svg {{ width: 100%; height: 100%; }}
    .spine {{ width: 2px; height: 95%; background: rgba(0,0,0,0.07); align-self: center; }}
    </style></head><body>
    <div class="spread">
      <div class="page">{svg_r}</div>
      <div class="spine"></div>
      <div class="page">{svg_l}</div>
    </div>
    </body></html>'''
    
    tmp_h = out_png + '.html'
    with open(tmp_h, 'w') as f:
        f.write(html)
    subprocess.run([
        CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars',
        f'--window-size={w},{h}', f'--screenshot={out_png}', f'file://{tmp_h}'
    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if os.path.exists(tmp_h):
        os.remove(tmp_h)

def render_html_to_image(html, w, h, out_path):
    tmp_h = out_path + '.html'
    with open(tmp_h, 'w') as f:
        f.write(html)
    subprocess.run([
        CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars',
        '--allow-file-access-from-files', '--force-device-scale-factor=1',
        '--default-background-color=00000000',
        f'--window-size={w},{h}', f'--screenshot={out_path}', f'file://{tmp_h}'
    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if os.path.exists(tmp_h):
        os.remove(tmp_h)

def build_duo_scene_landscape(open_bg_url, closed_bg_url, open_badge, closed_badge, out_png):
    html = f'''<!doctype html><html><head><meta charset="utf-8"><style>
* {{ margin:0; padding:0; box-sizing:border-box; }}
body {{
  width: 2034px;
  height: 1398px;
  overflow: hidden;
  background: transparent;
  display: flex;
  align-items: center;
  justify-content: center;
}}
.scene {{
  position: relative;
  width: 1960px;
  height: 1100px;
}}
/* Open unfolded phone (landscape) */
.open-phone {{
  position: absolute;
  left: 420px;
  top: 50px;
  width: 1480px;
  height: 1000px;
  background: #151a1b;
  border-radius: 46px;
  padding: 16px;
  box-shadow: 0 40px 90px rgba(0,0,0,0.7), 0 0 0 2px #5a6467;
}}
.open-screen {{
  width: 100%;
  height: 100%;
  border-radius: 34px;
  overflow: hidden;
  position: relative;
  background: #FFFDF8 url('{open_bg_url}') center/cover no-repeat;
}}
.hinge {{
  position: absolute;
  top: 0;
  bottom: 0;
  left: 50%;
  width: 3px;
  transform: translateX(-50%);
  background: rgba(0,0,0,0.12);
  box-shadow: -1px 0 3px rgba(0,0,0,0.08), 1px 0 3px rgba(255,255,255,0.4);
}}
.open-notch {{
  position: absolute;
  top: 10px;
  left: 50%;
  transform: translateX(-50%);
  width: 12px;
  height: 12px;
  border-radius: 50%;
  background: #081116;
  border: 1px solid #24333b;
}}
.open-badge {{
  position: absolute;
  bottom: 22px;
  right: 40px;
  padding: 8px 24px;
  border-radius: 999px;
  background: rgba(7,31,29,0.92);
  border: 1.5px solid #D9B266;
  color: #D9B266;
  font-family: 'Changa', sans-serif;
  font-size: 16px;
  font-weight: bold;
  white-space: nowrap;
}}

/* Closed folded phone (portrait, outer cover screen) */
.closed-phone {{
  position: absolute;
  left: 20px;
  top: 30px;
  width: 480px;
  height: 1030px;
  background: #151a1b;
  border-radius: 54px;
  padding: 16px;
  box-shadow: 0 50px 110px rgba(0,0,0,0.85), 0 0 0 2.5px #5a6467;
  z-index: 10;
}}
.closed-screen {{
  width: 100%;
  height: 100%;
  border-radius: 40px;
  overflow: hidden;
  position: relative;
  background: url('{closed_bg_url}') center/cover no-repeat;
}}
.closed-notch {{
  position: absolute;
  top: 18px;
  left: 50%;
  transform: translateX(-50%);
  width: 80px;
  height: 24px;
  border-radius: 12px;
  background: #000;
}}
.closed-badge {{
  position: absolute;
  bottom: 22px;
  left: 50%;
  transform: translateX(-50%);
  padding: 7px 18px;
  border-radius: 999px;
  background: rgba(7,31,29,0.92);
  border: 1.2px solid #D9B266;
  color: #F6F1E8;
  font-family: 'Changa', sans-serif;
  font-size: 14px;
  font-weight: bold;
  white-space: nowrap;
}}
</style></head><body>
<div class="scene">
  <div class="open-phone">
    <div class="open-screen">
      <div class="hinge"></div>
      <div class="open-notch"></div>
      <div class="open-badge">{open_badge}</div>
    </div>
  </div>
  <div class="closed-phone">
    <div class="closed-screen">
      <div class="closed-notch"></div>
      <div class="closed-badge">{closed_badge}</div>
    </div>
  </div>
</div>
</body></html>'''
    render_html_to_image(html, 2034, 1398, out_png)

def build_duo_scene_portrait(open_bg_url, closed_bg_url, open_badge, closed_badge, out_png):
    html = f'''<!doctype html><html><head><meta charset="utf-8"><style>
* {{ margin:0; padding:0; box-sizing:border-box; }}
body {{
  width: 1398px;
  height: 2034px;
  overflow: hidden;
  background: transparent;
  position: relative;
}}
.scene {{
  position: absolute;
  top: 480px;
  left: 0;
  width: 1398px;
  height: 1520px;
}}
/* Open unfolded phone (landscape) */
.open-phone {{
  position: absolute;
  right: 25px;
  top: 20px;
  width: 1180px;
  height: 800px;
  background: #151a1b;
  border-radius: 40px;
  padding: 14px;
  box-shadow: 0 40px 90px rgba(0,0,0,0.7), 0 0 0 2px #5a6467;
}}
.open-screen {{
  width: 100%;
  height: 100%;
  border-radius: 28px;
  overflow: hidden;
  position: relative;
  background: #FFFDF8 url('{open_bg_url}') center/cover no-repeat;
}}
.hinge {{
  position: absolute;
  top: 0;
  bottom: 0;
  left: 50%;
  width: 3px;
  transform: translateX(-50%);
  background: rgba(0,0,0,0.12);
  box-shadow: -1px 0 3px rgba(0,0,0,0.08), 1px 0 3px rgba(255,255,255,0.4);
}}
.open-badge {{
  position: absolute;
  bottom: 20px;
  right: 35px;
  padding: 7px 18px;
  border-radius: 999px;
  background: rgba(7,31,29,0.92);
  border: 1.5px solid #D9B266;
  color: #D9B266;
  font-family: 'Changa', sans-serif;
  font-size: 15px;
  font-weight: bold;
  white-space: nowrap;
}}

/* Closed folded phone (portrait, outer cover screen) */
.closed-phone {{
  position: absolute;
  left: 45px;
  top: 430px;
  width: 490px;
  height: 1030px;
  background: #151a1b;
  border-radius: 54px;
  padding: 16px;
  box-shadow: 0 50px 110px rgba(0,0,0,0.9), 0 0 0 2.5px #5a6467;
  z-index: 10;
}}
.closed-screen {{
  width: 100%;
  height: 100%;
  border-radius: 40px;
  overflow: hidden;
  position: relative;
  background: url('{closed_bg_url}') center/cover no-repeat;
}}
.closed-notch {{
  position: absolute;
  top: 18px;
  left: 50%;
  transform: translateX(-50%);
  width: 80px;
  height: 24px;
  border-radius: 12px;
  background: #000;
}}
.closed-badge {{
  position: absolute;
  bottom: 22px;
  left: 50%;
  transform: translateX(-50%);
  padding: 7px 18px;
  border-radius: 999px;
  background: rgba(7,31,29,0.92);
  border: 1.2px solid #D9B266;
  color: #F6F1E8;
  font-family: 'Changa', sans-serif;
  font-size: 14px;
  font-weight: bold;
  white-space: nowrap;
}}
</style></head><body>
<div class="scene">
  <div class="open-phone">
    <div class="open-screen">
      <div class="hinge"></div>
      <div class="open-badge">{open_badge}</div>
    </div>
  </div>
  <div class="closed-phone">
    <div class="closed-screen">
      <div class="closed-notch"></div>
      <div class="closed-badge">{closed_badge}</div>
    </div>
  </div>
</div>
</body></html>'''
    render_html_to_image(html, 1398, 2034, out_png)

def render_landscape_header(gold, white, out_png):
    html = f'''<!doctype html><html dir="rtl" lang="ar"><head><meta charset="utf-8"><style>
@font-face {{ font-family: 'Changa'; src: url('file://{FONTS}/changa/Changa[wght].ttf'); font-weight: 700; }}
* {{ margin:0; padding:0; box-sizing:border-box; }}
body {{ width: 2034px; height: 1398px; overflow: hidden; background: transparent; font-family: 'Changa', sans-serif; }}
.headline {{ position: absolute; top: 55px; right: 280px; left: 80px; text-align: center; line-height: 1.25; }}
.gold {{ color: #ECC87D; font-size: 72px; font-weight: 700; text-shadow: 0 4px 14px rgba(0,0,0,0.5); }}
.white {{ color: #FFFFFF; font-size: 38px; font-weight: 700; margin-top: 10px; opacity: 0.95; text-shadow: 0 3px 10px rgba(0,0,0,0.4); }}
</style></head><body>
<div class="headline"><div class="gold">{gold}</div><div class="white">{white}</div></div>
</body></html>'''
    render_html_to_image(html, 2034, 1398, out_png)

def render_portrait_header(gold, white, out_png):
    html = f'''<!doctype html><html dir="rtl" lang="ar"><head><meta charset="utf-8"><style>
@font-face {{ font-family: 'Changa'; src: url('file://{FONTS}/changa/Changa[wght].ttf'); font-weight: 700; }}
* {{ margin:0; padding:0; box-sizing:border-box; }}
body {{ width: 1398px; height: 2034px; overflow: hidden; background: transparent; font-family: 'Changa', sans-serif; }}
.headline {{ position: absolute; top: 250px; left: 50px; width: 1298px; text-align: center; line-height: 1.25; }}
.gold {{ color: #ECC87D; font-size: 82px; font-weight: 700; text-shadow: 0 4px 14px rgba(0,0,0,0.5); }}
.white {{ color: #FFFFFF; font-size: 40px; font-weight: 700; margin-top: 12px; opacity: 0.95; text-shadow: 0 3px 10px rgba(0,0,0,0.4); }}
</style></head><body>
<div class="headline"><div class="gold">{gold}</div><div class="white">{white}</div></div>
</body></html>'''
    render_html_to_image(html, 1398, 2034, out_png)

SCREENS = [
    {
        'num': '01',
        'gold': 'مصحف بصفحتين متقابلتين',
        'white': 'شاشة عريضة كالمصحف المطبوع وتصفح سريع بالهاتف المغلق',
        'open_spread': (603, 604),
        'closed_img': os.path.join(TMP_DIR, 'home.jpg'),
        'open_badge': 'مفتوح بالعرض · صفحتان متقابلتان كالمصحف',
        'closed_badge': 'مقفول · شاشة الغلاف الخارجية',
    },
    {
        'num': '02',
        'gold': 'إستمع وأنت تقرأ بتزامن صوتي',
        'white': 'تتبّع التلاوة بالصوت والكلمة تضيء أمامك تلقائيًا',
        'open_spread': (1, 2),
        'closed_img': os.path.join(SCREENS_DIR, '01_listen.png'),
        'open_badge': 'تلاوة متزامنة وتظليل حي للكلمات',
        'closed_badge': 'مشغل الاستماع السريع',
    },
    {
        'num': '03',
        'gold': 'تعلّم وتدبّر مع التفسير',
        'white': 'بلمسة واحدة استمع للآية وتدبر معانيها وتفسيرها المعتمد',
        'open_spread': (3, 4),
        'closed_img': os.path.join(SCREENS_DIR, '04_tafsir.png'),
        'open_badge': 'قراءة رحبة بوضوح فائق',
        'closed_badge': 'تفسير الآيات ومعاني الكلمات',
    },
    {
        'num': '04',
        'gold': 'تسميع ذكي ومسبحة إلكترونية',
        'white': 'يستمع لتلاوتك ويصحح أخطاء الحفظ أوفلاين مع أذكار مأثورة',
        'open_spread': (5, 6),
        'closed_img': os.path.join(SCREENS_DIR, '02_tasmee.png'),
        'open_badge': 'تثبيت الحفظ ومصحح التلاوة المباشر',
        'closed_badge': 'مصحح الحفظ الذكي يعمل بلا إنترنت',
    },
    {
        'num': '05',
        'gold': 'رحلة ومسيرة الحفظ',
        'white': 'خريطة تفاعلية لمقدار حفظك ومتابعة التثبيت والمراجعة',
        'open_spread': (10, 11),
        'closed_img': os.path.join(SCREENS_DIR, '05_hifz.png'),
        'open_badge': 'متابعة تفاعلية لـ ٣٠ جزءًا',
        'closed_badge': 'جلسات التثبيت والأوراد',
    },
    {
        'num': '06',
        'gold': 'ورد يومي وختمات',
        'white': 'تنظيم الورد وخيارات ختمات فردية وجماعية بدون مشاركة البيانات',
        'open_spread': (20, 21),
        'closed_img': os.path.join(SCREENS_DIR, '06_khatma.png'),
        'open_badge': 'ختمات فردية وجماعية مع العائلة',
        'closed_badge': 'متابعة نسبة إنجاز الورد اليومي',
    },
    {
        'num': '07',
        'gold': 'مسبحة إلكترونية وأذكار',
        'white': 'تصاميم متعددة ومؤثرات اهتزازية مع باقة أذكار المسلم',
        'open_spread': (30, 31),
        'closed_img': os.path.join(SCREENS_DIR, '08_tasbih.png'),
        'open_badge': 'قراءة القرآن والأوراد المأثورة',
        'closed_badge': 'مسبحة إلكترونية بأشكال متعددة',
    },
    {
        'num': '08',
        'gold': 'تصميم إسلامي راقٍ',
        'white': 'أنماط هندسية ووضع ليلي مريح ووضع لكبار السن',
        'open_spread': (50, 51),
        'closed_img': os.path.join(SCREENS_DIR, '07_styles.png'),
        'open_badge': 'راحة تامة للعين في القراءة الليلية',
        'closed_badge': 'أنماط هندسية وخطوط مريحة',
    },
]

def main():
    print("Preparing vector Quran spreads...")
    spread_cache = {}
    for sc in SCREENS:
        p_r, p_l = sc['open_spread']
        sp_path = os.path.join(TMP_DIR, f'_spread_{p_r}_{p_l}.png')
        if not os.path.exists(sp_path):
            render_vector_spread(p_r, p_l, sp_path)
        spread_cache[(p_r, p_l)] = sp_path

    # Prepare logos
    logo_raw = Image.open(LOGO_SRC).convert('RGBA')
    logo_land = logo_raw.resize((210, 153), Image.Resampling.LANCZOS)
    logo_port = logo_raw.resize((240, 175), Image.Resampling.LANCZOS)

    # Backgrounds
    bg_land = Image.open(os.path.join(STORE_TEMPLATES, '2034x1398/layers/background.png')).convert('RGBA')
    bg_port = Image.open(os.path.join(STORE_TEMPLATES, '1398x2034/layers/background.png')).convert('RGBA')

    print("Generating iPhone Duo Screenshots for both Landscape and Portrait...")
    for sc in SCREENS:
        num = sc['num']
        sp_path = spread_cache[sc['open_spread']]
        cl_path = sc['closed_img']

        # 1. LANDSCAPE (2034x1398 and 2853x2007)
        dev_land_png = os.path.join(TMP_DIR, f'_dev_land_{num}.png')
        build_duo_scene_landscape(f"file://{sp_path}", f"file://{cl_path}", sc['open_badge'], sc['closed_badge'], dev_land_png)
        
        head_land_png = os.path.join(TMP_DIR, f'_head_land_{num}.png')
        render_landscape_header(sc['gold'], sc['white'], head_land_png)
        
        res_land = bg_land.copy()
        dev_img = Image.open(dev_land_png).convert('RGBA')
        res_land.alpha_composite(dev_img, (0, 160))
        res_land.paste(logo_land, (1740, 45), logo_land)
        head_img = Image.open(head_land_png).convert('RGBA')
        res_land.alpha_composite(head_img)
        
        rgb_land = res_land.convert('RGB')
        dst_2034 = os.path.join(STORE_TEMPLATES, f'2034x1398/{num}.jpg')
        rgb_land.save(dst_2034, quality=95)
        
        rgb_2853 = rgb_land.resize((2853, 2007), Image.Resampling.LANCZOS)
        dst_2853 = os.path.join(STORE_TEMPLATES, f'2853x2007/{num}.jpg')
        rgb_2853.save(dst_2853, quality=95)
        print(f"  ✓ Saved Landscape Duo {num}.jpg (2034x1398 & 2853x2007)")

        # 2. PORTRAIT (1398x2034 and 2007x2853)
        dev_port_png = os.path.join(TMP_DIR, f'_dev_port_{num}.png')
        build_duo_scene_portrait(f"file://{sp_path}", f"file://{cl_path}", sc['open_badge'], sc['closed_badge'], dev_port_png)
        
        head_port_png = os.path.join(TMP_DIR, f'_head_port_{num}.png')
        render_portrait_header(sc['gold'], sc['white'], head_port_png)
        
        res_port = bg_port.copy()
        dev_p_img = Image.open(dev_port_png).convert('RGBA')
        res_port.alpha_composite(dev_p_img)
        res_port.paste(logo_port, ((1398 - 240) // 2, 45), logo_port)
        head_p_img = Image.open(head_port_png).convert('RGBA')
        res_port.alpha_composite(head_p_img)
        
        rgb_port = res_port.convert('RGB')
        dst_1398 = os.path.join(STORE_TEMPLATES, f'1398x2034/{num}.jpg')
        rgb_port.save(dst_1398, quality=95)
        
        rgb_2007 = rgb_port.resize((2007, 2853), Image.Resampling.LANCZOS)
        dst_2007 = os.path.join(STORE_TEMPLATES, f'2007x2853/{num}.jpg')
        rgb_2007.save(dst_2007, quality=95)
        print(f"  ✓ Saved Portrait Duo {num}.jpg (1398x2034 & 2007x2853)")

        # Clean temp
        for p in [dev_land_png, head_land_png, dev_port_png, head_port_png]:
            if os.path.exists(p): os.remove(p)

    # Clean spreads
    for sp in spread_cache.values():
        if os.path.exists(sp): os.remove(sp)

    print("\n✓ ALL 32 iPhone Duo Screenshots Successfully Generated with Ultra-Crisp Quality!")

if __name__ == '__main__':
    main()
