#!/usr/bin/env bash
# Makes loudness maps for the instrumentals Smash Director plays, so SUGGEST can find the quiet spots for the voice.
# Downloads each track's audio with yt-dlp, measures it with ffmpeg every half second, sends only the numbers, deletes the audio.
API="https://offset-listener.vercel.app/api/energy"
WORK="$HOME/.smash-energy"
mkdir -p "$WORK"
done_count=0
measure() { # $1 audio file, $2 extra filter, prints one decibel value per half second
  ffmpeg -nostdin -nostats -loglevel error -i "$1" \
    -af "aformat=sample_rates=8000:channel_layouts=mono,${2}asetnsamples=n=4000:p=0,astats=metadata=1:reset=1,ametadata=mode=print:key=lavfi.astats.Overall.RMS_level:file=-" \
    -f null - 2>/dev/null | grep -o 'RMS_level=.*' | cut -d= -f2 | sed 's/-inf/-120/; s/^inf$/-120/'
}
map_one() {
  local vid="$1"
  rm -f "$WORK"/a.*
  if ! yt-dlp -q --no-warnings -f 'bestaudio[abr<=96]/bestaudio/worst' -o "$WORK/a.%(ext)s" "https://www.youtube.com/watch?v=$vid" </dev/null 2>"$WORK/err.txt"; then
    reason=$(tail -n 1 "$WORK/err.txt" | cut -c1-100)
    curl -s -X POST -H 'content-type: application/json' --data "$(jq -n --arg v "$vid" --arg r "$reason" '{vid:$v, failed:true, reason:$r}')" "$API" >/dev/null
    echo "$vid: could not download (${reason:-unknown}), marked and skipped"
    return 1
  fi
  f=$(ls "$WORK"/a.* 2>/dev/null | head -1)
  measure "$f" "" > "$WORK/total.txt"
  measure "$f" "highpass=f=300,lowpass=f=3000," > "$WORK/voice.txt"
  rm -f "$WORK"/a.*
  n=$(wc -l < "$WORK/total.txt")
  if [ "$n" -lt 10 ]; then echo "$vid: audio too short to map, skipped"; return 1; fi
  body=$(jq -n --arg v "$vid" --rawfile t "$WORK/total.txt" --rawfile o "$WORK/voice.txt" \
    '{vid:$v, step:0.5, dur:(($t|split("\n")|map(select(length>0))|length)*0.5), total:($t|split("\n")|map(select(length>0)|tonumber)), voice:($o|split("\n")|map(select(length>0)|tonumber))}')
  out=$(curl -s -X POST -H 'content-type: application/json' --data "$body" "$API")
  echo "$vid: mapped $(( n / 2 )) seconds, $(printf '%s' "$out" | jq -r 'if .ok then "saved" else (.error // "not saved") end')"
}
command -v ffmpeg >/dev/null || { echo "ffmpeg is missing, install it with: pkg install ffmpeg"; exit 1; }
while true; do
  vids=$(curl -s "$API?queue=1&n=4" | jq -r '.vids[]?')
  if [ -z "$vids" ]; then echo "nothing left to map, $done_count done this run"; break; fi
  for v in $vids; do
    map_one "$v" && done_count=$((done_count + 1))
    sleep $((2 + RANDOM % 3))
  done
done
