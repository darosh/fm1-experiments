# fm1-experiments

Scratch repo for M-VAVE FM-1 firmware experiments, maintained mostly by an LLM following this
file. It pins thirteen upstream repositories at known revisions, keeps our changes as patch series, and
gives each firmware its own build, verify and deploy script.

## Contents

- [1. Prerequisites](#1-prerequisites)
- [2. Build and deploy](#2-build-and-deploy)
  - [LOOM-8](#loom-8-fm1-loom)
  - [AMB-1](#amb-1-fm1-amb)
  - [fm1-base template](#fm1-base-template-the-base-template)
  - [Felucca](#felucca-hugeltonfelucca)
  - [ZEN-1](#zen-1-zen-1)
  - [TONITOR](#tonitor-tonitor)
  - [SLOOP](#sloop-sloop-fm1)
  - [Dinghy](#dinghy-dinghy)
  - [CS-1](#cs-1-cs-1)
  - [Melodee](#melodee-melodee)
  - [Mutable Dreams](#mutable-dreams-mutable-dreams)
- [3. Pinned revisions](#3-pinned-revisions)
- [4. Layout](#4-layout)
- [5. Patches](#5-patches)
- [6. Bumping a pin](#6-bumping-a-pin)
- [7. Findings](#7-findings)
- [8. Troubleshooting](#8-troubleshooting)
- [9. Recovery](#9-recovery)

Eleven firmwares are built here. **LOOM-8** ([fm1-loom](https://github.com/charlesvestal/fm1-loom)) and
**AMB-1** ([fm1-amb](https://github.com/charlesvestal/fm1-amb)) sit on the shared fm1-base; fm1-base's
own **template** firmware is built too, as the platform's reference app. **Felucca**
([Felucca](https://github.com/hugelton/Felucca)) is standalone: it carries its own platform under
`firmware/` and does not use fm1-base or felucca-bsp. **ZEN-1** ([zen-1](https://github.com/aceyprime/zen-1))
is standalone too, on FoMni's older copy of the Felucca platform (vendored, no submodules).
**TONITOR** ([tonitor](https://github.com/nzimas/tonitor)) is standalone as well, on its own vendored
descendant of the Felucca/SLOOP platform (newer than ZEN-1's: 48 kHz USB audio, no submodules).
**SLOOP** ([sloop-fm1](https://github.com/isod89/sloop-fm1)) is standalone too, on its own vendored
descendant of the same platform (48 kHz USB audio, a runtime USB RATE menu, no submodules).
**Dinghy** ([dinghy](https://github.com/zvenson/dinghy)) is the "build your own firmware" template on
that platform, also vendored (and its own SMK-37 board layer). **CS-1**
([CS-1](https://github.com/twochannels/CS-1)) is a CS-80-style synthesizer built on Dinghy's platform.
Dinghy and CS-1 carry SLOOP's platform *before* its AS-first collection change: their stock plain
build is variant B below, the buggy layout. **Melodee**
([melodee](https://github.com/keremimo/melodee)) is a GPL-3.0 fork of Felucca with its own USB stack,
vendored (no submodules). It is included as a reference: its stock build is host-compatible with no
patch, and its descriptors solve the macOS bug a different way than we do (§7). **Mutable Dreams**
([mutable-dreams](https://github.com/kidbee85-beep/mutable-dreams)) is a standalone six-track
Mutable Instruments-inspired instrument: it vendors an fm1-base snapshot (fm1-base `bbfd461` plus
the app's own delta, with felucca-bsp `33cac69` under `base/bsp`), so it is not on our shared base
clone, and its stock plain build is variant B below. That snapshot is published only as a source
archive, which `setup.sh` extracts into `clones/mutable-dreams/src`.

The current experiment is **USB host compatibility**: the firmwares built from these patches have a
working USB audio input and a correctly named USB-MIDI port on macOS, Windows, Linux, Android and
iPadOS. Nothing here is pushed upstream.

---

## 1. Prerequisites

| what | why | how |
|---|---|---|
| Docker Desktop | the JieLi toolchain is Linux x86-64 only | install Docker Desktop |
| Rosetta (Apple silicon) | the build container is `linux/amd64` | `softwareupdate --install-rosetta --agree-to-license` |
| JieLi toolchain | `clang` for `pi32v2` | after the first `setup.sh`: `clones/fm1-base/tools/get_toolchain.sh` (installs `~/.jieli/toolchain`; the pinned package is `jieli-linux-toolchains-20260730.1`) |
| AC79 SDK | SPL, `cfg_tool.bin`, EQ table for packaging | see below |
| Python with Pillow+raqm, fontTools, numpy, scipy, freetype-py | fonts, screen-reader words; Felucca, TONITOR, SLOOP, Melodee and Mutable Dreams rasterise their UI font at build time; ZEN-1's reference-analysis selftest uses numpy/scipy; Font Rendering's hinted sets use freetype-py | `brew install python@3.15 pillow` (the venv is built from Homebrew python3.15 with `--system-site-packages`); `setup.sh` adds fontTools, numpy, scipy and freetype-py |

The SDK is ~1.4 GB and is **not** cloned into this repo:

```sh
. ./revisions.env
git clone --depth 1 --branch "$AC79_SDK_TAG" "$AC79_SDK_URL" "$HOME/fw-AC79_AIoT_SDK"
```

`JIELI_TOOLCHAIN` and `AC79_SDK` default to `~/.jieli/toolchain` and `~/fw-AC79_AIoT_SDK`; export
them to point elsewhere.

> Keep everything under `/Users`: `build.py` bind-mounts the common parent of the clones into the
> container, and Docker's file sharing does not cover arbitrary paths.

---

## 2. Build and deploy

One setup, then each firmware has its own scripts. Every script resolves the repo root itself, so
the blocks below work from any directory. **One block is one action** — an IDE's run action passes
the block's text to the shell as it is, so each block here is a single command with no comments or
decoration.

Setup (once):

```sh
./scripts/setup.sh
```

Run `setup.sh` twice and the second run is a no-op; that is the intended invariant.

**Flashing:** plug the FM-1 in and leave it running — the installer asks the running firmware to
enter the update mode. If the firmware does not start, hold **REC** while powering on (the chip's
own update mode). Deploy scripts take an explicit package as the first argument if you do not want
the last build, and pass `--info`, `--port NAME`, `--yes` and `--force` through to the installer.

### LOOM-8 (fm1-loom)

Build; writes `clones/fm1-loom/app/build/loom.fwsc`:

```sh
./scripts/build-loom.sh
```

The text blend is a build-time choice: `MIXED_RENDERING=1` selects the linear-light "MIXED"
blend (light ink is corrected for the panel's sRGB gamma) instead of the default sRGB one. It
applies to the device, host and web builds, so the two can be compared from one checkout:

```sh
MIXED_RENDERING=1 ./scripts/build-loom.sh
```

A model turned mid-note (cane and voile) is a build-time choice too: `MODEL_CHANGE_FADE` is what
an automated model knob does while a note sounds — unset or `0` resets the model at once (upstream,
which clicks), `1` fades the voice through the change, `2` keeps the note's model until the next
note. Same three builds, one variable (§7, "A model turned mid-note"):

```sh
MODEL_CHANGE_FADE=1 ./scripts/build-loom.sh
```

Host tests (run a build first):

```sh
./scripts/verify-loom.sh
```

Flash (`--info` prints the connected FM-1's identity and writes nothing):

```sh
./scripts/deploy-loom.sh
```

`build-loom.sh` passes its arguments to `fm1-loom/build.sh`: `--host` (host simulator), `--web`
(browser emulator), `--demo` (mirroring for demos), `--release X.Y`, `--no-ble`. v0.8.1's `fm1.toml`
turns Bluetooth MIDI and the USB MIDI host on in the default build (`--no-ble` builds `loom-usb.fwsc`
without the radio); the image is 526180 B, with 90304 B of RAM used and the pool 97% full.

### AMB-1 (fm1-amb)

Build; writes `clones/fm1-amb/app/build/amb.fwsc`:

```sh
./scripts/build-amb.sh
```

Host tests (run a build first):

```sh
./scripts/verify-amb.sh
```

Flash (`--info` prints the connected FM-1's identity and writes nothing):

```sh
./scripts/deploy-amb.sh
```

`build-amb.sh` passes `--host`, `--web`, `--release X.Y` (no `--demo`/`--no-ble`: AMB-1 has no
radio).

### fm1-base template (the base template)

Build; writes `clones/fm1-base/template/build/template-usb.fwsc`:

```sh
FM1B_MIRROR=1 FELUCCA_UAC_MIDI_LAST=1 FELUCCA_UAC_IAD=1 ./scripts/build-template.sh
```

fm1-base's host tests, including the USB descriptor matrix (run `build-template.sh` first):

```sh
./scripts/verify-base.sh
```

Flash the template (same update mode as above):

```sh
./scripts/deploy-template.sh
```

The template's `fm1.toml` has Bluetooth on. Upstream documents SDK V1.2.1 for it; with the pinned
V1.2.14 its `btctrler.a` wants `usr_timeout_del`, which fm1-base's shim defines only for its WiFi
build — `patches/fm1-base/08-ble-timer-shim` supplies it, and the BLE template now links against
V1.2.14 too. `build-template.sh` still builds the USB-only template (`--no-ble`) by default, the
smaller package the update-path test uses; pass no flag to `build.py` directly for the BLE one.
`verify-base.sh` runs fm1-base's whole suite; after `build-template.sh` its update-path test runs
against the USB-only package (it borrows the `template.fwsc` name the test looks for).

### Felucca (hugelton/Felucca)

Build; writes `clones/felucca/build/felucca.fwsc`:

```sh
./scripts/build-felucca.sh
```

Felucca's host tests (the engines' goldens, USB audio and descriptors, the UI renders, the update
path, the installer; run a build first — several need `build/felucca.fwsc` and `build/gen`):

```sh
./scripts/verify-felucca.sh
```

Flash (`--info` prints the connected FM-1's identity and writes nothing):

```sh
./scripts/deploy-felucca.sh
```

Felucca is **not** an fm1-base firmware: it vendors its own platform (`firmware/hal`, `firmware/src`,
including its own USB stack) and its only submodule is `firmware/engines` (Felucca-Engines). It builds
with the USB host-compat descriptor set: `build-felucca.sh` exports `FELUCCA_CDC=0` (no serial console)
and the plain-build flags `FELUCCA_UAC_MIDI_LAST=1`, `FELUCCA_UAC_IAD=1`; the serial number follows the
package identity (`FELUCCA_ID`, `FM-1_900`). `build-felucca.sh` passes `--release X.Y` and `--sdk DIR`
through; export `FELUCCA_CDC=1` for the console layout (then clear the two plain-build flags — they
`#error` on CDC builds). In the USB-only build MENU > USB SERIAL is still listed but does nothing:
the console it would switch is not compiled in.

### ZEN-1 (zen-1)

Build; writes `clones/zen-1/build/zen1.fwsc`:

```sh
./scripts/build-zen1.sh
```

ZEN-1's host tests (the platform guard, the DSP and scene goldens, the USB descriptor matrix, the
simulator scenarios, the update path, the installer; run a build first — several need
`build/zen1.fwsc` and `build/gen`):

```sh
./scripts/verify-zen1.sh
```

Flash (`--info` prints the connected FM-1's identity and writes nothing):

```sh
./scripts/deploy-zen1.sh
```

ZEN-1 vendors FoMni's copy of the old Felucca platform under `firmware/` (no submodules), so neither
fm1-base's nor Felucca's patches reach it: the host-compat set is ported into its own `usb.c`.
`build-zen1.sh` exports `OM_CDC=0` (no serial console) and `OM_UAC=1` (the USB audio input;
main.c maps these onto `FELUCCA_CDC` / `FELUCCA_UAC`), and the plain descriptors take
`FELUCCA_UAC_MIDI_LAST=1` and `FELUCCA_UAC_IAD=1`; the serial follows the package identity
(`FELUCCA_ID`, `FM-1_600`). Export `OM_CDC=1` for the console layout (then clear the plain-build
flags — they `#error` on CDC builds). `build-zen1.sh` passes `--release X.Y.Z` and `--sdk DIR`
through (the SDK otherwise comes from `AC79_SDK`).

ZEN-1's `tools/guard_platform.sh` keeps the platform byte-for-byte against its FoMni upstream;
`patches/zen-1` also relaxes it for `usb.c` (the file we diverge in) and requires the host-compat set
there instead. `setup.sh` fetches FoMni by SHA into the clone, because those commits are not on any
branch.

### TONITOR (tonitor)

Build; writes `clones/tonitor/build/tonitor.fwsc`:

```sh
./scripts/build-tonitor.sh
```

TONITOR's host tests (the generated tables and fonts, the target-instruction check, the DSP and sound
goldens, the screens, the backup protocol, the USB host-compat descriptors; run a build first — the
browser-installer test needs `build/tonitor.fwsc`):

```sh
./scripts/verify-tonitor.sh
```

Flash (`--info` prints the connected FM-1's identity and writes nothing):

```sh
./scripts/deploy-tonitor.sh
```

TONITOR vendors its own platform under `firmware/` (from Felucca and SLOOP; no submodules), so neither
fm1-base's nor Felucca's patches reach it: the host-compat set is ported into its own `usb.c`.
`build-tonitor.sh` exports `FELUCCA_UAC_MIDI_LAST=1` and `FELUCCA_UAC_IAD=1`; the serial follows the
package identity (`FELUCCA_ID`, `FM-1_700`, or `FM-1_7XY` with `--release`). Export either flag as 0
to override. `build-tonitor.sh` passes `--release X.Y` and `--sdk DIR` through. The USB audio input
is on in TONITOR 0.52 and later (`FELUCCA_UAC=1` in `firmware/src/tonitor.c`); there is no CDC
console build wired into its build script.

### SLOOP (sloop-fm1)

Build; writes `clones/sloop/build/felucca.fwsc`:

```sh
./scripts/build-sloop.sh
```

SLOOP's host tests (the sound goldens, the DSP and CPU budgets, the sequencer and screens, the FM6
engine, the installer and the offline site, and the USB descriptors; run a build first — the installer,
OTA and site tests need `build/felucca.fwsc`):

```sh
./scripts/verify-sloop.sh
```

Flash (`--info` prints the connected FM-1's identity and writes nothing):

```sh
./scripts/deploy-sloop.sh
```

SLOOP vendors its own platform under `firmware/` (from Felucca and SLOOP; no submodules), so neither
fm1-base's nor Felucca's patches reach it: the host-compat set is ported into its own `usb.c`.
`build-sloop.sh` compiles the serial console out (`FELUCCA_CDC=0`; SLOOP 2.7 dropped it from the FM-1's
build anyway) and exports `FELUCCA_UAC_MIDI_LAST=1` and `FELUCCA_UAC_IAD=1`; the serial follows the
package identity (`FELUCCA_ID`, `FM-1_900`, or `FM-1_9XY` with `--release`). Export any of them to
override — the layout flags `#error` on a CDC build. `build-sloop.sh` passes `--release X.Y` and
`--sdk DIR` through. The USB audio input is on in `firmware/src/felucca.c` (`FELUCCA_UAC=1`) and the
runtime AUDIO > USB RATE menu keeps working across the new layout.

### Dinghy (dinghy)

Build; writes `clones/dinghy/build/dinghy.fwsc`:

```sh
./scripts/build-dinghy.sh
```

Host tests (run a build first; the installer and OTA tests need `build/dinghy.fwsc`; the SMK-37
packages are optional, build them with `--board smk37` if you want them checked):

```sh
./scripts/verify-dinghy.sh
```

Flash (`--info` prints the connected FM-1's identity and writes nothing):

```sh
./scripts/deploy-dinghy.sh
```

Dinghy vendors the Felucca/SLOOP platform (no submodules) as SLOOP carried it before 2.7.2: the plain
build's AC collection names MIDI first and the interface order is `AC, MIDI, AS` — variant B, which
macOS 13–15 mis-attaches. The host-compat set is ported into its own `usb.c`:
`FELUCCA_UAC_MIDI_LAST` (MIDI behind the streams, and out of the AC collection: the fix),
`FELUCCA_UAC_IAD` (hygiene) and `FELUCCA_USB_SERIAL` (string descriptor 3, default `FELUCCA_ID`,
`FM-1_990` or `FM-1_99Y` with `--release`). `build-dinghy.sh` exports MIDI_LAST and IAD; its
`build.py` forwards them. It passes `--release X.Y`, `--board`, `--model` and `--sdk DIR` through.
`patches/dinghy/02-host-build` lets the macOS host tests compile the canvas strip (`gfx.c`'s `.pool`
section is ELF-only; CS-1 already handles it).

### CS-1 (CS-1)

Build; writes `clones/cs1/build/cs1.fwsc`:

```sh
./scripts/build-cs1.sh
```

Host tests (run a build first; they also need Node and Emscripten — `tools/get_emsdk.sh` installs
the latter — for the site and browser-emulator tests):

```sh
./scripts/verify-cs1.sh
```

Flash (`--info` prints the connected FM-1's identity and writes nothing):

```sh
./scripts/deploy-cs1.sh
```

CS-1 is built on Dinghy's platform (vendored, no submodules), so it has the same stock layout and the
same ported host-compat set: `build-cs1.sh` exports `FELUCCA_UAC_MIDI_LAST=1` and
`FELUCCA_UAC_IAD=1`, and the serial follows the package identity (`FM-1_950`, or `FM-1_95Y` with
`--release`). Its `build.py` forwards the flags; `tests/run_tests.sh` runs the three descriptor
variants (its upstream suite has no end marker, so the patch also adds the `ALL HOST TESTS PASSED`
line the verify script reads). `DINGHY_DUAL_CORE=0` builds single-core.

### Melodee (melodee)

Build; writes `clones/melodee/build/melodee.fwsc` (or `melodee-X.Y.fwsc` for a release):

```sh
./scripts/build-melodee.sh
```

Host tests (run a build first; the web tests need Node and are skipped without it):

```sh
./scripts/verify-melodee.sh
```

Flash (`--info` prints the connected FM-1's identity and writes nothing):

```sh
./scripts/deploy-melodee.sh
```

Melodee is a GPL-3.0 fork of Felucca with its own USB stack (`firmware/src/usb.c`, `usb_audio.c`,
`usb_audio_stream.c`, `usb_audio_desc.h`); it vendors its platform (no submodules) and **needs no
patch here**. Its build has duplex USB audio on by default (`MELODEE_USB_AUDIO=1` in
`firmware/src/melodee.c`): stereo playback and stereo or four-track capture, 16/24-bit PCM at
44.1 kHz, with the direction and capture layout chosen on the device (MENU > USB AUDIO and USB
INPUT). `build-melodee.sh` runs Melodee's own `build.sh`, which needs the venv's Pillow with Raqm;
it passes `--release X.Y[.Z]`, `--nightly` and `--sdk DIR` through. Melodee's `tools/build.py`
checks the SDK files against **AC79NN_SDK_V1.2.1** and *warns* (does not fail) on the pinned
V1.2.14, so the package carries V1.2.14's `cfg_tool.bin` and EQ table rather than the ones Melodee
was tested with. The MIDI serial console is not built in; Melodee's CDC composite and the USB audio
share EP2/EP3 and are mutually exclusive.

The SDK version also reaches the test suite: `tools/fm1_recover.py` accepts only the unmodified
**V1.2.1** `wl82loader.bin` (30,720 B, `d9de9f1c…`) that Melodee ships under `assets/recovery/`, and
it prefers `$AC79_SDK` when set. `verify-melodee.sh` therefore runs the suite against a temporary SDK
view: the pinned SDK's `uboot.boot`, `cfg_tool.bin` and `cfg/eq_cfg_hw.bin`, with Melodee's shipped
recovery helper in place of V1.2.14's. The build is unaffected and uses the pinned SDK as is.

### Mutable Dreams (mutable-dreams)

Build; writes `clones/mutable-dreams/src/app/build/mutable-dreams.fwsc` (or
`mutable-dreams-X.Y.fwsc` for a release):

```sh
./scripts/build-mutable-dreams.sh
```

Host tests and the descriptor check (run a build first; the descriptor check reads
`src/app/build/mutable-dreams.bin`, the WASM suite runs only when `WASI_SDK` names a clang):

```sh
./scripts/verify-mutable-dreams.sh
```

Flash (`--info` prints the connected FM-1's identity and writes nothing):

```sh
./scripts/deploy-mutable-dreams.sh
```

Mutable Dreams is standalone on a **vendored fm1-base snapshot**: `src/base/` is fm1-base `bbfd461`
(the revision the app was written against) with the app's own delta — `plat.h`'s bench hooks
(`plat_audio_peak_us`/`_reset`), `device/sysex_dispatch.h`, its backup tooling and the `dreams`
font set — and `src/base/bsp/` is felucca-bsp `33cac69` (no symlink, no submodules). That is why
it does not use our shared base clone: our pin is newer and does not carry those app hooks. Its
stock plain build is variant B below (`AC, MIDI, AS`, the AC collection naming both), so
`patches/mutable-dreams/01-usb-host-compat` ports the host-compat set into the vendored `usb.c`
unchanged, and `base/device/unity.c` turns `FELUCCA_UAC_MIDI_LAST` and `FELUCCA_UAC_IAD` on for
the plain build. The serial number follows `FELUCCA_ID` (`FM-1_71000`, or the release identity).
The CDC console is not part of this snapshot (its `console.c` is not vendored, so `FM1B_CDC=1`
does not link); the flags are plain-build only anyway and leave the CDC layouts' descriptors
untouched.

The upstream repository publishes **no source tree**, only release archives: `setup.sh` pins the
v1.1 commit and the `Mutable-Dreams-1.1-Source.zip` SHA-256, extracts the archive into
`clones/mutable-dreams/src` and commits it there so the patch series has a base. The build is
`src/base/tools/build.py src/app`, and `build-mutable-dreams.sh` passes `--release X.Y[.Z]` and
`--sdk DIR` through. Its build.py checks the SDK against **AC79NN_SDK_V1.2.1** and only warns on
the pinned V1.2.14, so the package carries V1.2.14's `cfg_tool.bin` and EQ table.

---

## 3. Pinned revisions

All pins live in [`revisions.env`](revisions.env), which the scripts source.

| repo | commit | role |
|---|---|---|
| `charlesvestal/fm1-loom` | `dfc94c6` (v0.8.1 + site republish) | LOOM-8 |
| `charlesvestal/fm1-amb` | `188b0a42` (v1.3) | AMB-1 |
| `charlesvestal/fm1-base` | `934e40d` | the platform layer (both firmwares' `base`) |
| `hugelton/felucca-bsp` | `2cd696a` | the chip layer (`fm1-base/bsp`) |
| `hugelton/Felucca` | `63f88ec` | Felucca (main, 5 commits past v1.6.1) |
| `hugelton/Felucca-Engines` | `c46e008` | Felucca's `firmware/engines` submodule |
| `aceyprime/zen-1` | `ec92952` (v1.2) | ZEN-1 |
| `nzimas/tonitor` | `f51bd68` (0.56) | TONITOR |
| `isod89/sloop-fm1` | `d893642` (2.8.1) | SLOOP |
| `zvenson/dinghy` | `22acb91` (0.4) | Dinghy |
| `twochannels/CS-1` | `5dce8fa` (0.3.4) | CS-1 |
| `keremimo/melodee` | `398ada1` (v1.4.5) | Melodee (reference: no patch) |
| `kidbee85-beep/mutable-dreams` | `04cf468` (v1.1) + archive `90fef68…` | Mutable Dreams (source is the pinned Source zip) |
| `charlesvestal/fm1-fomni` | `b81eb6b` / `6c32623` | ZEN-1's platform guard upstreams (fetched by SHA into the zen-1 clone) |
| AC79 SDK | tag `AC79NN_SDK_V1.2.14_2026-10-13` | external, outside this repo |
| JieLi toolchain | package `jieli-linux-toolchains-20260730.1` | external, outside this repo |
| docker base | `debian:bookworm-slim@sha256:7ff6ba3…` | the build container's image, `JIELI_DOCKER_IMAGE` |
| python | `mido 1.3.3`, `python-rtmidi 1.5.8`, `fonttools 4.66.1`, `numpy 2.5.4`, `scipy 1.18.1` | `.venv`, installed by `setup.sh` |

The repos are pinned to their latest `main` (LOOM-8, AMB-1, ZEN-1, Melodee and Mutable Dreams are
at their latest release tag; TONITOR, SLOOP, Dinghy and CS-1 have none, so their pins are their
latest main commits). ZEN-1's two `fm1-fomni` rows are not
clones: `setup.sh` fetches them by SHA into `clones/zen-1` for its platform guard, because they are
not on any branch of that repository. Mutable Dreams' pin is two things: the v1.1 commit that
publishes the release (and its checksums), and the SHA-256 of the source archive that commit
carries (the repository has no source tree of its own).
One fm1-base and one felucca-bsp are shared by both fm1-base firmwares, so the base is pinned to its
own `main` rather than to either firmware's submodule pointer (`934e40d` for LOOM-8 v0.8.1 — the
pin itself — and `15dff6d` for AMB-1, an ancestor). Felucca-Engines is pinned to the commit Felucca's own tree
names, not to engines `main`: engines `main` adds the PHASE engine and an FS-rate refactor, while
Felucca has its own `firmware/src/eng_phase.c` and goldens that pair with the older sources. The SDK
tag and the toolchain package are the newest published.

`./scripts/check-upstream.sh` reports which of these have moved since they were pinned, and by how
many commits (§6).

---

## 4. Layout

```
clones/                      ignored; scripts/setup.sh creates it
  fm1-loom/                  pinned checkout, branch "experiments"
    base -> ../fm1-base      symlink
  fm1-amb/                   pinned checkout, branch "experiments"
    base -> ../fm1-base      symlink
  fm1-base/                  pinned checkout, branch "experiments"
    bsp -> ../felucca-bsp    symlink
  felucca-bsp/               pinned checkout, branch "experiments"
  felucca/                   pinned checkout, branch "experiments" (standalone: no base/bsp)
    firmware/engines -> ../../felucca-engines   symlink
  felucca-engines/           pinned checkout, branch "experiments"
  zen-1/                     pinned checkout, branch "experiments" (standalone: no base/bsp/engines)
  tonitor/                   pinned checkout, branch "experiments" (standalone: no base/bsp/engines)
  sloop/                     pinned checkout, branch "experiments" (standalone: no base/bsp/engines)
  dinghy/                    pinned checkout, branch "experiments" (standalone: no base/bsp/engines)
  cs1/                       pinned checkout, branch "experiments" (standalone: no base/bsp/engines)
  melodee/                   pinned checkout, branch "experiments" (standalone: no base/bsp/engines)
  mutable-dreams/            pinned checkout (release assets only), branch "experiments"
    src/                     the pinned Source zip extracted and committed: the build root
patches/<repo>/<NN-problem>/NNNN-*.patch
scripts/
  setup.sh                   clones, archives, links, patches, venv, prerequisite report
  lib/common.sh              ROOT, the pins, environment, shared helpers
  lib/usb_desc.py            read a built image's USB descriptors; checks the host-compat set
  check-upstream.sh          what each pin is missing from upstream's default branch (§6)
  build-loom.sh   deploy-loom.sh   verify-loom.sh
  build-amb.sh    deploy-amb.sh    verify-amb.sh
  build-template.sh  deploy-template.sh  verify-base.sh
  build-felucca.sh   deploy-felucca.sh   verify-felucca.sh
  build-zen1.sh      deploy-zen1.sh      verify-zen1.sh
  build-tonitor.sh   deploy-tonitor.sh   verify-tonitor.sh
  build-sloop.sh     deploy-sloop.sh     verify-sloop.sh
  build-dinghy.sh    deploy-dinghy.sh    verify-dinghy.sh
  build-cs1.sh       deploy-cs1.sh       verify-cs1.sh
  build-melodee.sh   deploy-melodee.sh   verify-melodee.sh
  build-mutable-dreams.sh  deploy-mutable-dreams.sh  verify-mutable-dreams.sh
revisions.env                the pins
```

`mutable-dreams/` is the one clone whose source is not its checkout: the repository carries only
release assets, so `setup.sh` extracts `Mutable-Dreams-1.1-Source.zip` into `src/` (after checking
its pinned SHA-256) and commits it on `experiments`, giving the patch series a base whose pre-image
blobs exist. `src/` is the build root; there is no `base` symlink (its platform is vendored).

The submodule paths are **symlinks**, not real checkouts: one copy of each repo, and patches are
applied once. Git records those paths as submodules, so `setup.sh` sets
`diff.ignoreSubmodules=all` in each clone; without it, `git status` there fails with
`expected submodule path 'base' not to be a symbolic link` (and an IDE lists the path as a
permanent change). The builds do not care: fm1-base's `build.py` resolves the `bsp` link when it
computes its source root, and Felucca's mounts the common parent of `felucca/` and its engines
checkout (patches 03 in each set).

---

## 5. Patches

```
patches/
  felucca-bsp/01-usb-host-compat/   usb.c: interface order, serial number, an optional IAD
  fm1-base/01-usb-host-compat/      build.py: usb_midi_last, usb_iad, usb_serial; descriptor test
  fm1-base/02-sdk-v1.2.14/          build.py: the SDK hashes of the installed V1.2.14; the BLE trim
                                    accepts V1.2.14's multilink configuration (already 0)
  fm1-base/03-symlinked-bsp/        build.py: the source root covers a symlinked bsp
  fm1-base/04-esm-modules/          package.json: the web/ modules are ESM
  fm1-base/05-mixed-text-blend/     gfx.c: the MIXED coverage blend, behind MIXED_RENDERING=1 (build.py
                                    forwards it)
  fm1-base/07-stale-builder/        build.py: replace a toolchain container whose mount went stale
  fm1-base/08-ble-timer-shim/       ble/shim: usr_timeout_del, which V1.2.14's btctrler.a wants in a
                                    Bluetooth-only build
  fm1-base/09-model-change-fade/    build.py: forward MODEL_CHANGE_FADE, and give the host's and the
                                    web's o2 units opt_flags() (dsp/synth.c is an o2 unit)
  fm1-loom/01-usb-host-compat/      LOOM-8's USB names and its descriptor flags
  fm1-loom/02-mixed-text-blend/     gfx_loom.c: the same MIXED blend, behind MIXED_RENDERING=1
  fm1-loom/04-model-change-fade/    braids.h: a model turned mid-note, behind MODEL_CHANGE_FADE
                                    (0 reset, 1 fade through, 2 latch); the click measured in
                                    tests/host/braids_test.c, run once per mode
  fm1-loom/05-step-sel-list/        ui.c: SELECT moves a held step's SEL list (the lock editor no
                                    longer keeps it), and letting the step go closes the list
                                    instead of switching it to the pattern's (§7, bugs 4-5)
  fm1-amb/01-usb-host-compat/       AMB-1's: the same descriptor set, and its USB names
  felucca/01-usb-host-compat/       usb.c: MIDI behind the streams, the audio IAD, a serial; descriptor test
  felucca/02-sdk-v1.2.14/           build.py: the SDK hashes of the installed V1.2.14
  felucca/03-symlinked-engines/     build.py: the container mount covers a symlinked engines submodule
  zen-1/01-usb-host-compat/         usb.c: the same descriptor set, a descriptor test, and the platform
                                    guard relaxed for usb.c; build.py forwards the flags
  zen-1/02-sdk-v1.2.14/             build.py: the SDK hashes of the installed V1.2.14
  zen-1/03-esm-modules/             package.json: the web/ modules are ESM
  tonitor/01-usb-host-compat/       usb.c: the same descriptor set, a descriptor test, and build.py
                                    forwarding the flags
  tonitor/02-esm-modules/           package.json: the docs/ modules are ESM
  sloop/01-usb-host-compat/         usb.c: the same descriptor set, a descriptor test, and build.py
                                    forwarding the flags
  sloop/02-sdk-v1.2.14/             build.py: the SDK hashes of the installed V1.2.14
  sloop/03-target-budget/           tests/target_budget.txt: the pinned toolchain's loop counts
  dinghy/01-usb-host-compat/        usb.c: the same descriptor set, a descriptor test, and build.py
                                    forwarding the flags
  dinghy/02-host-build/             gfx.c: the canvas strip is an ordinary static on a macOS host build
  cs1/01-usb-host-compat/           usb.c: the same descriptor set, a descriptor test, build.py
                                    forwarding the flags, and the suite's end marker
  melodee/                          none: its own USB stack is already host-compatible (§7)
  mutable-dreams/01-usb-host-compat/  usb.c (under src/base/bsp): the same descriptor set; unity.c
                                    turns MIDI_LAST and the IAD on for the plain build
```

- Generated with `git format-patch`, applied with `git am --3way`, so the commit messages and
  authorship survive and applied work shows up as commits on the `experiments` branch.
- The `NN-` prefix on the problem directory defines order. It matters: most of fm1-base's patches
  touch `tools/build.py` and must apply in this order.
- The fm1-base patches are shared by both firmwares (one base clone); the fm1-amb patch turns the
  same `usb_midi_last`/`usb_iad` on in AMB-1's `fm1.toml`, so both firmwares present the same
  descriptor set.
- `setup.sh` skips a patch whose reverse applies cleanly (already applied), applies it if it
  applies cleanly, and stops with the patch name if neither is true.
- The two `mixed-text-blend` patches are build-time options, not the default: with
  `MIXED_RENDERING=1` in the environment, `build.py` adds `-DMIXED_RENDERING=1` for the device,
  the host and the web, and the partial-coverage blend remaps light ink on a darker pixel for
  linear light. Without it the blend is the platform's sRGB one, exactly as upstream. Dark ink on
  a light box keeps the raw coverage in both (the stem-darkening direction that reads better on
  the panel).
- `setup.sh` fetches DejaVu Sans into `assets/fonts/` (release tarball pinned by SHA-256 in
  `revisions.env`); no current patch reads it.

- `patches/mutable-dreams` applies to the extracted `src/` tree, so its paths carry that prefix;
  the archive commit is what its `index` lines resolve against.

Adding an experiment: make the change in `clones/<repo>`, commit it, then

```
git -C clones/<repo> format-patch <base>..HEAD -o patches/<repo>/03-<problem>
```

Regenerating an existing one: delete the old `.patch` files in that problem directory first, or
`format-patch` will add a second copy.

---

## 6. Bumping a pin

1. `./scripts/check-upstream.sh` lists every pinned repo with the number of commits upstream's
   default branch has that the pin does not, the newest commit there and any release tag; `-q`
   prints only the repos that have moved, and the exit status is 1 when any has. It fetches into
   `clones/` when `setup.sh` has made them and into `.cache/upstream-check/` otherwise, so it
   works before a setup too. For an archive-only upstream such as Mutable Dreams it counts
   commits and names the newest tag, but the source archive is pinned separately: take the new
   release's archive name and SHA-256 (and the top directory `setup.sh` moves into `src/`) from
   that release by hand.
2. Edit `revisions.env` with the new commit(s) — and, for an archive-only upstream such as
   Mutable Dreams, the archive name, SHA-256 and top directory from step 1.
3. Move `clones/` away (or delete it) so `setup.sh` clones fresh at the new pins. The pin check
   refuses to move an existing `experiments` branch forward, so this step is not optional.
4. Run `./scripts/setup.sh --no-patches` to get the new trees linked without our changes.
5. For each patch that the new pins made stale: apply the intent by hand in the clone, commit on
   `experiments`, delete the old `.patch` file, and regenerate it into a scratch directory first
   (the file name follows the subject, so writing straight into the problem directory leaves the
   stale file beside the new one). Example:

   ```
   git -C clones/fm1-base format-patch 0944289..HEAD -o /tmp/regen
   rm -f patches/fm1-base/01-usb-host-compat/*.patch
   cp /tmp/regen/*.patch patches/fm1-base/01-usb-host-compat/
   ```

6. Move `clones/` away again and run `./scripts/setup.sh` twice, to prove every patch applies on a
   fresh clone and the second run is a no-op.
7. `./scripts/verify-base.sh`, `./scripts/verify-loom.sh`, `./scripts/verify-amb.sh` (and the
   standalone firmwares' verifies when their pins move), then the builds, then re-check hardware if
   the change touches USB.

If `git am` stops inside a clone (a patch that neither applies nor is applied), the clone is left
mid-session: `git -C clones/<repo> am --abort` (and `am --show-current-patch` to see where).

Not every commit ahead is a reason to move a pin: Felucca-Engines follows Felucca's own submodule
pointer and fm1-base follows its own `main`, not either firmware's (`§3` has each pin's rationale).

---

## 7. Findings

### Dependency chain

`fm1-loom` → `base/` (fm1-base) → `bsp/` (felucca-bsp), and the same for `fm1-amb`. The macOS/USB
code lives in `bsp/chip/usb.c`, so one fix there reaches LOOM-8, AMB-1, the template and anything
else on the bsp.

Felucca is a separate chain: it vendors its own platform under `firmware/` — including its own,
diverged copy of the USB stack (`firmware/src/usb.c`, a GPL-3.0 descendant of `bsp/chip/usb.c`'s
descriptor code) — and its only submodule is `firmware/engines` (Felucca-Engines). The bsp patches
do not reach it; the USB fix is ported into its own `usb.c` and its own build script.

ZEN-1 is a third chain: it vendors FoMni's copy of the Felucca platform (the same lineage as
Felucca's, but an older revision: `firmware/src/usb.c` has no `FELUCCA_UAC_AS_FIRST` and no 48 kHz
input) and has no submodules at all. Its stock plain build is exactly the buggy variant — `AC, MIDI,
AS` with the AC collection naming both — and `iSerialNumber` is 0. The host-compat set is ported into
its `usb.c` the same way; its build script enables the audio input (`OM_UAC=1`), which upstream's
`main.c` already defaults on but its `build.py` did not let a caller select. Its
`tools/guard_platform.sh` keeps the rest of the platform byte-for-byte and now checks that `usb.c`
still carries the set.

TONITOR is a fourth chain: its platform is its own vendored descendant of Felucca and SLOOP (no
submodules), newer than ZEN-1's copy — USB audio since 0.52, 48 kHz since 0.54/0.56, and TONITOR
0.55's own #67 fix: the streaming interface first **inside the AC collection** while the interface
order stays `AC, MIDI, AS`. That is variant C below, which our bisection — and Felucca's own tested
1.6 build, which ships the same layout — found is not enough on macOS 15. The host-compat set is
ported into its `usb.c`; `build-tonitor.sh` turns the plain-build flags on and its `build.py`
forwards them (`FELUCCA_UAC` itself is on in `firmware/src/tonitor.c`).

SLOOP is a fifth chain: its own vendored descendant of the same Felucca/SLOOP platform as TONITOR
(no submodules), with 48 kHz audio and a runtime AUDIO > USB RATE menu. Since 2.7.2 it ships variant
C — the streaming interface first **inside the AC collection**, interface order `AC, MIDI, AS` — and
its own menu USB SERIAL toggle (a CDC composite, which macOS 13–15 mis-attach). The host-compat set
is ported into its `usb.c`; `build-sloop.sh` compiles the console out (`FELUCCA_CDC=0`, the default
from 2.7) and turns the plain-build flags on. The USB RATE menu's descriptor copies are made by
walking the configuration descriptor, so they follow the new order and the audio IAD unchanged.

Dinghy is a sixth chain (CS-1 a seventh, on it): its platform is a vendored copy of SLOOP's *before*
2.7.2, so its stock plain build is variant B — the AC collection names MIDI first and the interface
order is `AC, MIDI, AS`. The host-compat set is ported into its `usb.c`; `build-dinghy.sh` turns the
plain-build flags on. CS-1 vendors the same `usb.c` (only its endpoint-buffer alignment and MIDI ring
size differ from Dinghy's), so `patches/cs1/01-usb-host-compat` is the same set. Dinghy's host tests
also need `patches/dinghy/02-host-build`: `gfx.c` puts the canvas strip in `.pool`, which Mach-O has
no bare section for, so the static is plain on `__APPLE__`.

Melodee is an eighth chain and the odd one out: a GPL-3.0 fork of Felucca that keeps its own USB
stack (`firmware/src/usb.c` plus `usb_audio.c`, `usb_audio_stream.c` and `usb_audio_desc.h`) and
vendors the rest of its platform (no submodules). Nothing here patches it: its stock build is
host-compatible, and its descriptors are built on a different principle from the bsp's (below).

Mutable Dreams is a ninth chain: it vendors fm1-base `bbfd461` (plus the app's own delta) and
felucca-bsp `33cac69`, so its `base/bsp/chip/usb.c` is the same descriptor code the bsp had at
that pin — variant B in the plain build. The host-compat set is ported into that copy
(`patches/mutable-dreams/01-usb-host-compat`), and `base/device/unity.c` turns `MIDI_LAST` and
the audio IAD on for the plain build. Its source is distributed only as a release archive, so the
tree `setup.sh` builds is the extracted archive, not the checkout. Its platform predates 48 kHz
USB audio (`FM1B_UAC_48K` off), and `usb_audio_out` is off in its `fm1.toml`: the build has the
stereo input only.

### Bug 1 — no USB audio input on macOS 13–15

Upstream: [hugelton/Felucca#67](https://github.com/hugelton/Felucca/issues/67),
[kmplngj/Felucca#532](https://github.com/kmplngj/Felucca/issues/532).

The plain build has no CDC function and emits `AC(0) MIDI(1) AS(2)`, with the AC header's
collection naming both MIDI and the streaming interface. Community fixes bundled three changes and
never bisected them. We did, on macOS 15.8.1:

| variant | AC collection | interface order | audio |
|---|---|---|---|
| A | streaming only | AC, AS, MIDI | works |
| B | streaming only | AC, MIDI, AS | **fails** |
| C | streaming + MIDI | AC, AS, MIDI | works |
| D | streaming + MIDI | AC, MIDI, AS | **fails** (reproduces the bug) |

**Moving the MIDI function behind the streaming interfaces is what fixes it.** The collection
change alone is necessary-but-not-sufficient, and it moves with the ordering anyway (once MIDI
leaves the audio function it must leave the collection). Implemented as `FELUCCA_UAC_MIDI_LAST`,
enabled through `usb_midi_last` in `fm1.toml`; both fm1-base firmwares turn it on, and Felucca,
ZEN-1, TONITOR, SLOOP, Dinghy and CS-1 export it from their build scripts, and Mutable Dreams sets
it in its vendored `base/device/unity.c` (Melodee does not need it: its MIDI is a function of its
own — see below). TONITOR 0.55, SLOOP 2.7.2 and Felucca
1.6 all ship variant C (the streaming interface first in the collection, the old interface order); it
does not fix the audio input on macOS 15.

The shipped builds also carry `FELUCCA_UAC_IAD` (`usb_iad`), which gives the audio function an IAD
covering AC + AS only. It is descriptor hygiene, not a host fix: the plain no-IAD build enumerates
on every host we tried too, and the flag is there so the audio interfaces are explicitly one
function.

### Felucca — the same bug, fixed differently upstream

Upstream Felucca already has a fix for #67, `FELUCCA_UAC_AS_FIRST` (default on since 1.6): it lists
the streaming interface before MIDI **inside the AC header's collection** but leaves the interface
order `AC, MIDI, AS`. That is variant C above plus the old order — and a stock Felucca build's USB
audio input does not appear on macOS 15 (tested on the device). Its own MENU > USB SERIAL OFF, which
re-enumerates as a plain audio + MIDI device (`FELUCCA_CDC=0`'s descriptors), does not help either,
for the same reason: it keeps the old order.

`patches/felucca/01-usb-host-compat` therefore ports the same three changes into Felucca's own
`usb.c`: `FELUCCA_UAC_MIDI_LAST` (the fix), `FELUCCA_UAC_IAD` (hygiene) and `FELUCCA_USB_SERIAL`
(bug 2). They default to 0, so upstream's byte-for-byte descriptor tests keep passing;
`build-felucca.sh` exports them, with `FELUCCA_CDC=0` — the serial console is a developer tool and
its CDC composite is the layout macOS 13–15 mis-attaches, so it is compiled out. Build the console
variant with `FELUCCA_CDC=1` (and no MIDI_LAST/IAD) if you want it.

### Melodee — one audio function per job, every function contiguous

Melodee has the same symptom class (a UAC1 input that macOS 13–15 mis-attaches) and never had the
bug, because it does not put MIDI and the audio streams in the same function. Its configuration
carries **two audio functions**, each behind an IAD:

| function | IAD | interfaces | AC header's collection names |
|---|---|---|---|
| MIDI | 0–1 | 0 = AC, 1 = MIDI streaming | IF1 |
| playback + capture | 2–4 | 2 = AC, 3 = playback AS, 4 = capture AS | IF3, IF4 |

The raw interface order is `AC, MS, AC, AS, AS`. The bsp's layout is one audio function whose
streaming interfaces MIDI can sit between (variants B and D in the table above); Melodee's audio
function is not interleaved with anything — its AC and both streaming interfaces are contiguous and
covered by its own IAD, so the condition behind the macOS bug never arises. It is not a fifth
variant: the fix here is structurally different, not a different ordering. Melodee therefore needs
no `FELUCCA_UAC_MIDI_LAST` equivalent, and moving MIDI behind the streams would not be a meaningful
change.

Other differences worth knowing:

- **The configuration is rebuilt on the device.** `ua_cfg_build()` walks a template descriptor and
  drops a disabled direction (MENU > USB AUDIO: IN+OUT, IN, OUT, OFF) — its streaming interface,
  terminal pair and, for playback, the feature unit — then renumbers interfaces, rewrites the AC
  header's collection and adjusts the IAD. MENU > USB INPUT switches capture between the stereo
  master and four mono track stems (2 vs 4 channels; 16-bit packet 360 B, 24-bit 540 B). `bcdDevice`
  becomes `3.30 + direction bits + 4-track bit` (3.30–3.37) so a host that caches descriptors sees
  a new revision for each layout; the product string stays `Melodee FM-1`.
- **Rate.** UAC1 at a fixed 44.1 kHz: one discrete frequency in the format descriptors, `GET_CUR` /
  `GET_MIN` / `GET_MAX` = 44100, `GET_RES` = 0, and `SET_CUR` accepts and rounds anything else to
  44.1 kHz. There is no 48 kHz mode and no resampler (the bsp's `FELUCCA_UAC_48K` has both). Hosts
  commonly offer both 44.1 and 48 kHz for such a device; a client set to 48 kHz is resampled in the
  host's audio stack, not by the firmware.
- **Formats and endpoints.** Playback and capture each have alt 1 = PCM16 and alt 2 = PCM24. The
  playback endpoint is asynchronous with an explicit 10.14 feedback endpoint (3 bytes, EP3 IN);
  playback volume and mute are a standard UAC1 feature unit (FU5). The streams run from the TIMER5
  ISR and are served by elapsed time, like TIMER5 MIDI.
- **Identity.** `iSerialNumber` is 0 (the bug-2 fix is not here). Identity is the product string plus
  the per-layout `bcdDevice` revision. That is enough for a host to re-read the descriptors after a
  USB AUDIO / USB INPUT change, but not enough to tell two Melodee builds with the same layout
  apart — the opposite trade-off from our serial.
- **Device class.** The audio build is `misc/IAD` (`EF/02/01`); the MIDI-only build has no IAD and
  uses class 0. The update loader is a separate MIDI-only build named `Melodee FM-1 Update`.

On macOS 15 a stock Melodee build enumerates with working input and output, including the four-channel
capture, with no descriptor patch (tested on the device): the computer sees both the playback and the
recording stream, and can select either rate its stack offers. The four-track option is selected on
the FM-1 (MENU > USB INPUT) and the host then sees four input channels; the stereo master is the
default.

### Bug 2 — stale MIDI device name (AMB-1 stuck on LOOM-8)

`iSerialNumber` was 0 and `bcdDevice` only varied with feature flags, so every firmware on
VID/PID `1209:0001` looked identical to the host and cached names stuck. Each build now reports its
package identity as string descriptor 3 (`FELUCCA_USB_SERIAL`, default `FELUCCA_ID`). The update
loader keeps `iSerialNumber 0` so installer tooling is untouched.

### Cross-platform result (shipped configuration)

| host | result |
|---|---|
| macOS 15.8.1 | audio input, correct Manufacturer/Model |
| Windows 11 | audio + MIDI, two clean child devices |
| Linux (Nobara) | audio works; card name reads "pid.codes Test PID" (see below) |
| Android | ok |
| iPadOS | ok |

Linux naming is **not** a descriptor bug: `lsusb -v` shows `iProduct "FM-1 LOOM-8"`, but ALSA
prefers the usb.ids entry for `1209:0001`. The real fix is a non-test PID from
[pid.codes](https://pid.codes/) — the bsp's own comment says the current one "must be replaced
before any release".

### Bug 3 — automating the model knob on cane (or voile) clicks

`model` is `TP_E1`, and for cane and voile it is a discrete selector that is deliberately left out
of the glide (`E_GLIDE` is `0xE` for both, so bit 0 steps at a 64-sample chunk boundary). The
model's entire state *is* the voice: a waveguide line for pluck, bow, reed and flute, the partials
or formants for bell, drum, vowel, choir and whisper. `cn_prep` / `vo_prep` compare the model with
the one the state was made for and reset it when they differ — `cn_clear` zeroes the
1536-sample slot and `o[1..15]`, then `cn_chunk` strikes; `vo_init` zeroes the formants. So the
change steps the output from the old model's sample (measured: 0.25 where the bell's own largest
step is 0.13) straight to zero, and the new model starts from rest. The manual's "the pluck and
the strikes play once on each note" is the same reset, but a *held* note should not restart.

Nothing is wrong with the automation path itself; the defect is that a discrete selector wipes a
sounding voice. It is reachable three ways, all of which were checked:

- a parameter lock on the step (`lock_knob` → a lane → `apply_locks`/`lock_put` → `synth_lock`),
- recorded motion (the same lane, written by `seq_rec_knob`),
- the track LFO with destination `synth` and parameter `model` (`LD_TP[LD_SYNTH][0] = TP_E1`),
  which sweeps the model every chunk; with `SHAPE` a lock ramp steps it too.

`MODEL_CHANGE_FADE` selects the treatment (`patches/fm1-base/09-model-change-fade` forwards it to
the device, host and web, as `MIXED_RENDERING` is; `patches/fm1-loom/04-model-change-fade` is the
engine). Unset or `0` is upstream, byte-for-byte: the image is 526180 B and the click is there.

| `MODEL_CHANGE_FADE` | what a change during a note does | steps a sample across it (cane / voile) | image |
|---|---|---|---|
| `0` (default) | resets the voice at once — the click | 0.25 / 0.34 (their own waveforms: 0.13 / 0.11) | 526180 B |
| `1` | fades the voice out over 3 ms, switches at zero, back in over 3 ms | 0.04 / 0.11 | 526776 B |
| `2` | the note keeps its model; the lock reaches the next note | 0.02 / 0.008, and bit-identical to no change at all | 526536 B |

Measured by `tests/host/braids_test.c` (a droning bell / whisper changed at eight successive
blocks, each compared with the models' own largest step; the suite runs once per mode). RAM and
the pool are unchanged in every mode — the fade lives in three floats of the engine's derived-value
array that cane and voile do not otherwise use, not in `voice_t`. `dsp_hash`'s 623 cases are
identical in all three modes, so mode 1 changes no existing sound; the fade costs one multiply a
sample and only while it is in flight.

Mode 1 is the one that keeps automation live; mode 2 is the conservative reading (the model knob
behaves like `TP_ENGINE`, which only takes effect on the next note). Neither is wired in by
default: the flag is there to compare them on the FM-1.

### Bug 4 — SELECT does not move a held step's SEL list

Seen on LOOM-8 v0.8.1. On Steps, hold a step's key and press EDIT (the lock editor: the knobs
show that step's locks), then tap SEL. The step's list opens (`REMOVE <note>`, `COPY STEP`,
`CLEAR LOCKS`) and its footer offers **SELECT move** — but turning SELECT does nothing, the
highlight stays on the first row. ALGORITHM still changes a row's value and SEL still runs the row
under the highlight, so only the choice of row is stuck. The same list opened without EDIT held
scrolls normally, which is why this reads as "the SELECT knob is dead in this menu".

Cause: `input()` in `app/ui.c` takes every SELECT turn for the lock editor's own page cycle
(`ui.lockpg`, the held step's EDIT/ENV/FX/LFO pages) and consumes the event before the list
branch is reached; `list_move()` (`lst.open`) never sees it. The lock editor and the list can be
open at once, and the list did not take precedence.

Fix: `patches/fm1-loom/05-step-sel-list`, first commit — the page cycle yields while a list is
open, and resumes when the list closes (the held step and EDIT are untouched).

Repro on the FM-1:
1. Steps page, a track with a note on a step.
2. Hold that step's key; press and hold EDIT. The lock editor's knobs show pitch/length/punch/tone.
3. Tap SEL. The step's menu appears; the footer says SELECT move.
4. Turn SELECT. Nothing moves.
5. Let go of EDIT and step, hold the step again, tap SEL without EDIT: SELECT moves the same menu.

Regression: `tests/scenarios/heldsteplist.xy` opens the list over the lock editor, turns SELECT
down to CLEAR LOCKS, picks it, and checks the step's note is still there (the unfixed build stays
on REMOVE and deletes the note).

### Bug 5 — releasing the held step turns its SEL list into the pattern's

Seen on LOOM-8 v0.8.1. On Steps, hold a step and tap SEL: its list opens. Let the step key go
without picking a row: instead of going back to the Steps page, the menu is rebuilt as the
pattern's own Steps list (`PATTERN`, `LENGTH`, `SCALE`, `GROOVE`, `QUANT`, `NOTE`, `SHAPE`,
`CLEAR NOTES`, …) and the selection resets to its first row. The step's actions disappear, and
what was meant to dismiss the menu can now run a pattern-level action.

Cause: the list keeps no state of its own — `list_build()` decides its rows from `ui.held` on
every draw. Releasing the last held step cleared `ui.held`, `ui.lockpg` and `ui.trickpg` but left
`lst.open` set, so the next repaint built the pattern list.

Fix: the second commit of the same patch — the last step's release closes the list (with more
steps still held the list stays, on the one left, as before).

Repro on the FM-1:
1. Steps page, hold a step's key and tap SEL. The step's menu opens.
2. Let go of the step key. The menu changes to PATTERN / LENGTH / SCALE / … instead of closing.

Regression: `tests/scenarios/heldsteplist.xy` (after the step is let go, SELECT must turn the
Steps page to Bar; the unfixed build keeps the leftover list and scrolls it instead).

### SDK and the boot area

The SDK contributes exactly three blobs, and the update path writes only two of them:

| blob | placement | written by the installer? |
|---|---|---|
| `uboot.boot` | flash `0xA0` (head) | **no** — the loader's range starts at `0x4000` |
| `cfg_tool.bin` | app area | yes |
| `cfg/eq_cfg_hw.bin` | app area | yes |

So `SDK_SHA256` pins **V1.2.14** (what is installed) rather than changing what the device runs: a
firmware installed over USB-MIDI keeps whatever SPL is already on the device. V1.2.1 has the same
`cfg_tool.bin`, a smaller EQ table, and a different `uboot.boot`.

### Build quirks worth knowing

- `build.py` computes its source root as the common parent of fm1-base, the app and the resolved
  `bsp`; every compile path is relative to it. Keep all clones under one parent (our patch 03 is
  what makes the template — an app *inside* fm1-base — build with a symlinked bsp).
- `chip/uac_fir.h` is absent at this pin, so host test builds must define `FELUCCA_UAC_48K=0`
  (the descriptor test does).
- The template's Bluetooth build links against the pinned V1.2.14 once
  `patches/fm1-base/08-ble-timer-shim` provides `usr_timeout_del`; before that it needed SDK
  V1.2.1. Its USB-only build always worked with V1.2.14.
- The GUI arm of the bsp (`FELUCCA_USB_LAYOUT`, CDC console) is orthogonal and untested here; the
  new flags `#error` on CDC builds rather than multiplying the matrix.
- SLOOP's static target budget was measured with an older toolchain; on a stock checkout of its pin
  the pinned `jieli-linux-toolchains-20260730.1` clang counts the loops differently (`drums_mix`
  +11 %, `fm1_alnk0_irq` +54 %). Its patch 03 remeasures it with `BUDGET_UPDATE=1` — the patched and
  stock builds print identical numbers, so the change is the compiler's.
- Felucca's `build.py` mounts its own tree in the container; a symlinked `firmware/engines` needs the
  common parent mounted instead (its patch 03). Felucca also generates its UI font at build time, so
  the venv needs `fontTools` (the 48 kHz FIR, `chip/uac_fir.h`'s equivalent, **is** in Felucca's
  `firmware/src`).

---

## 8. Troubleshooting

| symptom | cause / fix |
|---|---|
| `expected submodule path 'base' not to be a symbolic link` | run `setup.sh` (it sets `diff.ignoreSubmodules=all` in each clone); otherwise `git -C clones/<repo> status --ignore-submodules=all` |
| `build: cannot start the toolchain container` | Docker not running; or the tree is outside `/Users` (file sharing) |
| `JIELI_TOOLCHAIN must point at ...` | run `clones/fm1-base/tools/get_toolchain.sh` |
| `warning: toolchain package ...; revisions.env pins ...` | the toolchain is not the pinned build; re-run `get_toolchain.sh` (newest) or update the pin |
| `warning: SDK ... differs` | SDK is not at the pinned tag; re-clone the SDK or update the pin **and** `SDK_SHA256` |
| patches fail after a pin bump | expected; use `setup.sh --no-patches` and regenerate them (§6) |
| `error: ... neither applies nor is already applied` mid-session | `git -C clones/<repo> am --abort` |
| `firmware/engines is empty` | run `setup.sh` (it links `clones/felucca/firmware/engines` to `clones/felucca-engines`) |
| `deploy-*.sh: no package in ...` | run the matching build first; a release build is named `NAME-X.Y.fwsc` and is picked automatically |
| `undefined reference to usr_timeout_del` in a BLE build | `patches/fm1-base/08-ble-timer-shim` is missing (the symbol lives in the Wi-Fi shim otherwise); re-run `setup.sh`, or use `--no-ble` |
| `warning: SDK ... differs from AC79NN_SDK_V1.2.1` (Melodee or Mutable Dreams build) | expected: both check their tested SDK (V1.2.1), the pinned one is V1.2.14 and only warns; see §2 |
| Mutable Dreams: `no clones/mutable-dreams/src` | `setup.sh` could not unpack the source archive; install `unzip`, or the archive's SHA-256 no longer matches the pin (see `revisions.env`) |
| Melodee: `Unsupported wl82loader.bin` from `tools/fm1_recover.py` | the tool accepts only the V1.2.1 helper Melodee ships, and prefers the (V1.2.14) `$AC79_SDK` one when set; pass `--loader clones/melodee/assets/recovery/wl82loader.bin` or unset `AC79_SDK`; `verify-melodee.sh` already does this |
| macOS shows the old MIDI name | CoreMIDI caches per VID/PID/serial: unplug, delete the stale entry in Audio MIDI Setup → MIDI Studio, replug. Each build here reports its identity as the serial, so switching between LOOM-8, AMB-1, Felucca, ZEN-1, TONITOR, SLOOP and Mutable Dreams gives distinct entries |
| Linux card named "pid.codes Test PID" | host-side naming; see the pid.codes note above |

## 9. Recovery

`clones/felucca-bsp/tools/fm1_rescue.py` restores **M-VAVE's stock V15** through the chip's
mask-ROM bootloader. It does not restore FM1 Community or any other custom firmware — reflash those
from their own releases. Flashing is at your own risk.
