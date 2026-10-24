#!/usr/bin/env bash
# Creates the Lyric Smash Supabase project, loads the tables, and hands the keys to Vercel.
# Uses the login the Supabase CLI already saved on this phone. Run from the project folder.
set -u
API="https://api.supabase.com/v1"
NAME="2026-10-23-orange-smash"
APP_URL="https://2026-10-23-orange-smash.vercel.app"
DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DIR" || exit 1

TOKEN="${SUPABASE_ACCESS_TOKEN:-}"
[ -z "$TOKEN" ] && [ -f "$HOME/.supabase/access-token" ] && TOKEN="$(tr -d '\n' < "$HOME/.supabase/access-token")"
if [ -z "$TOKEN" ]; then echo "No saved Supabase login found on this phone."; exit 1; fi
H=(-H "Authorization: Bearer $TOKEN" -H "content-type: application/json")

ORG=$(curl -s "${H[@]}" "$API/organizations" | jq -r '.[0].id // empty')
if [ -z "$ORG" ]; then echo "Could not read your Supabase organization."; exit 1; fi

REF=$(curl -s "${H[@]}" "$API/projects" | jq -r --arg n "$NAME" '.[] | select(.name == $n) | .id' | head -n 1)
NEW=0
if [ -z "$REF" ]; then
  PASS=$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 24)
  reply=$(curl -s "${H[@]}" -X POST "$API/projects" --data "$(jq -n --arg n "$NAME" --arg o "$ORG" --arg p "$PASS" '{name:$n, organization_id:$o, db_pass:$p, region:"us-west-1"}')")
  REF=$(printf '%s' "$reply" | jq -r '.id // empty')
  if [ -z "$REF" ]; then
    echo "New project not allowed: $(printf '%s' "$reply" | jq -r '.message // .error // .' | head -c 200)"
    REF=$(curl -s "${H[@]}" "$API/projects" | jq -r '[.[] | select(.status == "ACTIVE_HEALTHY")][0].id // empty')
    [ -z "$REF" ] && { echo "No active Supabase project to use."; exit 1; }
    echo "Using your existing project $REF instead. Tables are prefixed smash_ so nothing collides."
  else
    NEW=1
    echo "SAVE THIS database password: $PASS"
  fi
fi
echo "SAVE THIS Supabase project ref: $REF"

echo "Waiting for the project to come up..."
for i in $(seq 1 60); do
  st=$(curl -s "${H[@]}" "$API/projects/$REF" | jq -r '.status // empty')
  [ "$st" = "ACTIVE_HEALTHY" ] && break
  sleep 10
done

for i in $(seq 1 12); do
  out=$(curl -s "${H[@]}" -X POST "$API/projects/$REF/database/query" --data "$(jq -n --rawfile q supabase/schema.sql '{query:$q}')")
  if printf '%s' "$out" | jq -e 'type == "array"' >/dev/null 2>&1; then echo "Tables loaded."; break; fi
  echo "Database not ready yet, trying again in 15 s"; sleep 15
done

if [ "$NEW" = "1" ]; then
  curl -s "${H[@]}" -X PATCH "$API/projects/$REF/config/auth" \
    --data "$(jq -n --arg u "$APP_URL" '{mailer_autoconfirm:true, site_url:$u}')" >/dev/null
  echo "Sign ups work without an email confirmation."
fi

URL="https://$REF.supabase.co"
ANON=$(curl -s "${H[@]}" "$API/projects/$REF/api-keys" | jq -r '.[] | select(.name == "anon") | .api_key' | head -n 1)
[ -z "$ANON" ] && { echo "Could not read the public key."; exit 1; }

for v in SUPABASE_URL SUPABASE_ANON_KEY; do vercel env rm "$v" production --yes >/dev/null 2>&1; done
printf '%s' "$URL" | vercel env add SUPABASE_URL production >/dev/null && echo "Vercel has SUPABASE_URL"
printf '%s' "$ANON" | vercel env add SUPABASE_ANON_KEY production >/dev/null && echo "Vercel has SUPABASE_ANON_KEY"
echo "Done. Tell Claude it finished."
