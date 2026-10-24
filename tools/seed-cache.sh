#!/usr/bin/env bash
# Fills the shared search cache with acapella and instrumental results for chart songs,
# using yt-dlp instead of the YouTube API, so those searches cost the app zero quota.
# Run:  bash tools/seed-cache.sh            (Deezer charts, every genre)
#       bash tools/seed-cache.sh 200        (stop after 200 songs)
#       bash tools/seed-cache.sh 0 list.txt (your own list, one "Title|Artist" per line)
#       bash tools/seed-cache.sh bottom     (second phone: same list, starting from the last song)
#       bash tools/seed-cache.sh middle     (third phone: starts in the middle and works up)

API="https://offset-listener.vercel.app/api/seed-search"
WORK="$HOME/.smash-seed"
REVERSE=0
MIDDLE=0
if [ "$1" = "bottom" ]; then REVERSE=1; shift; fi
if [ "$1" = "middle" ]; then MIDDLE=1; shift; fi
LIMIT="${1:-0}"
LIST_FILE="$2"
mkdir -p "$WORK"
SONGS="$WORK/songs.tsv"
DONE="$WORK/done.txt"
touch "$DONE"
rm -f "$WORK/stopped"

for tool in curl jq yt-dlp; do
  command -v "$tool" >/dev/null 2>&1 || { echo "missing $tool, install it first"; exit 1; }
done

: > "$SONGS"
if [ -n "$LIST_FILE" ]; then
  tr -d '\r' < "$LIST_FILE" | awk -F'|' 'NF>=2 { print $1 "\t" $2 }' >> "$SONGS"
else
  # all, pop, rap, rock, dance, r&b, alternative, electro, country, latin, soul and funk, metal, reggae
  for g in 0 132 116 152 113 165 85 106 84 197 169 464 144; do
    curl -s "https://api.deezer.com/chart/$g/tracks?limit=100" \
      | jq -r '.data[]? | [(.title_short // .title), .artist.name] | @tsv' >> "$SONGS"
    sleep 1
  done
fi
sort -u -o "$SONGS" "$SONGS"
if [ "$REVERSE" = "1" ]; then tac "$SONGS" > "$SONGS.rev" && mv "$SONGS.rev" "$SONGS"; echo "starting from the bottom of the list"; fi
if [ "$MIDDLE" = "1" ]; then
  half=$(( $(wc -l < "$SONGS") / 2 ))
  { head -n "$half" "$SONGS" | tac; tail -n +"$((half + 1))" "$SONGS"; } > "$SONGS.mid" && mv "$SONGS.mid" "$SONGS"
  echo "starting from the middle of the list, working up"
fi
TOTAL=$(wc -l < "$SONGS")
echo "songs to cover: $TOTAL"

count=0
stored=0
fails=0
while IFS=$'\t' read -r title artist; do
  [ -z "$title" ] && continue
  count=$((count + 1))
  if [ "$LIMIT" -gt 0 ] && [ "$count" -gt "$LIMIT" ]; then break; fi
  for kind in acapella instrumental; do
    q="$title $artist $kind"
    grep -Fxq "$q" "$DONE" && continue
    already=$(curl -s -X POST -H 'content-type: application/json' --data "$(jq -n --arg q "$q" '{query: $q, checkOnly: true}')" "$API" | jq -r '.cached // false')
    if [ "$already" = "true" ]; then echo "$q" >> "$DONE"; echo "[$count/$TOTAL] $title / $artist / $kind: already in the cache, skipped"; continue; fi
    lines=""
    reason=""
    for wait in 30 90 240; do
      out=$(yt-dlp --flat-playlist --skip-download --no-warnings \
        --print $'%(id)s\t%(title)s\t%(channel,uploader|)s' "ytsearch8:$q" 2>"$WORK/err.txt" </dev/null)
      lines=$(printf '%s\n' "$out" | grep -E '^[A-Za-z0-9_-]{11}'$'\t' || true)
      [ -n "$lines" ] && break
      reason=$(grep -v '^$' "$WORK/err.txt" | tail -n 1 | cut -c1-140)
      echo "[$count/$TOTAL] $kind: no results (${reason:-empty search}), trying again in $wait s"
      sleep "$wait"
    done
    if [ -z "$lines" ]; then
      fails=$((fails + 1))
      echo "$q" >> "$WORK/skipped.txt"
      if [ "$fails" -ge 3 ]; then
        echo "YouTube is refusing searches right now. Stopping here, run the same command later and it picks up from this song."
        echo blocked > "$WORK/stopped"
        exit 0
      fi
      continue
    fi
    fails=0
    body=$(printf '%s\n' "$lines" | jq -R -s --arg q "$q" '
      { query: $q,
        results: [ split("\n")[] | select(length > 0) | split("\t") | { videoId: .[0], title: .[1], channel: (.[2] // "") } ] }')
    reply=$(curl -s -X POST -H 'content-type: application/json' --data "$body" "$API")
    if [ "$(printf '%s' "$reply" | jq -r '.stored // false')" = "true" ]; then stored=$((stored + 1)); fi
    echo "[$count/$TOTAL] $title / $artist / $kind: $(printf '%s' "$reply" | jq -r 'if .stored then "saved \(.count)" else (.reason // .error // "skipped") end')"
    echo "$q" >> "$DONE"
    sleep $((3 + RANDOM % 4))
  done
done < "$SONGS"

rm -f "$WORK/stopped"
echo "finished, $stored searches saved to the cache"
