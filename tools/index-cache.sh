#!/usr/bin/env bash
# Tags every saved song with its genre, decade and BPM so Autosmash can pick from them for free.
# Safe to stop and run again; it picks up where it left off. Run it again after more seeding.
API="https://offset-listener.vercel.app/api/index-cached?limit=10"
while true; do
  r=$(curl -s -m 60 "$API")
  rem=$(printf '%s' "$r" | jq -r '.remaining // empty')
  if [ -z "$rem" ]; then echo "server busy, trying again in 20 s"; sleep 20; continue; fi
  tags=$(printf '%s' "$r" | jq -r '.artistsToTag // 0')
  echo "indexed $(printf '%s' "$r" | jq -r '.indexed') of $(printf '%s' "$r" | jq -r '.saved') saved songs, $rem to go, $tags artists left to tag"
  [ "$rem" = "0" ] && [ "$tags" = "0" ] && break
  sleep 2
done
echo "Done. Autosmash can use every saved song now."
