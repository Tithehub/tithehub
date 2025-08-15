// Self-heal: validate logo + QR assets; regenerate if broken; ensure JSONs sane.
import fs from 'fs';
import path from 'path';
import QRCode from 'qrcode';
import Jimp from 'jimp';

const root = process.cwd();
const SITE_BASE = (process.env.SITE_BASE_URL || 'https://tithehub.com').replace(/\/$/,'');
const orgDir = path.join(root, 'orgs');
const qrDir  = path.join(root, 'qrs');
const widDir = path.join(root, 'widgets');
const assetsDir = path.join(root, 'assets');

for (const d of [orgDir, qrDir, widDir, assetsDir]) {
  if (!fs.existsSync(d)) fs.mkdirSync(d, { recursive: true });
}

// Helpers
async function isPngReadable(bufOrPath) {
  try {
    const img = await Jimp.read(typeof bufOrPath === 'string' ? bufOrPath : bufOrPath);
    return img && img.bitmap && img.bitmap.width > 0;
  } catch {
    return false;
  }
}
function safeSlug(s) {
  return String(s || '')
   .toLowerCase().normalize('NFKD').replace(/[\u0300-\u036f]/g,'')
   .replace(/[^a-z0-9]+/g,'-').replace(/^-+|-+$/g,'');
}
function orgJsonPath(slug){ return path.join(orgDir, `${slug}.json`); }
function widgetPath(slug){ return path.join(widDir, `${slug}.js`); }
function qrPath(slug){ return path.join(qrDir, `${slug}.png`); }

// 1×1 transparent fallback logo
const FALLBACK_LOGO_PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAAWgmWQ0AAAAASUVORK5CYII=','base64');

// Ensure logo exists/valid
const logoFile = path.join(assetsDir,'tithehub-logo.png');
if (!fs.existsSync(logoFile) || !(await isPngReadable(logoFile))) {
  fs.writeFileSync(logoFile, FALLBACK_LOGO_PNG);
  console.log('⚠️  assets/tithehub-logo.png was missing/bad — wrote fallback.');
}

// Read repository_dispatch payload if present
let payload = {};
try {
  const eventPath = process.env.GITHUB_EVENT_PATH;
  if (eventPath && fs.existsSync(eventPath)) {
    const ev = JSON.parse(fs.readFileSync(eventPath,'utf8'));
    payload = ev.client_payload || {};
  }
} catch {}

// Upsert one org (JSON, QR with centered logo, widget)
async function upsertOrg(p) {
  const slug = safeSlug(p.slug || p.name || '');
  if (!slug) return;
  const donateUrl = `${SITE_BASE}/donate/${slug}`;
  const record = {
    slug,
    name: p.name,
    email: p.email,
    orgWebsite: p.orgWebsite,
    stripeMonthlyLink: p.stripeMonthlyLink,
    stripeAnnualLink: p.stripeAnnualLink,
    crypto: { BTC: p.cryptoBTC, ETH: p.cryptoETH, USDT: p.cryptoUSDT },
    notes: p.notes,
    donateUrl,
    qrUrl: `${SITE_BASE}/qrs/${slug}.png`,
    updatedAt: new Date().toISOString()
  };
  fs.writeFileSync(orgJsonPath(slug), JSON.stringify(record,null,2));

  // QR generate (with centered logo)
  const qrData = `${donateUrl}?ref=${slug}`;
  const qrBuf = await QRCode.toBuffer(qrData, { errorCorrectionLevel:'H', margin:2, scale:12 });
  const qrImg = await Jimp.read(qrBuf);
  const logoImg = await Jimp.read(logoFile);
  const logoTargetW = Math.round(qrImg.bitmap.width * 0.22);
  logoImg.scale(logoTargetW / logoImg.bitmap.width);
  const x = (qrImg.bitmap.width - logoImg.bitmap.width) >> 1;
  const y = (qrImg.bitmap.height - logoImg.bitmap.height) >> 1;
  qrImg.composite(logoImg, x, y);
  await qrImg.writeAsync(qrPath(slug));

  // Widget
  const widgetJs = `(function(){var d=document;function r(f){if(d.readyState!=='loading'){f()}else d.addEventListener('DOMContentLoaded',f)}r(function(){var c=d.createElement('div');c.style.maxWidth='420px';c.style.margin='0 auto';c.style.border='1px solid #eee';c.style.borderRadius='12px';c.style.padding='16px';c.style.boxShadow='0 6px 20px rgba(0,0,0,.07)';var h=d.createElement('h3');h.textContent=${JSON.stringify(p.name||'Donate')};h.style.marginTop='0';c.appendChild(h);var a=d.createElement('a');a.href=${JSON.stringify(donateUrl)};a.target='_blank';a.rel='noopener';a.textContent='Open donation page';a.style.display='inline-block';a.style.padding='10px 14px';a.style.border='1px solid #ccc';a.style.borderRadius='8px';a.style.textDecoration='none';c.appendChild(a);var img=d.createElement('img');img.src=${JSON.stringify(`${SITE_BASE}/qrs/${safeSlug(slug)}.png`)};img.alt='Donation QR';img.style.display='block';img.style.width='100%';img.style.maxWidth='360px';img.style.margin='12px auto 0';c.appendChild(img);(document.currentScript&&document.currentScript.parentNode||d.body).appendChild(c);});})();`;
  fs.writeFileSync(widgetPath(slug), widgetJs);

  console.log('✅ Upserted org:', slug);
}

if (payload && (payload.name || payload.slug)) {
  await upsertOrg(payload);
}

// Heal/verify all QRs from orgs/
const bad = [];
if (!(await isPngReadable(logoFile))) { fs.writeFileSync(logoFile, FALLBACK_LOGO_PNG); bad.push('assets/tithehub-logo.png'); }

if (fs.existsSync(orgDir)) {
  for (const f of fs.readdirSync(orgDir)) {
    if (!f.endsWith('.json')) continue;
    try {
      const o = JSON.parse(fs.readFileSync(path.join(orgDir,f),'utf8'));
      const slug = o.slug || safeSlug(o.name);
      if (!slug) continue;
      const qp = qrPath(slug);
      if (!fs.existsSync(qp) || !(await isPngReadable(qp))) {
        console.log('⚠️  Regenerating QR for', slug);
        await upsertOrg(o);
        bad.push(`qrs/${slug}.png`);
      }
    } catch(e) {
      console.log('⚠️  Bad org JSON:', f, e.message);
    }
  }
}

if (bad.length) {
  console.log('🛠  Healed assets:', bad.join(', '));
} else {
  console.log('✔️  All assets look good.');
}
