import fs from 'fs';
import path from 'path';
import Jimp from 'jimp';

const ROOT = process.cwd();
const CANDIDATE_DIRS = ['assets','qrs','qr']; // cover both new and old folders
const FALLBACK = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAAWgmWQ0AAAAASUVORK5CYII=','base64');

async function readablePng(p){
  try { const img = await Jimp.read(p); return img?.bitmap?.width > 0; }
  catch { return false; }
}

let repaired = [];

for (const d of CANDIDATE_DIRS) {
  const dir = path.join(ROOT,d);
  if (!fs.existsSync(dir)) continue;
  for (const f of fs.readdirSync(dir)) {
    if (!f.toLowerCase().endsWith('.png')) continue;
    const p = path.join(dir,f);
    try {
      const ok = await readablePng(p);
      if (!ok) {
        fs.writeFileSync(p, FALLBACK);
        repaired.push(`${d}/${f}`);
      }
    } catch {
      fs.writeFileSync(p, FALLBACK);
      repaired.push(`${d}/${f}`);
    }
  }
}

const logo = path.join(ROOT,'assets','tithehub-logo.png');
if (!fs.existsSync(path.dirname(logo))) fs.mkdirSync(path.dirname(logo), {recursive:true});
if (!fs.existsSync(logo) || !(await readablePng(logo))) {
  fs.writeFileSync(logo, FALLBACK);
  repaired.push('assets/tithehub-logo.png');
}

if (repaired.length) {
  console.log('🛠 Repaired PNGs:\n - ' + repaired.join('\n - '));
} else {
  console.log('✔️ No unreadable PNGs found.');
}
