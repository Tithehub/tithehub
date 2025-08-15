import fs from 'fs';
import path from 'path';
import QRCode from 'qrcode';
import Jimp from 'jimp';
import slugify from 'slugify';

const repoRoot = process.cwd();
const siteBase = (process.env.SITE_BASE_URL || '').replace(/\/$/, '');
const eventPath = process.env.GITHUB_EVENT_PATH;

// Allow local dev with payload.json
let payload = {};
if (eventPath && fs.existsSync(eventPath)) {
  const event = JSON.parse(fs.readFileSync(eventPath, 'utf8'));
  payload = event.client_payload || {};
} else if (fs.existsSync('payload.json')) {
  payload = JSON.parse(fs.readFileSync('payload.json', 'utf8'));
} else {
  console.error('No client_payload found. Provide payload.json for local run or run via repository_dispatch.');
  process.exit(1);
}

function makeSlug(s) {
  return slugify(String(s || '').trim(), { lower: true, strict: true });
}

(async () => {
  const {
    name,
    email,
    orgWebsite,
    stripeMonthlyLink,
    stripeAnnualLink,
    cryptoBTC,
    cryptoETH,
    cryptoUSDT,
    notes,
    slug: providedSlug
  } = payload;

  const slug = providedSlug || makeSlug(name);
  if (!slug) throw new Error('Missing org name/slug');

  // Folders
  const orgDir = path.join(repoRoot, 'orgs');
  const qrDir  = path.join(repoRoot, 'qrs');
  const widDir = path.join(repoRoot, 'widgets');
  [orgDir, qrDir, widDir].forEach(d => fs.existsSync(d) || fs.mkdirSync(d, { recursive: true }));

  // URLs
  const donateUrl = `${siteBase}/donate/${slug}`;
  const qrUrl = `${siteBase}/qrs/${slug}.png`;

  // 1) Org JSON
  const record = {
    slug,
    name,
    email,
    orgWebsite,
    stripeMonthlyLink,
    stripeAnnualLink,
    crypto: { BTC: cryptoBTC, ETH: cryptoETH, USDT: cryptoUSDT },
    notes,
    donateUrl,
    qrUrl,
    updatedAt: new Date().toISOString()
  };
  fs.writeFileSync(path.join(orgDir, `${slug}.json`), JSON.stringify(record, null, 2));

  // 2) QR with centered logo
  const qrData = `${donateUrl}?ref=${slug}`;
  const qrPngBuffer = await QRCode.toBuffer(qrData, {
    errorCorrectionLevel: 'H',
    margin: 2,
    scale: 12
  });

  const qrImg = await Jimp.read(qrPngBuffer);
  const logoPath = path.join(repoRoot, 'assets', 'tithehub-logo.png');
  const logoImg = await Jimp.read(logoPath);

  const logoTargetW = Math.round(qrImg.bitmap.width * 0.22);
  const scale = logoTargetW / logoImg.bitmap.width;
  logoImg.scale(scale);

  const x = Math.floor((qrImg.bitmap.width - logoImg.bitmap.width) / 2);
  const y = Math.floor((qrImg.bitmap.height - logoImg.bitmap.height) / 2);
  qrImg.composite(logoImg, x, y);

  await qrImg.writeAsync(path.join(qrDir, `${slug}.png`));

  // 3) Per‑org embeddable widget
  const widgetJs = `
(function(){
  var d=document;
  function ready(fn){ if(d.readyState!=='loading'){fn();} else {d.addEventListener('DOMContentLoaded',fn);} }
  ready(function(){
    var container = d.createElement('div');
    container.style.maxWidth='420px';
    container.style.margin='0 auto';
    container.style.border='1px solid #eee';
    container.style.borderRadius='12px';
    container.style.padding='16px';
    container.style.boxShadow='0 6px 20px rgba(0,0,0,0.07)';

    var h=d.createElement('h3'); h.textContent=${JSON.stringify(name || 'Donate')}; h.style.marginTop='0'; container.appendChild(h);

    var a=d.createElement('a');
    a.href=${JSON.stringify(donateUrl)};
    a.target='_blank';
    a.rel='noopener';
    a.textContent='Open donation page';
    a.style.display='inline-block';
    a.style.padding='10px 14px';
    a.style.border='1px solid #ccc';
    a.style.borderRadius='8px';
    a.style.textDecoration='none';
    container.appendChild(a);

    var img=d.createElement('img');
    img.src=${JSON.stringify(qrUrl)};
    img.alt='Donation QR';
    img.style.display='block';
    img.style.width='100%';
    img.style.maxWidth='360px';
    img.style.margin='12px auto 0';
    container.appendChild(img);

    (document.currentScript && document.currentScript.parentNode || d.body).appendChild(container);
  });
})();
  `.trim();
  fs.writeFileSync(path.join(widDir, `${slug}.js`), widgetJs);

  console.log('Generated org, QR, widget for slug:', slug);
})();
