# tvplay

Send a stream URL from Termux to VLC on an Android TV over ADB.

tvplay was written for moviebox-tui, where you search on the phone but want the
video on the television. It works with any URL you can produce from a terminal.

What it does:

- `tvplay <url>` opens the URL in VLC on the TV and watches the TV for a playing session.
- If the TV does not start playback within `TV_WAIT` seconds, `TV_FALLBACK=auto` downloads the stream on the phone and serves it over the local network.
- `tv-serve` answers byte-range requests, so seeking works in VLC.
- `tv-serve` redirects `/now` to the newest download, which gives you one URL to save in VLC history.

## Requirements

Phone:

- Termux, installed from F-Droid
- `adb` from `pkg install android-tools`
- `curl`, `python`, and `nmap`
- optional: `ffmpeg` for HLS downloads, `aria2` for faster direct downloads
- VLC for Android, which moviebox-tui uses for playback

TV:

- Android TV or Google TV
- VLC installed
- USB debugging enabled

Both devices need to be on the same network. A phone hotspot works: the phone
is the access point host, so it can reach clients even when access point
isolation blocks traffic between clients.

## TV setup (once)

1. Open Settings > System > About.
2. Select "Android TV OS build" seven times.
3. Go back to Settings > System > Developer options and enable USB debugging.
4. Run `tv-doctor` from Termux. A dialog appears on the TV. Select "Always allow from this computer" and accept.

Enabling "Disable adb authorization timeout" in Developer options saves you
from repeating the dialog after a week of disuse.

## Install

```sh
pkg install -y git
termux-setup-storage
git clone https://github.com/pdev-labs/tvplay.git
bash tvplay/install.sh
exec bash
tv-doctor
```

`install.sh` copies the scripts to `~/bin`, adds `~/bin` to `PATH`, writes
`~/.tvrc`, and creates `Download/tv`. Pass the TV address as the first argument
if you already know it: `bash tvplay/install.sh 192.168.1.50`.

If `tv-doctor` reports missing tools:

```sh
pkg install -y android-tools curl python nmap
```

## Use with moviebox-tui

```sh
TV_FALLBACK=auto moviebox-tui
```

On Termux, moviebox-tui plays through `termux-open`. The installer puts a
`termux-open` wrapper in `~/bin`. When `TV_IP` is set, the wrapper hands the URL
to `tvplay`. Otherwise it passes the call to the real `termux-open`, and
playback stays on the phone.

To watch on the phone for one run:

```sh
MB_LOCAL=1 moviebox-tui
```

## Manual use

```sh
tv-fetch "https://example.com/movie.mkv"
```

`tv-fetch` stores the file in `Download/tv`, starts `tv-serve`, and prints the
path. In VLC on the TV, open:

```text
http://<phone-ip>:8080/now
```

Do that once. VLC keeps the address in its history, and `/now` always points at
the newest file, so the same entry plays whatever you downloaded last. This
path does not use ADB.

## Commands

| Command | Purpose |
|---|---|
| `tvplay <url>` | open a URL in VLC on the TV and poll for playback |
| `tv-fetch <url>` | download with aria2 or ffmpeg, then start `tv-serve` |
| `tv-serve --daemon` | start the HTTP server in the background |
| `tv-serve --status` | show whether the server is running |
| `tv-serve --stop` | stop the server |
| `tv-doctor` | check the TV address, port 5555, adb state, VLC, and the server |
| `tv-discover` | scan the subnet for port 5555 and update `~/.tvrc` |

## Configuration

Settings live in `~/.tvrc`:

```sh
TV_IP=192.168.1.50
TV_PORT=5555
TV_SERVE_PORT=8080
TV_DIR="$HOME/storage/downloads/tv"
TV_WAIT=20
TV_FALLBACK=manual
```

`TV_FALLBACK` accepts `manual` (print the `tv-fetch` command), `auto` (download
and serve), or `off`.

If the TV gets a new lease, run `tv-discover`. It reads the phone's current
subnet, scans for port 5555, and rewrites `TV_IP`.

## How the handoff works

moviebox-tui does not stream by itself on Termux. It looks up `termux-open` and
calls it with the stream URL. The wrapper in `~/bin` runs before the system one
because `~/bin` comes first in `PATH`. With `TV_IP` set, the wrapper passes the
URL to `tvplay` instead of launching a player on the phone.

`tvplay` connects to adbd on the TV and starts a VIEW intent for the URL,
targeted at VLC. It then polls `dumpsys media_session` for a playing state. A TV
that can play the URL directly needs no download.

Some CDN URLs only work with the headers moviebox-tui sends to desktop players,
and Android intents cannot carry those headers. That is the case the download
path covers: `tv-fetch` runs on the phone with the same network access, writes a
local file, and `tv-serve` gives the TV a plain HTTP URL.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `adb devices` shows `unauthorized` | Accept the dialog on the TV. If it never appears, press Home on the remote and reconnect. Enable "Disable adb authorization timeout" in Developer options. |
| `Connection refused` on port 5555 | USB debugging is off, the TV is asleep, or the address changed. Wake the TV, then run `tv-discover`. |
| The TV opens VLC but nothing plays | The URL needs headers. Use `TV_FALLBACK=auto` or run `tv-fetch`. |
| Playback restarts when you seek | The server does not support ranges. Use `tv-serve` instead of `python -m http.server`. |
| Stutter or long buffering | Pick 720p in the TUI. A 1366x768 panel does not benefit from 1080p, and low-RAM TVs struggle with HEVC. |
| Termux dies in the background | Run `termux-wake-lock` and set Termux battery usage to Unrestricted. |
| The TV cannot reach the phone | Check that both are on the same subnet and that no VPN is active on the phone. |

## Notes

- Do not `adb push` video files to the TV unless it has free space. Many sets ship with 8 GB, and the system image takes most of it.
- Port 5555 is plaintext. The on-screen authorization prompt is the only gate. Turn USB debugging off when you are not using it, and do not leave it enabled on a shared network.
- Logs are written to `~/tvplay.log` and `~/tvserve.log`.
- To remove it, delete the `tv*` scripts and `termux-open` from `~/bin`, then delete `~/.tvrc`.

## Built for

A Vivo T4x running Android 16 with Termux, and a Haier H32K82FX Google TV
running VLC. Other Android TV and Google TV sets need the same two things: VLC,
and an open ADB port.

## License

GNU General Public License v3.0 only. See [LICENSE](LICENSE).
