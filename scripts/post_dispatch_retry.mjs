// Lightweight note after healing
import fs from 'fs';
const evPath = process.env.GITHUB_EVENT_PATH;
if (!evPath || !fs.existsSync(evPath)) {
  console.log('No event payload, skipping re-dispatch hint.');
  process.exit(0);
}
const ev = JSON.parse(fs.readFileSync(evPath,'utf8'));
const cp = ev.client_payload || {};
if (cp && (cp.name || cp.slug)) {
  console.log('Healed after payload for', cp.slug || cp.name, '— commit will trigger Pages deploy.');
} else {
  console.log('Healed generic assets — commit will deploy via Pages workflow.');
}
