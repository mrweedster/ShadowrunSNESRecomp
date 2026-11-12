# Mouse mod: absolute hand cursor, WASD directions, mouse action buttons

Design and evidence record for the `mod/mouse` branch. Date: 2026-11-10.
Base: shipped `main` at `07fd928`; the control change is the only thing this
branch adds.

## What the player gets

| SNES | input |
|---|---|
| hand cursor | the OS pointer, absolutely (no relative d-pad emulation) |
| D-pad | `W` `A` `S` `D` |
| A | right mouse button |
| B | left mouse button |
| Y | middle mouse button |
| Start | `X` |
| Select | `Y` |
| X | `C` |
| L / R | `Q` / `E` |

A/B/Y have **no keyboard binding** (`None` in the generated `keybinds.ini`),
so the mouse buttons are the only way to press them. The directions stay on
the keyboard *and* the gamepad still works; the mouse adds to the controller
word the host assembled for the frame, it does not replace it.

## Where the hand cursor lives

Shadowrun draws the hand as OAM sprite 0 and keeps its position in two 8.8
fixed-point WRAM words (high byte = screen pixel; the game only ever uses
whole pixels):

| address | meaning |
|---|---|
| `$7E01F0` | cursor X, `x << 8` |
| `$7E01F2` | cursor Y, `y << 8` |
| `$7E01F4` | nonzero while the hand is up |

`$7E01F4` is the gate. With the hand down the same two words hold the screen
origin the room is drawn from, so writing them then scrolls the level instead
of moving the pointer.

The addresses were identified by diffing WRAM dumps of the same boot route
with one direction held for 30 frames: only `$7E01F1` (right/left) and
`$7E01F3` (up/down) moved. A one-frame poke of `$7E01F0` moved the drawn hand
and stuck, and the game's own d-pad movement continued from the poked value;
the same held in the street scene. The cursor box was measured by holding each
direction to its limit: **x 3..239, y 3..206** on a 256x224 field. The mod
clamps to that box; the game clamps too.

## How it is wired

The framework's desktop host gained one accessor
(`snesrecomp_desktop_mouse_state`, `runner/src/desktop/host_main.c`):

* position is `SDL_GetGlobalMouseState()` minus `SDL_GetWindowPosition()`,
  then scaled through the drawable/Retina factor and the presenter's
  letterbox viewport to SNES frame pixels;
* buttons are the async platform state OR'd with SDL's event-driven cache, so
  a click is seen whichever path it came through;
* it answers only while the window has **input focus** and the pointer is over
  the presented image, so the mod never steals the pointer while another
  application is frontmost.

The pointer source is platform-split because the desktop coordinates are not.
Windows, X11 and Cocoa report a global pointer and a window origin, so the
accessor subtracts one from the other; that also works before SDL has seen a
first motion event. Wayland does not tell a client where its window is:
`SDL_GetWindowPosition()` answers 0,0 and `SDL_GetGlobalMouseState()` is
window-relative while the pointer is over the surface and 0,0 when it is not
(`SDL_waylandmouse.c`, `Wayland_GetGlobalMouseState`). There the accessor reads
SDL's cached window-relative point and requires mouse focus, so a leave event
cannot turn into a phantom (0,0). The debug line names the driver it used.

The same module hides the OS arrow while the pointer is over the image: the
title calls `snesrecomp_desktop_set_game_pointer(1)` every frame with the
accessor's answer, and the host hides SDL's cursor. That request is layered
over the player's own cursor setting rather than overwriting it — the
fullscreen cursor key and the in-game launcher still work — and the host
shows the arrow again on window leave or focus loss, so switching to another
application never leaves the pointer invisible. With the game paused (no
guest frames, so no accessor call) the window-event path is what restores it.

The title side is `src/mouse_cursor.c`, called from `GameRunOneFrame()` before
the guest runs. When the hand is up it writes the two cursor words each frame;
when the hand is down it writes nothing. Mouse buttons are OR'd into
`g_snes->input1_currentState` through `RtlSetPadState(0, pad)` (bit 0 B,
1 Y, 8 A), which is the same seat the host fills from keyboard/pad/script.

The mod stays **inert until it sees real input** — pointer motion or a button
press. The SDL dummy driver used by the headless harness still creates a
window and reports a pointer; without the latch a scripted R-and-aim route
would be rewritten by that phantom. In the headless runs the dummy window
happens to sit at (32,24) with the pointer at (0,0), i.e. outside the window,
so the latch is belt and braces; it is kept anyway.

## Framework patch

The host accessor, the OS-pointer hiding and the new keybind defaults live in
the framework, not in this repository. They are committed as branch `mod/mouse`
(`2bfb3a63`) in the `sr-mouse` clone, based on `32266300` — the framework
revision the shipped macOS build used (pin `773285b8` plus the writable-state
commit). The same change is checked in here as `tools/mouse_mod_framework.patch`:

```sh
git -C /path/to/snesrecomp checkout 32266300   # or the pin, 773285b8
git -C /path/to/snesrecomp apply tools/mouse_mod_framework.patch
cmake -S . -B build-mouse -DCMAKE_BUILD_TYPE=Release \
      -DSNESRECOMP_ROOT=/path/to/snesrecomp
cmake --build build-mouse -j8
```

The patch touches four files and is 404 lines:
`runner/src/desktop/host_main.{c,h}`, `runner/src/desktop/sdl_compat.h` and
`runner/src/keybinds.c`. It applies to the pin (`773285b8`) as well as to
`32266300`, which is what a Windows or Linux builder starting from
`framework_pins.txt` will check out; the configure step now refuses a framework
without the accessor and prints this `git apply` command.

The embedded-ROM personal package applies the same patch to the host that can
boot the guest image: `sr-embed-osx` at `a7fb67e6` (the embed commit plus the
state fix) takes the patch cleanly, and that branch is `mod/mouse-embed` at
`3e5255b4`.

## Evidence

### Headless routes are untouched

`tests/scripts/combat.txt` was run to completion on the shipped binary
(`build-ship-m11`, `main` at `07fd928`) and on the mod binary
(`build-mouse/ShadowrunSNESRecomp`, sha256
`73b29fa0dc28572514ada69a51925c7b1ddcc920a3512c322c034678a0efb072`).
Both runs wrote 264 dump files across the 22 tagged checkpoints; every file
is byte-identical. The mod is inert without mouse input, and moving A/B/Y off
the keyboard does not touch scripted pad injection (scripts feed the pad word
directly, not `keybinds.ini`).

### The hand follows the pointer (GUI)

Run: `gui.txt` boots to the saved game, raises the R cursor, and dumps `M0` …
`M8` every 180 frames. The window content was 960x720 at screen (800,330)
with no letterbox, i.e. 3.75 x 3.214 SNES pixels per screen pixel. After
activating the window and moving the pointer, these warps were made:

| dump | frame | pointer (screen) | frame point | `$7E01F0` | `$7E01F2` | OAM sprite 0 |
|---|---:|---|---:|---|---|---|
| `M0` | 4542 | 1280,690 | 480,360 | `0x8000` (128) | `0x7000` (112) | (128,112) |
| `M1` | 4722 | 900,400 | 100,70 | `0x1a00` (26) | `0x1500` (21) | (26,21) |
| `M2` | 4902 | 1700,980 | 900,650 | `0xef00` (239) | `0xca00` (202) | (239,202) |
| `M3`…`M8` | 5082…5982 | unchanged | | `0xef00` | `0xca00` | (239,202) |

`M2` is the bottom-right clamp (239,202), and it stays there for the next
three seconds of dumps with the pointer stationary: the mod rewrites the
position every frame while the hand is up, so the guest cannot drift it.

The debug line that produced the mapping (`SNESRECOMP_MOUSE_DEBUG=1`):

```text
[mouse] window 800,330 960x720 drawable 960x720 viewport 0,0 960x720
        global 1280,690 point 480,360 input=1 mouse=1 held=0x0 cached=0x0
```

### The OS arrow disappears over the image

`hide.txt` waits 1400 frames while the pointer is warped in and out of the
same window (960x720 at screen 800,330). The host logs every change of SDL's
cursor state:

```text
[mouse] OS pointer hidden (title pointer 1, host cursor 1)   # 1280,690
[mouse] OS pointer shown  (title pointer 0, host cursor 1)   # 100,300
[mouse] OS pointer hidden (title pointer 1, host cursor 1)   # 1000,500
[mouse] OS pointer shown  (title pointer 0, host cursor 1)   # 2200,1200
```

The first and third warps are inside the image; the second and fourth are
outside the window. `host cursor 1` is the player's own setting: hiding is
layered on top of it, so the fullscreen cursor key still takes effect when
the pointer later leaves. A window-leave or focus-lost event shows the arrow
immediately, which also covers the paused case where no guest frame runs.

With the pointer hidden the mod still reads its position and buttons: the
button run below re-ran under the hiding build and produced the same
`pad 0x0001` and the same 42,905-pixel menu change.

### Mouse buttons reach the guest

A real OS click could not be synthesized on this machine: the harness process
has no Accessibility permission (`AXIsProcessTrusted()` is 0 and System
Events reports `UI elements enabled` = false), so `CGEventPost` and
`CGEventPostToPid` clicks are dropped before SDL sees them. Warping works
because `CGWarpMouseCursorPosition` is not gated.

Everything after the SDL button read was exercised with the harness hook
`SNESRECOMP_MOUSE_TEST_BUTTONS=<mask>[:<from>][:<to>]`, which injects the same
mask `SDL_GetMouseState` would return between two guest frames. The script
`btn.txt` leaves the main menu up at frame 1554 and dumps `C0` at 2454; the
mask was applied for frames 1850–1880:

| mask | debug line | pad bit written | `C0` vs the no-input menu |
|---:|---|---|---|
| `0x01` left | `buttons 0x01 … pad 0x0001` | `0x0001` B | **different**: the morgue scene (42,905 px) |
| `0x04` right | `buttons 0x04 … pad 0x0100` | `0x0100` A | identical |
| `0x02` middle | `buttons 0x02 … pad 0x0002` | `0x0002` Y | identical |

The left-button row is end to end: B confirms the menu, the game loads, and
the dumped frame is the morgue. The right/middle rows show the mask lands on
the A/Y bits and not on B. On a real mouse the SDL read reports the same
masks; a player can verify by clicking in the menu.

## Release packages

Both shapes were rebuilt on this branch's framework, for a thin arm64 binary
and a universal (arm64 + x86_64) one. The `.dmg` files are in `dist/`
(git-ignored); this branch's packaging transcripts are under
`tests/out/pkg/mouse/` (`macos_package_arm64.log`,
`macos_package_personal_arm64.log`, `macos_package_universal.log`,
`macos_package_personal_universal.log`). The committed evidence copies still
describe the mainline package, so the doc audit's quote set is unchanged.

| package | build tree | framework | size | sha256 |
|---|---|---|---:|---|
| `shadowrun-0.1.0-macos-arm64.dmg` (shareable) | `build-mouse` (`20b72fe3…`) | `sr-mouse` `mod/mouse` `2bfb3a63` | 2,225,569 B | `5f683f58cbf14c31…` |
| `shadowrun-0.1.0-macos-universal.dmg` (shareable) | `build-macos-universal` (`39408884…`) | `sr-mouse` `mod/mouse` `2bfb3a63` | 4,717,488 B | `3a22d24bb79b0e63…` |
| `shadowrun-embed-0.1.0-macos-arm64-personal.dmg` | `build-embed-mouse` (`20d090f4…`) | `sr-embed-osx` `mod/mouse-embed` `3e5255b4` | 2,952,968 B | `2b9bd20b58ba10c6…` |
| `shadowrun-embed-0.1.0-macos-universal-personal.dmg` | `build-embed-universal` (`764e4027…`) | `sr-embed-osx` `mod/mouse-embed` `3e5255b4` | 6,159,258 B | `7a84ed7b2ffb65ad…` |

The commands are `scripts/package_macos_bundle.sh <build> <tag>` and its
`PERSONAL=1` form. Both images' `README.txt` lists the mouse controls; the DMGs
are ad-hoc signed and unnotarised, as before. The universal payload reports
`x86_64 arm64` to `lipo -archs`; the packaging run exercises the arm64 slice,
because this host cannot execute the Intel one (`evidence/README.md`, the
`arch -x86_64` note).

The transcripts re-measure what the mouse change costs the machine: the
shareable app and its build tree produced identical WRAM over 1200 frames, and
the personal package's four legs (file/embedded against the pin and floor-11
references) produced identical WRAM over 1245 frames. Those legs are run on
both the arm64 and the universal package.

Linux and Windows use `tools/package_desktop.py` instead of the macOS script.
That tool stages the same executable, any shared libraries beside it, `mods/`,
`assets/` and a controls README, and writes `.tar.gz` or `.zip` plus a
`.sha256`. The framework builds SDL3 statically (runner.cmake forces
`SDL_SHARED=OFF`), so the archive carries no SDL. The tool was exercised here
on a macOS build; the Linux and Windows archives need a build on those hosts
and are produced by the same command there.

## Limits

* The hide applies to the presented image. The letterbox, when a display
  mode produces one, keeps the OS arrow (the guest hand is clamped at the
  nearest edge there, so the arrow is still the honest pointer).
* Once armed, the cursor belongs to the pointer every frame the hand is up.
  A gamepad d-pad aim while the hand is up loses to a stationary pointer.
* macOS arm64 was built, run and packaged here; the universal DMG compiles and
  links both slices, and its arm64 slice is what the run legs execute. The
  Windows and Linux targets are compiled by the cross-platform workflow, but
  no Windows or Linux machine was available to run them in this round. The
  accessor's Windows/X11 branch is the same global-minus-origin arithmetic the
  macOS path uses; the Wayland branch is the cached-point path described above.
  The SDL2 branch in the accessor compiles but was not run.
