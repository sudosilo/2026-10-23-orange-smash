#!/usr/bin/env bash
# One line setup for an extra phone. Waits for the internet instead of quitting, then runs the seed from the bottom.
main() {
  cd ~ && pwd
  until curl -sf -o /dev/null https://api.github.com; do echo "no internet yet, trying again in 30 s"; sleep 30; done
  until pkg install yt-dlp jq curl git -y </dev/null; do echo "install failed, trying again in 30 s"; sleep 30; pkg update -y </dev/null; done
  until [ -d 2026-10-23-orange-smash/.git ]; do
    git clone https://github.com/sudosilo/2026-10-23-orange-smash || { echo "download failed, trying again in 30 s"; sleep 30; }
  done
  cd 2026-10-23-orange-smash && git pull
  pwd
  termux-wake-lock 2>/dev/null
  until bash tools/seed-cache.sh bottom </dev/null && ! grep -q . "$HOME/.smash-seed/stopped" 2>/dev/null; do
    echo "seed paused, starting again in 10 minutes"; sleep 600
  done
}
main
