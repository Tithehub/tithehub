#!/usr/bin/env bash
set -euo pipefail

SITE_BASE_URL="https://tithehub.com"
SLUG="tithehub-demo-church"
BRANCH="main"

echo "🔧 Install tools…"
sudo apt-get update -y >/dev/null 2>&1 || true
sudo apt-get install -y imagemagick jq curl >/dev/null 2>&1 || true

echo "🔁 Sync $BRANCH…"
git fetch origin
git checkout "$BRANCH"
git pull --ff-only || true

echo "🧹 Find & repair unreadable PNGs…"
REPAIRED=0
REPLACED=0
while IFS= read -r -d '' f; do
  if identify -quiet "$f" >/dev/null 2>&1; then
    convert "$f" -strip "$f" || true
  else
    echo "⚠️  $f is unreadable → attempting salvage"
    if convert "$f" -strip "$f".fixed 2>/dev/null; then
      mv "$f".fixed "$f"
      echo "✅ salvaged: $f"
      REPAIRED=$((REPAIRED+1))
    else
      echo "❌ cannot salvage: $f → replacing with transparent placeholder"
      convert -size 512x512 xc:none -alpha on "$f"
      REPLACED=$((REPLACED+1))
    fi
  fi
done < <(find . -type f -iname '*.png' -print0)

echo "📊 PNG repair summary → repaired: $REPAIRED, replaced: $REPLACED"

echo "📝 Ensure donation.json has $SLUG…"
[ -f donation.json ] || echo '{}' > donation.json
TMP=$(mktemp)
jq --arg slug "$SLUG" \
   --arg name "TitheHub Demo Church" \
   --arg email "demo@tithehub.com" \
   --arg org "https://tithehub.com" \
   --arg sm "https://buy.stripe.com/test_monthly_link" \
   --arg sa "https://buy.stripe.com/test_annual_link" \
   --arg btc "37LoinW7gvJEYGigZAHCeRdL84iwjkcEY5" \
   --arg notes "Thank you for supporting our mission." \
   '. + {($slug): {name:$name,email:$email,orgWebsite:$org,stripeMonthlyLink:$sm,stripeAnnualLink:$sa,cryptoBTC:$btc,notes:$notes}}' \
   donation.json > "$TMP" && mv "$TMP" donation.json

if ! git diff --quiet; then
  git add -A
  git commit -m "chore(ci): repair PNGs + ensure $SLUG in donation.json"
  git push origin "$BRANCH" || { git pull --rebase origin "$BRANCH"; git push origin "$BRANCH"; }
fi

echo "📦 Install deps…"
if [ -f package.json ]; then
  npm ci >/dev/null 2>&1 || npm i >/dev/null 2>&1
else
  echo "❌ No package.json → generator missing."
  exit 1
fi

echo "⚙️ Generate assets with SITE_BASE_URL=$SITE_BASE_URL…"
export SITE_BASE_URL="$SITE_BASE_URL"
if npm run | grep -q "^  generate"; then
  npm run generate
elif [ -f scripts/generate_assets.mjs ]; then
  node scripts/generate_assets.mjs
else
  echo "❌ Missing generator (need npm run generate or scripts/generate_assets.mjs)."
  exit 1
fi

echo "🧾 Commit generated files…"
git add -A
if git diff --cached --quiet; then
  echo "ℹ️ No generated changes to commit."
else
  git commit -m "build: generated assets for $SLUG"
  git push origin "$BRANCH" || { git pull --rebase origin "$BRANCH"; git push origin "$BRANCH"; }
fi

PAGE="$SITE_BASE_URL/donate/$SLUG"
QR="$SITE_BASE_URL/qrs/$SLUG.png"

echo "⏳ Waiting for GitHub Pages…"
for i in {1..36}; do
  PCODE=$(curl -s -o /dev/null -w "%{http_code}" "$PAGE" || echo 000)
  QCODE=$(curl -s -o /dev/null -w "%{http_code}" "$QR"   || echo 000)
  echo "   try $i: page=$PCODE  qr=$QCODE"
  if [ "$PCODE" = "200" ] && [ "$QCODE" = "200" ]; then
    echo ""
    echo "✅ LIVE!"
    echo "   Page: $PAGE"
    echo "   QR  : $QR"
    exit 0
  fi
  sleep 5
done

echo ""
echo "❌ Still 404. Check latest Pages deploy:"
echo "   https://github.com/Tithehub/tithehub/actions"
