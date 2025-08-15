# TitheHub Autonomous Agent (Pages + QR + Widgets)

- SITE_BASE_URL currently set to: https://tithehub.com
- Replace `assets/tithehub-logo.png` with your square transparent logo (e.g. 512x512).
- In GitHub repo Settings → Pages: set your custom domain (https://tithehub.com) if desired.
- In GitHub repo Settings → Variables → Actions: add `SITE_BASE_URL` = https://tithehub.com

## Local Test
1) npm i
2) SITE_BASE_URL=https://tithehub.com npm run generate
3) Open https://tithehub.com/donate/tithehub-demo-church (once deployed to Pages or your server)

## Live Automation
Use the Google Apps Script printed below (GOOGLE_APPS_SCRIPT_PASTE_ME.txt) to dispatch payloads after Google Form submissions or via its Web App endpoint.
