// usage: node render.mjs <outdir> <query e.g. f=reel&c=30> [only times]
import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
const HERE = dirname(fileURLToPath(import.meta.url));
const [out, qs, only] = process.argv.slice(2);
const fps = 30; const H = qs.includes('f=feed') ? 1350 : 1920;
mkdirSync(out, { recursive: true });
const CH = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const port = 9300 + Math.floor(Math.random() * 500);
const ch = spawn(CH, ['--headless=new', `--remote-debugging-port=${port}`, '--hide-scrollbars', '--allow-file-access-from-files', '--autoplay-policy=no-user-gesture-required',
  '--force-device-scale-factor=1', `--window-size=1080,${H}`, `--user-data-dir=/tmp/tourchrome${port}`, 'about:blank']);
let tabs;
for (let i = 0; i < 50; i++) { try { tabs = await (await fetch(`http://127.0.0.1:${port}/json`)).json(); break; } catch { await new Promise(r => setTimeout(r, 200)); } }
const ws = new WebSocket(tabs.find(t => t.type === 'page').webSocketDebuggerUrl);
await new Promise(r => ws.onopen = r);
let id = 0; const pend = {};
ws.onmessage = m => { const d = JSON.parse(m.data); if (d.id && pend[d.id]) { pend[d.id](d); delete pend[d.id]; } };
const call = (method, params = {}) => new Promise(r => { const i = ++id; pend[i] = r; ws.send(JSON.stringify({ id: i, method, params })); });
await call('Emulation.setDeviceMetricsOverride', { width: 1080, height: H, deviceScaleFactor: 1, mobile: false });
await call('Page.enable');
await call('Page.navigate', { url: 'file://' + join(HERE, 'tour.html') + '?' + qs });
await new Promise(r => setTimeout(r, 2500));
await call('Runtime.evaluate', { expression: 'Promise.all([document.fonts.ready, window.ready])', awaitPromise: true });
const total = (await call('Runtime.evaluate', { expression: 'TOTAL', returnByValue: true })).result.result.value;
const times = only ? only.split(',').map(Number) : Array.from({ length: Math.round(total * fps) }, (_, i) => i / fps);
let n = 0;
for (const t of times) {
  const r0 = await call('Runtime.evaluate', { expression: `render(${t})`, awaitPromise: true });
  if (r0.result.exceptionDetails) console.log(JSON.stringify(r0.result.exceptionDetails).slice(0, 300));
  const r = await call('Page.captureScreenshot', { format: only ? 'png' : 'jpeg', quality: 92 });
  writeFileSync(join(out, only ? `t_${t}.png` : `f_${String(n).padStart(4, '0')}.jpg`), Buffer.from(r.result.data, 'base64'));
  n++;
}
ws.close(); ch.kill(); console.log('frames', n, 'total', total);
