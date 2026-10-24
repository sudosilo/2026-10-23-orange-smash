#!/usr/bin/env bash
# One line setup for an extra phone:  curl -sL 2026-10-23-orange-smash.vercel.app/s | bash
cd ~ && pwd
pkg update -y
pkg install yt-dlp jq curl git gh -y
if [ -d 2026-10-23-orange-smash ]; then
  cd 2026-10-23-orange-smash && git pull
else
  git clone https://github.com/sudosilo/2026-10-23-orange-smash && cd 2026-10-23-orange-smash
fi
pwd
termux-wake-lock 2>/dev/null
bash tools/seed-cache.sh bottom </dev/null
