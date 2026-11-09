# tvplay

Send a stream URL from Termux to VLC on an Android TV over ADB.

tvplay exists because moviebox-tui runs on the phone while the screen you want is
across the room. It works with any stream URL you can produce from a terminal.

## Quick start

Turn on USB debugging on the TV before the last two commands.

```sh
pkg install -y git android-tools curl python nmap
termux-setup-storage
git clone https://github.com/pdev-labs/tvplay.git
bash tvplay/install.sh
exec bash
tv-doctor
TV_FALLBACK=auto moviebox-tui
```

## How it fits together

```text
moviebox-tui
    |  stream URL
    v
~/bin/termux-open
    |  TV_IP unset: opens VLC on the phone
    |  TV_IP set:   runs tvplay
    v
tvplay --ADB--> VLC on the TV
    |
    |  no playback after TV_WAIT seconds
    v
tv-auto -> tv-fetch (download) -> tv-serve (HTTP) -> VLC on the TV
```

The direct path uses no download and no disk space. The TV fetches the stream
directly from the provider. The fallback exists for streams that only work with
headers the TV cannot send.

## Requirements

Phone:

- Termux from F-Droid. The Play Store build is discontinued and lacks features.
- `adb` from `android-tools`, plus `curl`, `python`, and `nmap`.
- Optional: `ffmpeg` for HLS downloads, `aria2` for faster direct downloads.
- VLC for Android, used by moviebox-tui when playback stays on the phone.

TV:

- Android TV or Google TV.
- VLC installed and able to open network streams.
- USB debugging enabled in Developer options.

Both devices on the same network. A phone hotspot is fine: the phone is the
access point host, so it can reach the TV even when the access point isolates
clients from each other. If the phone is on mobile data and the TV is on a home
router, they are on different networks and nothing here will work.

## Install

```sh
pkg install -y git android-tools curl python nmap
termux-setup-storage
git clone https://github.com/pdev-labs/tvplay.git
bash tvplay/install.sh
```

`install.sh` copies the scripts to `~/bin`, appends `~/bin` to `PATH` in
`~/.bashrc`, writes `~/.tvrc`, and creates `Download/tv`. Expected output:

```text
PATH: added ~/bin to ~/.bashrc
config: wrote ~/.tvrc with TV_IP=192.168.1.50
media: /data/data/com.termux/files/home/storage/downloads/tv
```

An extra `install:` line appears when a tool is missing. Fix that and run the
installer again.

Reload the shell so the new `PATH` applies:

```sh
exec bash
```

If you already know the TV address, pass it to the installer instead of editing
the file later:

```sh
bash tvplay/install.sh 192.168.1.50
```

## TV setup (once)

1. Open Settings > System > About.
2. Select "Android TV OS build" seven times. The TV says you are a developer.
3. Go back to Settings > System > Developer options and enable USB debugging.
4. Run `tv-doctor` from Termux. The TV shows an "Allow USB debugging?" dialog with a fingerprint.
5. Tick "Always allow from this computer" and accept.

Turn on "Disable adb authorization timeout" in the same menu. Android forgets
an unused authorization after seven days, and you would have to repeat step 5.

If the dialog never appears, press Home on the TV remote and run `tv-doctor`
again. Some sets only show the dialog on the launcher.

## Check the link

Run this before the first movie:

```sh
tv-doctor
```

A healthy result looks like this:

```text
settings
  TV           192.168.1.50:5555
  serve        port 8080, dir /data/.../storage/downloads/tv
  fallback     manual
phone
  ip           192.168.43.1
  storage      /data/.../storage/downloads
tv
  ping         ok
  port 5555    open
adb
  state        device
  VLC          installed on TV
server
  status       not running (starts with tv-fetch, or: tv-serve --daemon)
tools
  nmap         ok
  ffmpeg       missing
  aria2c       missing
```

The phone IP matters for the manual path, where the TV pulls a file over HTTP.
The `state` line is the one that usually fails. `unauthorized` means the dialog
was dismissed or timed out. `unreachable` means adb could not open the port.

## Daily use

Open Termux and run `termux-wake-lock`. Without it, Android may freeze the
session while the TV is buffering.

Turn the TV on and confirm it is on the same network as the phone. Start the TUI
with the fallback enabled:

```sh
TV_FALLBACK=auto moviebox-tui
```

Search for something, choose a resolution, and press Enter.

The prefix sets the fallback mode for this run. The handoff to the TV happens
whenever `TV_IP` is set, so plain `moviebox-tui` also plays on the TV and simply
skips the download fallback.

The sequence from there:

- moviebox-tui resolves the stream URL and calls `termux-open`.
- The wrapper in `~/bin` sees `TV_IP` and runs `tvplay` instead of opening a phone player.
- `tvplay` runs `adb connect`, sends a VIEW intent to VLC on the TV, and polls the TV every second.
- VLC usually appears within a second or two, and playback starts a few seconds later on a 720p stream.
- `tvplay` stops polling as soon as the TV reports a playing media session.

Press Enter in the TUI and watch the TV. The TUI may return to its own screen
immediately, and the messages from `tvplay` stay out of the way because the
wrapper sets `TV_QUIET=1`. To see them, run `TV_VERBOSE=1` before `moviebox-tui`
or read `~/tvplay.log`.

To keep playback on the phone for one run:

```sh
MB_LOCAL=1 moviebox-tui
```

## When the direct URL fails

Some providers hand out URLs that work only with a specific `Referer`,
`User-Agent`, or cookie. moviebox-tui forwards those headers to desktop players.
An Android intent carries no headers, so the TV gets the bare URL and may show
an error.

With `TV_FALLBACK=auto`, `tvplay` waits `TV_WAIT` seconds, then starts `tv-auto`
in the background. That script downloads the stream on the phone, starts
`tv-serve`, and sends VLC the local address. The TV may show an error screen
while the download runs; the second launch replaces it.

Download behaviour:

- Direct files go through `aria2c` when it is installed, otherwise `curl`.
- HLS playlists are recorded with `ffmpeg -c copy` into an MKV file.
- A 700 MB 720p file takes a few minutes on a typical hotspot. For HLS, ffmpeg downloads segment by segment, so the wait depends on the provider.
- Progress and errors go to `~/tvplay.log`.

The download is the reliable path, and it costs disk space in `Download/tv`.
Delete old files when the folder grows.

## Manual mode without ADB

If you do not want network debugging enabled on the TV, skip the ADB parts and
use the HTTP path:

```sh
tv-fetch "https://example.com/movie.mkv"
```

Expected output:

```text
downloading to /data/.../storage/downloads/tv/20261109-143000.mp4
/data/.../storage/downloads/tv/20261109-143000.mp4
http://192.168.43.1:8080/20261109-143000.mp4
```

`tv-fetch` downloads the file, starts `tv-serve` in the background, and prints
the local URL. Files that moviebox-tui downloaded itself may sit in `Download/`
rather than `Download/tv`; move them into `TV_DIR`, or point `TV_DIR` at the
folder you use. In VLC on the TV, choose "Open network stream" and enter:

```text
http://<phone-ip>:8080/now
```

`/now` redirects to the newest video in `Download/tv`, so this one entry keeps
working for every future download. VLC keeps it in history, which makes it two
taps on the remote.

Typing a URL with a TV remote is slow. Use the Google TV app on the phone as a
keyboard: open the app, connect to the TV, and use its keyboard field while the
URL box is focused on screen.

`tv-serve` also serves the folder at `http://<phone-ip>:8080/`. That listing is
useful in a browser for checking what is available. VLC does not browse HTML
listings, so give it `/now` or a direct file URL.

## Playing any URL

`tvplay` accepts `http`, `https`, `rtsp`, and `rtmp` URLs:

```sh
tvplay "https://example.com/trailer.mp4"
tvplay "https://example.com/live/index.m3u8"
```

The URL must be reachable from the TV. A URL on `127.0.0.1` points at the TV
itself, not the phone. Use the phone's LAN address for local files.

Exit codes: 0 when the TV reports playback, 1 when it does not start and the
fallback is `off`, 2 for bad arguments, 3 when `termux-open` is missing. The
auto fallback returns 0 after handing off to the background downloader.

## Serving files you already have

Copy or move the files into the directory in `TV_DIR`, then start the server:

```sh
tv-serve --daemon
```

Open `http://<phone-ip>:8080/now` on the TV for the newest file, or the direct
URL for a specific one. The server is unauthenticated, so anyone on the same
network can read that folder while it runs. Stop it with `tv-serve --stop` when
you are done.

## Quality and subtitles

Pick 720p. A 1366x768 panel throws away the extra detail of 1080p, and some
low-RAM TVs decode HEVC less smoothly than H.264. If the quality picker shows
codecs, prefer AVC for the direct path.

Embedded subtitle tracks travel with the video and work on the TV. External
subtitles do not: the wrapper forwards only the URL, so the separate subtitle
files moviebox-tui downloads to `Download/moviebox_subs` never reach the TV.
Choose releases with embedded subtitles, or load a subtitle manually in VLC
after the video starts.

## When the TV address changes

A hotspot restart can change the subnet, and the TV then gets a new address.
Run:

```sh
tv-discover
```

It reads the phone's address, scans that subnet for port 5555, and rewrites
`TV_IP` in `~/.tvrc`. It needs `nmap`. As an alternative, reserve a fixed lease
in your router if the TV is on a home network.

## Background and battery

`tv-serve --daemon` keeps running after the Termux session closes. Android can
still kill Termux when memory is tight. Keep `termux-wake-lock` active and set
Termux battery usage to Unrestricted in Android settings.

Check the server:

```sh
tv-serve --status
```

Logs:

- `~/tvplay.log` holds every URL, adb result, and fallback attempt.
- `~/tvserve.log` holds the HTTP server access log.
- `~/.tvserve.pid` holds the server process id.

## Command reference

| Command | Purpose |
|---|---|
| `tvplay <url>` | open a URL in VLC on the TV and poll for playback |
| `tv-fetch <url>` | download with aria2 or ffmpeg, start the server, print the URL |
| `tv-serve` | run the HTTP server in the foreground |
| `tv-serve --daemon` | start it in the background |
| `tv-serve --status` | show whether it is running |
| `tv-serve --stop` | stop it |
| `tv-doctor` | check the address, port, adb state, VLC, and server |
| `tv-discover` | scan the subnet for port 5555 and update `~/.tvrc` |
| `tv-auto <url>` | download and hand off; started by `tvplay` in auto mode |

## Configuration

`~/.tvrc`:

```sh
TV_IP=192.168.1.50
TV_PORT=5555
TV_SERVE_PORT=8080
TV_DIR="$HOME/storage/downloads/tv"
TV_WAIT=20
TV_FALLBACK=manual
```

| Variable | Default | Meaning |
|---|---|---|
| `TV_IP` | none | TV address. Run `tv-discover` if it changes. |
| `TV_PORT` | 5555 | ADB port. |
| `TV_SERVE_PORT` | 8080 | HTTP server port. |
| `TV_DIR` | `~/storage/downloads/tv` | Folder served at `/` and scanned by `/now`. |
| `TV_WAIT` | 20 | Seconds to wait for a playing session before falling back. |
| `TV_FALLBACK` | `manual` | `manual` prints the fetch command, `auto` downloads and serves, `off` does nothing. |

Environment overrides: `TV_QUIET=1` hides progress on the terminal while still
logging it, and `TV_VERBOSE=1` forces it back on. `MB_LOCAL=1` makes the
`termux-open` wrapper ignore `TV_IP` and play on the phone.

To make the fallback permanent, set `TV_FALLBACK=auto` in `~/.tvrc` and drop the
prefix from the launch command. `tv-doctor` reports the value from the file, not
from a one-off environment override.

## Files it creates

- `~/bin/tvplay`, `tv-fetch`, `tv-serve`, `tv-doctor`, `tv-discover`, `tv-auto`, `tvlib`
- `~/bin/termux-open`, which shadows the system `termux-open`
- `~/.tvrc`
- `~/storage/downloads/tv/`
- `~/tvplay.log`, `~/tvserve.log`, `~/.tvserve.pid`

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `state unauthorized` | The dialog was dismissed or timed out. Press Home on the TV, run `tv-doctor`, and accept it. |
| `Connection refused` on 5555 | USB debugging is off, the TV is asleep, or the address changed. Wake the TV, then run `tv-discover`. |
| `cannot reach` and the phone plays instead | adb failed, so `tvplay` fell back to the phone on purpose. Check `~/tvplay.log` for the adb message. |
| VLC opens on the TV, then errors | The URL needs headers. Use `TV_FALLBACK=auto` or `tv-fetch`. |
| Video plays but `tvplay` reports failure | The TV may not publish a media session, or it is slower than `TV_WAIT`. Raise `TV_WAIT`, or set `TV_FALLBACK=off`. Run `adb shell dumpsys media_session` and look for a videolan entry. |
| Subtitles are missing | External subtitle files are not forwarded. Use embedded tracks. |
| Seeking restarts the video | The server does not support ranges. Use `tv-serve`, not `python -m http.server`. |
| Stutter or long buffering | Select 720p. Use 5 GHz or Ethernet if available. |
| `tv-serve` reports the port is in use | Another process holds `TV_SERVE_PORT`. Stop it or change the port in `~/.tvrc`. |
| `/now` returns 404 | `TV_DIR` has no video files yet. Check the folder, or run `tv-fetch` first. |
| Download fails with 403 or 404 | Provider URLs expire. Start the download while the link is fresh. |
| Termux dies during playback | Run `termux-wake-lock` and set battery usage to Unrestricted. |
| The TV cannot reach the phone | Both must be on the same subnet. Turn off any VPN on the phone. |
| `install.sh` reports missing tools | Run `pkg install -y android-tools curl python nmap`. |

## Security

Port 5555 is a plaintext ADB port. The on-screen prompt is the only thing
stopping another device on your network from connecting. Turn USB debugging off
when you are not using this, and use "Revoke USB debugging authorizations" if a
device you no longer trust is listed.

`tv-serve` has no password. Anyone on the hotspot can read `TV_DIR` while it
runs. That is acceptable on a home network with a strong hotspot password.
Stop the server when you are done.

## Uninstall

```sh
tv-serve --stop
rm -f ~/bin/tvplay ~/bin/tv-fetch ~/bin/tv-serve ~/bin/tv-doctor \
      ~/bin/tv-discover ~/bin/tv-auto ~/bin/tvlib ~/bin/termux-open
rm -rf ~/.tvrc ~/tvplay.log ~/tvserve.log ~/.tvserve.pid
```

Remove the `export PATH="$HOME/bin:$PATH"` line from `~/.bashrc`. The files in
`Download/tv` are yours to keep or delete.

## Built for

A Vivo T4x running Android 16 with Termux, and a Haier H32K82FX Google TV with
VLC. Other Android TV and Google TV sets need the same two things: VLC, and an
open ADB port.

## License

GNU General Public License v3.0 only. See [LICENSE](LICENSE).
