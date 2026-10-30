#!/usr/bin/env bash
# Takes one waiting Smash Director job, downloads its instrumental and acapella with yt-dlp, and uploads both
# as files to Smash Bender in Frankfurt, which cannot reach YouTube itself. Reports the result back so the app can show it.
QUEUE="https://offset-listener.vercel.app/api/bender"
BENDER="https://smash-bender.167-233-137-169.sslip.io/api/import"
WORK="$HOME/.smash-bender-relay"
mkdir -p "$WORK"
report() { curl -s -X POST -H 'content-type: application/json' --data "$1" "$QUEUE" >/dev/null; }
job=$(curl -s "$QUEUE?next=1" | jq -c '.job // empty')
[ -z "$job" ] && exit 0
id=$(printf '%s' "$job" | jq -r .id)
echo "smash bender job $id: $(printf '%s' "$job" | jq -r '.song_one + " under " + .song_two')"
rm -f "$WORK"/inst.* "$WORK"/aca.*
fail() { echo "smash bender job $id: $1"; report "$(jq -n --arg i "$id" --arg e "$1" '{action:"result", id:$i, ok:false, error:$e}')"; rm -f "$WORK"/inst.* "$WORK"/aca.*; exit 0; }
for part in inst aca; do
  vid=$(printf '%s' "$job" | jq -r ".$part")
  yt-dlp -q --no-warnings -f 'bestaudio[ext=m4a]/bestaudio' -o "$WORK/$part.%(ext)s" "https://www.youtube.com/watch?v=$vid" </dev/null 2>"$WORK/err.txt" \
    || fail "could not download the $part track: $(tail -n 1 "$WORK/err.txt" | cut -c1-100)"
done
inst=$(ls "$WORK"/inst.* | head -1); aca=$(ls "$WORK"/aca.* | head -1)
out=$(curl -s -w '\n%{http_code}' -X POST "$BENDER" \
  -F "project=$(printf '%s' "$job" | jq -r .project)" \
  -F "song_one=$(printf '%s' "$job" | jq -r .song_one)" \
  -F "song_two=$(printf '%s' "$job" | jq -r .song_two)" \
  -F "seconds=$(printf '%s' "$job" | jq -r .seconds)" \
  -F "music_start=$(printf '%s' "$job" | jq -r '.music_start // 0')" \
  -F "voice_start=$(printf '%s' "$job" | jq -r '.voice_start // 0')" \
  -F "source=smash director" \
  -F "instrumental=@$inst" -F "acapella=@$aca")
code=$(printf '%s' "$out" | tail -n 1); body=$(printf '%s' "$out" | sed '$d')
rm -f "$WORK"/inst.* "$WORK"/aca.*
if [ "$code" = "200" ]; then
  report "$(printf '%s' "$body" | jq -c --arg i "$id" '{action:"result", id:$i, ok:true, job:.job, project:.project, open:.open}')"
  echo "smash bender job $id: sent, $(printf '%s' "$body" | jq -r .open)"
else
  fail "Smash Bender said: $(printf '%s' "$body" | jq -r '.detail // .error // "error"' 2>/dev/null | cut -c1-140) ($code)"
fi
