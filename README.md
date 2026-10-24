# fm-1-experiments

Scratch repo for M-VAVE FM-1 firmware experiments, maintained mostly by an LLM following this
file. It pins four upstream repositories at known commits, keeps our changes as patch series, and
gives each firmware its own build, verify and deploy script.

Two firmwares are built here, both on the shared fm1-base: **LOOM-8** ([fm1-loom](https://github.com/charlesvestal/fm1-loom))
and **AMB-1** ([fm1-amb](https://github.com/charlesvestal/fm1-amb)). fm1-base's own **template**
firmware is built too, as the platform's reference app.

The current experiment is **USB host compatibility**: LOOM-8 and AMB-1 built from these patches have a
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
| Python with Pillow+raqm | fonts, screen-reader words | `brew install python@3.15 pillow` (the venv is built from Homebrew python3.15 with `--system-site-packages`) |

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

## 2. Build and deploy, per firmware

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

Host tests (run a build first):

```sh
./scripts/verify-loom.sh
```

Flash (`--info` prints the connected FM-1's identity and writes nothing):

```sh
./scripts/deploy-loom.sh
```

`build-loom.sh` passes its arguments to `fm1-loom/build.sh`: `--host` (host simulator), `--web`
(browser emulator), `--demo` (mirroring for demos), `--release X.Y`, `--no-ble`.

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
./scripts/build-template.sh
```

fm1-base's host tests, including the USB descriptor matrix (run `build-template.sh` first):

```sh
./scripts/verify-base.sh
```

Flash the template (same update mode as above):

```sh
./scripts/deploy-template.sh
```

The template's `fm1.toml` has Bluetooth on, but the pinned AC79 SDK (V1.2.14) does not link the
BLE template: its `btctrler.a` wants `usr_timeout_del`, which fm1-base's shim defines only for its
WiFi build (upstream documents SDK V1.2.1 for the template). `build-template.sh` therefore builds
the USB-only template (`--no-ble`) unless you pass `--host`, `--web` or `--no-ble` yourself.
`verify-base.sh` runs fm1-base's whole suite; after `build-template.sh` its update-path test runs
against the USB-only package (it borrows the `template.fwsc` name the test looks for).

---

## 3. Pinned revisions

All pins live in [`revisions.env`](revisions.env), which the scripts source.

| repo | commit | role |
|---|---|---|
| `charlesvestal/fm1-loom` | `75e8607` (v0.7) | LOOM-8 |
| `charlesvestal/fm1-amb` | `188b0a42` (v1.3) | AMB-1 |
| `charlesvestal/fm1-base` | `0944289` | the platform layer (both firmwares' `base`) |
| `hugelton/felucca-bsp` | `b413cd8` | the chip layer (`fm1-base/bsp`) |
| AC79 SDK | tag `AC79NN_SDK_V1.2.14_2026-10-13` | external, outside this repo |
| JieLi toolchain | package `jieli-linux-toolchains-20260730.1` | external, outside this repo |
| docker base | `debian:bookworm-slim@sha256:7ff6ba3…` | the build container's image, `JIELI_DOCKER_IMAGE` |
| python | `mido 1.3.3`, `python-rtmidi 1.5.8` | `.venv`, installed by `setup.sh` |

The repos are pinned to their latest `main` (both firmwares are at their latest release tag).
One fm1-base and one felucca-bsp are shared by both firmwares, so the base is pinned to its own
`main` rather than to either firmware's submodule pointer (`42dc630` for LOOM-8, `15dff6d` for
AMB-1 — both are ancestors of the pin). The SDK tag and the toolchain package are the newest
published.

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
patches/<repo>/<NN-problem>/NNNN-*.patch
scripts/
  setup.sh                   clones, links, patches, venv, prerequisite report
  lib/common.sh              ROOT, the pins, environment, shared helpers
  build-loom.sh   deploy-loom.sh   verify-loom.sh
  build-amb.sh    deploy-amb.sh    verify-amb.sh
  build-template.sh  deploy-template.sh  verify-base.sh
revisions.env                the pins
```

The submodule paths are **symlinks**, not real checkouts: one copy of each repo, and patches are
applied once. The trade-off is that `git status` inside a clone with such a link fails with
`expected submodule path 'base' not to be a symbolic link` — run git in `clones/<repo>` itself
(or with `--no-recurse-submodules`) instead. The build does not care; `build.py` resolves the
`bsp` link when it computes its source root (patch 03).

---

## 5. Patches

```
patches/
  felucca-bsp/01-usb-host-compat/   usb.c: interface order, serial number, an optional IAD
  fm1-base/01-usb-host-compat/      build.py: usb_midi_last, usb_iad, usb_serial; descriptor test
  fm1-base/02-sdk-v1.2.14/          build.py: the SDK hashes of the installed V1.2.14
  fm1-base/03-symlinked-bsp/        build.py: the source root covers a symlinked bsp
  fm1-base/04-esm-modules/          package.json: the web/ modules are ESM
  fm1-loom/01-usb-host-compat/      LOOM-8's USB names and its descriptor flags
  fm1-amb/01-usb-host-compat/       AMB-1's: the same descriptor set, and its USB names
```

- Generated with `git format-patch`, applied with `git am --3way`, so the commit messages and
  authorship survive and applied work shows up as commits on the `experiments` branch.
- The `NN-` prefix on the problem directory defines order. It matters: fm1-base's patches all
  touch `tools/build.py` and must apply in this order.
- The fm1-base patches are shared by both firmwares (one base clone); the fm1-amb patch turns the
  same `usb_midi_last`/`usb_iad` on in AMB-1's `fm1.toml`, so both firmwares present the same
  descriptor set.
- `setup.sh` skips a patch whose reverse applies cleanly (already applied), applies it if it
  applies cleanly, and stops with the patch name if neither is true.

Adding an experiment: make the change in `clones/<repo>`, commit it, then

```
git -C clones/<repo> format-patch <base>..HEAD -o patches/<repo>/03-<problem>
```

Regenerating an existing one: delete the old `.patch` files in that problem directory first, or
`format-patch` will add a second copy.

---

## 6. Bumping a pin

1. Edit `revisions.env` with the new commit(s).
2. Move `clones/` away (or delete it) so `setup.sh` clones fresh at the new pins. The pin check
   refuses to move an existing `experiments` branch forward, so this step is not optional.
3. Run `./scripts/setup.sh --no-patches` to get the new trees linked without our changes.
4. For each patch that the new pins made stale: apply the intent by hand in the clone, commit on
   `experiments`, delete the old `.patch` file, and regenerate it into a scratch directory first
   (the file name follows the subject, so writing straight into the problem directory leaves the
   stale file beside the new one). Example:

   ```
   git -C clones/fm1-base format-patch 0944289..HEAD -o /tmp/regen
   rm -f patches/fm1-base/01-usb-host-compat/*.patch
   cp /tmp/regen/*.patch patches/fm1-base/01-usb-host-compat/
   ```

5. Move `clones/` away again and run `./scripts/setup.sh` twice, to prove every patch applies on a
   fresh clone and the second run is a no-op.
6. `./scripts/verify-base.sh`, `./scripts/verify-loom.sh`, `./scripts/verify-amb.sh`, then the
   three builds, then re-check hardware if the change touches USB.

If `git am` stops inside a clone (a patch that neither applies nor is applied), the clone is left
mid-session: `git -C clones/<repo> am --abort` (and `am --show-current-patch` to see where).

---

## 7. Findings

### Dependency chain

`fm1-loom` → `base/` (fm1-base) → `bsp/` (felucca-bsp), and the same for `fm1-amb`. The macOS/USB
code lives in `bsp/chip/usb.c`, so one fix there reaches LOOM-8, AMB-1, the template and anything
else on the bsp.

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
enabled through `usb_midi_last` in `fm1.toml`; both firmwares turn it on.

The shipped builds also carry `FELUCCA_UAC_IAD` (`usb_iad`), which gives the audio function an IAD
covering AC + AS only. It is descriptor hygiene, not a host fix: the plain no-IAD build enumerates
on every host we tried too, and the flag is there so the audio interfaces are explicitly one
function.

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
- The template's Bluetooth build needs SDK V1.2.1 (see §2); its USB-only build works with the
  pinned V1.2.14.
- The GUI arm of the bsp (`FELUCCA_USB_LAYOUT`, CDC console) is orthogonal and untested here; the
  new flags `#error` on CDC builds rather than multiplying the matrix.

---

## 8. Troubleshooting

| symptom | cause / fix |
|---|---|
| `expected submodule path 'base' not to be a symbolic link` | run git in `clones/<repo>` itself or with `--no-recurse-submodules`, not in the parent |
| `build: cannot start the toolchain container` | Docker not running; or the tree is outside `/Users` (file sharing) |
| `JIELI_TOOLCHAIN must point at ...` | run `clones/fm1-base/tools/get_toolchain.sh` |
| `warning: toolchain package ...; revisions.env pins ...` | the toolchain is not the pinned build; re-run `get_toolchain.sh` (newest) or update the pin |
| `warning: SDK ... differs` | SDK is not at the pinned tag; re-clone the SDK or update the pin **and** `SDK_SHA256` |
| patches fail after a pin bump | expected; use `setup.sh --no-patches` and regenerate them (§6) |
| `error: ... neither applies nor is already applied` mid-session | `git -C clones/<repo> am --abort` |
| `deploy-*.sh: no package in ...` | run the matching build first; a release build is named `NAME-X.Y.fwsc` and is picked automatically |
| template build: `undefined reference to usr_timeout_del` | the pinned SDK cannot link the BLE template; use the script's default `--no-ble` (or SDK V1.2.1) |
| macOS shows the old MIDI name | CoreMIDI caches per VID/PID/serial: unplug, delete the stale entry in Audio MIDI Setup → MIDI Studio, replug |
| Linux card named "pid.codes Test PID" | host-side naming; see the pid.codes note above |

## 9. Recovery

`clones/felucca-bsp/tools/fm1_rescue.py` restores **M-VAVE's stock V15** through the chip's
mask-ROM bootloader. It does not restore FM1 Community or any other custom firmware — reflash those
from their own releases. Flashing is at your own risk.
