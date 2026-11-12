#!/usr/bin/env python3
"""Diff two L3 machine snapshots (debug-server `save_state`) by section.

    l3sn_diff.py A.l3sn B.l3sn

The file is exactly `snes_saveload` order (runner/src/snes/snes.c); the only
in-stream landmark is the PPU's own 'PPU0' tag:

    head       8 B          'L3SN' + version
    Cpu        20 B         from cpu.a: a x y sp pc dp k db + 9 flag bytes
    Apu        ~?           apu->ram .. Apu.pad+6, then dsp_saveload, spc_saveload
    Dma        220 B        208 B channels + dmaTimer/dmaBusy/hdma fields
    Ppu        8 + 0x10460  'PPU0' + size, 0x40 regs, 0x10420 mem (cgram..oam)
    Cart       ramSize B    cart->ram: WRAM $7E0000-$7E1FFF, then VRAM
                            $7E2000-$7E3FFF for Shadowrun (192 KiB)
    Snes tail  ~?           hPos .. end of struct (timers, irq flags, hw-mode)

CPU regs and cart RAM are the sections that decide a state-vs-code question:
APU/DMA/PPU internals free-run and always differ between two legs that were
never in lockstep, so they are reported separately and discounted.
"""
import sys

HEAD = 8
PPU_LEN = 8 + 0x40 + 0x10420


def cpu_struct_size():
    """sizeof(struct Cpu) by the C ABI on this platform: 5*u16 + 8*u8
    (k, db, nine _Bool = 11 bytes of u8 after the u16 run), aligned to 2.
    Computed, not hard-coded, so the split cannot rot with the struct."""
    off = 2 * 5
    off += 2 * 1 + 9 * 1          # k, db, then the flag bytes
    return (off + 1) // 2 * 2


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    a, b = (open(p, "rb").read() for p in sys.argv[1:3])
    if len(a) != len(b):
        raise SystemExit(f"different sizes: {len(a)} vs {len(b)}")
    if a[:4] != b"NS3L":  # u32 LE 0x4c33534e = "L3SN"
        raise SystemExit("bad magic -- not an L3 snapshot")
    ppu = a.find(b"PPU0")
    if ppu < 0:
        raise SystemExit("no PPU0 tag -- not an L3 snapshot from this runner")
    n = cpu_struct_size()
    cart = ppu + PPU_LEN
    sec = [
        ("head", 0, HEAD),
        ("cpu", HEAD, HEAD + n),
        ("apu+dma", HEAD + n, ppu),
        ("ppu", ppu, cart),
        ("cart.wram", cart, min(cart + 0x20000, len(a))),
        ("cart.vram+", cart + 0x20000, len(a)),
    ]
    notes = {"cpu": "regs only -- THIS is where code-vs-state shows up",
             "apu+dma": "free-running -- drift expected, discount",
             "ppu": "incl. counters/raster -- drift expected, discount",
             "cart.wram": "WRAM -- decides game state",
             "cart.vram+": "VRAM mirror + snes timing tail"}
    print(f"{sys.argv[1]} vs {sys.argv[2]}   ({len(a)} bytes, "
          f"cpu struct {n} B, ppu tag @0x{ppu:X}, cart @0x{cart:X})")
    print(f"{'section':12s} {'bytes':>7s} {'differ':>7s}  note")
    total = 0
    for name, lo, hi in sec:
        hi = min(hi, len(a))
        if hi <= lo:
            continue
        d = sum(1 for i in range(lo, hi) if a[i] != b[i])
        total += d
        print(f"{name:12s} {hi-lo:7d} {d:7d}  {notes.get(name, '')}")
    print(f"{'TOTAL':12s} {len(a):7d} {total:7d}")


if __name__ == "__main__":
    main()
