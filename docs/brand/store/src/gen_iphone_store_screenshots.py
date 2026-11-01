#!/usr/bin/env python3
"""Generate iPhone 6.3 (1179x2556) branded App Store screenshots.

Uses the real Photoshop template structure:
- Islamic background pattern (layers/background.png)
- Official Tibyan calligraphic logo with gold styling
- Changa-Bold gold & white headlines
- Vector device frame with Dynamic Island (layers/frame.png)
- Real app screenshots clipped to screen mask (layers/screen_mask.png)
"""
import os, subprocess, shutil
from PIL import Image, ImageChops

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../../..'))
TEMPLATE_DIR = os.path.join(ROOT, 'docs/brand/store/templates/iphone_6.3/1179x2556')
LAYERS = os.path.join(TEMPLATE_DIR, 'layers')
FONTS = os.path.join(ROOT, 'assets/fonts/ofl')
CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
TMP_DIR = os.path.join(ROOT, 'docs/brand/store/src')

bg = Image.open(os.path.join(LAYERS, 'background.png')).convert('RGBA')
frame = Image.open(os.path.join(LAYERS, 'frame.png')).convert('RGBA')
mask = Image.open(os.path.join(LAYERS, 'screen_mask.png')).convert('RGBA')

# Ensure standard 02.jpg and 03.jpg exist alongside ٠٢.jpg and ٠٣.jpg
for ar_name, en_name in [('٠٢.jpg', '02.jpg'), ('٠٣.jpg', '03.jpg')]:
    src = os.path.join(TEMPLATE_DIR, ar_name)
    dst = os.path.join(TEMPLATE_DIR, en_name)
    if os.path.exists(src) and not os.path.exists(dst):
        shutil.copy(src, dst)

SCREENS = [
    {
        'num': '04',
        'gold': 'حفظ موضع القراءة',
        'white': 'وخدمات الآية (إستماع - تفسير - معاني - دراسة)',
        'img': os.path.join(ROOT, 'docs/brand/store/src/screens/01_listen.png'),
    },
    {
        'num': '05',
        'gold': 'تعلم وتدبر مع التفسير',
        'white': 'بمصادر متعددة وإمكانية الاستماع للتفسير',
        'img': os.path.join(ROOT, 'docs/brand/store/src/screens/04_tafsir.png'),
    },
    {
        'num': '06',
        'gold': 'نموذج تسميع ذكي',
        'white': 'يعمل بدون إنترنت ويستمع لتلاوتك ويقيّم حفظك',
        'img': os.path.join(ROOT, 'docs/brand/store/src/screens/02_tasmee.png'),
    },
    {
        'num': '07',
        'gold': 'مسبحة إلكترونية',
        'white': 'بأشكال وأنواع متعددة وأذكار مأثورة',
        'img': os.path.join(ROOT, 'docs/brand/store/src/screens/08_tasbih.png'),
    },
    {
        'num': '08',
        'gold': 'ورد يومي وختمة',
        'white': 'تنظيم الورد وخيارات ختمات فردية وجماعية',
        'img': os.path.join(ROOT, 'docs/brand/store/src/screens/06_khatma.png'),
    },
    {
        'num': '09',
        'gold': 'رحلة ومسيرة الحفظ',
        'white': 'خريطة تفاعلية لمقدار حفظك ومتابعة التثبيت',
        'img': os.path.join(ROOT, 'docs/brand/store/src/screens/05_hifz.png'),
    },
    {
        'num': '10',
        'gold': 'تصميم إسلامي راقٍ',
        'white': 'أنماط هندسية ووضع ليلي مريح ووضع لكبار السن',
        'img': os.path.join(ROOT, 'docs/brand/store/src/screens/07_styles.png'),
    },
]

def render_headline(gold, white, num):
    html = f'''<!doctype html><html dir="rtl" lang="ar"><head><meta charset="utf-8"><style>
@font-face {{
  font-family: 'Changa';
  src: url('file://{FONTS}/changa/Changa[wght].ttf');
  font-weight: 700;
}}
* {{ margin:0; padding:0; box-sizing:border-box; }}
body {{
  width: 1179px;
  height: 2556px;
  overflow: hidden;
  background: transparent;
  font-family: 'Changa', sans-serif;
  -webkit-font-smoothing: antialiased;
}}
.headline {{
  position: absolute;
  top: 310px;
  left: 50px;
  width: 1079px;
  text-align: center;
  line-height: 1.22;
}}
.gold {{
  color: #ECC87D;
  font-size: 102px;
  font-weight: 700;
  text-shadow: 0 4px 14px rgba(0,0,0,0.5);
}}
.white {{
  color: #FFFFFF;
  font-size: 52px;
  font-weight: 700;
  margin-top: 14px;
  opacity: 0.95;
  text-shadow: 0 3px 10px rgba(0,0,0,0.4);
}}
</style></head><body>
<div class="headline">
  <div class="gold">{gold}</div>
  <div class="white">{white}</div>
</div>
</body></html>'''

    tmp_h = os.path.join(TMP_DIR, f'_head_{num}.html')
    tmp_p = os.path.join(TMP_DIR, f'_head_{num}.png')
    with open(tmp_h, 'w') as f:
        f.write(html)
        
    subprocess.run([
        CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars',
        '--allow-file-access-from-files', '--force-device-scale-factor=1',
        '--default-background-color=00000000',
        '--window-size=1179,2556', '--virtual-time-budget=2000',
        f'--screenshot={tmp_p}', f'file://{tmp_h}'
    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    
    img = Image.open(tmp_p).convert('RGBA')
    if os.path.exists(tmp_h): os.remove(tmp_h)
    if os.path.exists(tmp_p): os.remove(tmp_p)
    return img

def build_screenshot(screen_cfg, logo_img):
    num = screen_cfg['num']
    out_file = os.path.join(TEMPLATE_DIR, f"{num}.jpg")
    
    head_img = render_headline(screen_cfg['gold'], screen_cfg['white'], num)
    
    sc_src = Image.open(screen_cfg['img']).convert('RGBA')
    tw, th = 859, 1868
    ratio = max(tw / sc_src.width, th / sc_src.height)
    new_w, new_h = int(sc_src.width * ratio), int(sc_src.height * ratio)
    sc_resized = sc_src.resize((new_w, new_h), Image.Resampling.LANCZOS)
    left = (new_w - tw) // 2
    top = (new_h - th) // 2
    sc_cropped = sc_resized.crop((left, top, left + tw, top + th))
    
    sc_layer = Image.new('RGBA', (1179, 2556), (0, 0, 0, 0))
    sc_layer.paste(sc_cropped, (160, 596))
    
    mask_a = mask.getchannel('A')
    sc_layer.putalpha(ImageChops.multiply(sc_layer.getchannel('A'), mask_a))
    
    res = bg.copy()
    res.alpha_composite(sc_layer)
    res.alpha_composite(frame)
    res.paste(logo_img, (443, 50), logo_img)
    res.alpha_composite(head_img)
    
    final_rgb = res.convert('RGB')
    final_rgb.save(out_file, quality=95)
    print(f"✓ Saved {out_file}")

def main():
    logo_file = os.path.join(TMP_DIR, 'logo_extracted.png')
    if not os.path.exists(logo_file):
        # Extract from template.psd if needed
        from psd_tools import PSDImage
        psd = PSDImage.open(os.path.join(TEMPLATE_DIR, 'template.psd'))
        for l in psd:
            if 'logo' in l.name.lower():
                l.composite().save(logo_file)
                break
    logo_img = Image.open(logo_file).convert('RGBA')

    print("Generating 7 iPhone store screenshots...")
    for sc in SCREENS:
        build_screenshot(sc, logo_img)
    print("All iPhone store screenshots completed!")

if __name__ == '__main__':
    main()
