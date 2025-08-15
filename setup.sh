# ==== TitheHub Autonomous Agent: One-shot Installer (Tithehub/tithehub) ====
set -e

# --- Locked to your repo/domain ---
OWNER="Tithehub"
REPO="tithehub"
SITE_BASE_URL="https://tithehub.com"
# ----------------------------------

mkdir -p .github/workflows scripts orgs qrs widgets assets donate

# package.json
cat > package.json <<'JSON'
{
  "name": "tithehub",
  "private": true,
  "type": "module",
  "scripts": {
    "generate": "node scripts/generate_assets.mjs"
  },
  "dependencies": {
    "jimp": "^0.22.12",
    "qrcode": "^1.5.3",
    "slugify": "^1.6.6"
  }
}
JSON

# Node generator: org JSON, QR with centered logo, per-org widget
cat > scripts/generate_assets.mjs <<'JS'
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
JS

# GitHub Action: generate assets on repository_dispatch
cat > .github/workflows/generate-assets.yml <<'YAML'
name: Generate referral assets
on:
  repository_dispatch:
    types: [tithehub_referral_created]
permissions:
  contents: write
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'
      - name: Install deps
        run: npm ci
      - name: Generate assets
        env:
          SITE_BASE_URL: ${{ vars.SITE_BASE_URL }}
          GITHUB_EVENT_PATH: ${{ github.event_path }}
        run: node scripts/generate_assets.mjs
      - name: Commit & push changes
        uses: EndBug/add-and-commit@v9
        with:
          author_name: tithehub-bot
          author_email: bot@tithehub.com
          message: "chore: add org, QR, widget from dispatch"
          add: "."
YAML

# GitHub Action: deploy Pages on push to main
cat > .github/workflows/pages.yml <<'YAML'
name: Deploy Pages
on:
  push:
    branches: [ main ]
permissions:
  contents: read
  pages: write
  id-token: write
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/upload-pages-artifact@v3
        with:
          path: .
  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/deploy-pages@v4
YAML

# Donation router page
cat > donate/index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <title>TitheHub — Donate</title>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <style>
    body { font-family: Inter, system-ui, -apple-system, Segoe UI, Roboto, sans-serif; margin:0; }
    .wrap { max-width: 960px; margin: 0 auto; padding: 24px; }
    .card { border:1px solid #eee; border-radius:16px; padding:24px; box-shadow:0 6px 24px rgba(0,0,0,.06); }
    .grid { display:grid; gap:16px; grid-template-columns: 1fr; }
    .row { display:flex; gap:12px; flex-wrap:wrap; align-items:center; }
    .btn { display:inline-block; padding:10px 14px; border-radius:10px; border:1px solid #ccc; text-decoration:none; }
    img.qr { width:100%; max-width:360px; border-radius:10px; }
    @media (min-width: 800px){ .grid { grid-template-columns: 1fr 360px; } }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="card">
      <div id="content" class="grid">
        <div>
          <h1 id="orgName">Loading…</h1>
          <p id="orgDesc">Please wait while we load this organization.</p>
          <div class="row" id="ctaRow"></div>
          <h3>Crypto addresses</h3>
          <ul id="cryptoList"></ul>
        </div>
        <div>
          <img id="qrImg" class="qr" alt="Donation QR"/>
        </div>
      </div>
    </div>
  </div>

  <script>
    (async function(){
      const parts = location.pathname.replace(/\/+$/,'').split('/donate/');
      const base = parts[0];
      const slug = (parts[1]||'').split('/').pop();
      const jsonUrl = base + '/orgs/' + slug + '.json';
      try{
        const org = await (await fetch(jsonUrl, {cache:'no-store'})).json();
        document.title = 'Donate — ' + (org.name || slug);
        document.getElementById('orgName').textContent = org.name || slug;
        document.getElementById('orgDesc').textContent = org.notes || 'Support our mission.';
        document.getElementById('qrImg').src = org.qrUrl;

        const row = document.getElementById('ctaRow');
        function btn(href, text){
          const a = document.createElement('a');
          a.className='btn';
          a.href=href; a.target='_blank'; a.rel='noopener'; a.textContent=text;
          row.appendChild(a);
        }
        if(org.stripeMonthlyLink) btn(org.stripeMonthlyLink, 'Give Monthly');
        if(org.stripeAnnualLink) btn(org.stripeAnnualLink, 'Give Annually');
        if(org.orgWebsite) btn(org.orgWebsite, 'Visit Website');

        const ul = document.getElementById('cryptoList');
        for(const [k,v] of Object.entries(org.crypto || {})){
          if(!v) continue;
          const li = document.createElement('li');
          li.textContent = k + ': ' + v;
          ul.appendChild(li);
        }
      }catch(e){
        document.getElementById('orgName').textContent = 'Not Found';
        document.getElementById('orgDesc').textContent = 'This donation page does not exist.';
      }
    })();
  </script>
</body>
</html>
HTML

# Widget template (placeholder; per-org widgets are generated)
cat > widgets/template.js <<'JS'
// Usage:
// <script src="https://tithehub.com/widgets/SLUG.js" async></script>
JS

# Tiny placeholder logo (replace with your gold crucifix PNG)
base64 -d > assets/tiny.png <<'B64'
iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAAWgmWQ0AAAAASUVORK5CYII=
B64
cp assets/tiny.png assets/tithehub-logo.png

# Demo payload using your BTC address for quick local test
cat > payload.json <<'JSON'
{
  "name": "TitheHub Demo Church",
  "email": "demo@tithehub.com",
  "orgWebsite": "https://tithehub.com",
  "stripeMonthlyLink": "https://buy.stripe.com/test_monthly_link",
  "stripeAnnualLink": "https://buy.stripe.com/test_annual_link",
  "cryptoBTC": "37LoinW7gvJEYGigZAHCeRdL84iwjkcEY5",
  "cryptoETH": "0x0000000000000000000000000000000000000000",
  "cryptoUSDT": "",
  "notes": "Thank you for supporting our mission.",
  "slug": "tithehub-demo-church"
}
JSON

# .gitignore
cat > .gitignore <<'TXT'
node_modules
.DS_Store
TXT

# README
cat > README.md <<TXT
# TitheHub Autonomous Agent (Pages + QR + Widgets)

- SITE_BASE_URL currently set to: ${SITE_BASE_URL}
- Replace \`assets/tithehub-logo.png\` with your square transparent logo (e.g. 512x512).
- In GitHub repo Settings → Pages: set your custom domain (${SITE_BASE_URL}) if desired.
- In GitHub repo Settings → Variables → Actions: add \`SITE_BASE_URL\` = ${SITE_BASE_URL}

## Local Test
1) npm i
2) SITE_BASE_URL=${SITE_BASE_URL} npm run generate
3) Open ${SITE_BASE_URL}/donate/tithehub-demo-church (once deployed to Pages or your server)

## Live Automation
Use the Google Apps Script printed below (GOOGLE_APPS_SCRIPT_PASTE_ME.txt) to dispatch payloads after Google Form submissions or via its Web App endpoint.
TXT

# Google Apps Script (print to file for copy-paste)
cat > GOOGLE_APPS_SCRIPT_PASTE_ME.txt <<TXT
/*** Google Apps Script for TitheHub Automation (Tithehub/tithehub)

SETUP
1) Open your Google Form's Spreadsheet → Extensions → Apps Script.
2) Paste this entire code.
3) Script Properties → add key "GITHUB_PAT" with your GitHub Personal Access Token (scope: repo:public_repo).
4) OWNER = "Tithehub", REPO = "tithehub" are set below.
5) Deploy → "Deploy as web app" (execute as you; anyone with link can access). Copy the Web App URL.

— Expected Sheet Columns (edit if different):
  Name / Organisation Name, Email, Website, Stripe Monthly Link, Stripe Annual Link,
  BTC Address, ETH Address, USDT Address, Notes

*** SECURITY ***
Do NOT put your PAT in repo files. Only store it in Script Properties.

************************************************************/

const OWNER = "Tithehub";
const REPO  = "tithehub";
const DISPATCH_EVENT = "tithehub_referral_created";
const SITE_BASE_URL = "https://tithehub.com";

function slugify(s){
  return String(s || '')
    .toLowerCase()
    .normalize('NFKD').replace(/[\\u0300-\\u036f]/g, '')
    .replace(/[^a-z0-9]+/g,'-')
    .replace(/^-+|-+$/g,'');
}

function dispatchToGithub(payload){
  const pat = PropertiesService.getScriptProperties().getProperty('GITHUB_PAT'); // <-- add your token in Script Properties
  if(!pat) throw new Error("Missing GITHUB_PAT in Script Properties.");
  const url = \`https://api.github.com/repos/\${OWNER}/\${REPO}/dispatches\`;
  const body = { event_type: DISPATCH_EVENT, client_payload: payload };
  const res = UrlFetchApp.fetch(url, {
    method: 'post',
    contentType: 'application/json',
    payload: JSON.stringify(body),
    headers: { 'Authorization': 'token ' + pat, 'Accept':'application/vnd.github+json' },
    muteHttpExceptions: true
  });
  if(res.getResponseCode() >= 300){
    throw new Error('GitHub dispatch failed: ' + res.getResponseCode() + ' ' + res.getContentText());
  }
}

/*** Trigger for Google Form Submissions ***/
function onFormSubmit(e){
  const row = e.namedValues;
  const name = (row['Name'] || row['Organisation Name'] || [''])[0];
  const email = (row['Email'] || [''])[0];
  const orgWebsite = (row['Website'] || [''])[0];
  const stripeMonthlyLink = (row['Stripe Monthly Link'] || [''])[0];
  const stripeAnnualLink = (row['Stripe Annual Link'] || [''])[0];
  const cryptoBTC = (row['BTC Address'] || [''])[0];
  const cryptoETH = (row['ETH Address'] || [''])[0];
  const cryptoUSDT = (row['USDT Address'] || [''])[0];
  const notes = (row['Notes'] || [''])[0];

  const slug = slugify(name);
  dispatchToGithub({
    name, email, orgWebsite, stripeMonthlyLink, stripeAnnualLink,
    cryptoBTC, cryptoETH, cryptoUSDT, notes, slug
  });

  const donateUrl = SITE_BASE_URL + "/donate/" + slug;
  const qrUrl = SITE_BASE_URL + "/qrs/" + slug + ".png";
  MailApp.sendEmail({
    to: email,
    subject: "Your TitheHub donation page is being set up",
    htmlBody: \`
      <p>Hi \${name || ''},</p>
      <p>Your donation page is being generated and will be live shortly:</p>
      <p><a href="\${donateUrl}">\${donateUrl}</a></p>
      <p>Your QR (may take ~1–2 minutes to appear):<br>
         <img src="\${qrUrl}" width="240" alt="QR"/></p>
      <p>You can embed your widget with:<br>
      <code>&lt;script src="\${SITE_BASE_URL}/widgets/\${slug}.js" async&gt;&lt;/script&gt;</code></p>
      <p>— TitheHub</p>
    \`
  });
}

/*** Web App Endpoint (for voice/agent POST JSON) ***/
function doPost(e){
  const data = JSON.parse(e.postData.contents || '{}');
  if(!data.name){ return ContentService.createTextOutput('Missing name').setMimeType(ContentService.MimeType.TEXT); }
  if(!data.slug){ data.slug = slugify(data.name); }
  dispatchToGithub(data);
  return ContentService.createTextOutput(JSON.stringify({ ok:true, slug:data.slug })).setMimeType(ContentService.MimeType.JSON);
}

/*** Install trigger:
    Triggers → Add Trigger → onFormSubmit
    Event source: From spreadsheet | Event type: On form submit
***/
TXT

# Done
echo
echo "✅ Files written."
echo "Next:"
echo "  1) npm i"
echo "  2) git init && git add . && git commit -m 'init tithehub agent' && git branch -M main"
echo "  3) git remote add origin https://github.com/Tithehub/tithehub && git push -u origin main"
echo "  4) In GitHub → Settings → Pages: set your domain (already using ${SITE_BASE_URL} if configured)"
echo "  5) In GitHub → Settings → Variables → Actions: add variable SITE_BASE_URL = ${SITE_BASE_URL}"
echo "  6) Open GOOGLE_APPS_SCRIPT_PASTE_ME.txt, paste into Apps Script, and add Script Property GITHUB_PAT = <your token>"
echo "  7) Submit a test form (or POST to the Web App) to generate a live page + QR."
