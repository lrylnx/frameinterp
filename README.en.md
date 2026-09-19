# FrameInterp — Hardware Frame Interpolation Player for macOS

**The native Apple Silicon replacement for SVP4 Pro on Mac.** Real-time motion-compensated
frame interpolation running on Apple's **Neural Engine / media engine** — turn 24 / 25 / 30 fps
video into 60 / 96 / 120 fps. Native arm64. **No Rosetta. No VapourSynth. No CPU burn.**

> In one line: **24 fps → 60 fps, fully smooth, using 0.12 of a CPU core.**

[简体中文](README.md) · [Download the latest release](https://github.com/lrylnx/frameinterp/releases/latest)

---

## Table of contents

- [The problem](#the-problem)
- [How it differs from SVP4 Pro](#how-it-differs-from-svp4-pro)
- [Measured numbers](#measured-numbers)
- [Requirements](#requirements)
- [Download & install](#download--install)
- [Usage](#usage)
- [How the interpolation gear is chosen](#how-the-interpolation-gear-is-chosen)
- [FAQ](#faq)
- [Known limitations](#known-limitations)
- [About the source code](#about-the-source-code)

---

## The problem

Watching 24 fps films or anime on a 60 Hz / 120 Hz / 180 Hz display produces **judder** —
the source frame rate and the display refresh rate don't line up, so the display layer has to
repeat the last frame to fill the cadence. It's obvious on any horizontal pan.

On macOS the traditional answer is **SVP4 Pro** (SmoothVideo Project), which does
**CPU optical flow + OpenCL rendering**. On Apple Silicon that has three unavoidable problems:

1. It's **x86_64**, running under **Rosetta**;
2. Optical flow saturates every core — **fans spin up, laptops get hot**;
3. It uses **OpenCL**, which Apple has stopped pushing for years.

**But Apple Silicon already contains dedicated silicon for exactly this job.**
`VTLowLatencyFrameInterpolation` (part of the `VTFrameProcessor` family) exists for real-time
frame interpolation, runs on the Neural Engine / media engine, and produces one intermediate
frame per call with **zero lookahead** and low latency. This player drives it directly.

---

## How it differs from SVP4 Pro

| | SVP4 Pro (Mac) | FrameInterp |
|---|---|---|
| Motion estimation | CPU (mvtools, all cores) | **Hardware** (`VTFrameProcessor`) |
| Frame rendering | OpenCL (legacy, no longer advanced by Apple) | Same processor, in-pipeline |
| Architecture | x86_64 under Rosetta | **Native arm64** |
| CPU for 30 → 60 fps | Several cores | **0.12 of a core** |
| Dependencies | VapourSynth / mpv / SVP stack | **One .app, drag it in** |
| OS support | Also runs on old systems | **macOS 26+ / Apple Silicon** (hard limit) |
| Tuning knobs | Very extensive | Just Off / 2× / 4× |

**To be fair to SVP**: its strength is that it **runs on old Intel Macs and older macOS**, and it
offers far more tuning parameters. This player trades "runs anywhere" for "costs almost no CPU and
works out of the box", and the price is a **hard macOS 26 floor**.

Also note the hardware path is **zero-lookahead** — it must produce an intermediate frame from
just "previous + current". So **large occlusion regions** won't be as clean as multi-frame-lookahead
software algorithms. That's a fundamental trade-off, and it's what buys the real-time capability.

---

## Measured numbers

Test machine: Apple Silicon, 10 cores, fanless laptop; 1080p source; external 2560×1440 @ 180 Hz display.

```
source 29.999 fps  ->  interpolated 60.00 fps  [2x]  screen 180Hz
measured 60.3 fps     921 frames out   buffer 0.06s   playing
CPU 13.7%  (0.14 core)   no stutter

source 23.943 fps  ->  interpolated 95.77 fps  [4x]  screen 180Hz
measured 96.3 fps     2065 frames out  buffer 0.08s   playing
CPU 7.0%   (0.07 core)   no stutter
```

These are read straight off the player's own HUD (press `i` while playing).
The same HUD, interpolation on vs off:

![HUD comparison: top is 2× interpolation, bottom is passthrough](docs/hud-on-vs-off.png)

> Top: `60.00 fps [2×]`, measured 61.4 fps, **CPU 11.6% (0.12 core)**
> Bottom: `30.00 fps [passthrough]`, measured 31.1 fps — the original cadence with interpolation off.

| Scenario | CPU |
|---|---|
| 30 fps → 60 fps (2×) | **~0.12 – 0.14 of a core** |
| 24 fps → 96 fps (4×) | **~0.07 – 0.10 of a core** |

> 4× costs *less* than 2× because the cost scales with **source frames**: a 24 fps source only needs
> 24 frame-pairs per second, a 30 fps source needs 30. **The multiplier itself barely costs anything** —
> it only affects the final blending step.

More screenshots:

| | |
|---|---|
| [![2× → 60fps](docs/2x-60fps.png)](docs/2x-60fps.png) | [![4× → 96fps](docs/4x-96fps.png)](docs/4x-96fps.png) |
| 2× → 60 fps | 4× → 96 fps (cascaded interpolation) |
| [![Automatic fallback notice](docs/auto-fallback.png)](docs/auto-fallback.png) | [![Network stream playback](docs/network-stream.png)](docs/network-stream.png) |
| Automatic fallback when hardware can't keep up | Network streams, download-while-playing |

---

## Requirements

**Both are hard requirements:**

| | |
|---|---|
| **macOS 26.0 or later** | Interpolation relies on Apple's `VTLowLatencyFrameInterpolation`, available since macOS 26 |
| **Apple Silicon (any M1 / M2 / M3 / M4)** | It's a native arm64 binary and does not use Rosetta |

- ❌ **Intel Macs will not work** — neither the silicon nor the API exists there
- ❌ **macOS 15 or earlier will not work**
- ✅ **M1 is enough** — interpolation cost is tiny; the bottleneck is decode

---

## Download & install

1. Grab `FrameInterp-1.1-arm64.dmg` from [**Releases**](https://github.com/lrylnx/frameinterp/releases/latest)
2. Open the DMG and **drag the app into Applications**
3. If Gatekeeper blocks the first launch ("unidentified developer"):
   **right-click the app → Open → Open**. The app is ad-hoc signed (no paid Apple Developer
   certificate), but it needs **no special permissions, makes no network calls, and uploads nothing**.

> **Want it as your default player?** Menu → *File → Set as Default Player…* associates
> mp4 / mov / mkv / avi / webm / ts / flv / rmvb and 20 UTIs in one go — **no dialogs, no password**.

---

## Usage

Double-click the app, drop a video in. That's it.

**Ways to open**
- Double-click the app → empty window → drag a video in
- Right-click a video → *Open With* → the player
- Drag a video onto the Dock icon

**Keyboard**

| Key | Action |
|---|---|
| `Space` | Play / pause |
| `←` `→` | Back / forward 5 s (hold `Shift` for 30 s) |
| `↑` `↓` | Volume + / − (5% steps) |
| `f` | Fullscreen (`Esc` to exit) |
| `i` | Toggle the on-screen status HUD |
| `[` `]` | Lower / raise interpolation (Off → 2× → 4×) |
| `Esc` | Exit fullscreen, or quit when not fullscreen |

**Supported input**
- Natively decodable formats (mp4 / mov / m4v) play **directly, zero dependencies**
- mkv / rmvb / flv containers are automatically **remuxed** (`-c copy`, no re-encode, takes seconds)
  using your system `ffmpeg`, cached under `~/Library/Caches/` — the same file opens instantly next time
- **Network streams** (m3u8 / direct mp4 links) work too, downloading while playing. This path needs
  `ffmpeg` installed (`brew install ffmpeg`)

**UI**: controls and the cursor auto-hide after 3 seconds of inactivity, and come back on mouse move.

**Your display won't dim during playback.** While playing, the app holds a power assertion
(`IOPMAssertion` / `PreventUserIdleDisplaySleep` — the same one behind `caffeinate -d`), so the
screen stays on and won't slowly fade to black mid-movie. It's released the moment you pause,
finish, or close the window. If you only want audio, uncheck
*Play menu → Keep display awake during playback*.

---

## How the interpolation gear is chosen

Three positions only: **Off / 2× / 4×**. Switch with `[` `]` — **playback continues uninterrupted**.

When you open a file the player **picks the highest gear** subject to two hard constraints:

1. Hardware throughput (at 1080p: about 76 pairs/s for 2×, 26.7 pairs/s for 4×)
2. **Output frame rate should not exceed the display refresh rate** (anything above is wasted work)

| Source fps | 180 Hz display | 60 Hz display |
|---|---|---|
| 24 fps | **4× → 96 fps** (full) | 2× → 48 fps |
| 25 fps | 4× (borderline) | 2× → 50 fps |
| 30 fps | 2× → 60 fps | 2× → 60 fps |
| ≥ 50 fps | Off / 2× | Off |

**It automatically steps down when it can't keep up.** Take a 30 fps source pushed to 4× manually:
the hardware delivers 26.7 pairs/s but 30 are needed — an 11% shortfall. The symptom isn't "low frame
rate", it's **uneven cadence**: the display layer repeatedly shows the last frame to fill the beat,
which looks *worse* than a steady 48 fps. So the player **corrects for you once** — reverting to 2×
after a few seconds and showing a notice. If you press `]` again after that, it stops interfering.

> **Why there is no 3× or 5×**: the hardware's interpolation phase is **quantized to 1/8 steps**
> (measured: a requested 0.333 snaps to 0.375, and the output frames are pixel-identical).
> 3× needs phases 1/3 and 2/3, which aren't on that grid → output spacing becomes
> 0.375 / 0.25 / 0.375, i.e. **uneven**, producing periodic judder that cancels out the benefit.
> And actually cascading 3× measures 86 ms/pair — more than twice the 37 ms of 4×.
> **Only powers of two** (2×/4×/8×) land every phase on a cheap grid point.

---

## FAQ

**Will it run on my Mac?**
Check two things: **macOS 26+** and **Apple Silicon**. If both hold, yes. No Intel Mac will work.

**Is "0.12 of a core" real?**
That's the HUD reading for 1080p, 30 → 60 fps (screenshot above). In Activity Monitor the CPU
column reads about 12%. Note the units: **0.12 of a core = 1.2% of total CPU on a 10-core machine**,
not 0.12%.

**How's the quality versus SVP4 Pro?**
Comparable on moderate motion and clean footage. On **large occlusion** (a foreground object sweeping
across the background) the software algorithm is cleaner, because it looks ahead over multiple frames
while the hardware path is zero-lookahead. But SVP burns several cores on Apple Silicon; this uses 0.12.

**Does it support subtitles?**
**Not in the current version.** See the known limitations below.

**Does it modify my video files?**
No. Interpolation happens live during playback — nothing is written to disk, nothing is re-encoded.

**Why doesn't it help with 4K or 60 fps sources?**
4× at 4K exceeds hardware throughput (4× at 1080p is already near the ceiling), and sources at
≥ 50 fps have little to interpolate. The player automatically drops the gear or goes passthrough.

**Can it play network / online video?**
Yes — `m3u8` and direct `mp4` links, downloading while playing. Requires `ffmpeg` on your machine.
(A companion Chrome extension can sniff video streams from web pages and hand them to the player;
it is not distributed in this repository.)

---

## Known limitations

Listed plainly, so you find out now rather than after installing:

- **No subtitle rendering, no subtitle track support.** Not embedded, not external srt/ass.
  If you watch subtitled anime, this is a real gap.
- **macOS 26+ and Apple Silicon only** — not a lack of porting effort, it's a hardware/API floor.
- **Only 2× and 4×** — no 3× or 5× (see above for why).
- **No live streams** (indeterminate duration); the architecture assumes seekable, finite media.
- **Zero-lookahead algorithm** — mild artifacts are possible in large occlusion regions.
- **No features requiring special TCC permissions** (no screen recording, accessibility, or input monitoring).

---

## About the source code

**This is closed-source software; only the compiled `.app` is distributed.** This repository contains
documentation and download links only — **no source code** — and does not accept source contributions.

- Provided "as is", without warranty of any kind.
- You may freely download, install, and use it on your own devices.
- You may **not** decompile, disassemble, repackage, redistribute, or use it commercially.
- See [LICENSE](LICENSE) for details.

---

## Feedback

Please open an [Issue](https://github.com/lrylnx/frameinterp/issues) and **include**:

1. Your macOS version and chip (e.g. `M4 / 10-core`)
2. The source frame rate and resolution of the video
3. A screenshot of the HUD (press `i` while playing) — it shows measured fps, CPU, and the stutter counter

Diagnostic files live in `~/Library/Caches/硬件插帧播放/` (`stat.txt`, `events.log`).
Attaching them saves a lot of back-and-forth.

---

*FrameInterp — because the hardware was already in your machine.*
