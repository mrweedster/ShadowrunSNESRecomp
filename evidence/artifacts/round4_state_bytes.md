# round4_state_bytes.md
#
# what: the same gate read at byte level: for every checkpoint, how many state-image bytes differ, how many of them are label bytes, and the exact non-label bytes; then whether a rejected seed's split survives phase alignment
# how:  tests/cp_byte_diff.py <control> <variant> over every tagged checkpoint with all five guest memory images plus the host framebuffer (wram.bin vram.bin oam.bin cgram.bin sram.bin fb.bgrx); label/state split comes from the label rule in tests/framedump_diff.py, which cp_byte_diff.py imports rather than restates.  Inputs are the checkpoint dumps in tests/out/r4/<variant>/ and tests/out/r4/accepted/.  The alignment probes at the end come from tests/rejected_shift.sh, whose logs are tests/out/r4/shift_<variant>.md
#
# framework pin: 773285b8210f2254ae87d0a14113980fb36990ad
# generated: 2026-11-08T08:02:38Z (host Darwin arm64)
# source tree: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp

#
# how to read: `label` bytes are the ones the framedump_diff rule excuses (frame-kernel
# counter window $01C80-$01D40, timer singletons $012C/$012E/$012F/$0132); `state` is every
# other differing byte, and those are the ones shown.  A row with state 0 is a clock shift,
# not a wrong computation -- and it still fails the gate, because the gate is byte equality
# against the control tree.  The first pair is the same program run twice: that is what a
# clean row looks like here, so any non-zero state count on a seeded tree is the seed.

==== same program, run twice (harness determinism control): accepted tree vs its own anchor exe
# checkpoint byte diff: tests/out/r4/accepted/r4pair_accepted vs tests/out/r4/accepted/anchor_pair

Bytes differing in the state images each run dumped at the same tagged
checkpoint (`dump TAG` in the route).  Address columns are the guest
bus address of the byte, control value then variant value.  On wram,
`label` counts the bytes the label rule in framedump_diff.py excuses
(host frame-kernel counter window, documented timer singletons);
`state` is every other differing byte, and those are the ones shown.

| checkpoint | surface | bytes differ | label | state | size | state bytes (control -> variant) | span |
|---|---|---|---|---|---|---|---|
| A0 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| A0 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| A0 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| A0 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A0 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A0 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| A1 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| A1 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| A1 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| A1 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A1 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A1 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| A2 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| A2 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| A2 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| A2 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A2 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A2 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| A3 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| A3 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| A3 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| A3 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A3 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A3 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| A4 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| A4 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| A4 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| A4 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A4 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A4 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| A5 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| A5 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| A5 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| A5 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A5 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A5 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| H8 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| H8 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| H8 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| H8 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| H8 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| H8 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J1 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J1 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J1 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J1 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J1 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J1 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J10 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J10 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J10 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J10 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J10 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J10 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J2 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J2 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J2 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J2 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J2 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J2 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J3 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J3 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J3 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J3 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J3 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J3 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J4 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J4 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J4 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J4 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J4 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J4 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J5 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J5 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J5 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J5 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J5 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J5 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J6 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J6 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J6 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J6 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J6 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J6 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J7 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J7 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J7 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J7 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J7 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J7 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J8 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J8 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J8 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J8 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J8 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J8 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J9 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J9 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J9 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J9 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J9 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J9 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| K1 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| K1 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| K1 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| K1 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| K1 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| K1 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| K2 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| K2 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| K2 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| K2 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| K2 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| K2 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| K3 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| K3 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| K3 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| K3 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| K3 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| K3 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| L0 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| L0 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| L0 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| L0 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| L0 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| L0 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| L1 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| L1 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| L1 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| L1 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| L1 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| L1 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |

no checkpoint has a state (non-label) byte differing: every WRAM difference on this run is a label byte

==== r4pair, the accepted pair
# checkpoint byte diff: tests/out/r4/r4base vs tests/out/r4/r4pair

Bytes differing in the state images each run dumped at the same tagged
checkpoint (`dump TAG` in the route).  Address columns are the guest
bus address of the byte, control value then variant value.  On wram,
`label` counts the bytes the label rule in framedump_diff.py excuses
(host frame-kernel counter window, documented timer singletons);
`state` is every other differing byte, and those are the ones shown.

| checkpoint | surface | bytes differ | label | state | size | state bytes (control -> variant) | span |
|---|---|---|---|---|---|---|---|
| A0 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| A0 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| A0 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| A0 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A0 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A0 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| A1 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| A1 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| A1 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| A1 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A1 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A1 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| A2 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| A2 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| A2 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| A2 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A2 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A2 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| A3 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| A3 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| A3 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| A3 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A3 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A3 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| A4 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| A4 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| A4 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| A4 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A4 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A4 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| A5 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| A5 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| A5 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| A5 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A5 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A5 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| H8 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| H8 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| H8 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| H8 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| H8 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| H8 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J1 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J1 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J1 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J1 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J1 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J1 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J10 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J10 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J10 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J10 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J10 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J10 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J2 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J2 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J2 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J2 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J2 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J2 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J3 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J3 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J3 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J3 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J3 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J3 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J4 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J4 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J4 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J4 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J4 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J4 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J5 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J5 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J5 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J5 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J5 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J5 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J6 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J6 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J6 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J6 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J6 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J6 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J7 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J7 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J7 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J7 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J7 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J7 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J8 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J8 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J8 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J8 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J8 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J8 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J9 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J9 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J9 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J9 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J9 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J9 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| K1 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| K1 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| K1 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| K1 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| K1 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| K1 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| K2 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| K2 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| K2 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| K2 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| K2 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| K2 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| K3 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| K3 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| K3 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| K3 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| K3 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| K3 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| L0 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| L0 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| L0 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| L0 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| L0 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| L0 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| L1 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| L1 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| L1 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| L1 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| L1 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| L1 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |

no checkpoint has a state (non-label) byte differing: every WRAM difference on this run is a label byte

==== the accepted tree, as checked out
# checkpoint byte diff: tests/out/r4/r4base vs tests/out/r4/accepted/r4pair_accepted

Bytes differing in the state images each run dumped at the same tagged
checkpoint (`dump TAG` in the route).  Address columns are the guest
bus address of the byte, control value then variant value.  On wram,
`label` counts the bytes the label rule in framedump_diff.py excuses
(host frame-kernel counter window, documented timer singletons);
`state` is every other differing byte, and those are the ones shown.

| checkpoint | surface | bytes differ | label | state | size | state bytes (control -> variant) | span |
|---|---|---|---|---|---|---|---|
| A0 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| A0 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| A0 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| A0 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A0 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A0 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| A1 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| A1 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| A1 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| A1 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A1 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A1 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| A2 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| A2 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| A2 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| A2 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A2 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A2 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| A3 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| A3 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| A3 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| A3 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A3 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A3 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| A4 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| A4 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| A4 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| A4 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A4 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A4 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| A5 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| A5 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| A5 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| A5 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A5 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A5 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| H8 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| H8 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| H8 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| H8 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| H8 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| H8 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J1 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J1 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J1 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J1 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J1 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J1 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J10 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J10 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J10 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J10 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J10 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J10 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J2 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J2 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J2 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J2 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J2 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J2 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J3 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J3 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J3 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J3 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J3 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J3 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J4 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J4 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J4 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J4 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J4 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J4 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J5 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J5 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J5 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J5 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J5 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J5 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J6 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J6 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J6 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J6 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J6 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J6 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J7 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J7 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J7 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J7 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J7 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J7 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J8 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J8 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J8 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J8 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J8 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J8 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J9 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J9 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J9 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J9 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J9 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J9 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| K1 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| K1 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| K1 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| K1 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| K1 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| K1 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| K2 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| K2 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| K2 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| K2 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| K2 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| K2 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| K3 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| K3 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| K3 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| K3 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| K3 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| K3 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| L0 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| L0 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| L0 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| L0 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| L0 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| L0 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| L1 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| L1 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| L1 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| L1 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| L1 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| L1 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |

no checkpoint has a state (non-label) byte differing: every WRAM difference on this run is a label byte

==== seed only: $80C399
# checkpoint byte diff: tests/out/r4/r4base vs tests/out/r4/s80C399

Bytes differing in the state images each run dumped at the same tagged
checkpoint (`dump TAG` in the route).  Address columns are the guest
bus address of the byte, control value then variant value.  On wram,
`label` counts the bytes the label rule in framedump_diff.py excuses
(host frame-kernel counter window, documented timer singletons);
`state` is every other differing byte, and those are the ones shown.

| checkpoint | surface | bytes differ | label | state | size | state bytes (control -> variant) | span |
|---|---|---|---|---|---|---|---|
| A0 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| A0 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| A0 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| A0 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A0 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A0 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| A1 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| A1 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| A1 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| A1 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A1 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A1 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| A2 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| A2 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| A2 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| A2 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A2 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A2 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| A3 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| A3 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| A3 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| A3 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A3 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A3 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| A4 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| A4 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| A4 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| A4 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A4 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A4 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| A5 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| A5 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| A5 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| A5 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A5 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A5 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| H8 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| H8 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| H8 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| H8 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| H8 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| H8 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J1 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J1 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J1 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J1 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J1 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J1 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J10 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J10 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J10 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J10 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J10 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J10 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J2 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J2 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J2 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J2 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J2 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J2 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J3 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J3 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J3 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J3 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J3 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J3 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J4 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J4 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J4 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J4 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J4 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J4 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J5 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J5 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J5 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J5 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J5 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J5 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J6 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J6 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J6 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J6 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J6 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J6 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J7 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J7 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J7 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J7 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J7 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J7 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J8 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J8 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J8 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J8 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J8 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J8 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J9 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J9 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J9 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J9 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J9 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J9 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| K1 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| K1 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| K1 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| K1 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| K1 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| K1 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| K2 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| K2 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| K2 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| K2 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| K2 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| K2 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| K3 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| K3 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| K3 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| K3 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| K3 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| K3 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| L0 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| L0 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| L0 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| L0 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| L0 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| L0 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| L1 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| L1 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| L1 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| L1 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| L1 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| L1 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |

no checkpoint has a state (non-label) byte differing: every WRAM difference on this run is a label byte

==== seed only: $80AAB3
# checkpoint byte diff: tests/out/r4/r4base vs tests/out/r4/s80AAB3

Bytes differing in the state images each run dumped at the same tagged
checkpoint (`dump TAG` in the route).  Address columns are the guest
bus address of the byte, control value then variant value.  On wram,
`label` counts the bytes the label rule in framedump_diff.py excuses
(host frame-kernel counter window, documented timer singletons);
`state` is every other differing byte, and those are the ones shown.

| checkpoint | surface | bytes differ | label | state | size | state bytes (control -> variant) | span |
|---|---|---|---|---|---|---|---|
| A0 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| A0 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| A0 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| A0 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A0 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A0 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| A1 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| A1 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| A1 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| A1 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A1 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A1 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| A2 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| A2 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| A2 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| A2 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A2 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A2 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| A3 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| A3 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| A3 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| A3 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A3 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A3 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| A4 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| A4 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| A4 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| A4 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A4 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A4 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| A5 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| A5 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| A5 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| A5 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A5 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A5 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| H8 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| H8 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| H8 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| H8 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| H8 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| H8 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J1 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J1 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J1 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J1 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J1 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J1 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J10 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J10 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J10 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J10 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J10 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J10 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J2 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J2 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J2 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J2 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J2 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J2 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J3 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J3 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J3 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J3 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J3 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J3 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J4 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J4 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J4 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J4 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J4 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J4 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J5 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J5 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J5 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J5 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J5 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J5 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J6 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J6 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J6 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J6 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J6 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J6 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J7 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J7 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J7 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J7 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J7 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J7 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J8 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J8 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J8 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J8 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J8 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J8 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J9 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| J9 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| J9 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J9 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J9 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J9 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| K1 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| K1 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| K1 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| K1 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| K1 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| K1 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| K2 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| K2 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| K2 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| K2 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| K2 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| K2 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| K3 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| K3 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| K3 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| K3 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| K3 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| K3 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| L0 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| L0 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| L0 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| L0 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| L0 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| L0 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| L1 | wram.bin | 0 | 0 | 0 | 131,072 | identical | - |
| L1 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| L1 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| L1 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| L1 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| L1 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |

no checkpoint has a state (non-label) byte differing: every WRAM difference on this run is a label byte

==== rejected: seed only $80ABBC
# checkpoint byte diff: tests/out/r4/r4base vs tests/out/r4/s80ABBC

Bytes differing in the state images each run dumped at the same tagged
checkpoint (`dump TAG` in the route).  Address columns are the guest
bus address of the byte, control value then variant value.  On wram,
`label` counts the bytes the label rule in framedump_diff.py excuses
(host frame-kernel counter window, documented timer singletons);
`state` is every other differing byte, and those are the ones shown.

| checkpoint | surface | bytes differ | label | state | size | state bytes (control -> variant) | span |
|---|---|---|---|---|---|---|---|
| A0 | wram.bin | 438 | 3 | 435 | 131,072 | $7E0000:52->01 $7E0001:00->08 $7E0002:00->01 $7E0004:70->48 $7E0005:E8->8E $7E0008:78->50 …(429 more) | $7E0000-$7EED10 |
| A0 | vram.bin | 544 | 0 | 544 | 65,536 | $2100C0:B4->CF $2100C1:33->D7 $2100C2:50->B7 $2100C3:95->8B $2100C4:D8->63 $2100C5:12->02 …(538 more) | $2100C0-$21ECB7 |
| A0 | oam.bin | 39 | 0 | 39 | 544 | $020004:78->86 $020005:66->79 $020006:24->26 $020007:20->30 $020009:76->66 $02000A:22->24 …(33 more) | $020004-$02004F |
| A0 | cgram.bin | 29 | 0 | 29 | 512 | $3E8162:84->00 $3E8163:10->00 $3E8164:85->00 $3E8165:08->00 $3E8166:C8->00 $3E8167:0C->00 …(23 more) | $3E8162-$3E817E |
| A0 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A0 | fb.bgrx | 43,488 | 0 | 43,488 | 229,376 | $001C24:08->18 $001C26:21->18 $001C2D:18->10 $001C2E:21->10 $001C3C:08->00 $001C3D:10->00 …(43482 more) | $001C24-$02A1AA |
| A1 | wram.bin | 421 | 4 | 417 | 131,072 | $7E0004:01->70 $7E0005:00->E8 $7E0008:50->78 $7E0009:8E->E8 $7E0011:47->3E $7E0013:9B->9C …(411 more) | $7E0004-$7EED10 |
| A1 | vram.bin | 214 | 0 | 214 | 65,536 | $210561:00->21 $210562:00->21 $210563:00->63 $210564:00->44 $210569:00->40 $21056C:00->04 …(208 more) | $210561-$21ECB7 |
| A1 | oam.bin | 41 | 0 | 41 | 544 | $020004:78->86 $020005:67->79 $020006:24->26 $020007:20->30 $020009:77->67 $02000A:22->24 …(35 more) | $020004-$02004F |
| A1 | cgram.bin | 29 | 0 | 29 | 512 | $3E8162:84->00 $3E8163:10->00 $3E8164:85->00 $3E8165:08->00 $3E8166:C8->00 $3E8167:0C->00 …(23 more) | $3E8162-$3E817E |
| A1 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A1 | fb.bgrx | 43,230 | 0 | 43,230 | 229,376 | $001C24:08->18 $001C26:21->18 $001C2D:18->10 $001C2E:21->10 $001C3C:08->00 $001C3D:10->00 …(43224 more) | $001C24-$02A1AA |
| A2 | wram.bin | 393 | 2 | 391 | 131,072 | $7E0011:47->3E $7E0014:F3->F6 $7E0017:F3->F6 $7E0041:98->B8 $7E0053:96->B6 $7E005C:05->06 …(385 more) | $7E0011-$7EED10 |
| A2 | vram.bin | 214 | 0 | 214 | 65,536 | $210561:00->21 $210562:00->21 $210563:00->63 $210564:00->44 $210569:00->40 $21056C:00->04 …(208 more) | $210561-$21ECB7 |
| A2 | oam.bin | 39 | 0 | 39 | 544 | $020004:78->86 $020005:67->79 $020006:24->26 $020007:20->30 $020009:77->67 $02000A:22->24 …(33 more) | $020004-$02004F |
| A2 | cgram.bin | 29 | 0 | 29 | 512 | $3E8162:84->00 $3E8163:10->00 $3E8164:85->00 $3E8165:08->00 $3E8166:C8->00 $3E8167:0C->00 …(23 more) | $3E8162-$3E817E |
| A2 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A2 | fb.bgrx | 43,506 | 0 | 43,506 | 229,376 | $001C24:08->18 $001C26:21->18 $001C2D:18->10 $001C2E:21->10 $001C3C:08->00 $001C3D:10->00 …(43500 more) | $001C24-$02A1AA |
| A3 | wram.bin | 427 | 5 | 422 | 131,072 | $7E0004:48->01 $7E0005:8E->00 $7E0011:47->3E $7E0014:F3->F6 $7E0017:F3->F6 $7E005C:04->02 …(416 more) | $7E0004-$7EED10 |
| A3 | vram.bin | 561 | 0 | 561 | 65,536 | $2100C0:CF->3B $2100C1:D7->AA $2100C2:B7->42 $2100C3:8B->B4 $2100C4:63->DC $2100C5:02->F8 …(555 more) | $2100C0-$21ECB7 |
| A3 | oam.bin | 42 | 0 | 42 | 544 | $020004:78->86 $020005:67->79 $020006:24->26 $020007:20->30 $020009:77->67 $02000A:22->24 …(36 more) | $020004-$02004F |
| A3 | cgram.bin | 29 | 0 | 29 | 512 | $3E8162:84->00 $3E8163:10->00 $3E8164:85->00 $3E8165:08->00 $3E8166:C8->00 $3E8167:0C->00 …(23 more) | $3E8162-$3E817E |
| A3 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A3 | fb.bgrx | 43,046 | 0 | 43,046 | 229,376 | $001C24:08->18 $001C26:21->18 $001C2D:18->10 $001C2E:21->10 $001C3C:08->00 $001C3D:10->00 …(43040 more) | $001C24-$02A1AA |
| A4 | wram.bin | 512 | 6 | 506 | 131,072 | $7E0004:D8->70 $7E0005:88->E8 $7E0008:E0->78 $7E0009:88->E8 $7E000E:27->24 $7E0011:47->3E …(500 more) | $7E0004-$7EED10 |
| A4 | vram.bin | 237 | 0 | 237 | 65,536 | $210540:70->00 $210541:70->00 $210542:F8->00 $210543:88->00 $210544:38->00 $210545:28->00 …(231 more) | $210540-$21F0BA |
| A4 | oam.bin | 51 | 0 | 51 | 544 | $020004:7D->87 $020005:5B->6E $020006:2A->2C $020007:20->A2 $020008:7A->86 $020009:67->79 …(45 more) | $020004-$02004F |
| A4 | cgram.bin | 29 | 0 | 29 | 512 | $3E8162:84->00 $3E8163:10->00 $3E8164:85->00 $3E8165:08->00 $3E8166:C8->00 $3E8167:0C->00 …(23 more) | $3E8162-$3E817E |
| A4 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A4 | fb.bgrx | 44,042 | 0 | 44,042 | 229,376 | $001C24:08->18 $001C26:21->18 $001C2D:18->10 $001C2E:21->10 $001C3C:08->00 $001C3D:10->00 …(44036 more) | $001C24-$02A1AA |
| A5 | wram.bin | 531 | 3 | 528 | 131,072 | $7E0004:D8->48 $7E0005:88->8E $7E0008:E0->50 $7E0009:88->8E $7E000E:27->21 $7E0011:47->3E …(522 more) | $7E0004-$7EED10 |
| A5 | vram.bin | 222 | 0 | 222 | 65,536 | $210542:70->00 $210543:70->00 $210544:F8->00 $210545:88->00 $210546:78->00 $210547:68->00 …(216 more) | $210542-$21F0BA |
| A5 | oam.bin | 44 | 0 | 44 | 544 | $020004:7D->86 $020005:59->79 $020006:2A->26 $020007:20->30 $020008:7A->78 $02000C:7A->78 …(38 more) | $020004-$02004F |
| A5 | cgram.bin | 29 | 0 | 29 | 512 | $3E8162:84->00 $3E8163:10->00 $3E8164:85->00 $3E8165:08->00 $3E8166:C8->00 $3E8167:0C->00 …(23 more) | $3E8162-$3E817E |
| A5 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A5 | fb.bgrx | 43,981 | 0 | 43,981 | 229,376 | $001C24:08->18 $001C26:21->18 $001C2D:18->10 $001C2E:21->10 $001C3C:08->00 $001C3D:10->00 …(43975 more) | $001C24-$02A1AA |
| H8 | wram.bin | 10 | 9 | 1 | 131,072 | $7E0127:63->A2 | $7E0127-$7E1D04 |
| H8 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| H8 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| H8 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| H8 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| H8 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J1 | wram.bin | 203 | 2 | 201 | 131,072 | $7E0000:50->54 $7E0004:28->16 $7E0005:87->99 $7E0008:30->1E $7E0009:87->99 $7E0082:0A->02 …(195 more) | $7E0000-$7E41BF |
| J1 | vram.bin | 351 | 0 | 351 | 65,536 | $210046:00->01 $210048:00->03 $21004A:00->0F $21004B:01->0C $21004C:03->02 $21004D:01->0F …(345 more) | $210046-$21087B |
| J1 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J1 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J1 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J1 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J10 | wram.bin | 120 | 2 | 118 | 131,072 | $7E0120:A4->25 $7E0121:04->0A $7E02DE:D2->00 $7E02DF:F4->00 $7E039E:06->FF $7E039F:00->FF …(112 more) | $7E0120-$7E4215 |
| J10 | vram.bin | 99 | 0 | 99 | 65,536 | $210880:FF->18 $210881:00->18 $210882:0F->AC $210883:F0->FE $210884:07->62 $210885:78->66 …(93 more) | $210880-$210ABF |
| J10 | oam.bin | 29 | 0 | 29 | 544 | $02000E:06->0C $020010:1D->3E $020012:02->06 $020013:70->20 $020014:1D->40 $020016:02->06 …(23 more) | $02000E-$02004F |
| J10 | cgram.bin | 29 | 0 | 29 | 512 | $3E8162:84->00 $3E8163:10->00 $3E8164:85->00 $3E8165:08->00 $3E8166:C8->00 $3E8167:0C->00 …(23 more) | $3E8162-$3E817E |
| J10 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J10 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J2 | wram.bin | 298 | 5 | 293 | 131,072 | $7E0000:4E->50 $7E0002:02->04 $7E0004:16->10 $7E0005:99->93 $7E0008:1E->18 $7E0009:99->93 …(287 more) | $7E0000-$7E4217 |
| J2 | vram.bin | 434 | 0 | 434 | 65,536 | $210046:00->01 $210048:00->03 $210049:0C->00 $21004A:00->0F $21004C:04->02 $21004D:04->0F …(428 more) | $210046-$210ABF |
| J2 | oam.bin | 34 | 0 | 34 | 544 | $020004:A8->56 $020005:CA->C4 $020006:24->28 $020007:70->20 $020008:77->56 $020009:7D->D4 …(28 more) | $020004-$020201 |
| J2 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J2 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J2 | fb.bgrx | 824 | 0 | 824 | 229,376 | $00A2B4:9C->4A $00A2B5:9C->4A $00A2B6:9C->4A $00A2B8:9C->4A $00A2B9:9C->4A $00A2BA:9C->4A …(818 more) | $00A2B4-$035ADA |
| J3 | wram.bin | 255 | 3 | 252 | 131,072 | $7E0000:01->52 $7E0001:08->00 $7E0002:01->02 $7E0010:9B->9C $7E0014:0D->4B $7E0017:0D->4B …(246 more) | $7E0000-$7E4376 |
| J3 | vram.bin | 352 | 0 | 352 | 65,536 | $210049:00->0C $21004B:00->0C $21004C:02->04 $21004D:03->04 $21004E:07->00 $21004F:07->00 …(346 more) | $210049-$210ABF |
| J3 | oam.bin | 35 | 0 | 35 | 544 | $020008:AF->8E $020009:B1->A5 $02000A:28->04 $02000B:70->60 $02000C:AF->8E $02000D:C1->B5 …(29 more) | $020008-$02004F |
| J3 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J3 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J3 | fb.bgrx | 1,667 | 0 | 1,667 | 229,376 | $026210:08->29 $026211:18->29 $026212:21->31 $026214:18->29 $026215:18->29 $026216:18->31 …(1661 more) | $026210-$0322DA |
| J4 | wram.bin | 172 | 2 | 170 | 131,072 | $7E00A5:98->A0 $7E011F:04->07 $7E0120:FE->00 $7E0495:CD->00 $7E067E:E9->F1 $7E06A1:E0->00 …(164 more) | $7E00A5-$7E4215 |
| J4 | vram.bin | 377 | 0 | 377 | 65,536 | $210046:01->00 $210048:03->00 $21004A:0F->00 $21004B:0C->01 $21004C:02->03 $21004D:0F->01 …(371 more) | $210046-$210ABF |
| J4 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J4 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J4 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J4 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J5 | wram.bin | 261 | 2 | 259 | 131,072 | $7E0020:01->00 $7E0023:01->02 $7E0026:01->00 $7E0029:0C->0A $7E0038:02->05 $7E003B:02->00 …(253 more) | $7E0020-$7E4215 |
| J5 | vram.bin | 916 | 0 | 916 | 65,536 | $210040:0C->1C $210041:0C->00 $210042:3C->38 $210043:3C->00 $210044:FC->38 $210045:FC->00 …(910 more) | $210040-$210ABF |
| J5 | oam.bin | 27 | 0 | 27 | 544 | $020006:06->04 $02000A:04->02 $02000E:0A->08 $020012:08->06 $020014:7A->7D $020016:04->28 …(21 more) | $020006-$02004F |
| J5 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J5 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J5 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J6 | wram.bin | 265 | 2 | 263 | 131,072 | $7E0023:01->02 $7E0029:0C->0A $7E0038:02->05 $7E003B:02->00 $7E0074:23->CC $7E0075:05->04 …(257 more) | $7E0023-$7E4215 |
| J6 | vram.bin | 929 | 0 | 929 | 65,536 | $210040:0C->1F $210041:0C->00 $210042:3C->0F $210043:3C->00 $210044:FC->00 $210045:FC->00 …(923 more) | $210040-$210ABF |
| J6 | oam.bin | 28 | 0 | 28 | 544 | $020006:06->04 $02000A:04->02 $02000E:0A->08 $020012:08->06 $020014:10->7D $020016:02->28 …(22 more) | $020006-$02004F |
| J6 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J6 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J6 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J7 | wram.bin | 4,153 | 12 | 4,141 | 131,072 | $7E0026:34->D6 $7E0027:03->06 $7E007A:E0->78 $7E007B:0E->0F $7E007C:58->0E $7E007E:FF->0C …(4135 more) | $7E0026-$7EF583 |
| J7 | vram.bin | 12,442 | 0 | 12,442 | 65,536 | $210041:00->01 $210042:00->02 $210043:00->07 $210044:00->08 $210045:00->3F $210046:00->E1 …(12436 more) | $210041-$218D5F |
| J7 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J7 | cgram.bin | 29 | 0 | 29 | 512 | $3E8162:84->00 $3E8163:10->00 $3E8164:85->00 $3E8165:08->00 $3E8166:C8->00 $3E8167:0C->00 …(23 more) | $3E8162-$3E817E |
| J7 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J7 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J8 | wram.bin | 145 | 3 | 142 | 131,072 | $7E00AB:3C->F4 $7E00AE:02->00 $7E00B1:02->FF $7E00B7:4A->06 $7E00BA:10->03 $7E00BB:02->03 …(136 more) | $7E00AB-$7E4215 |
| J8 | vram.bin | 99 | 0 | 99 | 65,536 | $210880:FF->18 $210881:00->18 $210882:0F->AC $210883:F0->FE $210884:07->62 $210885:78->66 …(93 more) | $210880-$210ABF |
| J8 | oam.bin | 29 | 0 | 29 | 544 | $02000E:06->0C $020010:1D->3E $020012:02->06 $020013:70->20 $020014:1D->40 $020016:02->06 …(23 more) | $02000E-$02004F |
| J8 | cgram.bin | 29 | 0 | 29 | 512 | $3E8162:84->00 $3E8163:10->00 $3E8164:85->00 $3E8165:08->00 $3E8166:C8->00 $3E8167:0C->00 …(23 more) | $3E8162-$3E817E |
| J8 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J8 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J9 | wram.bin | 189 | 6 | 183 | 131,072 | $7E0000:FF->01 $7E0001:FF->08 $7E0002:18->01 $7E0004:20->48 $7E0005:00->8E $7E0006:03->8C …(177 more) | $7E0000-$7E4215 |
| J9 | vram.bin | 497 | 0 | 497 | 65,536 | $2100C0:A4->CF $2100C1:D0->D7 $2100C2:C0->B7 $2100C3:E8->8B $2100C4:50->63 $2100C5:E0->02 …(491 more) | $2100C0-$210ABF |
| J9 | oam.bin | 29 | 0 | 29 | 544 | $02000E:06->0C $020010:1D->3E $020012:02->06 $020013:70->20 $020014:1D->40 $020016:02->06 …(23 more) | $02000E-$02004F |
| J9 | cgram.bin | 29 | 0 | 29 | 512 | $3E8162:84->00 $3E8163:10->00 $3E8164:85->00 $3E8165:08->00 $3E8166:C8->00 $3E8167:0C->00 …(23 more) | $3E8162-$3E817E |
| J9 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J9 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| K1 | wram.bin | 120 | 2 | 118 | 131,072 | $7E0120:A4->25 $7E0121:04->0A $7E02DE:D2->00 $7E02DF:F4->00 $7E039E:06->FF $7E039F:00->FF …(112 more) | $7E0120-$7E4215 |
| K1 | vram.bin | 99 | 0 | 99 | 65,536 | $210880:FF->18 $210881:00->18 $210882:0F->AC $210883:F0->FE $210884:07->62 $210885:78->66 …(93 more) | $210880-$210ABF |
| K1 | oam.bin | 29 | 0 | 29 | 544 | $02000E:06->0C $020010:1D->3E $020012:02->06 $020013:70->20 $020014:1D->40 $020016:02->06 …(23 more) | $02000E-$02004F |
| K1 | cgram.bin | 29 | 0 | 29 | 512 | $3E8162:84->00 $3E8163:10->00 $3E8164:85->00 $3E8165:08->00 $3E8166:C8->00 $3E8167:0C->00 …(23 more) | $3E8162-$3E817E |
| K1 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| K1 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| K2 | wram.bin | 99 | 2 | 97 | 131,072 | $7E0120:A4->25 $7E0121:04->0A $7E0438:4E->54 $7E043A:08->05 $7E043C:4E->54 $7E04D1:DD->DB …(91 more) | $7E0120-$7E4215 |
| K2 | vram.bin | 99 | 0 | 99 | 65,536 | $210880:FF->18 $210881:00->18 $210882:0F->AC $210883:F0->FE $210884:07->62 $210885:78->66 …(93 more) | $210880-$210ABF |
| K2 | oam.bin | 15 | 0 | 15 | 544 | $020032:37->36 $020036:48->37 $020037:01->41 $020038:70->68 $02003A:2F->48 $02003B:41->01 …(9 more) | $020032-$02004F |
| K2 | cgram.bin | 29 | 0 | 29 | 512 | $3E8162:84->00 $3E8163:10->00 $3E8164:85->00 $3E8165:08->00 $3E8166:C8->00 $3E8167:0C->00 …(23 more) | $3E8162-$3E817E |
| K2 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| K2 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| K3 | wram.bin | 131 | 3 | 128 | 131,072 | $7E0002:00->01 $7E0082:0E->FE $7E0083:00->FF $7E00A5:68->60 $7E0133:B4->B5 $7E0438:4E->54 …(122 more) | $7E0002-$7EED04 |
| K3 | vram.bin | 483 | 0 | 483 | 65,536 | $2100C0:A4->80 $2100C1:D0->00 $2100C2:C0->00 $2100C3:E8->40 $2100C4:50->10 $2100C5:E0->A0 …(477 more) | $2100C0-$21F0BA |
| K3 | oam.bin | 21 | 0 | 21 | 544 | $020010:67->69 $020014:67->69 $020018:77->79 $02001C:77->79 $020021:54->53 $020022:2A->2C …(15 more) | $020010-$02004F |
| K3 | cgram.bin | 29 | 0 | 29 | 512 | $3E8162:84->00 $3E8163:10->00 $3E8164:85->00 $3E8165:08->00 $3E8166:C8->00 $3E8167:0C->00 …(23 more) | $3E8162-$3E817E |
| K3 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| K3 | fb.bgrx | 1,224 | 0 | 1,224 | 229,376 | $003FB9:00->31 $003FBA:00->B5 $0043B9:00->31 $0043BA:00->B5 $0047B9:00->31 $0047BA:00->B5 …(1218 more) | $003FB9-$0249DA |
| L0 | wram.bin | 331 | 6 | 325 | 131,072 | $7E0004:70->00 $7E0005:E8->00 $7E0006:8C->01 $7E0008:78->34 $7E0009:E8->CF $7E000E:21->27 …(319 more) | $7E0004-$7EF024 |
| L0 | vram.bin | 202 | 0 | 202 | 65,536 | $210562:00->40 $210563:00->20 $210564:00->28 $210565:00->64 $210566:00->04 $210567:00->5C …(196 more) | $210562-$21F0BA |
| L0 | oam.bin | 52 | 0 | 52 | 544 | $020004:78->7E $020005:7B->6A $020006:24->2C $020008:78->7A $020009:8B->75 $02000A:22->24 …(46 more) | $020004-$02004F |
| L0 | cgram.bin | 29 | 0 | 29 | 512 | $3E8162:84->00 $3E8163:10->00 $3E8164:85->00 $3E8165:08->00 $3E8166:C8->00 $3E8167:0C->00 …(23 more) | $3E8162-$3E817E |
| L0 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| L0 | fb.bgrx | 44,144 | 0 | 44,144 | 229,376 | $001C24:00->08 $001C25:00->10 $001C26:00->10 $001C28:00->08 $001C29:00->10 $001C2A:00->10 …(44138 more) | $001C24-$029586 |
| L1 | wram.bin | 250 | 2 | 248 | 131,072 | $7E0011:3E->31 $7E005C:02->03 $7E0065:D8->E5 $7E00A5:BA->8E $7E00A8:A1->A8 $7E00AB:46->72 …(242 more) | $7E0011-$7EF881 |
| L1 | vram.bin | 184 | 0 | 184 | 65,536 | $210561:00->21 $210562:00->21 $210563:00->63 $210564:00->44 $210569:00->40 $21056C:00->04 …(178 more) | $210561-$21F0BA |
| L1 | oam.bin | 30 | 0 | 30 | 544 | $020005:7C->76 $020009:8C->86 $02000C:86->79 $020010:83->7A $020011:52->53 $020014:83->7A …(24 more) | $020005-$02004F |
| L1 | cgram.bin | 29 | 0 | 29 | 512 | $3E8162:84->00 $3E8163:10->00 $3E8164:85->00 $3E8165:08->00 $3E8166:C8->00 $3E8167:0C->00 …(23 more) | $3E8162-$3E817E |
| L1 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| L1 | fb.bgrx | 48,247 | 0 | 48,247 | 229,376 | $001C20:08->00 $001C21:18->00 $001C22:21->00 $001C24:08->00 $001C25:10->00 $001C26:10->00 …(48241 more) | $001C20-$0295AA |

checkpoints with state (non-label) bytes differing, in route order: H8 f16188 (1), J1 f16865 (552), J2 f17196 (1,585), J3 f17317 (2,306), J4 f17438 (547), J5 f17559 (1,202), J6 f17680 (1,220), J7 f17801 (16,612)

==== rejected: seed only $80B1DB
# checkpoint byte diff: tests/out/r4/r4base vs tests/out/r4/s80B1DB

Bytes differing in the state images each run dumped at the same tagged
checkpoint (`dump TAG` in the route).  Address columns are the guest
bus address of the byte, control value then variant value.  On wram,
`label` counts the bytes the label rule in framedump_diff.py excuses
(host frame-kernel counter window, documented timer singletons);
`state` is every other differing byte, and those are the ones shown.

| checkpoint | surface | bytes differ | label | state | size | state bytes (control -> variant) | span |
|---|---|---|---|---|---|---|---|
| A0 | wram.bin | 573 | 4 | 569 | 131,072 | $7E0000:52->01 $7E0001:00->08 $7E0002:00->01 $7E0004:70->01 $7E0005:E8->00 $7E0008:78->50 …(563 more) | $7E0000-$7EF887 |
| A0 | vram.bin | 718 | 0 | 718 | 65,536 | $2100C0:B4->CF $2100C1:33->D7 $2100C2:50->B7 $2100C3:95->8B $2100C4:D8->63 $2100C5:12->02 …(712 more) | $2100C0-$21F0BA |
| A0 | oam.bin | 44 | 0 | 44 | 544 | $020004:78->86 $020005:66->7B $020006:24->26 $020007:20->30 $020009:76->66 $02000A:22->24 …(38 more) | $020004-$02004B |
| A0 | cgram.bin | 29 | 0 | 29 | 512 | $3E8162:84->00 $3E8163:10->00 $3E8164:85->00 $3E8165:08->00 $3E8166:C8->00 $3E8167:0C->00 …(23 more) | $3E8162-$3E817E |
| A0 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A0 | fb.bgrx | 42,983 | 0 | 42,983 | 229,376 | $001C21:18->10 $001C22:21->10 $001C25:18->10 $001C26:21->10 $001C2D:18->10 $001C2E:21->10 …(42977 more) | $001C21-$02A9AA |
| A1 | wram.bin | 526 | 4 | 522 | 131,072 | $7E0004:01->70 $7E0005:00->E8 $7E0008:50->78 $7E0009:8E->E8 $7E0011:47->3E $7E0013:9B->9C …(516 more) | $7E0004-$7EF887 |
| A1 | vram.bin | 559 | 0 | 559 | 65,536 | $210440:06->00 $210441:12->00 $210442:08->00 $210443:16->00 $210444:0F->00 $210445:1C->00 …(553 more) | $210440-$21F0BA |
| A1 | oam.bin | 45 | 0 | 45 | 544 | $020004:78->86 $020005:67->7B $020006:24->26 $020007:20->30 $020008:78->74 $020009:77->67 …(39 more) | $020004-$02004B |
| A1 | cgram.bin | 29 | 0 | 29 | 512 | $3E8162:84->00 $3E8163:10->00 $3E8164:85->00 $3E8165:08->00 $3E8166:C8->00 $3E8167:0C->00 …(23 more) | $3E8162-$3E817E |
| A1 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A1 | fb.bgrx | 43,052 | 0 | 43,052 | 229,376 | $001C21:18->10 $001C22:21->10 $001C25:18->10 $001C26:21->10 $001C2D:18->10 $001C2E:21->10 …(43046 more) | $001C21-$02A9AA |
| A2 | wram.bin | 492 | 2 | 490 | 131,072 | $7E0011:47->3E $7E0014:F3->F8 $7E0017:F3->F8 $7E0041:98->B8 $7E0053:96->B6 $7E005C:05->06 …(484 more) | $7E0011-$7EF887 |
| A2 | vram.bin | 559 | 0 | 559 | 65,536 | $210440:06->00 $210441:12->00 $210442:08->00 $210443:16->00 $210444:0F->00 $210445:1C->00 …(553 more) | $210440-$21F0BA |
| A2 | oam.bin | 43 | 0 | 43 | 544 | $020004:78->86 $020005:67->7B $020006:24->26 $020007:20->30 $020008:78->74 $020009:77->67 …(37 more) | $020004-$02004B |
| A2 | cgram.bin | 29 | 0 | 29 | 512 | $3E8162:84->00 $3E8163:10->00 $3E8164:85->00 $3E8165:08->00 $3E8166:C8->00 $3E8167:0C->00 …(23 more) | $3E8162-$3E817E |
| A2 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A2 | fb.bgrx | 43,489 | 0 | 43,489 | 229,376 | $001C21:18->10 $001C22:21->10 $001C25:18->10 $001C26:21->10 $001C2D:18->10 $001C2E:21->10 …(43483 more) | $001C21-$02A9AA |
| A3 | wram.bin | 554 | 2 | 552 | 131,072 | $7E0004:48->B8 $7E0008:50->C0 $7E0011:47->3E $7E0014:F3->F8 $7E0017:F3->F8 $7E004A:01->02 …(546 more) | $7E0004-$7EF887 |
| A3 | vram.bin | 916 | 0 | 916 | 65,536 | $2100C0:CF->3B $2100C1:D7->AA $2100C2:B7->42 $2100C3:8B->B4 $2100C4:63->DC $2100C5:02->F8 …(910 more) | $2100C0-$21F0BA |
| A3 | oam.bin | 46 | 0 | 46 | 544 | $020004:78->86 $020005:67->7B $020006:24->26 $020007:20->30 $020008:78->74 $020009:77->67 …(40 more) | $020004-$02004B |
| A3 | cgram.bin | 29 | 0 | 29 | 512 | $3E8162:84->00 $3E8163:10->00 $3E8164:85->00 $3E8165:08->00 $3E8166:C8->00 $3E8167:0C->00 …(23 more) | $3E8162-$3E817E |
| A3 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A3 | fb.bgrx | 42,952 | 0 | 42,952 | 229,376 | $001C21:18->10 $001C22:21->10 $001C25:18->10 $001C26:21->10 $001C2D:18->10 $001C2E:21->10 …(42946 more) | $001C21-$02A9AA |
| A4 | wram.bin | 611 | 6 | 605 | 131,072 | $7E0004:D8->70 $7E0005:88->E8 $7E0008:E0->78 $7E0009:88->E8 $7E000E:27->24 $7E0011:47->3E …(599 more) | $7E0004-$7EF887 |
| A4 | vram.bin | 573 | 0 | 573 | 65,536 | $210440:06->00 $210441:12->00 $210442:08->00 $210443:16->00 $210444:0F->00 $210445:1C->00 …(567 more) | $210440-$21F0BA |
| A4 | oam.bin | 51 | 0 | 51 | 544 | $020004:7D->86 $020005:5B->7B $020006:2A->26 $020007:20->30 $020008:7A->74 $02000C:7A->74 …(45 more) | $020004-$02004B |
| A4 | cgram.bin | 29 | 0 | 29 | 512 | $3E8162:84->00 $3E8163:10->00 $3E8164:85->00 $3E8165:08->00 $3E8166:C8->00 $3E8167:0C->00 …(23 more) | $3E8162-$3E817E |
| A4 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A4 | fb.bgrx | 43,600 | 0 | 43,600 | 229,376 | $001C21:18->10 $001C22:21->10 $001C25:18->10 $001C26:21->10 $001C2D:18->10 $001C2E:21->10 …(43594 more) | $001C21-$02A9AA |
| A5 | wram.bin | 628 | 3 | 625 | 131,072 | $7E0004:D8->48 $7E0005:88->8E $7E0008:E0->50 $7E0009:88->8E $7E000E:27->21 $7E0011:47->3E …(619 more) | $7E0004-$7EF887 |
| A5 | vram.bin | 566 | 0 | 566 | 65,536 | $210440:06->00 $210441:12->00 $210442:08->00 $210443:16->00 $210444:0F->00 $210445:1C->00 …(560 more) | $210440-$21F0BA |
| A5 | oam.bin | 49 | 0 | 49 | 544 | $020004:7D->86 $020005:59->7B $020006:2A->26 $020007:20->30 $020008:7A->74 $02000C:7A->74 …(43 more) | $020004-$02004B |
| A5 | cgram.bin | 29 | 0 | 29 | 512 | $3E8162:84->00 $3E8163:10->00 $3E8164:85->00 $3E8165:08->00 $3E8166:C8->00 $3E8167:0C->00 …(23 more) | $3E8162-$3E817E |
| A5 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A5 | fb.bgrx | 43,493 | 0 | 43,493 | 229,376 | $001C21:18->10 $001C22:21->10 $001C25:18->10 $001C26:21->10 $001C2D:18->10 $001C2E:21->10 …(43487 more) | $001C21-$02A9AA |
| H8 | wram.bin | 9 | 8 | 1 | 131,072 | $7E0127:63->6D | $7E0127-$7E1D04 |
| H8 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| H8 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| H8 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| H8 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| H8 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J1 | wram.bin | 147 | 2 | 145 | 131,072 | $7E0082:0A->FE $7E0083:00->FF $7E00A5:E8->00 $7E00A6:00->04 $7E00AB:18->00 $7E00AC:FF->FC …(139 more) | $7E0082-$7E4219 |
| J1 | vram.bin | 342 | 0 | 342 | 65,536 | $210040:00->01 $210041:00->01 $21004A:00->20 $21004B:01->00 $21004C:03->58 $21004D:01->30 …(336 more) | $210040-$210B7F |
| J1 | oam.bin | 4 | 0 | 4 | 544 | $020026:48->46 $02002E:48->46 $020032:48->46 $020036:48->46 | $020026-$020036 |
| J1 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J1 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J1 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J10 | wram.bin | 243 | 3 | 240 | 131,072 | $7E0121:04->FC $7E0280:4B->C2 $7E0282:73->64 $7E0286:C2->F1 $7E02DE:D2->00 $7E02DF:F4->00 …(234 more) | $7E0121-$7E4219 |
| J10 | vram.bin | 265 | 0 | 265 | 65,536 | $210840:FF->14 $210841:00->13 $210842:0F->00 $210843:F0->07 $210844:07->00 $210845:78->07 …(259 more) | $210840-$210B7F |
| J10 | oam.bin | 37 | 0 | 37 | 544 | $02000E:06->02 $020010:1D->40 $020012:02->08 $020013:70->20 $020014:1D->40 $020016:02->06 …(31 more) | $02000E-$02004B |
| J10 | cgram.bin | 29 | 0 | 29 | 512 | $3E8162:84->00 $3E8163:10->00 $3E8164:85->00 $3E8165:08->00 $3E8166:C8->00 $3E8167:0C->00 …(23 more) | $3E8162-$3E817E |
| J10 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J10 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J2 | wram.bin | 227 | 5 | 222 | 131,072 | $7E0000:4E->54 $7E0002:02->04 $7E000E:12->15 $7E0011:68->AD $7E0014:60->29 $7E0017:70->29 …(216 more) | $7E0000-$7E4219 |
| J2 | vram.bin | 553 | 0 | 553 | 65,536 | $210049:0C->00 $21004B:0C->01 $21004C:04->03 $21004D:04->01 $21004F:00->03 $210051:07->03 …(547 more) | $210049-$210B7F |
| J2 | oam.bin | 9 | 0 | 9 | 544 | $020005:CA->CB $020015:F0->28 $020016:44->46 $020022:48->46 $020026:48->46 $02002A:48->46 …(3 more) | $020005-$020036 |
| J2 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J2 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J2 | fb.bgrx | 338 | 0 | 338 | 229,376 | $00A2B4:9C->4A $00A2B5:9C->4A $00A2B6:9C->4A $00A2B8:9C->4A $00A2B9:9C->4A $00A2BA:9C->4A …(332 more) | $00A2B4-$035ACE |
| J3 | wram.bin | 309 | 8 | 301 | 131,072 | $7E0000:01->52 $7E0001:08->00 $7E0002:01->02 $7E000E:1E->21 $7E0011:00->F6 $7E0014:0D->ED …(295 more) | $7E0000-$7E4378 |
| J3 | vram.bin | 705 | 0 | 705 | 65,536 | $210046:00->01 $210048:00->03 $21004A:00->0F $21004B:00->0C $21004D:03->0F $21004E:07->01 …(699 more) | $210046-$210B7F |
| J3 | oam.bin | 55 | 0 | 55 | 544 | $020008:AF->98 $020009:B1->C9 $02000A:28->CA $02000B:70->01 $02000C:AF->A0 $02000D:C1->C9 …(49 more) | $020008-$020201 |
| J3 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J3 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J3 | fb.bgrx | 1,651 | 0 | 1,651 | 229,376 | $023FC8:18->7B $023FC9:31->7B $023FCA:42->84 $023FD0:00->42 $023FD1:29->42 $023FD2:52->39 …(1645 more) | $023FC8-$0322DA |
| J4 | wram.bin | 172 | 3 | 169 | 131,072 | $7E0084:28->20 $7E00A5:98->A0 $7E0120:FE->EA $7E0495:CD->53 $7E0640:16->2E $7E0657:44->7F …(163 more) | $7E0084-$7E4219 |
| J4 | vram.bin | 591 | 0 | 591 | 65,536 | $210046:01->00 $210048:03->00 $21004A:0F->00 $21004B:0C->01 $21004C:02->03 $21004D:0F->01 …(585 more) | $210046-$210B7F |
| J4 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J4 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J4 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J4 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J5 | wram.bin | 386 | 2 | 384 | 131,072 | $7E0023:01->02 $7E0026:01->02 $7E0029:0C->0E $7E0038:02->04 $7E0074:23->CC $7E0075:05->04 …(378 more) | $7E0023-$7E4219 |
| J5 | vram.bin | 1,214 | 0 | 1,214 | 65,536 | $210040:0C->1C $210041:0C->00 $210042:3C->38 $210043:3C->00 $210044:FC->38 $210045:FC->00 …(1208 more) | $210040-$210B7F |
| J5 | oam.bin | 37 | 0 | 37 | 544 | $020006:06->04 $02000A:04->02 $02000E:0A->08 $020012:08->06 $020014:7A->DD $020016:04->24 …(31 more) | $020006-$02004B |
| J5 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J5 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J5 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J6 | wram.bin | 393 | 2 | 391 | 131,072 | $7E0023:01->02 $7E0029:0C->0E $7E0038:02->05 $7E003B:02->00 $7E0074:23->CC $7E0075:05->04 …(385 more) | $7E0023-$7E4219 |
| J6 | vram.bin | 1,229 | 0 | 1,229 | 65,536 | $210040:0C->1F $210041:0C->00 $210042:3C->0F $210043:3C->00 $210044:FC->00 $210045:FC->00 …(1223 more) | $210040-$210B7F |
| J6 | oam.bin | 37 | 0 | 37 | 544 | $020006:06->04 $02000A:04->02 $02000E:0A->08 $020012:08->06 $020014:10->DD $020016:02->24 …(31 more) | $020006-$02004B |
| J6 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J6 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J6 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J7 | wram.bin | 4,290 | 12 | 4,278 | 131,072 | $7E0026:34->D6 $7E0027:03->06 $7E007A:E0->78 $7E007B:0E->0F $7E007C:58->0E $7E007E:FF->0C …(4272 more) | $7E0026-$7EF583 |
| J7 | vram.bin | 12,564 | 0 | 12,564 | 65,536 | $210041:00->01 $210042:00->02 $210043:00->07 $210044:00->08 $210045:00->3F $210046:00->E1 …(12558 more) | $210041-$218D5F |
| J7 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J7 | cgram.bin | 29 | 0 | 29 | 512 | $3E8162:84->00 $3E8163:10->00 $3E8164:85->00 $3E8165:08->00 $3E8166:C8->00 $3E8167:0C->00 …(23 more) | $3E8162-$3E817E |
| J7 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J7 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J8 | wram.bin | 284 | 3 | 281 | 131,072 | $7E00AB:3C->F4 $7E00AE:02->00 $7E00B1:02->FF $7E00B7:4A->06 $7E00BA:10->03 $7E00BB:02->03 …(275 more) | $7E00AB-$7E4219 |
| J8 | vram.bin | 265 | 0 | 265 | 65,536 | $210840:FF->14 $210841:00->13 $210842:0F->00 $210843:F0->07 $210844:07->00 $210845:78->07 …(259 more) | $210840-$210B7F |
| J8 | oam.bin | 37 | 0 | 37 | 544 | $02000E:06->02 $020010:1D->40 $020012:02->08 $020013:70->20 $020014:1D->40 $020016:02->06 …(31 more) | $02000E-$02004B |
| J8 | cgram.bin | 29 | 0 | 29 | 512 | $3E8162:84->00 $3E8163:10->00 $3E8164:85->00 $3E8165:08->00 $3E8166:C8->00 $3E8167:0C->00 …(23 more) | $3E8162-$3E817E |
| J8 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J8 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J9 | wram.bin | 312 | 6 | 306 | 131,072 | $7E0000:FF->01 $7E0001:FF->08 $7E0002:18->01 $7E0004:20->48 $7E0005:00->8E $7E0006:03->8C …(300 more) | $7E0000-$7E4219 |
| J9 | vram.bin | 663 | 0 | 663 | 65,536 | $2100C0:A4->CF $2100C1:D0->D7 $2100C2:C0->B7 $2100C3:E8->8B $2100C4:50->63 $2100C5:E0->02 …(657 more) | $2100C0-$210B7F |
| J9 | oam.bin | 37 | 0 | 37 | 544 | $02000E:06->02 $020010:1D->40 $020012:02->08 $020013:70->20 $020014:1D->40 $020016:02->06 …(31 more) | $02000E-$02004B |
| J9 | cgram.bin | 29 | 0 | 29 | 512 | $3E8162:84->00 $3E8163:10->00 $3E8164:85->00 $3E8165:08->00 $3E8166:C8->00 $3E8167:0C->00 …(23 more) | $3E8162-$3E817E |
| J9 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J9 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| K1 | wram.bin | 242 | 2 | 240 | 131,072 | $7E0121:04->FC $7E0280:4B->C2 $7E0282:73->64 $7E0286:C2->F1 $7E02DE:D2->00 $7E02DF:F4->00 …(234 more) | $7E0121-$7E4219 |
| K1 | vram.bin | 265 | 0 | 265 | 65,536 | $210840:FF->14 $210841:00->13 $210842:0F->00 $210843:F0->07 $210844:07->00 $210845:78->07 …(259 more) | $210840-$210B7F |
| K1 | oam.bin | 37 | 0 | 37 | 544 | $02000E:06->02 $020010:1D->40 $020012:02->08 $020013:70->20 $020014:1D->40 $020016:02->06 …(31 more) | $02000E-$02004B |
| K1 | cgram.bin | 29 | 0 | 29 | 512 | $3E8162:84->00 $3E8163:10->00 $3E8164:85->00 $3E8165:08->00 $3E8166:C8->00 $3E8167:0C->00 …(23 more) | $3E8162-$3E817E |
| K1 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| K1 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| K2 | wram.bin | 452 | 3 | 449 | 131,072 | $7E000E:27->21 $7E0011:19->0D $7E0014:3E->44 $7E0017:3E->44 $7E0041:14->54 $7E0044:12->0C …(443 more) | $7E000E-$7EED10 |
| K2 | vram.bin | 824 | 0 | 824 | 65,536 | $2100C0:00->20 $2100C1:00->C0 $2100C2:00->C0 $2100E0:02->00 $2100E1:0C->00 $2100E2:0A->00 …(818 more) | $2100C0-$21F0BA |
| K2 | oam.bin | 50 | 0 | 50 | 544 | $020004:61->55 $020005:C1->C7 $020008:44->38 $020009:B2->B8 $02000C:54->48 $02000D:B2->B8 …(44 more) | $020004-$02004B |
| K2 | cgram.bin | 29 | 0 | 29 | 512 | $3E8162:84->00 $3E8163:10->00 $3E8164:85->00 $3E8165:08->00 $3E8166:C8->00 $3E8167:0C->00 …(23 more) | $3E8162-$3E817E |
| K2 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| K2 | fb.bgrx | 46,680 | 0 | 46,680 | 229,376 | $003FB9:31->00 $003FBA:B5->00 $003FBD:31->00 $003FBE:B5->00 $0043B9:31->00 $0043BA:B5->00 …(46674 more) | $003FB9-$0359EE |
| K3 | wram.bin | 326 | 2 | 324 | 131,072 | $7E0011:19->0D $7E0014:3E->44 $7E0017:3E->44 $7E0041:14->54 $7E0044:12->0C $7E0047:01->02 …(318 more) | $7E0011-$7EED10 |
| K3 | vram.bin | 383 | 0 | 383 | 65,536 | $210542:70->04 $210543:70->04 $210544:F8->0E $210545:88->0A $210546:78->1E $210547:68->12 …(377 more) | $210542-$21EFC3 |
| K3 | oam.bin | 35 | 0 | 35 | 544 | $020004:61->55 $020005:C1->C7 $020008:44->38 $020009:B2->B8 $02000C:54->48 $02000D:B2->B8 …(29 more) | $020004-$02004B |
| K3 | cgram.bin | 29 | 0 | 29 | 512 | $3E8162:84->00 $3E8163:10->00 $3E8164:85->00 $3E8165:08->00 $3E8166:C8->00 $3E8167:0C->00 …(23 more) | $3E8162-$3E817E |
| K3 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| K3 | fb.bgrx | 46,393 | 0 | 46,393 | 229,376 | $0043C4:18->00 $0043C5:18->00 $0043C6:18->00 $0043C8:18->00 $0043C9:18->00 $0043CA:18->00 …(46387 more) | $0043C4-$0359EE |
| L0 | wram.bin | 378 | 2 | 376 | 131,072 | $7E0011:35->2B $7E0041:F6->18 $7E0042:05->06 $7E004A:01->04 $7E0053:F6->16 $7E0054:05->06 …(370 more) | $7E0011-$7EF887 |
| L0 | vram.bin | 297 | 0 | 297 | 65,536 | $210840:FF->14 $210841:00->13 $210842:0F->00 $210843:F0->07 $210844:07->00 $210845:78->07 …(291 more) | $210840-$21ECFB |
| L0 | oam.bin | 32 | 0 | 32 | 544 | $020005:7B->76 $020009:8B->86 $02000C:7D->73 $020010:60->56 $020014:70->66 $020018:7E->7C …(26 more) | $020005-$02004B |
| L0 | cgram.bin | 29 | 0 | 29 | 512 | $3E8162:84->00 $3E8163:10->00 $3E8164:85->00 $3E8165:08->00 $3E8166:C8->00 $3E8167:0C->00 …(23 more) | $3E8162-$3E817E |
| L0 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| L0 | fb.bgrx | 44,765 | 0 | 44,765 | 229,376 | $001C20:00->08 $001C21:00->10 $001C22:00->10 $001C24:00->08 $001C25:00->10 $001C26:00->10 …(44759 more) | $001C20-$029586 |
| L1 | wram.bin | 401 | 2 | 399 | 131,072 | $7E0011:3E->34 $7E0041:F8->18 $7E0042:05->06 $7E0053:F6->16 $7E0054:05->06 $7E005C:02->03 …(393 more) | $7E0011-$7EF887 |
| L1 | vram.bin | 328 | 0 | 328 | 65,536 | $2105A1:21->00 $2105A2:21->00 $2105A3:63->00 $2105A4:44->00 $2105A9:40->00 $2105AC:04->00 …(322 more) | $2105A1-$21F0BA |
| L1 | oam.bin | 35 | 0 | 35 | 544 | $020005:7C->77 $020009:8C->87 $02000C:86->7C $020010:83->7F $020011:52->53 $020014:83->7F …(29 more) | $020005-$02004B |
| L1 | cgram.bin | 29 | 0 | 29 | 512 | $3E8162:84->00 $3E8163:10->00 $3E8164:85->00 $3E8165:08->00 $3E8166:C8->00 $3E8167:0C->00 …(23 more) | $3E8162-$3E817E |
| L1 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| L1 | fb.bgrx | 45,632 | 0 | 45,632 | 229,376 | $001C20:08->00 $001C21:18->00 $001C22:21->00 $001C24:08->00 $001C25:10->00 $001C26:10->00 …(45626 more) | $001C20-$0295AA |

checkpoints with state (non-label) bytes differing, in route order: H8 f16188 (1), J1 f16865 (491), J2 f17196 (1,122), J3 f17317 (2,712), J4 f17438 (760), J5 f17559 (1,635), J6 f17680 (1,657), J7 f17801 (16,871)

==== rejected: all ten gap seeds that gate ($80C399+$80AAB3+$80ABBC+$80B1DB)
# checkpoint byte diff: tests/out/r4/r4base vs tests/out/r4/r4clean

Bytes differing in the state images each run dumped at the same tagged
checkpoint (`dump TAG` in the route).  Address columns are the guest
bus address of the byte, control value then variant value.  On wram,
`label` counts the bytes the label rule in framedump_diff.py excuses
(host frame-kernel counter window, documented timer singletons);
`state` is every other differing byte, and those are the ones shown.

| checkpoint | surface | bytes differ | label | state | size | state bytes (control -> variant) | span |
|---|---|---|---|---|---|---|---|
| A0 | wram.bin | 627 | 4 | 623 | 131,072 | $7E0000:52->01 $7E0001:00->08 $7E0002:00->01 $7E0004:70->01 $7E0005:E8->00 $7E0008:78->50 …(617 more) | $7E0000-$7EF887 |
| A0 | vram.bin | 741 | 0 | 741 | 65,536 | $2100C0:B4->CF $2100C1:33->D7 $2100C2:50->B7 $2100C3:95->8B $2100C4:D8->63 $2100C5:12->02 …(735 more) | $2100C0-$21F0BA |
| A0 | oam.bin | 37 | 0 | 37 | 544 | $020004:78->86 $020005:66->7C $020006:24->26 $020007:20->30 $020009:76->66 $02000A:22->24 …(31 more) | $020004-$02003B |
| A0 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A0 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A0 | fb.bgrx | 45,191 | 0 | 45,191 | 229,376 | $001C21:18->10 $001C22:21->10 $001C25:18->10 $001C26:21->10 $001C2D:18->10 $001C2E:21->10 …(45185 more) | $001C21-$02ADAA |
| A1 | wram.bin | 593 | 4 | 589 | 131,072 | $7E0004:01->70 $7E0005:00->E8 $7E0008:50->78 $7E0009:8E->E8 $7E0011:47->3E $7E0013:9B->9C …(583 more) | $7E0004-$7EF887 |
| A1 | vram.bin | 589 | 0 | 589 | 65,536 | $210440:06->00 $210441:12->00 $210442:08->00 $210443:16->00 $210444:0F->00 $210445:1C->00 …(583 more) | $210440-$21F0BA |
| A1 | oam.bin | 38 | 0 | 38 | 544 | $020004:78->86 $020005:67->7C $020006:24->26 $020007:20->30 $020008:78->74 $020009:77->67 …(32 more) | $020004-$02003B |
| A1 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A1 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A1 | fb.bgrx | 45,240 | 0 | 45,240 | 229,376 | $001C21:18->10 $001C22:21->10 $001C25:18->10 $001C26:21->10 $001C2D:18->10 $001C2E:21->10 …(45234 more) | $001C21-$02ADAA |
| A2 | wram.bin | 563 | 2 | 561 | 131,072 | $7E0011:47->3E $7E0014:F3->F9 $7E0017:F3->F9 $7E0041:98->B8 $7E0053:96->B6 $7E005C:05->06 …(555 more) | $7E0011-$7EF887 |
| A2 | vram.bin | 589 | 0 | 589 | 65,536 | $210440:06->00 $210441:12->00 $210442:08->00 $210443:16->00 $210444:0F->00 $210445:1C->00 …(583 more) | $210440-$21F0BA |
| A2 | oam.bin | 34 | 0 | 34 | 544 | $020004:78->86 $020005:67->7C $020006:24->26 $020007:20->30 $020008:78->74 $020009:77->67 …(28 more) | $020004-$02003B |
| A2 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A2 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A2 | fb.bgrx | 45,783 | 0 | 45,783 | 229,376 | $001C21:18->10 $001C22:21->10 $001C25:18->10 $001C26:21->10 $001C2D:18->10 $001C2E:21->10 …(45777 more) | $001C21-$02ADAA |
| A3 | wram.bin | 626 | 3 | 623 | 131,072 | $7E0004:48->B8 $7E0008:50->C0 $7E0011:47->3E $7E0014:F3->F9 $7E0017:F3->F9 $7E0044:12->0C …(617 more) | $7E0004-$7EF887 |
| A3 | vram.bin | 938 | 0 | 938 | 65,536 | $2100C0:CF->2A $2100C1:D7->1A $2100C2:B7->88 $2100C3:8B->6C $2100C4:63->58 $2100C5:02->F0 …(932 more) | $2100C0-$21F0BA |
| A3 | oam.bin | 37 | 0 | 37 | 544 | $020004:78->86 $020005:67->7C $020006:24->26 $020007:20->30 $020008:78->74 $020009:77->67 …(31 more) | $020004-$02003B |
| A3 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A3 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A3 | fb.bgrx | 45,213 | 0 | 45,213 | 229,376 | $001C21:18->10 $001C22:21->10 $001C25:18->10 $001C26:21->10 $001C2D:18->10 $001C2E:21->10 …(45207 more) | $001C21-$02ADAA |
| A4 | wram.bin | 682 | 3 | 679 | 131,072 | $7E0004:D8->B8 $7E0005:88->8E $7E0008:E0->C0 $7E0009:88->8E $7E000E:27->21 $7E0011:47->3E …(673 more) | $7E0004-$7EF887 |
| A4 | vram.bin | 659 | 0 | 659 | 65,536 | $2100C0:CF->E6 $2100C1:D7->DD $2100C2:B7->49 $2100C3:8B->AF $2100C4:63->D1 $2100C5:02->3B …(653 more) | $2100C0-$21F0BA |
| A4 | oam.bin | 42 | 0 | 42 | 544 | $020004:7D->86 $020005:5B->7C $020006:2A->26 $020007:20->30 $020008:7A->74 $02000C:7A->74 …(36 more) | $020004-$02003B |
| A4 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A4 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A4 | fb.bgrx | 45,940 | 0 | 45,940 | 229,376 | $001C21:18->10 $001C22:21->10 $001C25:18->10 $001C26:21->10 $001C2D:18->10 $001C2E:21->10 …(45934 more) | $001C21-$02ADAA |
| A5 | wram.bin | 4,101 | 19 | 4,082 | 131,072 | $7E0000:01->4A $7E0001:08->00 $7E0002:01->00 $7E0004:D8->3E $7E0005:88->03 $7E0006:8C->40 …(4076 more) | $7E0000-$7EFF83 |
| A5 | vram.bin | 957 | 0 | 957 | 65,536 | $2100C0:CF->01 $2100C1:D7->00 $2100C2:B7->01 $2100C3:8B->00 $2100C4:63->01 $2100C5:02->00 …(951 more) | $2100C0-$21F67B |
| A5 | oam.bin | 427 | 0 | 427 | 544 | $020001:6D->F0 $020002:00->F0 $020003:30->F0 $020004:7D->F0 $020005:59->F0 $020006:2A->F0 …(421 more) | $020001-$02021F |
| A5 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| A5 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| A5 | fb.bgrx | 45,187 | 0 | 45,187 | 229,376 | $00181C:84->00 $00181D:84->00 $00181E:84->00 $001820:84->00 $001821:84->00 $001822:84->00 …(45181 more) | $00181C-$035FE2 |
| H8 | wram.bin | 10 | 9 | 1 | 131,072 | $7E0127:63->6A | $7E0127-$7E1D04 |
| H8 | vram.bin | 0 | 0 | 0 | 65,536 | identical | - |
| H8 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| H8 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| H8 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| H8 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J1 | wram.bin | 190 | 2 | 188 | 131,072 | $7E0002:04->02 $7E0004:28->10 $7E0005:87->93 $7E0008:30->18 $7E0009:87->93 $7E0082:0A->06 …(182 more) | $7E0002-$7E4219 |
| J1 | vram.bin | 497 | 0 | 497 | 65,536 | $210046:00->01 $210048:00->03 $21004A:00->0F $21004B:01->0C $21004C:03->02 $21004D:01->0F …(491 more) | $210046-$210B7F |
| J1 | oam.bin | 3 | 0 | 3 | 544 | $020026:48->4A $02002E:48->4A $020032:48->4A | $020026-$020032 |
| J1 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J1 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J1 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J10 | wram.bin | 317 | 2 | 315 | 131,072 | $7E011E:A8->04 $7E0120:A4->26 $7E0121:04->FF $7E027E:23->1C $7E0280:4B->C2 $7E0282:73->64 …(309 more) | $7E011E-$7E43C2 |
| J10 | vram.bin | 265 | 0 | 265 | 65,536 | $210840:FF->14 $210841:00->13 $210842:0F->00 $210843:F0->07 $210844:07->00 $210845:78->07 …(259 more) | $210840-$210B7F |
| J10 | oam.bin | 22 | 0 | 22 | 544 | $02000E:06->04 $020010:1D->75 $020012:02->22 $020014:1D->75 $020018:1D->75 $02001C:EF->75 …(16 more) | $02000E-$020033 |
| J10 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J10 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J10 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J2 | wram.bin | 233 | 5 | 228 | 131,072 | $7E000E:12->1B $7E0011:68->AD $7E0014:60->29 $7E0017:70->29 $7E001A:20->00 $7E001D:5C->04 …(222 more) | $7E000E-$7E4219 |
| J2 | vram.bin | 445 | 0 | 445 | 65,536 | $2104C0:00->01 $2104C6:01->00 $2104C8:03->00 $2104CA:0F->00 $2104CB:0C->00 $2104CC:02->08 …(439 more) | $2104C0-$210B7F |
| J2 | oam.bin | 30 | 0 | 30 | 544 | $020008:77->82 $020009:7D->AE $02000A:C7->28 $02000B:41->20 $02000C:68->82 $02000D:5F->BE …(24 more) | $020008-$020201 |
| J2 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J2 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J2 | fb.bgrx | 581 | 0 | 581 | 229,376 | $00A2B4:9C->4A $00A2B5:9C->4A $00A2B6:9C->4A $00A2B8:9C->4A $00A2B9:9C->4A $00A2BA:9C->4A …(575 more) | $00A2B4-$031619 |
| J3 | wram.bin | 284 | 5 | 279 | 131,072 | $7E0000:01->50 $7E0001:08->00 $7E0002:01->04 $7E000E:1E->21 $7E0082:06->0A $7E0084:24->28 …(273 more) | $7E0000-$7E4378 |
| J3 | vram.bin | 697 | 0 | 697 | 65,536 | $210040:00->01 $210041:00->01 $21004A:00->20 $21004C:02->58 $21004D:03->30 $21004E:07->1C …(691 more) | $210040-$210B7F |
| J3 | oam.bin | 36 | 0 | 36 | 544 | $020008:AF->C0 $020009:B1->C9 $02000A:28->18 $02000B:70->41 $02000C:AF->B2 $02000D:C1->B7 …(30 more) | $020008-$020200 |
| J3 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J3 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J3 | fb.bgrx | 1,942 | 0 | 1,942 | 229,376 | $023BC8:42->00 $023BC9:42->29 $023BCA:39->52 $023BD0:7B->00 $023BD1:7B->29 $023BD2:84->52 …(1936 more) | $023BC8-$033AFE |
| J4 | wram.bin | 173 | 2 | 171 | 131,072 | $7E0084:28->34 $7E00A5:98->A0 $7E0495:CD->07 $7E067E:E9->04 $7E067F:00->01 $7E06A1:E0->FB …(165 more) | $7E0084-$7E4219 |
| J4 | vram.bin | 650 | 0 | 650 | 65,536 | $210046:01->00 $210048:03->00 $210049:00->0C $21004A:0F->00 $21004C:02->04 $21004D:0F->04 …(644 more) | $210046-$210B7F |
| J4 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J4 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J4 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J4 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J5 | wram.bin | 508 | 2 | 506 | 131,072 | $7E000E:12->15 $7E0023:01->02 $7E0026:01->02 $7E0029:0C->20 $7E0038:02->04 $7E0074:23->CC …(500 more) | $7E000E-$7E4219 |
| J5 | vram.bin | 822 | 0 | 822 | 65,536 | $210180:00->7C $210181:00->7C $210182:00->70 $210183:00->70 $210184:00->40 $210185:00->40 …(816 more) | $210180-$210B7F |
| J5 | oam.bin | 30 | 0 | 30 | 544 | $02000C:9B->27 $02000D:65->5D $02000E:0A->02 $02000F:30->70 $020011:75->65 $020012:08->0A …(24 more) | $02000C-$020033 |
| J5 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J5 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J5 | fb.bgrx | 252 | 0 | 252 | 229,376 | $0174C4:AD->08 $0174C5:D6->10 $0174C6:CE->18 $0174C8:AD->08 $0174C9:D6->10 $0174CA:CE->18 …(246 more) | $0174C4-$01B0DA |
| J6 | wram.bin | 722 | 4 | 718 | 131,072 | $7E000E:12->1B $7E0011:68->64 $7E0014:22->24 $7E0017:22->24 $7E0023:01->02 $7E0029:0C->20 …(712 more) | $7E000E-$7EED04 |
| J6 | vram.bin | 1,271 | 0 | 1,271 | 65,536 | $210040:0C->08 $210041:0C->08 $210042:3C->14 $210043:3C->08 $210044:FC->14 $210045:FC->08 …(1265 more) | $210040-$21E0BF |
| J6 | oam.bin | 32 | 0 | 32 | 544 | $020004:26->2A $020005:9A->96 $020008:26->2A $020009:AA->A6 $02000C:71->77 $02000D:69->65 …(26 more) | $020004-$020033 |
| J6 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J6 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J6 | fb.bgrx | 77,594 | 0 | 77,594 | 229,376 | $001C20:7B->10 $001C21:8C->29 $001C22:94->39 $001C24:7B->39 $001C25:8C->52 $001C26:94->5A …(77588 more) | $001C20-$035ADE |
| J7 | wram.bin | 481 | 3 | 478 | 131,072 | $7E0084:14->18 $7E00A5:C4->0C $7E00A8:F0->00 $7E00A9:FD->00 $7E00AB:3C->F4 $7E00B7:4A->46 …(472 more) | $7E0084-$7E43C2 |
| J7 | vram.bin | 1,166 | 0 | 1,166 | 65,536 | $210040:00->08 $210041:00->08 $210051:00->18 $210060:40->00 $210061:40->00 $210071:60->00 …(1160 more) | $210040-$215349 |
| J7 | oam.bin | 0 | 0 | 0 | 544 | identical | - |
| J7 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J7 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J7 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J8 | wram.bin | 358 | 3 | 355 | 131,072 | $7E00AB:3C->F4 $7E00B7:4A->46 $7E00BA:10->9C $7E00BB:02->00 $7E00BD:C4->84 $7E00C0:F0->64 …(349 more) | $7E00AB-$7E43C2 |
| J8 | vram.bin | 265 | 0 | 265 | 65,536 | $210840:FF->14 $210841:00->13 $210842:0F->00 $210843:F0->07 $210844:07->00 $210845:78->07 …(259 more) | $210840-$210B7F |
| J8 | oam.bin | 22 | 0 | 22 | 544 | $02000E:06->04 $020010:1D->75 $020012:02->22 $020014:1D->75 $020018:1D->75 $02001C:EF->75 …(16 more) | $02000E-$020033 |
| J8 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J8 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J8 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| J9 | wram.bin | 330 | 3 | 327 | 131,072 | $7E0000:FF->E0 $7E0001:FF->F4 $7E0002:18->01 $7E011E:A8->04 $7E0120:A4->26 $7E0121:04->FF …(321 more) | $7E0000-$7E43C2 |
| J9 | vram.bin | 265 | 0 | 265 | 65,536 | $210840:FF->14 $210841:00->13 $210842:0F->00 $210843:F0->07 $210844:07->00 $210845:78->07 …(259 more) | $210840-$210B7F |
| J9 | oam.bin | 22 | 0 | 22 | 544 | $02000E:06->04 $020010:1D->75 $020012:02->22 $020014:1D->75 $020018:1D->75 $02001C:EF->75 …(16 more) | $02000E-$020033 |
| J9 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| J9 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| J9 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| K1 | wram.bin | 317 | 2 | 315 | 131,072 | $7E011E:A8->04 $7E0120:A4->26 $7E0121:04->FF $7E027E:23->1C $7E0280:4B->C2 $7E0282:73->64 …(309 more) | $7E011E-$7E43C2 |
| K1 | vram.bin | 265 | 0 | 265 | 65,536 | $210840:FF->14 $210841:00->13 $210842:0F->00 $210843:F0->07 $210844:07->00 $210845:78->07 …(259 more) | $210840-$210B7F |
| K1 | oam.bin | 22 | 0 | 22 | 544 | $02000E:06->04 $020010:1D->75 $020012:02->22 $020014:1D->75 $020018:1D->75 $02001C:EF->75 …(16 more) | $02000E-$020033 |
| K1 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| K1 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| K1 | fb.bgrx | 0 | 0 | 0 | 229,376 | identical | - |
| K2 | wram.bin | 502 | 3 | 499 | 131,072 | $7E000E:27->21 $7E0011:19->0D $7E0014:3E->44 $7E0017:3E->44 $7E0041:14->54 $7E0044:12->0C …(493 more) | $7E000E-$7EED10 |
| K2 | vram.bin | 824 | 0 | 824 | 65,536 | $2100C0:00->20 $2100C1:00->C0 $2100C2:00->C0 $2100E0:02->00 $2100E1:0C->00 $2100E2:0A->00 …(818 more) | $2100C0-$21F0BA |
| K2 | oam.bin | 36 | 0 | 36 | 544 | $020004:61->55 $020005:C1->C7 $020008:44->38 $020009:B2->B8 $02000C:54->48 $02000D:B2->B8 …(30 more) | $020004-$020033 |
| K2 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| K2 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| K2 | fb.bgrx | 46,680 | 0 | 46,680 | 229,376 | $003FB9:31->00 $003FBA:B5->00 $003FBD:31->00 $003FBE:B5->00 $0043B9:31->00 $0043BA:B5->00 …(46674 more) | $003FB9-$0359EE |
| K3 | wram.bin | 438 | 2 | 436 | 131,072 | $7E000E:24->21 $7E0011:19->0D $7E0014:3E->44 $7E0017:3E->44 $7E0041:14->54 $7E0044:12->0C …(430 more) | $7E000E-$7EED10 |
| K3 | vram.bin | 472 | 0 | 472 | 65,536 | $210540:00->70 $210541:00->70 $210542:70->F8 $210543:70->88 $210544:F8->38 $210545:88->28 …(466 more) | $210540-$21F0BA |
| K3 | oam.bin | 34 | 0 | 34 | 544 | $020004:61->55 $020005:C1->C7 $020008:44->38 $020009:B2->B8 $02000C:54->48 $02000D:B2->B8 …(28 more) | $020004-$02003B |
| K3 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| K3 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| K3 | fb.bgrx | 46,440 | 0 | 46,440 | 229,376 | $003FB5:31->00 $003FB6:B5->00 $0043B5:31->00 $0043B6:B5->00 $0043C4:18->00 $0043C5:18->00 …(46434 more) | $003FB5-$0359EE |
| L0 | wram.bin | 456 | 2 | 454 | 131,072 | $7E0011:35->2C $7E0041:F6->18 $7E0042:05->06 $7E004A:01->04 $7E0053:F6->16 $7E0054:05->06 …(448 more) | $7E0011-$7EF887 |
| L0 | vram.bin | 401 | 0 | 401 | 65,536 | $210540:00->70 $210541:00->70 $210542:00->F8 $210543:00->88 $210544:00->38 $210545:00->28 …(395 more) | $210540-$21F0BA |
| L0 | oam.bin | 43 | 0 | 43 | 544 | $020004:78->85 $020005:7B->6F $020006:24->2C $020007:20->E2 $020009:8B->75 $02000A:22->24 …(37 more) | $020004-$02003B |
| L0 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| L0 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| L0 | fb.bgrx | 43,675 | 0 | 43,675 | 229,376 | $001C24:00->08 $001C25:00->10 $001C26:00->10 $001C28:00->08 $001C29:00->10 $001C2A:00->10 …(43669 more) | $001C24-$029586 |
| L1 | wram.bin | 548 | 6 | 542 | 131,072 | $7E0004:70->00 $7E0005:E8->00 $7E0006:8C->01 $7E0008:78->34 $7E0009:E8->CF $7E000E:21->24 …(536 more) | $7E0004-$7EF887 |
| L1 | vram.bin | 407 | 0 | 407 | 65,536 | $210540:00->70 $210541:00->70 $210542:00->F8 $210543:00->88 $210544:00->38 $210545:00->28 …(401 more) | $210540-$21F0BA |
| L1 | oam.bin | 43 | 0 | 43 | 544 | $020004:74->7D $020005:7C->68 $020006:24->2C $020009:8C->76 $02000A:22->24 $02000C:86->74 …(37 more) | $020004-$02003B |
| L1 | cgram.bin | 0 | 0 | 0 | 512 | identical | - |
| L1 | sram.bin | 0 | 0 | 0 | 8,192 | identical | - |
| L1 | fb.bgrx | 44,549 | 0 | 44,549 | 229,376 | $001C20:08->00 $001C21:18->00 $001C22:21->00 $001C24:08->00 $001C25:10->00 $001C26:10->00 …(44543 more) | $001C20-$0295AA |

checkpoints with state (non-label) bytes differing, in route order: H8 f16188 (1), J1 f16865 (688), J2 f17196 (1,284), J3 f17317 (2,954), J4 f17438 (821), J5 f17559 (1,610), J6 f17680 (79,615), J7 f17801 (1,644)

==== does the split of a rejected seed survive phase alignment on the frame dumps?
# how:  tests/rejected_shift.sh -- tests/parity.sh on route tests/out/probe_dense.txt (control exe
#       build-r4base/ShadowrunSNESRecomp, seeded exe copied to tests/out/r4/anchor_<variant>/),
#       then tests/framedump_diff.py tick / shift / drift / state / byte on that
#       leg and its frame dumps; `tick` is what makes the f<->f coordinate honest, `state`
#       is what names the bytes on this route

---- s80ABBC
# shift probe: s80ABBC vs the control, on the probe route
#
# what: does aligning the two legs on the guest timeline remove the
# state difference, or does the difference survive alignment?
# how:  tests/parity.sh tests/out/probe_dense.txt (PORT_BIN=build-r4base/ShadowrunSNESRecomp, PORT_BIN2=tests/out/r4/anchor_s80ABBC/ShadowrunSNESRecomp), then
#       tests/framedump_diff.py tick / shift / drift / state / byte on tests/out/run1 run2
#       byte addresses probed: 0x126 0x127
#       both legs: exit: script quit after 4575 frames
#       exe run1=1341448773c19617 run2=05f8aefb69d18851

==== tick (guest tick offset timeline)
counters: run1=4333 run2=4333 shared=4333 range=0..4332
only in run1: 0  only in run2: 0
phase segments (run1 host frame - run2 host frame, same guest tick):
  k=+0  counters 0..4332  host f0..f4574  (4333 ticks)
steps: none -- phase is constant across the whole run

==== shift (same guest tick, host frames aligned, label bytes excluded)
sampled guest counters: 41 of 4333 shared
  counter      f1      f2  diff@k=0   best k   best diff  aligned at
        0       0       0         0       +0          0  host f0
      108     116     116         -      -12          0  host f104
      216     235     235         -      -12          0  host f223
      324     343     343         -      -12          0  host f331
      432     531     531         0       +0          0  host f531
      540     639     639         0       +0          0  host f639
      648     747     747         0       +0          0  host f747
      756     855     855         0       +0          0  host f855
      864     963     963         0       +0          0  host f963
      972    1071    1071         0       +0          0  host f1071
     1080    1179    1179         0       +0          0  host f1179
     1188    1287    1287         0       +0          0  host f1287
     1296    1429    1429         -       -1          0  host f1428
     1404    1537    1537         0       +0          0  host f1537
     1512    1754    1754         0       +0          0  host f1754
     1620    1862    1862         0       +0          0  host f1862
     1728    1970    1970         3       +0          3  host f1970
     1836    2078    2078         0       +0          0  host f2078
     1944    2186    2186         2       +0          2  host f2186
     2052    2294    2294         2       +0          2  host f2294
     2160    2402    2402         4       +0          4  host f2402
     2268    2510    2510         2       +0          2  host f2510
     2376    2618    2618         2       +0          2  host f2618
     2484    2726    2726         2       +0          2  host f2726
     2592    2834    2834         2       +0          2  host f2834
     2700    2942    2942         2       +0          2  host f2942
     2808    3050    3050         2       +0          2  host f3050
     2916    3158    3158         2       +0          2  host f3158
     3024    3266    3266         2       +0          2  host f3266
     3132    3374    3374         2       +0          2  host f3374
     3240    3482    3482         0       +0          0  host f3482
     3348    3590    3590         0       +0          0  host f3590
     3456    3698    3698         -      -10          0  host f3688
     3564    3806    3806         -      -10          0  host f3796
     3672    3914    3914         -      -10          0  host f3904
     3780    4022    4022         -      -10          0  host f4012
     3888    4130    4130         -      -10          0  host f4120
     3996    4238    4238         -      -10          0  host f4228
     4104    4346    4346         -      -10          0  host f4336
     4212    4454    4454         -      -10          0  host f4444
     4332    4574    4574         -      -10          0  host f4564
byte-identical after phase alignment: 28 of 41

==== drift (per-frame differing 1 KiB blocks, then the exact bytes at the onset)
frames compared: 4575   differing 1 KiB blocks per frame (WRAM is 128 KiB = 128 blocks)
   frames     mean   max
       0-499      0.00     0
     500-999      0.00     0
    1000-1499     0.00     0
    1500-1999     0.49     2
    2000-2499     1.88     2
    2500-2999     2.00     2
    3000-3499     1.79     2
    3500-3999     1.00     1
    4000-4499     1.00     1
    4500-4574     1.00     1

first frame over 3 differing blocks: never -- the two legs stay within label-block distance
worst frame: f1832 with 2 differing blocks

==== state (which non-label bytes differ at the same host frame, and their values)

  f1830: 1 state bytes differ (1 bytes including label bytes)
      $7E00126: 88 -> 85

  f1832: 12 state bytes differ (15 bytes including label bytes)
      $7E00000: FF -> 2C
      $7E00001: FF -> B5
      $7E00002: 18 -> 01
      $7E00004: 20 -> 15
      $7E00006: 03 -> 04
      $7E00134: 05 -> 88
      $7E00135: 75 -> 81
      $7E00136: 05 -> 10
      ... 4 more

  f1833: 12 state bytes differ (18 bytes including label bytes)
      $7E00000: FF -> D2
      $7E00001: FF -> AB
      $7E00002: 18 -> 01
      $7E00004: 20 -> 15
      $7E00006: 03 -> 04
      $7E00134: 04 -> 88
      $7E00135: 62 -> 81
      $7E00136: 05 -> 10
      ... 4 more

  f1834: 4 state bytes differ (10 bytes including label bytes)
      $7E00000: 67 -> B7
      $7E00001: 3C -> 38
      $7E00004: 20 -> 15
      $7E00006: 03 -> 04

  f1835: 10 state bytes differ (13 bytes including label bytes)
      $7E00000: BF -> FF
      $7E00001: 79 -> FF
      $7E00002: 01 -> 1C
      $7E00134: 88 -> 05
      $7E00135: 81 -> 75
      $7E00136: 10 -> 05
      $7E00137: B2 -> 81
      $7E00138: E3 -> C4
      ... 2 more

  f1836: 10 state bytes differ (14 bytes including label bytes)
      $7E00000: 19 -> FF
      $7E00001: 3B -> FF
      $7E00002: 01 -> 1A
      $7E00134: 88 -> 04
      $7E00135: 81 -> 62
      $7E00136: 10 -> 05
      $7E00137: B2 -> 81
      $7E00138: E3 -> C4
      ... 2 more

first frame with a state byte differing: f1830
frames with a state byte differing: 1409 of 4575   total state bytes: 3409

==== byte probes (the latch bytes the combat-route checkpoint diff names)
$7E00126  frames compared=4575 identical=4455 differing=120
  run1 values: 00x25  01x69  04x1030  07x5  13x280  25x5  27x2  40x1846  7Fx282  82x506  85x3  88x6  8Bx12  9Ex393  E8x111
  run2 values: 00x25  01x69  04x1030  07x5  13x280  25x5  27x2  40x1846  7Fx401  82x387  85x4  88x5  8Bx12  9Ex393  E8x111
  same value set in both legs
  count moved: 7F 282 -> 401  82 506 -> 387  85 3 -> 4  88 6 -> 5
  timeline (frame: run1/run2), runs where both legs hold steady:
    f0             00==
    f1..f4         07==
    f5..f194       04== identical
    f195           07==
    f196..f475     13== identical
    f476           01==
    f477..f1316    04== identical
    f1317..f1709   9E== identical
    f1710..f1718   E8== identical
    f1719..f1730   8B== identical
    f1731..f1754   00== identical
    f1755..f1756   27==
    f1757..f1761   25==
    f1762..f1829   01== identical
    f1830          88/85  DIFFERS
    f1831..f1954   82== identical
    f1955          88==
    f1956..f2074   82/7F  DIFFERS
    f2075..f2202   40== identical
    f2203          88==
    f2204..f2386   7F== identical
    f2387..f2388   85==
    f2389..f2448   82== identical
    f2449..f2634   40== identical
    f2635          88==
    f2636..f2694   82== identical
    f2695..f3103   40== identical
    f3104          85==
    f3105..f3247   82== identical
    f3248          88==
    f3249..f3347   7F== identical
    f3348..f3393   40== identical
    f3394          88==
    f3395          82==
    f3396..f3497   E8== identical
    f3498..f4574   40== identical

$7E00127  frames compared=4575 identical=4575 differing=0
  run1 values: 00x74  01x5  03x1  06x1  07x1847  08x1  0Ax3  0Cx1  1Ex4  24x1  25x2  40x5  45x1  6Cx840  78x1  7Ex10  80x393  9Ex111  A4x1  A8x1  ACx797  E8x475
  run2 values: 00x74  01x5  03x1  06x1  07x1847  08x1  0Ax3  0Cx1  1Ex4  24x1  25x2  40x5  45x1  6Cx840  78x1  7Ex10  80x393  9Ex111  A4x1  A8x1  ACx797  E8x475
  same value set in both legs
  timeline (frame: run1/run2), runs where both legs hold steady:
    f0             00==
    f1..f475       E8== identical
    f476           00==
    f477..f1316    6C== identical
    f1317..f1709   80== identical
    f1710..f1718   9E== identical
    f1719..f1728   7E== identical
    f1729..f1730   01==
    f1731          03==
    f1732          00==
    f1733          A8==
    f1734          45==
    f1735          40==
    f1736          00==
    f1737          40==
    f1738          00==
    f1739          07==
    f1740          06==
    f1741          08==
    f1742..f1744   40==
    f1745          00==
    f1746..f1747   01==
    f1748          0A==
    f1749          01==
    f1750          78==
    f1751..f1754   1E==
    f1755          0C==
    f1756          24==
    f1757          0A==
    f1758          A4==
    f1759          0A==
    f1760..f1761   25==
    f1762..f1829   00== identical
    f1830..f2074   AC== identical
    f2075..f2202   07== identical
    f2203..f2448   AC== identical
    f2449..f2634   07== identical
    f2635..f2694   AC== identical
    f2695..f3103   07== identical
    f3104..f3347   AC== identical
    f3348..f3393   07== identical
    f3394..f3395   AC==
    f3396..f3497   9E== identical
    f3498..f4574   07== identical


---- s80B1DB
# shift probe: s80B1DB vs the control, on the probe route
#
# what: does aligning the two legs on the guest timeline remove the
# state difference, or does the difference survive alignment?
# how:  tests/parity.sh tests/out/probe_dense.txt (PORT_BIN=build-r4base/ShadowrunSNESRecomp, PORT_BIN2=tests/out/r4/anchor_s80B1DB/ShadowrunSNESRecomp), then
#       tests/framedump_diff.py tick / shift / drift / state / byte on tests/out/run1 run2
#       byte addresses probed: 0x126 0x127
#       both legs: exit: script quit after 4575 frames
#       exe run1=1341448773c19617 run2=d1fb51a5274b3e8d

==== tick (guest tick offset timeline)
counters: run1=4333 run2=4333 shared=4333 range=0..4332
only in run1: 0  only in run2: 0
phase segments (run1 host frame - run2 host frame, same guest tick):
  k=+0  counters 0..4332  host f0..f4574  (4333 ticks)
steps: none -- phase is constant across the whole run

==== shift (same guest tick, host frames aligned, label bytes excluded)
sampled guest counters: 41 of 4333 shared
  counter      f1      f2  diff@k=0   best k   best diff  aligned at
        0       0       0         0       +0          0  host f0
      108     116     116         -      -12          0  host f104
      216     235     235         -      -12          0  host f223
      324     343     343         -      -12          0  host f331
      432     531     531         0       +0          0  host f531
      540     639     639         0       +0          0  host f639
      648     747     747         0       +0          0  host f747
      756     855     855         0       +0          0  host f855
      864     963     963         0       +0          0  host f963
      972    1071    1071         0       +0          0  host f1071
     1080    1179    1179         0       +0          0  host f1179
     1188    1287    1287         0       +0          0  host f1287
     1296    1429    1429         -       -1          0  host f1428
     1404    1537    1537         0       +0          0  host f1537
     1512    1754    1754         0       +0          0  host f1754
     1620    1862    1862         1       +0          1  host f1862
     1728    1970    1970        10       -5          8  host f1965
     1836    2078    2078         4       +0          4  host f2078
     1944    2186    2186         3       +0          3  host f2186
     2052    2294    2294         3       +0          3  host f2294
     2160    2402    2402         5       +0          5  host f2402
     2268    2510    2510         3       +0          3  host f2510
     2376    2618    2618         3       +0          3  host f2618
     2484    2726    2726         3       +0          3  host f2726
     2592    2834    2834         3       +0          3  host f2834
     2700    2942    2942         3       +0          3  host f2942
     2808    3050    3050         3       +0          3  host f3050
     2916    3158    3158         3       +0          3  host f3158
     3024    3266    3266         3       +0          3  host f3266
     3132    3374    3374         3       +0          3  host f3374
     3240    3482    3482         2       +0          2  host f3482
     3348    3590    3590         4       +0          4  host f3590
     3456    3698    3698         4      -10          4  host f3688
     3564    3806    3806         4      -10          4  host f3796
     3672    3914    3914         4      -10          4  host f3904
     3780    4022    4022         4      -10          4  host f4012
     3888    4130    4130         4      -10          4  host f4120
     3996    4238    4238         4      -10          4  host f4228
     4104    4346    4346         4      -10          4  host f4336
     4212    4454    4454         4      -10          4  host f4444
     4332    4574    4574         4      -10          4  host f4564
byte-identical after phase alignment: 15 of 41

==== drift (per-frame differing 1 KiB blocks, then the exact bytes at the onset)
frames compared: 4575   differing 1 KiB blocks per frame (WRAM is 128 KiB = 128 blocks)
   frames     mean   max
       0-499      0.00     0
     500-999      0.00     0
    1000-1499     0.00     0
    1500-1999     0.64     2
    2000-2499     1.85     3
    2500-2999     2.00     3
    3000-3499     2.00     3
    3500-3999     2.00     2
    4000-4499     2.00     2
    4500-4574     2.00     2

first frame over 3 differing blocks: never -- the two legs stay within label-block distance
worst frame: f2449 with 3 differing blocks

==== state (which non-label bytes differ at the same host frame, and their values)

  f1831: 1 state bytes differ (1 bytes including label bytes)
      $7E00126: 82 -> 7F

  f1832: 13 state bytes differ (16 bytes including label bytes)
      $7E00000: FF -> 2C
      $7E00001: FF -> 88
      $7E00002: 18 -> 01
      $7E00004: 20 -> 15
      $7E00006: 03 -> 04
      $7E00126: 82 -> 7F
      $7E00134: 05 -> 88
      $7E00135: 75 -> 81
      ... 5 more

  f1833: 13 state bytes differ (19 bytes including label bytes)
      $7E00000: FF -> 38
      $7E00001: FF -> 80
      $7E00002: 18 -> 01
      $7E00004: 20 -> 15
      $7E00006: 03 -> 04
      $7E00126: 82 -> 7F
      $7E00134: 04 -> 88
      $7E00135: 62 -> 81
      ... 5 more

  f1834: 5 state bytes differ (11 bytes including label bytes)
      $7E00000: 67 -> E0
      $7E00001: 3C -> 62
      $7E00004: 20 -> 15
      $7E00006: 03 -> 04
      $7E00126: 82 -> 7F

  f1835: 5 state bytes differ (9 bytes including label bytes)
      $7E00000: BF -> FF
      $7E00001: 79 -> E0
      $7E00004: 20 -> 15
      $7E00006: 03 -> 04
      $7E00126: 82 -> 7F

  f1836: 5 state bytes differ (9 bytes including label bytes)
      $7E00000: 19 -> 51
      $7E00001: 3B -> DA
      $7E00004: 20 -> 15
      $7E00006: 03 -> 04
      $7E00126: 82 -> 7F

first frame with a state byte differing: f1831
frames with a state byte differing: 2654 of 4575   total state bytes: 9625

==== byte probes (the latch bytes the combat-route checkpoint diff names)
$7E00126  frames compared=4575 identical=4451 differing=124
  run1 values: 00x25  01x69  04x1030  07x5  13x280  25x5  27x2  40x1846  7Fx282  82x506  85x3  88x6  8Bx12  9Ex393  E8x111
  run2 values: 00x25  01x69  04x1030  07x5  13x280  25x5  27x2  40x1846  7Fx406  82x382  85x3  88x6  8Bx12  9Ex393  E8x111
  same value set in both legs
  count moved: 7F 282 -> 406  82 506 -> 382
  timeline (frame: run1/run2), runs where both legs hold steady:
    f0             00==
    f1..f4         07==
    f5..f194       04== identical
    f195           07==
    f196..f475     13== identical
    f476           01==
    f477..f1316    04== identical
    f1317..f1709   9E== identical
    f1710..f1718   E8== identical
    f1719..f1730   8B== identical
    f1731..f1754   00== identical
    f1755..f1756   27==
    f1757..f1761   25==
    f1762..f1829   01== identical
    f1830          88==
    f1831..f1954   82/7F  DIFFERS
    f1955          88==
    f1956..f2074   82== identical
    f2075..f2202   40== identical
    f2203          88==
    f2204..f2386   7F== identical
    f2387..f2388   85==
    f2389..f2448   82== identical
    f2449..f2634   40== identical
    f2635          88==
    f2636..f2694   82== identical
    f2695..f3103   40== identical
    f3104          85==
    f3105..f3247   82== identical
    f3248          88==
    f3249..f3347   7F== identical
    f3348..f3393   40== identical
    f3394          88==
    f3395          82==
    f3396..f3497   E8== identical
    f3498..f4574   40== identical

$7E00127  frames compared=4575 identical=4575 differing=0
  run1 values: 00x74  01x5  03x1  06x1  07x1847  08x1  0Ax3  0Cx1  1Ex4  24x1  25x2  40x5  45x1  6Cx840  78x1  7Ex10  80x393  9Ex111  A4x1  A8x1  ACx797  E8x475
  run2 values: 00x74  01x5  03x1  06x1  07x1847  08x1  0Ax3  0Cx1  1Ex4  24x1  25x2  40x5  45x1  6Cx840  78x1  7Ex10  80x393  9Ex111  A4x1  A8x1  ACx797  E8x475
  same value set in both legs
  timeline (frame: run1/run2), runs where both legs hold steady:
    f0             00==
    f1..f475       E8== identical
    f476           00==
    f477..f1316    6C== identical
    f1317..f1709   80== identical
    f1710..f1718   9E== identical
    f1719..f1728   7E== identical
    f1729..f1730   01==
    f1731          03==
    f1732          00==
    f1733          A8==
    f1734          45==
    f1735          40==
    f1736          00==
    f1737          40==
    f1738          00==
    f1739          07==
    f1740          06==
    f1741          08==
    f1742..f1744   40==
    f1745          00==
    f1746..f1747   01==
    f1748          0A==
    f1749          01==
    f1750          78==
    f1751..f1754   1E==
    f1755          0C==
    f1756          24==
    f1757          0A==
    f1758          A4==
    f1759          0A==
    f1760..f1761   25==
    f1762..f1829   00== identical
    f1830..f2074   AC== identical
    f2075..f2202   07== identical
    f2203..f2448   AC== identical
    f2449..f2634   07== identical
    f2635..f2694   AC== identical
    f2695..f3103   07== identical
    f3104..f3347   AC== identical
    f3348..f3393   07== identical
    f3394..f3395   AC==
    f3396..f3497   9E== identical
    f3498..f4574   07== identical


---- r4clean
# shift probe: r4clean vs the control, on the probe route
#
# what: does aligning the two legs on the guest timeline remove the
# state difference, or does the difference survive alignment?
# how:  tests/parity.sh tests/out/probe_dense.txt (PORT_BIN=build-r4base/ShadowrunSNESRecomp, PORT_BIN2=tests/out/r4/anchor_r4clean/ShadowrunSNESRecomp), then
#       tests/framedump_diff.py tick / shift / drift / state / byte on tests/out/run1 run2
#       byte addresses probed: 0x126 0x127
#       both legs: exit: script quit after 4575 frames
#       exe run1=1341448773c19617 run2=3e1a68bd32e963cc

==== tick (guest tick offset timeline)
counters: run1=4333 run2=4333 shared=4333 range=0..4332
only in run1: 0  only in run2: 0
phase segments (run1 host frame - run2 host frame, same guest tick):
  k=+0  counters 0..4332  host f0..f4574  (4333 ticks)
steps: none -- phase is constant across the whole run

==== shift (same guest tick, host frames aligned, label bytes excluded)
sampled guest counters: 41 of 4333 shared
  counter      f1      f2  diff@k=0   best k   best diff  aligned at
        0       0       0         0       +0          0  host f0
      108     116     116         -      -12          0  host f104
      216     235     235         -      -12          0  host f223
      324     343     343         -      -12          0  host f331
      432     531     531         0       +0          0  host f531
      540     639     639         0       +0          0  host f639
      648     747     747         0       +0          0  host f747
      756     855     855         0       +0          0  host f855
      864     963     963         0       +0          0  host f963
      972    1071    1071         0       +0          0  host f1071
     1080    1179    1179         0       +0          0  host f1179
     1188    1287    1287         0       +0          0  host f1287
     1296    1429    1429         -       -1          0  host f1428
     1404    1537    1537         0       +0          0  host f1537
     1512    1754    1754         0       +0          0  host f1754
     1620    1862    1862         1       +0          1  host f1862
     1728    1970    1970        11      +10          9  host f1980
     1836    2078    2078         2       +0          2  host f2078
     1944    2186    2186         1       +0          1  host f2186
     2052    2294    2294         1       +0          1  host f2294
     2160    2402    2402         3       +0          3  host f2402
     2268    2510    2510         1       +0          1  host f2510
     2376    2618    2618         1       +0          1  host f2618
     2484    2726    2726         1       +0          1  host f2726
     2592    2834    2834         2       +0          2  host f2834
     2700    2942    2942         2       +0          2  host f2942
     2808    3050    3050         2       +0          2  host f3050
     2916    3158    3158         2       +0          2  host f3158
     3024    3266    3266         2       +0          2  host f3266
     3132    3374    3374         2       +0          2  host f3374
     3240    3482    3482         0       +0          0  host f3482
     3348    3590    3590         4       +0          4  host f3590
     3456    3698    3698         4      -10          4  host f3688
     3564    3806    3806         4      -10          4  host f3796
     3672    3914    3914         4      -10          4  host f3904
     3780    4022    4022         4      -10          4  host f4012
     3888    4130    4130         4      -10          4  host f4120
     3996    4238    4238         4      -10          4  host f4228
     4104    4346    4346         4      -10          4  host f4336
     4212    4454    4454         4      -10          4  host f4444
     4332    4574    4574         4      -10          4  host f4564
byte-identical after phase alignment: 16 of 41

==== drift (per-frame differing 1 KiB blocks, then the exact bytes at the onset)
frames compared: 4575   differing 1 KiB blocks per frame (WRAM is 128 KiB = 128 blocks)
   frames     mean   max
       0-499      0.00     0
     500-999      0.00     0
    1000-1499     0.00     0
    1500-1999     0.67     2
    2000-2499     2.00     3
    2500-2999     2.00     3
    3000-3499     1.81     3
    3500-3999     2.00     2
    4000-4499     2.00     2
    4500-4574     2.00     2

first frame over 3 differing blocks: never -- the two legs stay within label-block distance
worst frame: f2449 with 3 differing blocks

==== state (which non-label bytes differ at the same host frame, and their values)

  f1831: 1 state bytes differ (1 bytes including label bytes)
      $7E00126: 82 -> 7F

  f1832: 13 state bytes differ (16 bytes including label bytes)
      $7E00000: FF -> 2C
      $7E00001: FF -> 47
      $7E00002: 18 -> 01
      $7E00004: 20 -> 15
      $7E00006: 03 -> 04
      $7E00126: 82 -> 7F
      $7E00134: 05 -> 88
      $7E00135: 75 -> 81
      ... 5 more

  f1833: 13 state bytes differ (19 bytes including label bytes)
      $7E00000: FF -> 8A
      $7E00001: FF -> A4
      $7E00002: 18 -> 01
      $7E00004: 20 -> 15
      $7E00006: 03 -> 04
      $7E00126: 82 -> 7F
      $7E00134: 04 -> 88
      $7E00135: 62 -> 81
      ... 5 more

  f1834: 5 state bytes differ (11 bytes including label bytes)
      $7E00000: 67 -> 78
      $7E00001: 3C -> 6D
      $7E00004: 20 -> 15
      $7E00006: 03 -> 04
      $7E00126: 82 -> 7F

  f1835: 11 state bytes differ (14 bytes including label bytes)
      $7E00000: BF -> FF
      $7E00001: 79 -> FF
      $7E00002: 01 -> 1A
      $7E00126: 82 -> 7F
      $7E00134: 88 -> 05
      $7E00135: 81 -> 75
      $7E00136: 10 -> 05
      $7E00137: B2 -> 81
      ... 3 more

  f1836: 3 state bytes differ (8 bytes including label bytes)
      $7E00000: 19 -> E8
      $7E00001: 3B -> CE
      $7E00126: 82 -> 7F

first frame with a state byte differing: f1831
frames with a state byte differing: 2643 of 4575   total state bytes: 7435

==== byte probes (the latch bytes the combat-route checkpoint diff names)
$7E00126  frames compared=4575 identical=4329 differing=246
  run1 values: 00x25  01x69  04x1030  07x5  13x280  25x5  27x2  40x1846  7Fx282  82x506  85x3  88x6  8Bx12  9Ex393  E8x111
  run2 values: 00x25  01x69  04x1030  07x5  13x280  25x5  27x2  40x1846  7Fx525  82x263  88x9  8Bx12  9Ex393  E8x111
  NOT the same values -- run1 only 85 
  count moved: 7F 282 -> 525  82 506 -> 263  85 3 -> 0  88 6 -> 9
  timeline (frame: run1/run2), runs where both legs hold steady:
    f0             00==
    f1..f4         07==
    f5..f194       04== identical
    f195           07==
    f196..f475     13== identical
    f476           01==
    f477..f1316    04== identical
    f1317..f1709   9E== identical
    f1710..f1718   E8== identical
    f1719..f1730   8B== identical
    f1731..f1754   00== identical
    f1755..f1756   27==
    f1757..f1761   25==
    f1762..f1829   01== identical
    f1830          88==
    f1831..f1954   82/7F  DIFFERS
    f1955          88==
    f1956..f2074   82/7F  DIFFERS
    f2075..f2202   40== identical
    f2203          88==
    f2204..f2386   7F== identical
    f2387..f2388   85/88  DIFFERS
    f2389..f2448   82== identical
    f2449..f2634   40== identical
    f2635          88==
    f2636..f2694   82== identical
    f2695..f3103   40== identical
    f3104          85/88  DIFFERS
    f3105..f3247   82== identical
    f3248          88==
    f3249..f3347   7F== identical
    f3348..f3393   40== identical
    f3394          88==
    f3395          82==
    f3396..f3497   E8== identical
    f3498..f4574   40== identical

$7E00127  frames compared=4575 identical=4575 differing=0
  run1 values: 00x74  01x5  03x1  06x1  07x1847  08x1  0Ax3  0Cx1  1Ex4  24x1  25x2  40x5  45x1  6Cx840  78x1  7Ex10  80x393  9Ex111  A4x1  A8x1  ACx797  E8x475
  run2 values: 00x74  01x5  03x1  06x1  07x1847  08x1  0Ax3  0Cx1  1Ex4  24x1  25x2  40x5  45x1  6Cx840  78x1  7Ex10  80x393  9Ex111  A4x1  A8x1  ACx797  E8x475
  same value set in both legs
  timeline (frame: run1/run2), runs where both legs hold steady:
    f0             00==
    f1..f475       E8== identical
    f476           00==
    f477..f1316    6C== identical
    f1317..f1709   80== identical
    f1710..f1718   9E== identical
    f1719..f1728   7E== identical
    f1729..f1730   01==
    f1731          03==
    f1732          00==
    f1733          A8==
    f1734          45==
    f1735          40==
    f1736          00==
    f1737          40==
    f1738          00==
    f1739          07==
    f1740          06==
    f1741          08==
    f1742..f1744   40==
    f1745          00==
    f1746..f1747   01==
    f1748          0A==
    f1749          01==
    f1750          78==
    f1751..f1754   1E==
    f1755          0C==
    f1756          24==
    f1757          0A==
    f1758          A4==
    f1759          0A==
    f1760..f1761   25==
    f1762..f1829   00== identical
    f1830..f2074   AC== identical
    f2075..f2202   07== identical
    f2203..f2448   AC== identical
    f2449..f2634   07== identical
    f2635..f2694   AC== identical
    f2695..f3103   07== identical
    f3104..f3347   AC== identical
    f3348..f3393   07== identical
    f3394..f3395   AC==
    f3396..f3497   9E== identical
    f3498..f4574   07== identical

