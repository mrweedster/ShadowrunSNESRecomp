#!/usr/bin/env python3
"""Find WRAM bytes that step once when Shadowrun changes screens.

Reads the per-frame WRAM dumps the host writes with --framedump and reports
offsets whose value changes at most a handful of times across the whole run,
i.e. screen/state latches rather than animation or timers. Those are the bytes
a script can `until` on to make a run self-verifying.
"""
import os
import sys

d = sys.argv[1] if len(sys.argv) > 1 else "/tmp/srfd_lle1"
lo = int(sys.argv[2]) if len(sys.argv) > 2 else 0
hi = int(sys.argv[3]) if len(sys.argv) > 3 else 10 ** 9
W = 8  # compare 8 bytes at a time; a plain Python byte loop over 1200 frames is too slow

frames = sorted(
    int(e[6:12])
    for e in os.listdir(d)
    if e.startswith("frame_") and e.endswith("_wram.bin")
)
frames = [f for f in frames if lo <= f <= hi]
if len(frames) < 2:
    raise SystemExit(f"only {len(frames)} frames in {d}")


def words(path):
    with open(path, "rb") as fh:
        raw = fh.read()
    return [int.from_bytes(raw[i : i + W], "little") for i in range(0, len(raw), W)]


prev = None
changes = {}
for f in frames:
    cur = words(os.path.join(d, f"frame_{f:06d}_wram.bin"))
    if prev is not None:
        for wi, (a, b) in enumerate(zip(prev, cur)):
            if a == b:
                continue
            for k in range(W):
                if (a >> (8 * k)) & 0xFF != (b >> (8 * k)) & 0xFF:
                    off = wi * W + k
                    changes[off] = changes.get(off, 0) + 1
    prev = cur

# A latch: changes 1..4 times over the run. Anything that changes constantly is
# animation, scroll or a frame timer.
latches = [(n, off) for off, n in changes.items() if 1 <= n <= 4]
latches.sort(key=lambda t: (t[0], t[1]))
print(f"{len(frames)} frames scanned ({frames[0]}..{frames[-1]})")
print(f"{len(latches)} offsets changed at most 4 times:")


def seq_at(off, frames):
    out = []
    last = None
    for f in frames:
        with open(os.path.join(d, f"frame_{f:06d}_wram.bin"), "rb") as fh:
            fh.seek(off)
            v = fh.read(1)[0]
        if v != last:
            out.append(f"={v:02X}@{f}")
            last = v
    return out


for n, off in latches[:45]:
    print(f"  $7E{off:04X} changes={n}  " + "".join(seq_at(off, frames)[:8]))
