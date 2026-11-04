// The phone's data on the watch (docs/HUAWEI-WATCH.md). One-way: the phone
// sends, the watch only receives and keeps the last state in storage, so it
// still shows «ورد اليوم» while the phone app is closed. The misbaha counts
// on the watch alone and never sends anything to the phone.
// Same keys as the Wear OS app's WatchData.kt: portion_/surah_/from_/to_<day>,
// progress, idle, tasbih_dhikr, tasbih_target, tasbih_stages, tasbih_stage_texts.
// Every text shown comes from the phone; nothing here writes Quran text.
import storage from '@system.storage';
import { P2pClient } from './wearengine';

// The phone app: package and the SHA-256 fingerprint of its AppGallery
// signing certificate (a public id). Ahmed fills it in (docs/HUAWEI-WATCH.md).
const PHONE_PACKAGE = 'app.tibyan.tibyan';
const PHONE_FINGERPRINT = '';

const p2p = new P2pClient();
p2p.setPeerPkgName(PHONE_PACKAGE);
p2p.setPeerFingerPrint(PHONE_FINGERPRINT);

const cache = { state: {}, session: 0, loaded: false };

function pad(n) { return n < 10 ? '0' + n : '' + n; }

export function dayKey() {
  const d = new Date();
  return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate());
}

function save(key, value) {
  storage.set({ key: key, value: '' + value });
}

/** Loads what the phone sent last time and the count, then calls [then]. */
export function load(then) {
  if (cache.loaded) { then(); return; }
  let left = 2;
  const done = () => { left -= 1; if (left === 0) { cache.loaded = true; then(); } };
  storage.get({ key: 'state', default: '{}',
    success: (v) => { try { cache.state = JSON.parse(v); } catch (e) { cache.state = {}; } },
    complete: done });
  storage.get({ key: 'session', default: '0',
    success: (v) => { cache.session = parseInt(v, 10) || 0; }, complete: done });
}

export function value(key) {
  const v = cache.state[key];
  return v === undefined || v === null ? '' : '' + v;
}

export function hasData() { return Object.keys(cache.state).length > 0; }

/** Today's portion as the screens show it, or null. */
export function wird() {
  const k = dayKey();
  const portion = value('portion_' + k);
  if (!portion) return null;
  const from = parseInt(value('from_' + k), 10);
  const to = parseInt(value('to_' + k), 10);
  return { surah: value('surah_' + k), from: isNaN(from) ? null : from,
    to: isNaN(to) ? null : to, portion: portion };
}

export function percent() {
  const p = parseInt(value('progress'), 10);
  return isNaN(p) ? 0 : Math.max(0, Math.min(100, p));
}

/** Where [session] stands in the current dhikr (WatchData.tasbih on Wear OS). */
export function tasbih(session) {
  const texts = value('tasbih_stage_texts').split('\n').filter((t) => t.trim() !== '');
  const stages = value('tasbih_stages').split(',')
    .map((s) => parseInt(s.trim(), 10)).filter((n) => !isNaN(n) && n > 0);
  const dhikr = value('tasbih_dhikr');
  if (stages.length > 0) {
    const total = stages.reduce((a, b) => a + b, 0);
    let n = session % total;
    if (n === 0 && session > 0) n = total;
    let i = 0;
    while (i < stages.length - 1 && n > stages[i]) { n -= stages[i]; i += 1; }
    return { label: texts[i] || dhikr, count: n, target: stages[i], stage: i + 1, stages: stages.length };
  }
  const target = parseInt(value('tasbih_target'), 10) || 0;
  if (target <= 0) return { label: dhikr, count: session, target: 0, stage: 0, stages: 0 };
  let n = session % target;
  if (n === 0 && session > 0) n = target;
  return { label: dhikr, count: n, target: target, stage: 0, stages: 0 };
}

export function session() { return cache.session; }

/** One count, kept on the watch only. */
export function count() {
  cache.session += 1;
  save('session', cache.session);
  return cache.session;
}

export function reset() {
  cache.session = 0;
  save('session', 0);
}

/** Keeps the phone's pushes; [changed] redraws the page. */
export function listen(changed) {
  if (!PHONE_FINGERPRINT) return;
  p2p.registerReceiver({
    onSuccess: () => {},
    onFailure: () => {},
    onReceiveMessage: (data) => {
      if (!data || data.isFileType) return;
      let next;
      try { next = JSON.parse(data); } catch (e) { return; }
      if (!next || Object.keys(next).length === 0) return;
      cache.state = next;
      storage.set({ key: 'state', value: data });
      changed();
    },
  });
}

export function stopListening() {
  if (PHONE_FINGERPRINT) p2p.unregisterReceiver({ onSuccess: () => {} });
}

/** Western digits to Arabic-Indic for Arabic, as the phone shows them. */
export function number(n, arabic) {
  const s = '' + n;
  if (!arabic) return s;
  const map = '٠١٢٣٤٥٦٧٨٩';
  let out = '';
  for (let i = 0; i < s.length; i++) {
    const c = s.charCodeAt(i) - 48;
    out += c >= 0 && c <= 9 ? map[c] : s[i];
  }
  return out;
}
