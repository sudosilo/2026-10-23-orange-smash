#!/usr/bin/env bash
# Loads every file in supabase/ into the Lyric Smash Supabase project, in order. Safe to run again.
API="https://api.supabase.com/v1"
NAME="2026-10-23-orange-smash"
cd "$(cd "$(dirname "$0")/.." && pwd)" || exit 1
TOKEN="${SUPABASE_ACCESS_TOKEN:-}"
[ -z "$TOKEN" ] && [ -f "$HOME/.supabase/access-token" ] && TOKEN="$(tr -d '\n' < "$HOME/.supabase/access-token")"
[ -z "$TOKEN" ] && { echo "No saved Supabase login found on this phone."; exit 1; }
H=(-H "Authorization: Bearer $TOKEN" -H "content-type: application/json")
# use the exact project the live app is connected to
REF=$(curl -s https://2026-10-23-orange-smash.vercel.app/api/config | jq -r '.supabaseUrl // empty' | sed -E 's#https?://([a-z0-9]+)\.supabase\.co.*#\1#')
[ -z "$REF" ] && REF=$(curl -s "${H[@]}" "$API/projects" | jq -r --arg n "$NAME" '.[] | select(.name == $n) | .id' | head -n 1)
[ -z "$REF" ] && { echo "Could not find the project the app uses."; exit 1; }
echo "Project $REF"
for f in supabase/schema.sql supabase/social.sql; do
  out=$(curl -s "${H[@]}" -X POST "$API/projects/$REF/database/query" --data "$(jq -n --rawfile q "$f" '{query:$q}')")
  if printf '%s' "$out" | jq -e 'type == "array"' >/dev/null 2>&1; then echo "loaded $f"; else echo "$f failed: $(printf '%s' "$out" | head -c 300)"; exit 1; fi
done
echo "Done. Tell Claude it finished."
