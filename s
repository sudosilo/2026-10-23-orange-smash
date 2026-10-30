#!/usr/bin/env bash
# One line setup for an extra phone. Waits for the internet instead of quitting, then runs the seed from the bottom.
main() {
  MODE="${1:-bottom}"
  cd ~ && pwd
  until curl -sf -o /dev/null https://api.github.com; do echo "no internet yet, trying again in 30 s"; sleep 30; done
  # use the main Termux package server instead of whatever mirror this phone picked
  echo "deb https://packages-cf.termux.dev/apt/termux-main stable main" > "$PREFIX/etc/apt/sources.list"
  rm -rf "$PREFIX/etc/termux/chosen_mirrors" "$PREFIX/etc/termux/mirrors/default" 2>/dev/null
  dpkg --configure -a </dev/null 2>/dev/null
  PKGS="yt-dlp jq curl git"; [ "$MODE" = "energy" ] && PKGS="$PKGS ffmpeg"
  [ "$MODE" = "energy" ] && apt-get update </dev/null && apt-get -y -o Dpkg::Options::=--force-confold upgrade </dev/null
  until apt-get update </dev/null && apt-get install -y -o Dpkg::Options::=--force-confold $PKGS </dev/null; do
    echo "install failed, trying again in 30 s"; sleep 30; dpkg --configure -a </dev/null 2>/dev/null
  done
  until [ -d 2026-10-23-orange-smash/.git ]; do
    git clone https://github.com/sudosilo/2026-10-23-orange-smash || { echo "download failed, trying again in 30 s"; sleep 30; }
  done
  cd 2026-10-23-orange-smash && git fetch -q origin && git reset -q --hard origin/main
  pwd
  termux-wake-lock 2>/dev/null
  if [ "$MODE" = "energy" ]; then
    # map every saved instrumental, then check for new ones every 30 minutes
    # between map runs it also relays Smash Bender jobs, checking every 20 seconds; it picks up new scripts each round
    while true; do
      git fetch -q origin && git reset -q --hard origin/main
      bash tools/energy-map.sh </dev/null
      echo "relaying Smash Bender jobs, checking for new beats in 30 minutes"
      for i in $(seq 1 90); do bash tools/bender-relay.sh </dev/null; sleep 20; done
    done
  fi
  until bash tools/seed-cache.sh "$MODE" </dev/null && ! grep -q . "$HOME/.smash-seed/stopped" 2>/dev/null; do
    echo "seed paused, starting again in 10 minutes"; sleep 600
  done
}
main "$@"
