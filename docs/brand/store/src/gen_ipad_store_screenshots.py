#!/usr/bin/env python3
"""Generate iPad 13" and 12.9" App Store screenshots for both Landscape and Portrait orientations.

Uses:
- Authentic Holy Quran horizontal two-page spreads with ornate golden Islamic borders
- Real template layers (background, frame, screen_mask)
- Official Tibyan calligraphy logo
- Changa-Bold headlines
Outputs:
- ipad_13/2752x2064 & 2732x2048 (Landscape)
- ipad_13/2064x2752 & 2048x2732 (Portrait)
"""
import os, subprocess
from PIL import Image, ImageChops

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../../..'))
STORE_TEMPLATES = os.path.join(ROOT, 'docs/brand/store/templates/ipad_13')
FONTS = os.path.join(ROOT, 'assets/fonts/ofl')
CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
TMP_DIR = os.path.join(ROOT, 'docs/brand/store/src')
LOGO_SRC = os.path.join(TMP_DIR, 'logo_extracted.png')
SCREENS_DIR = os.path.join(TMP_DIR, 'screens')

GOLD = '#D9B266'
CREAM = '#F6F1E8'
MINT = '#CFE3DF'
DEEP_BG = '#071F1D'

def render_html_to_image(html, w, h, out_path):
    tmp_h = out_path + '.html'
    with open(tmp_h, 'w', encoding='utf-8') as f:
        f.write(html)
    subprocess.run([
        CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars',
        '--allow-file-access-from-files', '--force-device-scale-factor=1',
        '--default-background-color=00000000',
        f'--window-size={w},{h}', f'--screenshot={out_path}', f'file://{tmp_h}'
    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if os.path.exists(tmp_h):
        os.remove(tmp_h)

def render_ipad_landscape_screen(sc_type, out_png, w=1921, h=1441):
    font_decl = f'''
    @font-face {{ font-family: 'Changa'; src: url('file://{FONTS}/changa/Changa[wght].ttf'); font-weight: 700; }}
    @font-face {{ font-family: 'Plex'; src: url('file://{FONTS}/ibm_plex_sans_arabic/IBMPlexSansArabic-SemiBold.ttf'); font-weight: 600; }}
    @font-face {{ font-family: 'PlexBold'; src: url('file://{FONTS}/ibm_plex_sans_arabic/IBMPlexSansArabic-Bold.ttf'); font-weight: 700; }}
    '''
    
    if sc_type == 'spread_plain':
        # Authentic two-page spread with complete golden borders
        inner = f'''
        <div style="width:100%;height:100%;background:#FFFDF8 url('file://{SCREENS_DIR}/spread_al_imran.png') center/cover no-repeat;position:relative;">
          <div style="position:absolute;top:22px;left:50%;transform:translateX(-50%);padding:8px 30px;border-radius:999px;background:rgba(7,31,29,0.92);border:1.5px solid {GOLD};font-family:'Plex', sans-serif;font-size:19px;font-weight:700;color:{CREAM};box-shadow:0 10px 25px rgba(0,0,0,0.4);">
            مصحف المدينة المنورة · صفحتان متقابلتان كالمصحف الشريف المطبوع
          </div>
        </div>
        '''
    elif sc_type == 'spread_audio':
        # Authentic spread with active verse highlight + floating audio bar
        inner = f'''
        <div style="width:100%;height:100%;background:#FFFDF8 url('file://{SCREENS_DIR}/spread_al_imran.png') center/cover no-repeat;position:relative;">
          <!-- Verse highlight -->
          <div style="position:absolute;top:362px;right:180px;width:730px;height:60px;background:rgba(217,178,102,0.28);border-radius:8px;border:1px solid rgba(217,178,102,0.6);pointer-events:none;"></div>
          
          <!-- Floating Audio Player Bar -->
          <div style="position:absolute;bottom:35px;left:70px;right:70px;height:100px;border-radius:999px;background:rgba(7,31,29,0.94);backdrop-filter:blur(25px);border:1.8px solid {GOLD};display:flex;align-items:center;justify-content:space-between;padding:0 35px;box-shadow:0 25px 50px rgba(0,0,0,0.6);">
            <div style="display:flex;align-items:center;gap:22px;">
              <div style="width:62px;height:62px;border-radius:50%;background:{GOLD};display:flex;align-items:center;justify-content:center;box-shadow:0 6px 15px rgba(217,178,102,0.4);">
                <svg width="26" height="26" viewBox="0 0 24 24" fill="{DEEP_BG}"><polygon points="7 4 19 12 7 20 7 4"/></svg>
              </div>
              <div>
                <div style="font-family:'PlexBold', sans-serif;font-size:25px;color:{CREAM};">الشيخ مشاري راشد العفاسي</div>
                <div style="font-family:'Plex', sans-serif;font-size:18px;color:{GOLD};margin-top:2px;">سورة آل عمران · الآية ٣ · إضاءة متزامنة كلمةً كلمة</div>
              </div>
            </div>
            <div style="display:flex;align-items:center;gap:35px;color:{MINT};font-family:'Plex', sans-serif;font-size:20px;font-weight:600;">
              <span>تكرار الآية: ١</span>
              <span>السرعة: ١.٠×</span>
              <div style="display:flex;align-items:center;gap:8px;color:{GOLD};background:rgba(217,178,102,0.15);padding:6px 18px;border-radius:999px;border:1px solid {GOLD};">● تلاوة حية متزامنة</div>
            </div>
          </div>
        </div>
        '''
    elif sc_type == 'spread_qiraat':
        # 3D curled page turn spread
        inner = f'''
        <div style="width:100%;height:100%;background:#FFFDF8 url('file://{SCREENS_DIR}/03_qiraat.png') center/cover no-repeat;position:relative;">
          <div style="position:absolute;top:22px;left:50%;transform:translateX(-50%);padding:8px 30px;border-radius:999px;background:rgba(7,31,29,0.92);border:1.5px solid {GOLD};font-family:'Plex', sans-serif;font-size:19px;font-weight:700;color:{CREAM};box-shadow:0 10px 25px rgba(0,0,0,0.4);">
            مصحف المدينة المنورة · رواية حفص عن عاصم (طبعة مجمع الملك فهد)
          </div>
        </div>
        '''
    elif sc_type == 'custom_tafsir':
        # Authentic two-page spread with rich floating Tafsir card over the left page
        inner = f'''
        <div style="width:100%;height:100%;background:#FFFDF8 url('file://{SCREENS_DIR}/spread_al_imran.png') center/cover no-repeat;position:relative;">
          <!-- Verse highlight on right page -->
          <div style="position:absolute;top:362px;right:180px;width:730px;height:60px;background:rgba(217,178,102,0.28);border-radius:8px;border:1.5px solid rgba(217,178,102,0.7);pointer-events:none;"></div>

          <!-- Floating Tafsir Card on left page -->
          <div style="position:absolute;top:70px;left:70px;bottom:70px;width:820px;border-radius:32px;background:rgba(7,31,29,0.95);backdrop-filter:blur(30px);border:2px solid {GOLD};padding:45px;display:flex;flex-direction:column;justify-content:space-between;box-shadow:0 30px 70px rgba(0,0,0,0.65);">
            <div>
              <div style="display:inline-flex;align-items:center;gap:12px;padding:8px 24px;border-radius:999px;background:rgba(217,178,102,0.18);border:1.5px solid {GOLD};color:{GOLD};font-family:'Plex', sans-serif;font-size:22px;font-weight:700;">
                التفسير الميسّر · سورة آل عمران
              </div>
              <div style="font-family:'Changa', sans-serif;font-size:38px;font-weight:700;color:{GOLD};margin-top:25px;line-height:1.45;">
                ﴿ نَزَّلَ عَلَيْكَ الْكِتَابَ بِالْحَقِّ مُصَدِّقًا لِّمَا بَيْنَ يَدَيْهِ ﴾
              </div>
              <div style="font-family:'Plex', sans-serif;font-size:26px;color:{CREAM};margin-top:22px;line-height:1.75;">
                نزّل عليك القرآن بالصدق والعدل، موافقًا للكتب الإلهية السابقة ومؤيدًا لما فيها من التوحيد وأصول الدين.
              </div>
            </div>

            <div style="background:rgba(10,38,36,0.85);border-radius:24px;border:1.5px solid rgba(217,178,102,0.35);padding:28px;">
              <div style="font-family:'PlexBold', sans-serif;font-size:24px;color:{GOLD};">معاني الكلمات:</div>
              <div style="font-family:'Plex', sans-serif;font-size:23px;color:{MINT};margin-top:14px;line-height:1.8;">
                • <strong style="color:{CREAM};">بِالْحَقِّ:</strong> بالصدق في أخباره والعدل في أحكامه.<br>
                • <strong style="color:{CREAM};">مُصَدِّقًا:</strong> شاهدًا وموافقًا لما تقدّمه من الكتب السماوية.
              </div>
            </div>

            <div style="display:flex;align-items:center;justify-content:space-between;padding-top:15px;border-top:1px solid rgba(217,178,102,0.3);">
              <span style="font-family:'Plex', sans-serif;font-size:21px;color:{GOLD};font-weight:600;">بلمسة واحدة تظهر معاني الكلمات والإعراب فورًا</span>
              <span style="font-family:'Plex', sans-serif;font-size:19px;color:{MINT};background:rgba(217,178,102,0.15);padding:6px 16px;border-radius:999px;">أسباب النزول ✓</span>
            </div>
          </div>
        </div>
        '''
    elif sc_type == 'custom_tasmee':
        # Authentic two-page spread with floating Smart Tasmee AI HUD
        inner = f'''
        <div style="width:100%;height:100%;background:#FFFDF8 url('file://{SCREENS_DIR}/spread_al_imran.png') center/cover no-repeat;position:relative;">
          <!-- Verse highlight on recited verse -->
          <div style="position:absolute;top:448px;right:180px;width:730px;height:62px;background:rgba(85,189,178,0.25);border-radius:8px;border:1.5px solid #55BDB2;pointer-events:none;"></div>

          <!-- Floating Smart Tasmee HUD Modal -->
          <div style="position:absolute;bottom:45px;left:50%;transform:translateX(-50%);width:1300px;border-radius:36px;background:rgba(7,31,29,0.96);backdrop-filter:blur(30px);border:2.5px solid {GOLD};padding:38px 50px;box-shadow:0 35px 80px rgba(0,0,0,0.7);display:flex;align-items:center;justify-content:space-between;">
            <div style="display:flex;align-items:center;gap:35px;">
              <!-- Glowing Microphone -->
              <div style="width:105px;height:105px;border-radius:50%;background:{GOLD};display:flex;align-items:center;justify-content:center;box-shadow:0 0 40px rgba(217,178,102,0.6);flex-shrink:0;">
                <svg width="52" height="52" viewBox="0 0 24 24" fill="none" stroke="{DEEP_BG}" stroke-width="2.3"><path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z"/><path d="M19 10v2a7 7 0 0 1-14 0v-2"/><line x1="12" y1="19" x2="12" y2="23"/><line x1="8" y1="23" x2="16" y2="23"/></svg>
              </div>
              <div>
                <div style="display:flex;align-items:center;gap:14px;">
                  <span style="font-family:'Changa', sans-serif;font-size:36px;font-weight:700;color:{CREAM};">مصحح التلاوة والتسميع الذكي</span>
                  <span style="padding:4px 14px;border-radius:999px;background:rgba(85,189,178,0.2);color:#55BDB2;font-family:'Plex', sans-serif;font-size:18px;font-weight:700;border:1px solid #55BDB2;">● يعمل بدون إنترنت</span>
                </div>
                <div style="font-family:'Plex', sans-serif;font-size:24px;color:{MINT};margin-top:6px;">
                  يستمع لتلاوتك الآن: <span style="color:{GOLD};font-weight:700;">﴿ قَبْلُ هُدًى لِّلنَّاسِ وَأَنزَلَ الْفُرْقَانَ ﴾</span>
                </div>
              </div>
            </div>

            <!-- Waveform & Verification -->
            <div style="display:flex;flex-direction:column;align-items:flex-end;gap:12px;">
              <div style="display:flex;align-items:center;gap:8px;height:45px;">
                <div style="width:7px;height:22px;background:{GOLD};border-radius:4px;"></div>
                <div style="width:7px;height:40px;background:{GOLD};border-radius:4px;"></div>
                <div style="width:7px;height:30px;background:{GOLD};border-radius:4px;"></div>
                <div style="width:7px;height:45px;background:{GOLD};border-radius:4px;"></div>
                <div style="width:7px;height:25px;background:{GOLD};border-radius:4px;"></div>
                <div style="width:7px;height:38px;background:{GOLD};border-radius:4px;"></div>
                <div style="width:7px;height:18px;background:{GOLD};border-radius:4px;"></div>
              </div>
              <div style="padding:6px 20px;border-radius:999px;background:rgba(85,189,178,0.22);color:#55BDB2;font-family:'PlexBold', sans-serif;font-size:22px;border:1px solid #55BDB2;">
                ✓ التلاوة صحيحة ومتقنة
              </div>
            </div>
          </div>
        </div>
        '''
    elif sc_type == 'custom_hifz':
        # Authentic two-page spread with Hifz verse masking mode
        inner = f'''
        <div style="width:100%;height:100%;background:#FFFDF8 url('file://{SCREENS_DIR}/spread_al_imran.png') center/cover no-repeat;position:relative;">
          <!-- Masked verse 1 on right page -->
          <div style="position:absolute;top:535px;right:180px;width:730px;height:65px;background:rgba(7,31,29,0.92);backdrop-filter:blur(8px);border-radius:10px;border:2px dashed {GOLD};display:flex;align-items:center;justify-content:center;box-shadow:0 8px 20px rgba(0,0,0,0.3);">
            <span style="font-family:'PlexBold', sans-serif;font-size:22px;color:{GOLD};">👁 اضغط لإظهار الآية والتحقق من حفظك</span>
          </div>

          <!-- Masked verse 2 on right page -->
          <div style="position:absolute;top:620px;right:180px;width:730px;height:65px;background:rgba(7,31,29,0.92);backdrop-filter:blur(8px);border-radius:10px;border:2px dashed {GOLD};display:flex;align-items:center;justify-content:center;box-shadow:0 8px 20px rgba(0,0,0,0.3);">
            <span style="font-family:'PlexBold', sans-serif;font-size:22px;color:{GOLD};">👁 اضغط لإظهار الآية والتحقق من حفظك</span>
          </div>

          <!-- Masked verse 3 on left page -->
          <div style="position:absolute;top:448px;left:180px;width:730px;height:65px;background:rgba(7,31,29,0.92);backdrop-filter:blur(8px);border-radius:10px;border:2px dashed {GOLD};display:flex;align-items:center;justify-content:center;box-shadow:0 8px 20px rgba(0,0,0,0.3);">
            <span style="font-family:'PlexBold', sans-serif;font-size:22px;color:{GOLD};">👁 اضغط لإظهار الآية والتحقق من حفظك</span>
          </div>

          <!-- Floating Hifz Control HUD at top -->
          <div style="position:absolute;top:25px;left:50%;transform:translateX(-50%);width:1300px;border-radius:999px;background:rgba(7,31,29,0.95);backdrop-filter:blur(25px);border:2px solid {GOLD};padding:14px 40px;display:flex;align-items:center;justify-content:space-between;box-shadow:0 20px 45px rgba(0,0,0,0.5);">
            <div style="display:flex;align-items:center;gap:18px;">
              <span style="width:16px;height:16px;border-radius:50%;background:#55BDB2;display:inline-block;box-shadow:0 0 12px #55BDB2;"></span>
              <span style="font-family:'PlexBold', sans-serif;font-size:24px;color:{CREAM};">وضع اختبار وتثبيت الحفظ النشط</span>
              <span style="font-family:'Plex', sans-serif;font-size:20px;color:{GOLD};">· سورة آل عمران</span>
            </div>

            <div style="display:flex;align-items:center;gap:30px;">
              <div style="font-family:'Plex', sans-serif;font-size:20px;color:{MINT};">
                المحفوظ: <strong style="color:{GOLD};font-size:22px;">١٢ / ٣٠ جزءًا (٤٠٪)</strong>
              </div>
              <div style="display:flex;gap:10px;">
                <span style="padding:6px 18px;border-radius:999px;background:rgba(217,178,102,0.2);color:{GOLD};border:1px solid {GOLD};font-family:'Plex', sans-serif;font-size:18px;font-weight:700;">إخفاء الكلمات</span>
                <span style="padding:6px 18px;border-radius:999px;background:{GOLD};color:{DEEP_BG};font-family:'Plex', sans-serif;font-size:18px;font-weight:700;">إخفاء الآيات</span>
              </div>
            </div>
          </div>
        </div>
        '''
    elif sc_type == 'custom_khatma':
        # Authentic two-page spread with Silk Ribbon Bookmarks & Reflections
        inner = f'''
        <div style="width:100%;height:100%;background:#FFFDF8 url('file://{SCREENS_DIR}/spread_al_imran.png') center/cover no-repeat;position:relative;">
          <!-- Silk Ribbon Bookmark 1 (Golden) hanging from top over right page -->
          <div style="position:absolute;top:0;right:280px;width:58px;height:240px;background:linear-gradient(180deg, #B88E3E, {GOLD}, #B88E3E);box-shadow:0 12px 25px rgba(0,0,0,0.4);border-radius:0 0 10px 10px;display:flex;flex-direction:column;align-items:center;justify-content:flex-end;padding-bottom:18px;">
            <span style="writing-mode:vertical-rl;font-family:'PlexBold', sans-serif;font-size:20px;color:{DEEP_BG};letter-spacing:2px;font-weight:700;">ورد الصباح</span>
          </div>

          <!-- Silk Ribbon Bookmark 2 (Emerald) hanging from top over left page -->
          <div style="position:absolute;top:0;left:280px;width:58px;height:300px;background:linear-gradient(180deg, #0A4E46, #148074, #0A4E46);box-shadow:0 12px 25px rgba(0,0,0,0.4);border-radius:0 0 10px 10px;display:flex;flex-direction:column;align-items:center;justify-content:flex-end;padding-bottom:18px;">
            <span style="writing-mode:vertical-rl;font-family:'PlexBold', sans-serif;font-size:20px;color:{CREAM};letter-spacing:2px;font-weight:700;">ختمة رمضان</span>
          </div>

          <!-- Floating Note / Reflection Card pinned to left page -->
          <div style="position:absolute;bottom:55px;left:90px;width:760px;border-radius:28px;background:rgba(7,31,29,0.95);backdrop-filter:blur(25px);border:2px solid {GOLD};padding:32px 40px;box-shadow:0 30px 65px rgba(0,0,0,0.65);">
            <div style="display:flex;align-items:center;justify-content:space-between;">
              <div style="display:flex;align-items:center;gap:12px;">
                <span style="font-size:28px;">📌</span>
                <span style="font-family:'Changa', sans-serif;font-size:26px;font-weight:700;color:{GOLD};">خاطرة وتدبّر الآية ٧</span>
              </div>
              <span style="font-family:'Plex', sans-serif;font-size:18px;color:{MINT};background:rgba(217,178,102,0.15);padding:4px 14px;border-radius:999px;">سورة آل عمران</span>
            </div>
            <div style="font-family:'Plex', sans-serif;font-size:23px;color:{CREAM};margin-top:16px;line-height:1.7;">
              ﴿ رَبَّنَا لَا تُزِغْ قُلُوبَنَا بَعْدَ إِذْ هَدَيْتَنَا وَهَبْ لَنَا مِن لَّدُنكَ رَحْمَةً ﴾
              <div style="color:{MINT};font-size:21px;margin-top:8px;">دعاء عظيم للثبات على الهداية بعد وضوح الآيات المحكمات.</div>
            </div>
          </div>

          <!-- Top Khatma Progress Bar -->
          <div style="position:absolute;top:25px;left:50%;transform:translateX(-50%);width:1100px;border-radius:999px;background:rgba(7,31,29,0.93);backdrop-filter:blur(20px);border:1.8px solid {GOLD};padding:12px 35px;display:flex;align-items:center;justify-content:space-between;box-shadow:0 15px 35px rgba(0,0,0,0.5);">
            <span style="font-family:'PlexBold', sans-serif;font-size:22px;color:{CREAM};">ختمة رمضان المباركة</span>
            <div style="display:flex;align-items:center;gap:20px;flex:1;max-width:500px;margin:0 25px;">
              <div style="flex:1;height:12px;background:rgba(255,255,255,0.15);border-radius:6px;overflow:hidden;">
                <div style="width:40%;height:100%;background:{GOLD};border-radius:6px;"></div>
              </div>
              <span style="font-family:'Plex', sans-serif;font-size:19px;color:{GOLD};font-weight:700;">صفحة ٥٠ من ٦٠٤ (٤٠٪)</span>
            </div>
            <span style="font-family:'Plex', sans-serif;font-size:18px;color:#55BDB2;font-weight:600;">مزامنة سحابية فورية ✓</span>
          </div>
        </div>
        '''
    else:
        inner = ''

    html = f'''<!doctype html><html dir="rtl" lang="ar"><head><meta charset="utf-8"><style>
    {font_decl}
    * {{ margin:0; padding:0; box-sizing:border-box; }}
    body {{ width: {w}px; height: {h}px; overflow: hidden; background: {DEEP_BG}; font-family: 'Plex', sans-serif; }}
    </style></head><body>{inner}</body></html>'''
    render_html_to_image(html, w, h, out_png)

def render_ipad_landscape_header(gold, white, out_png):
    html = f'''<!doctype html><html dir="rtl" lang="ar"><head><meta charset="utf-8"><style>
@font-face {{ font-family: 'Changa'; src: url('file://{FONTS}/changa/Changa[wght].ttf'); font-weight: 700; }}
* {{ margin:0; padding:0; box-sizing:border-box; }}
body {{ width: 2752px; height: 2064px; overflow: hidden; background: transparent; font-family: 'Changa', sans-serif; -webkit-font-smoothing: antialiased; }}
.headline {{ position: absolute; top: 75px; right: 380px; left: 100px; text-align: center; line-height: 1.25; }}
.gold {{ color: #ECC87D; font-size: 88px; font-weight: 700; text-shadow: 0 4px 14px rgba(0,0,0,0.5); }}
.white {{ color: #FFFFFF; font-size: 44px; font-weight: 700; margin-top: 14px; opacity: 0.95; text-shadow: 0 3px 10px rgba(0,0,0,0.4); }}
</style></head><body>
<div class="headline"><div class="gold">{gold}</div><div class="white">{white}</div></div>
</body></html>'''
    render_html_to_image(html, 2752, 2064, out_png)

def render_ipad_portrait_header(gold, white, out_png):
    html = f'''<!doctype html><html dir="rtl" lang="ar"><head><meta charset="utf-8"><style>
@font-face {{ font-family: 'Changa'; src: url('file://{FONTS}/changa/Changa[wght].ttf'); font-weight: 700; }}
* {{ margin:0; padding:0; box-sizing:border-box; }}
body {{ width: 2064px; height: 2752px; overflow: hidden; background: transparent; font-family: 'Changa', sans-serif; -webkit-font-smoothing: antialiased; }}
.headline {{ position: absolute; top: 320px; left: 60px; width: 1944px; text-align: center; line-height: 1.25; }}
.gold {{ color: #ECC87D; font-size: 110px; font-weight: 700; text-shadow: 0 4px 14px rgba(0,0,0,0.5); }}
.white {{ color: #FFFFFF; font-size: 55px; font-weight: 700; margin-top: 16px; opacity: 0.95; text-shadow: 0 3px 10px rgba(0,0,0,0.4); }}
</style></head><body>
<div class="headline"><div class="gold">{gold}</div><div class="white">{white}</div></div>
</body></html>'''
    render_html_to_image(html, 2064, 2752, out_png)

LANDSCAPE_SCREENS = [
    {
        'num': '01',
        'type': 'spread_plain',
        'gold': 'مصحف بصفحتين متقابلتين',
        'white': 'تجربة قراءة رحبة ومطابقة تمامًا للمصحف الشريف المطبوع',
    },
    {
        'num': '02',
        'type': 'spread_audio',
        'gold': 'إستمع وأنت تقرأ بتزامن صوتي',
        'white': 'مشغل صوتي متقدم وتظليل الكلمات لحظة بلحظة لكبار القرّاء',
    },
    {
        'num': '03',
        'type': 'spread_qiraat',
        'gold': 'تأثيرات بصرية مع قلب الصفحات',
        'white': 'محاكاة واقعية لتقليب صفحات المصحف الشريف ثلاثية الأبعاد',
    },
    {
        'num': '04',
        'type': 'custom_tafsir',
        'gold': 'تعلّم وتدبّر مع التفسير',
        'white': 'تفسير ميسّر ومعاني المفردات وأسباب النزول على صفحات المصحف',
    },
    {
        'num': '05',
        'type': 'custom_tasmee',
        'gold': 'مصحح التلاوة والتسميع الذكي',
        'white': 'يعمل بلا إنترنت ويستمع لتلاوتك ويُنبّهك فورًا لكل خطأ',
    },
    {
        'num': '06',
        'type': 'spread_night',
        'gold': 'النمط الليلي الذهبي',
        'white': 'راحة تامة للعين في القراءة الليلية مع خطوط واضحة لكبار السن',
    },
    {
        'num': '07',
        'type': 'custom_hifz',
        'gold': 'وضع الحفظ وتثبيت الآيات',
        'white': 'إخفاء تفاعلي للآيات والكلمات لاختبار الحفظ ومتابعة مسيرة الختم',
    },
    {
        'num': '08',
        'type': 'custom_khatma',
        'gold': 'فواصل متعددة وتدوين الخواطر',
        'white': 'علامات مرجعية ملونة وتدوين الملاحظات ومتابعة تقدم الختمة',
    },
]

PORTRAIT_SCREENS = [
    {
        'num': '01',
        'type': 'img',
        'img': os.path.join(TMP_DIR, 'home.jpg'),
        'gold': 'واجهة حديثة مصممة للآيباد',
        'white': 'تصفح سلس ومباشر للقرآن الكريم والختمات والأدوات',
    },
    {
        'num': '02',
        'type': 'img_page',
        'img': os.path.join(SCREENS_DIR, 'page_50_ornate.png'),
        'gold': 'مصحف المدينة المنورة بحجم كبير',
        'white': 'قراءة فائقة الوضوح بإطار مذهب وزخارف ومطابقة كاملة للطباعة',
    },
    {
        'num': '03',
        'type': 'img',
        'img': os.path.join(SCREENS_DIR, '04_tafsir.png'),
        'gold': 'تفسير وبيان لمعاني الكلمات',
        'white': 'تفسير ميسّر مع إعراب فوري وأسباب النزول بلمسة واحدة',
    },
    {
        'num': '04',
        'type': 'img',
        'img': os.path.join(SCREENS_DIR, '01_listen.png'),
        'gold': 'تلاوة متزامنة مع كبار القرّاء',
        'white': 'إضاءة الكلمة المقروءة ومكتبة صوتية ضخمة بروايات متعددة',
    },
    {
        'num': '05',
        'type': 'img',
        'img': os.path.join(SCREENS_DIR, '02_tasmee.png'),
        'gold': 'نموذج تسميع ذكي',
        'white': 'يستمع لتلاوتك ويُصحح الأخطاء دون الحاجة للاتصال بالإنترنت',
    },
    {
        'num': '06',
        'type': 'img',
        'img': os.path.join(SCREENS_DIR, '08_tasbih.png'),
        'gold': 'مسبحة إلكترونية وأذكار',
        'white': 'تصاميم متعددة ومؤثرات اهتزازية مع باقة أذكار المسلم',
    },
    {
        'num': '07',
        'type': 'img',
        'img': os.path.join(SCREENS_DIR, '06_khatma.png'),
        'gold': 'ورد يومي وختمة',
        'white': 'تنظيم الورد وخيارات ختمات فردية وجماعية بدون مشاركة البيانات',
    },
    {
        'num': '08',
        'type': 'img',
        'img': os.path.join(SCREENS_DIR, '05_hifz.png'),
        'gold': 'رحلة ومسيرة الحفظ',
        'white': 'خريطة تفاعلية لمقدار حفظك ومتابعة التثبيت والمراجعة',
    },
]

def generate_ipad_landscape(logo_raw):
    std_dir = os.path.join(STORE_TEMPLATES, '2752x2064')
    alt_dir = os.path.join(STORE_TEMPLATES, '2732x2048')
    layers = os.path.join(std_dir, 'layers')
    
    bg = Image.open(os.path.join(layers, 'background.png')).convert('RGBA')
    frame = Image.open(os.path.join(layers, 'frame.png')).convert('RGBA')
    mask = Image.open(os.path.join(layers, 'screen_mask.png')).convert('RGBA')
    logo = logo_raw.resize((280, 204), Image.Resampling.LANCZOS)
    
    print("Generating iPad Landscape (2752x2064 & 2732x2048)...")
    for sc in LANDSCAPE_SCREENS:
        num = sc['num']
        sc_png = os.path.join(TMP_DIR, f'_ipad_sc_land_{num}.png')
        render_ipad_landscape_screen(sc['type'], sc_png, w=1921, h=1441)
            
        head_png = os.path.join(TMP_DIR, f'_ipad_head_land_{num}.png')
        render_ipad_landscape_header(sc['gold'], sc['white'], head_png)
        
        sc_img = Image.open(sc_png).convert('RGBA')
        sc_layer = Image.new('RGBA', (2752, 2064), (0, 0, 0, 0))
        sc_layer.paste(sc_img, (416, 492))
        sc_layer.putalpha(ImageChops.multiply(sc_layer.getchannel('A'), mask.getchannel('A')))
        
        res = bg.copy()
        res.alpha_composite(sc_layer)
        res.alpha_composite(frame)
        res.paste(logo, (2380, 50), logo)
        
        head_img = Image.open(head_png).convert('RGBA')
        res.alpha_composite(head_img)
        
        rgb = res.convert('RGB')
        dst_2752 = os.path.join(std_dir, f'{num}.jpg')
        rgb.save(dst_2752, quality=95)
        
        rgb_2732 = rgb.resize((2732, 2048), Image.Resampling.LANCZOS)
        dst_2732 = os.path.join(alt_dir, f'{num}.jpg')
        rgb_2732.save(dst_2732, quality=95)
        print(f"  ✓ Saved iPad Landscape {num}.jpg (2752x2064 & 2732x2048)")
        
        for p in [sc_png, head_png]:
            if os.path.exists(p): os.remove(p)

def generate_ipad_portrait(logo_raw):
    std_dir = os.path.join(STORE_TEMPLATES, '2064x2752')
    alt_dir = os.path.join(STORE_TEMPLATES, '2048x2732')
    layers = os.path.join(std_dir, 'layers')
    
    bg = Image.open(os.path.join(layers, 'background.png')).convert('RGBA')
    frame = Image.open(os.path.join(layers, 'frame.png')).convert('RGBA')
    mask = Image.open(os.path.join(layers, 'screen_mask.png')).convert('RGBA')
    logo = logo_raw.resize((320, 233), Image.Resampling.LANCZOS)
    
    print("Generating iPad Portrait (2064x2752 & 2048x2732)...")
    for sc in PORTRAIT_SCREENS:
        num = sc['num']
        sc_png = os.path.join(TMP_DIR, f'_ipad_sc_port_{num}.png')
        if sc['type'] == 'img_page':
            # Authentic full-bleed page with ornate border on cream paper
            src_im = Image.open(sc['img']).convert('RGBA')
            tw, th = 1434, 1913
            # Fit inside 1434x1913 with cream background
            page_canvas = Image.new('RGBA', (tw, th), (255, 253, 248, 255))
            ratio = min(tw / src_im.width, th / src_im.height)
            nw, nh = int(src_im.width * ratio), int(src_im.height * ratio)
            resized = src_im.resize((nw, nh), Image.Resampling.LANCZOS)
            page_canvas.paste(resized, ((tw - nw) // 2, (th - nh) // 2), resized)
            page_canvas.save(sc_png)
        else:
            # Crop/scale input image to 1434x1913
            src_im = Image.open(sc['img']).convert('RGBA')
            tw, th = 1434, 1913
            ratio = max(tw / src_im.width, th / src_im.height)
            nw, nh = int(src_im.width * ratio), int(src_im.height * ratio)
            resized = src_im.resize((nw, nh), Image.Resampling.LANCZOS)
            left = (nw - tw) // 2
            top = (nh - th) // 2
            cropped = resized.crop((left, top, left + tw, top + th))
            cropped.save(sc_png)
            
        head_png = os.path.join(TMP_DIR, f'_ipad_head_port_{num}.png')
        render_ipad_portrait_header(sc['gold'], sc['white'], head_png)
        
        sc_img = Image.open(sc_png).convert('RGBA')
        sc_layer = Image.new('RGBA', (2064, 2752), (0, 0, 0, 0))
        sc_layer.paste(sc_img, (315, 688))
        sc_layer.putalpha(ImageChops.multiply(sc_layer.getchannel('A'), mask.getchannel('A')))
        
        res = bg.copy()
        res.alpha_composite(sc_layer)
        res.alpha_composite(frame)
        res.paste(logo, ((2064 - 320) // 2, 60), logo)
        
        head_img = Image.open(head_png).convert('RGBA')
        res.alpha_composite(head_img)
        
        rgb = res.convert('RGB')
        dst_2064 = os.path.join(std_dir, f'{num}.jpg')
        rgb.save(dst_2064, quality=95)
        
        rgb_2048 = rgb.resize((2048, 2732), Image.Resampling.LANCZOS)
        dst_2048 = os.path.join(alt_dir, f'{num}.jpg')
        rgb_2048.save(dst_2048, quality=95)
        print(f"  ✓ Saved iPad Portrait {num}.jpg (2064x2752 & 2048x2732)")
        
        for p in [sc_png, head_png]:
            if os.path.exists(p): os.remove(p)

def main():
    logo_raw = Image.open(LOGO_SRC).convert('RGBA')
    generate_ipad_landscape(logo_raw)
    generate_ipad_portrait(logo_raw)
    print("\n✓ ALL 32 iPad 13\" & 12.9\" Screenshots Successfully Generated!")

if __name__ == '__main__':
    main()
