// node render_frames.mjs spec.json outdir -> outdir/00000.jpg.. one frame per 1/fps (headless Chrome over CDP)
// Adapted from the hclinic reels-kit stills.mjs: same CDP approach, but deterministic per-frame time.
import fs from 'fs'; import path from 'path'; import { spawn } from 'child_process';
const [specPath, out] = process.argv.slice(2);
const spec = JSON.parse(fs.readFileSync(specPath, 'utf8')); fs.mkdirSync(out, { recursive: true });
const CHROME = process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const port = 9000 + Math.floor(Math.random() * 900);
const prof = fs.mkdtempSync(path.join(path.dirname(path.resolve(specPath)), 'chrome-'));
const ch = spawn(CHROME, ['--headless=new', `--remote-debugging-port=${port}`, `--user-data-dir=${prof}`,
  '--allow-file-access-from-files', '--hide-scrollbars', '--force-color-profile=srgb', 'about:blank'], { stdio: 'ignore' });
let t; for (let i = 0; i < 50; i++) { try { t = await (await fetch(`http://127.0.0.1:${port}/json/new?about:blank`, { method: 'PUT' })).json(); break; } catch { await new Promise(r => setTimeout(r, 200)); } }
const ws = new WebSocket(t.webSocketDebuggerUrl); await new Promise(r => ws.onopen = r);
let id = 0; const pend = new Map(); ws.onmessage = e => { const m = JSON.parse(e.data); if (m.id && pend.has(m.id)) { pend.get(m.id)(m); pend.delete(m.id); } };
const send = (method, params = {}) => new Promise(r => { const i = ++id; pend.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });
const ev = async expr => { const r = await send('Runtime.evaluate', { expression: expr, awaitPromise: true, returnByValue: true }); if (r.result?.exceptionDetails) throw new Error(JSON.stringify(r.result.exceptionDetails).slice(0, 400)); return r.result?.result?.value; };
await send('Page.enable');
await send('Emulation.setDeviceMetricsOverride', { width: 1080, height: 1920, deviceScaleFactor: 1, mobile: false });
await send('Page.navigate', { url: 'file://' + path.resolve(path.dirname(new URL(import.meta.url).pathname), spec.template || 'ayah_reel.html') });
await new Promise(r => setTimeout(r, 800));
const ok = await ev(`setup(${JSON.stringify(spec)})`);
if (ok !== true) { console.error('setup failed:', ok); process.exit(1); }
const n = Math.round(spec.total * spec.fps);
for (let f = 0; f < n; f++) {
  await ev(`frame(${f / spec.fps})`);
  const s = await send('Page.captureScreenshot', { format: 'jpeg', quality: 94, captureBeyondViewport: false });
  fs.writeFileSync(path.join(out, String(f).padStart(5, '0') + '.jpg'), Buffer.from(s.result.data, 'base64'));
  if (f % 150 === 0) process.stdout.write(`${f}/${n}\n`);
}
ws.close(); const gone = new Promise(r => ch.on('exit', r)); ch.kill(); await gone;
try { fs.rmSync(prof, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 }); } catch {}
