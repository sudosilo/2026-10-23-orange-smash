#!/usr/bin/env bash
# One time: makes the key that signs the Android app and hands it to GitHub as build secrets.
# Every future build is signed with it, so new versions install over old ones.
set -e
command -v openssl >/dev/null 2>&1 || pkg install openssl-tool -y </dev/null
REPO="sudosilo/2026-10-23-orange-smash"
DIR="$HOME/.smash-signing"
mkdir -p "$DIR" && cd "$DIR"
if [ ! -f smash-signing.p12 ]; then
  PW=$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 24)
  openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 10000 -nodes -subj "/CN=Smash Director" 2>/dev/null
  openssl pkcs12 -export -inkey key.pem -in cert.pem -out smash-signing.p12 -name smash -passout "pass:$PW"
  printf '%s' "$PW" > password.txt
  rm -f key.pem cert.pem
  echo "Signing key made and kept in $DIR"
fi
base64 -w0 smash-signing.p12 | gh secret set ANDROID_KEYSTORE -R "$REPO"
gh secret set ANDROID_KEYSTORE_PASSWORD -R "$REPO" < password.txt
echo "SAVE THIS signing key password: $(cat password.txt)"
gh workflow run build-apps.yml -R "$REPO" && echo "First build started. Tell Claude."
