# Alley probe 3: the Beretta goes pickup -> equip -> armed -> orc dead, and every step has a WRAM tell

Action record for the game-mechanics probe that runs beside the promotion
rounds (`evidence/m1_hybrid_decision.md`; round 2b:
`evidence/m2_promotion_round2b.md`). Date: 2026-11-07.

This is a **probe, not a route**. The committed route in
`tests/scripts/combat.txt` is untouched and stops alive at `A5`; the alley
pickup/equip/kill chain below lives only in throwaway legs under
`tests/out/probe/` and is explicitly out of bounds for the committed route.

Provenance for every leg: the round-2b full-LLE floor executable
`088307497a2dcd78…` in `./build-llefloor-r2b` over the archived generated set
`b7f71dec62601a5b…`, framework pin
`773285b8210f2254ae87d0a14113980fb36990ad` (`framework_pins.txt`). Legs are
`pG` (prefix + live route), `pJ`/`pK` (the wrong branches), `pL` (equip),
`pM` (control), `pN` (kill), each a single `--framedump` run over the same
shared prefix (`sed -n '1,/^dump L0$/p' pG.txt`) so they differ only in the
tail being tested.

Plain language first, then the table.

1. **Pickup is `press r` on the sign, and the game says so.** With the `B`
   action cursor up and the camera nudged until the `Beretta` sign enters the
   name window, `press r` puts the gun in the inventory: the window then reads
   `Beretta Pistol` (`pN`: `PB0` f19551 shows the `Beretta` label, `PK0`
   f19708 the item name) and the weapon submenu lists `Beretta Pistol`
   (`M4` f20088). `pL` proved the same chain end to end.
2. **Equip is `Use`, not `Give`, and the oracle is the equipment line.**
   Status screen (`start`) -> `down` x3 = **Weapon** (2 downs is Magic, and
   Jake knows no spells, so its submenu `a` bounces the cursor to the top --
   the dead branch `pJ`) -> `a` opens the weapon submenu only if a gun is
   held -> `down` = `Beretta Pistol` -> `a` opens the action box
   (`Exit / Give / Use`) -> `down` x2 = `Use` -> `a` equips. The tell is the
   status-screen line rendering `Weapon (A)  Beretta Pistol` where before it
   rendered `Weapon (A) none` (`pL` `M9`; `pN` `M9` f20558). `Give` leaves
   it not equipped (`pK` dead end).
3. **Armed/disarmed is directly observable in the world.** Once equipped,
   world `press a` draws the aim reticle (`pN` `CU0` f20909). When not
   armed, the same press instead prints `You are not armed yet!` (seen at
   f20565 in the failing `pK` leg). Reticle present + no such string = armed.
4. **The orc dies to repeated `press a`, and its name is the kill tell.**
   While aiming, the name window carries the hovered target's label: one
   `up` steps the camera onto the orc and the window reads `Orc` (stream
   change at f20960, tag `U1` f20971). Six more `press a` volleys, and at
   **f21603** the label changes `Orc` -> `body` -- a fresh corpse sprite at
   Jake's feet, the green orc sprite gone (`S4` f21575 still standing, `AT`
   f21702 corpse under the reticle). All 39 checkpoints alive, leg length
   21,702 frames, and `tests/route_state.py` reports `alive` for every tag
   from `L0` on.
5. **Mechanics measured along the way** (native 256x224 coords): category
   box x169..238 / y26..93, 7 rows at 8-px pitch, top entry `Exit`; item box
   x~77..147 / y~77..113; action box top-middle; WRAM name-draw order is
   visual top-to-bottom, one `press down 1` = one step, held `down` steps
   every frame. The whole status screen renders through the `$7E21A0` name
   window, so `tests/menutext.py` (promoted this round) reading the
   per-frame stream is the screen oracle; screenshots confirm layout only.
6. **Capture-path rules the probe settled** (already known to the harness,
   now written down): `SNESRECOMP_FRAMEDUMP_PIXELS=1` + `--framedump` is
   frame-accurate (wants `turbo off` around the read and `DisableFrameDelay
   = 1`); the `SNESRECOMP_FRAME_BMP_DIR` widescreen hook fires ~1/16 frames,
   so its labels are wrong and it is for visuals only. Tag `fb.bmp` files
   are native 256x224 stored **bottom-up** under a positive `biHeight` --
   raw pixel readers must use `display_y = 223 - row_index` (an earlier
   empty-crop scare was my reader's flip, not the harness).
7. **Housekeeping:** a script run launched from the repo root without
   `SNESRECOMP_DUMP_DIR` writes its dumps beside the executable, in the repo
   root -- 264 stray tag files from one probe run. `.gitignore` now carries
   root-level guards for exactly those names (`/*.fb.bmp`, `/*.wram.bin`,
   `/frame_*_wram.bin`, ...). Also re-confirmed: the parked alley legs get
   wiped by ~f22,644, so probe tail waits stay at 60-150 frames; `pN`'s
   extra combat is ~1,000 frames and still finished alive at f21702.

Checkpoint table for the kill leg (`pN`, `tests/route_state.py` output,
abridged to the probe tail; all `scr=(31744,31488)` unless the camera moved):

| tag | frame | name window | meaning |
|---|---|---|---|
| `PB0` | f19551 | `Beretta` | action cursor at the sign |
| `PK0` | f19708 | `Beretta Pistol` | `press r` took the gun |
| `M4` | f20088 | `Beretta Pistol` | weapon submenu open |
| `M9` | f20558 | `Beretta Pistol` | `Weapon (A) Beretta Pistol` |
| `CU0` | f20909 | `.ber.. Pistol` | aim reticle up (armed) |
| `U1` | f20971 | `Orc` | target box on the orc |
| `S4` | f21575 | `Orc` | orc still standing |
| -- | **f21603** | `body` | **kill frame** |
| `AT` | f21702 | `body...` | corpse under the reticle |

What this does *not* claim: no XP/karma byte has been located yet, so the
kill is proven by the label/state transition and the sprite, not by a number
going up; and none of this is in the committed route -- `combat.txt` and the
r9 baseline pair (`tests/baselines/horizon_xp.json`) are unchanged by this
probe.
