# fm-1-experiments

Scratch repo for M-VAVE FM-1 firmware experiments, maintained mostly by an LLM following this
file. It pins three upstream repositories at known commits, keeps our changes as patch series,
and scripts the whole clone → patch → build → flash flow.

The current experiment is **USB host compatibility**: LOOM-8 built from these patches has a working
USB audio input and a correctly named USB-MIDI port on macOS, Windows, Linux, Android and iPadOS.
Nothing here is pushed upstream.

---

## 1. Prerequisites

| what | why | how |
|---|---|---|
| Docker Desktop | the JieLi toolchain is Linux x86-64 only | install Docker Desktop |
| Rosetta (Apple silicon) | the build container is `linux/amd64` | `softwareupdate --install-rosetta --agree-to-license` |
| JieLi toolchain | `clang` for `pi32v2` | after the first `setup.sh`: `clones/fm1-base/tools/get_toolchain.sh` (installs `~/.jieli/toolchain`) |
| AC79 SDK | SPL, `cfg_tool.bin`, EQ table for packaging | see below |
| Python with Pillow+raqm | fonts, screen-reader words | `brew install python@3.15 pillow` (the venv is built from Homebrew python3.15 with `--system-site-packages`) |

The SDK is ~1.4 GB and is **not** cloned into this repo:

```sh
. ./revisions.env
git clone --depth 1 --branch "$AC79_SDK_TAG" "$AC79_SDK_URL" "$HOME/fw-AC79_AIoT_SDK"
```

`JIELI_TOOLCHAIN` and `AC79_SDK` default to `~/.jieli/toolchain` and `~/fw-AC79_AIoT_SDK`; export
them to point elsewhere.

> Keep everything under `/Users`: `build.py` bind-mounts the common parent of fm1-base and the app
> into the container, and Docker's file sharing does not cover arbitrary paths.

---

## 2. Quick start

```sh
./scripts/setup.sh      # clone at the pins, link submodules, apply patches, make .venv
./scripts/verify.sh     # host tests, incl. the USB descriptor matrix
./scripts/build.sh      # -> clones/fm1-loom/app/build/loom.fwsc
./scripts/deploy.sh     # flash the FM-1 (put it in update mode: hold OCT- and OCT+ ~5 s)
```

Run `setup.sh` twice and the second run is a no-op; that is the intended invariant.

`build.sh` passes its arguments to `fm1-loom/build.sh`: `--host` (host simulator), `--web`
(browser emulator), `--demo`, `--release X.Y`, `--no-ble`.

---

## 3. Pinned revisions

All pins live in [`revisions.env`](revisions.env), which the scripts source.

| repo | commit | role |
|---|---|---|
| `charlesvestal/fm1-loom` | `97d6726` | the firmware we build (LOOM-8) |
| `charlesvestal/fm1-base` | `93bee3f` | platform layer (`fm1-loom/base`) |
| `hugelton/felucca-bsp` | `33cac69` | chip layer (`fm1-base/bsp`) |
| AC79 SDK | tag `AC79NN_SDK_V1.2.14_2026-10-13` | external, outside this repo |
| toolchain | latest from `pkgman.jieliapp.com` | external, outside this repo |

The commits are exactly the ones the upstream submodule pointers name, so a clean checkout
reproduces what the firmware expects before our patches.

---

## 4. Layout

```
clones/                      ignored; scripts/setup.sh creates it
  fm1-loom/                  pinned checkout, branch "experiments"
    base -> ../fm1-base      symlink
  fm1-base/                  pinned checkout, branch "experiments"
    bsp -> ../felucca-bsp    symlink
  felucca-bsp/               pinned checkout, branch "experiments"
patches/<repo>/<NN-problem>/NNNN-*.patch
scripts/                     setup, build, verify, deploy
revisions.env                the pins
```

The submodule paths are **symlinks**, not real checkouts: one copy of each repo, and patches are
applied once. The trade-off is that `git status` inside `clones/fm1-loom` or `clones/fm1-base`
fails with `expected submodule path 'base' not to be a symbolic link` — run git in
`clones/<repo>` itself instead. The build does not care.

---

## 5. Patches

```
patches/
  felucca-bsp/01-usb-host-compat/0001-*.patch
  fm1-base/01-usb-host-compat/0001-*.patch
  fm1-base/02-sdk-v1.2.14/0001-*.patch
  fm1-loom/01-usb-host-compat/0001-*.patch
```

- Generated with `git format-patch`, applied with `git am --3way`, so the commit messages and
  authorship survive and applied work shows up as commits on the `experiments` branch.
- The `NN-` prefix on the problem directory defines order. It matters: both fm1-base patches touch
  `tools/build.py`.
- `setup.sh` skips a patch whose reverse applies cleanly (already applied), applies it if it
  applies cleanly, and stops with the patch name if neither is true.

Adding an experiment:

```sh
# make the change in clones/<repo>, commit it, then:
git -C clones/<repo> format-patch <base>..HEAD -o patches/<repo>/03-<problem>
```

Regenerating an existing one: delete the old `.patch` files in that problem directory first, or
`format-patch` will add a second copy.

---

## 6. Bumping a pin

1. Edit `revisions.env` with the new commit.
2. Move `clones/` away (or delete it) so `setup.sh` clones fresh at the new pin.
3. Run `setup.sh`; patches that no longer apply stop it with their name.
4. For each stale patch: apply the intent by hand in the clone, commit, and regenerate with
   `format-patch` as above.
5. `scripts/verify.sh` and `scripts/build.sh`, then re-check hardware if the change touches USB.

---

## 7. Findings

### Dependency chain

`fm1-loom` → `base/` (fm1-base) → `bsp/` (felucca-bsp). The macOS/USB code lives in
`bsp/chip/usb.c`, so one fix there reaches LOOM-8, CTL-1, Radio and anything else on the bsp.

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
enabled through `usb_midi_last` in `fm1.toml`.

### Bug 2 — Windows 11 did not show the device at all

Windows groups interfaces into functions by **IAD**. The plain build had none, so `usbccgp.sys`
never formed an audio function and `usbaudio.sys` never bound.

Adding an IAD is not enough on its own: the first attempt named all three interfaces, including
MIDI, and Windows failed with `CM_PROB_FAILED_START` — `usbaudio` tried to parse MIDI streaming
descriptors as audio. **The IAD must cover AC + AS only**, with MIDI outside it, which requires
`MIDI_LAST` to keep them contiguous. Implemented as `FELUCCA_UAC_IAD` (`usb_iad`), with
`#error` guards for the combinations that make no sense.

### Bug 3 — stale MIDI device name (AMB-1 stuck on LOOM-8)

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
before any release". Same root cause as Windows' cosmetic `2-` name prefix.

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

- `build.py` computes `ROOT = commonpath(fm1-base, app)` and mounts it at `/work`; every compile
  path is relative to it. Keep all three clones under one parent.
- `chip/uac_fir.h` is absent at this pin, so host test builds must define `FELUCCA_UAC_48K=0`
  (the descriptor test does).
- The GUI arm of the bsp (`FELUCCA_USB_LAYOUT`, CDC console) is orthogonal and untested here; the
  new flags `#error` on CDC builds rather than multiplying the matrix.

---

## 8. Troubleshooting

| symptom | cause / fix |
|---|---|
| `expected submodule path 'base' not to be a symbolic link` | run git in `clones/fm1-base` / `clones/felucca-bsp`, not in the parent |
| `build: cannot start the toolchain container` | Docker not running; or the tree is outside `/Users` (file sharing) |
| `JIELI_TOOLCHAIN must point at ...` | run `clones/fm1-base/tools/get_toolchain.sh` |
| `warning: SDK ... differs` | SDK is not at the pinned tag; re-clone the SDK or update the pin **and** `SDK_SHA256` |
| patches fail after a pin bump | expected; regenerate them (section 6) |
| macOS shows the old MIDI name | CoreMIDI caches per VID/PID/serial: unplug, delete the stale entry in Audio MIDI Setup → MIDI Studio, replug |
| Linux card named "pid.codes Test PID" | host-side naming; see the pid.codes note above |

## 9. Recovery

`clones/felucca-bsp/tools/fm1_rescue.py` restores **M-VAVE's
stock V15** through the chip's mask-ROM bootloader. It does not restore FM1 Community or any other
custom firmware — reflash those from their own releases. Flashing is at your own risk.
