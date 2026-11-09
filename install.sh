#!/data/data/com.termux/files/usr/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 pdev-labs
# install tvplay and friends into ~/bin. Run from Termux, not adb shell.
#
#   bash ~/storage/downloads/tvsetup/install.sh [TV_IP]
set -eu

src="$(cd "$(dirname "$0")" && pwd)"
bin="$HOME/bin"
mkdir -p "$bin"

for f in tvlib tvplay tv-fetch tv-doctor tv-discover tv-serve termux-open; do
  install -m 755 "$src/bin/$f" "$bin/$f"
done

if ! grep -qs 'HOME/bin' "$HOME/.bashrc" 2>/dev/null; then
  printf '\nexport PATH="$HOME/bin:$PATH"\n' >>"$HOME/.bashrc"
  echo "PATH: added ~/bin to ~/.bashrc"
else
  echo "PATH: ~/bin already in ~/.bashrc"
fi

ip="${1:-192.168.1.50}"
if [ ! -f "$HOME/.tvrc" ]; then
  sed "s/^TV_IP=.*/TV_IP=$ip/" "$src/tvrc.example" >"$HOME/.tvrc"
  echo "config: wrote ~/.tvrc with TV_IP=$ip"
else
  echo "config: kept existing ~/.tvrc"
fi

if mkdir -p "$HOME/storage/downloads/tv" 2>/dev/null; then
  echo "media: $HOME/storage/downloads/tv"
else
  mkdir -p "$HOME/downloads/tv"
  echo "media: $HOME/downloads/tv (storage not mounted)"
fi

missing=""
for c in adb curl python nmap; do
  command -v "$c" >/dev/null 2>&1 || missing="$missing $c"
done
[ -z "$missing" ] || echo "install: pkg install android-tools curl python nmap"
command -v ffmpeg >/dev/null 2>&1 || echo "optional: pkg install ffmpeg   (HLS fallback)"
command -v aria2c >/dev/null 2>&1 || echo "optional: pkg install aria2    (faster fallback)"

echo
echo "done. start a new Termux session, then:"
echo "  tv-doctor"
echo "  TV_FALLBACK=auto moviebox-tui"
