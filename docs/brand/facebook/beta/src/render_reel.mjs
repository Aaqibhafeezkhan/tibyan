// Render reel.html frame-by-frame via Chrome DevTools Protocol → frames/*.png
// usage: node render_reel.mjs <outdir> [fps=30] [dur=28] [only times comma-list]
import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
const HERE = dirname(fileURLToPath(import.meta.url));
const [out, fps = 30, dur = 28, only] = process.argv.slice(2);
mkdirSync(out, { recursive: true });
const CH = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const port = 9341;
const ch = spawn(CH, ['--headless=new', `--remote-debugging-port=${port}`, '--hide-scrollbars', '--allow-file-access-from-files',
  '--force-device-scale-factor=1', '--window-size=1080,1920', `--user-data-dir=/tmp/reelchrome`, 'about:blank']);
let tabs;
for (let i = 0; i < 50; i++) { try { tabs = await (await fetch(`http://127.0.0.1:${port}/json`)).json(); break; } catch { await new Promise(r => setTimeout(r, 200)); } }
const ws = new WebSocket(tabs.find(t => t.type === 'page').webSocketDebuggerUrl);
await new Promise(r => ws.onopen = r);
let id = 0; const pend = {};
ws.onmessage = m => { const d = JSON.parse(m.data); if (d.id && pend[d.id]) { pend[d.id](d); delete pend[d.id]; } };
const call = (method, params = {}) => new Promise(r => { const i = ++id; pend[i] = r; ws.send(JSON.stringify({ id: i, method, params })); });
await call('Emulation.setDeviceMetricsOverride', { width: 1080, height: 1920, deviceScaleFactor: 1, mobile: false });
await call('Page.enable');
await call('Page.navigate', { url: 'file://' + join(HERE, 'reel.html') });
await new Promise(r => setTimeout(r, 2500));
await call('Runtime.evaluate', { expression: 'document.fonts.ready', awaitPromise: true });
const times = only ? only.split(',').map(Number) : Array.from({ length: Math.round(dur * fps) }, (_, i) => i / fps);
let n = 0;
for (const t of times) {
  await call('Runtime.evaluate', { expression: `render(${t})` });
  const r = await call('Page.captureScreenshot', { format: 'png' });
  writeFileSync(join(out, only ? `t_${t}.png` : `f_${String(n).padStart(4, '0')}.png`), Buffer.from(r.result.data, 'base64'));
  n++;
}
ws.close(); ch.kill(); console.log('frames', n);
