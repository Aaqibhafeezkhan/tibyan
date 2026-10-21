// node stills.mjs layers.json outdir -> one transparent PNG per layer of feature_reel.html (headless Chrome over CDP)
// From the hclinic reels-kit stills.mjs; launches its own Chrome like render_frames.mjs.
import fs from 'fs'; import path from 'path'; import { spawn } from 'child_process';
const [spec, out] = process.argv.slice(2); const layers = JSON.parse(fs.readFileSync(spec, 'utf8')); fs.mkdirSync(out, { recursive: true });
const CHROME = process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const port = 9000 + Math.floor(Math.random() * 900);
const prof = fs.mkdtempSync(path.join(path.resolve(out), 'chrome-'));
const ch = spawn(CHROME, ['--headless=new', `--remote-debugging-port=${port}`, `--user-data-dir=${prof}`,
  '--allow-file-access-from-files', '--hide-scrollbars', '--force-color-profile=srgb', 'about:blank'], { stdio: 'ignore' });
let t; for (let i = 0; i < 50; i++) { try { t = await (await fetch(`http://127.0.0.1:${port}/json/new?about:blank`, { method: 'PUT' })).json(); break; } catch { await new Promise(r => setTimeout(r, 200)); } }
const ws = new WebSocket(t.webSocketDebuggerUrl); await new Promise(r => ws.onopen = r);
let id = 0; const pend = new Map(); ws.onmessage = e => { const m = JSON.parse(e.data); if (m.id && pend.has(m.id)) { pend.get(m.id)(m); pend.delete(m.id); } };
const send = (method, params = {}) => new Promise(r => { const i = ++id; pend.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });
await send('Page.enable'); await send('Emulation.setDefaultBackgroundColorOverride', { color: { r: 0, g: 0, b: 0, a: 0 } });
await send('Page.navigate', { url: 'file://' + path.resolve(path.dirname(new URL(import.meta.url).pathname), 'feature_reel.html') }); await new Promise(r => setTimeout(r, 1000));
let bad = 0;
for (const L of layers) {
  await send('Emulation.setDeviceMetricsOverride', { width: L.W, height: L.H, deviceScaleFactor: 1, mobile: false });
  const r = await send('Runtime.evaluate', { expression: `draw(${JSON.stringify(L)})`, awaitPromise: true, returnByValue: true });
  if (r.result?.result?.value !== true) { bad++; console.error('font not loaded:', L.name, JSON.stringify(r.result).slice(0, 200)); }
  const s = await send('Page.captureScreenshot', { format: 'png', clip: { x: 0, y: 0, width: L.W, height: L.H, scale: 1 } });
  fs.writeFileSync(`${out}/${L.name}.png`, Buffer.from(s.result.data, 'base64'));
}
ws.close(); const gone = new Promise(r => ch.on('exit', r)); ch.kill(); await gone;
try { fs.rmSync(prof, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 }); } catch {}
process.exit(bad ? 1 : 0);
