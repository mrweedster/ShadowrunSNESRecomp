#!/usr/bin/env python3
"""Linear 65816 disassembly of a ROM span, using the pinned framework's decoder.

usage: disasm_span.py <pc24-hex> <count> [m] [x] [rom]

The pin owns the opcode table (recompiler/snes65816.py), so this prints the
same decode the analyzer saw. Set SNESRECOMP_ROOT to the pinned checkout.
Linear decode: it does not follow branches, and mode-changing instructions
are not tracked, so keep spans short and state m/x for the entry.
"""
import os
import re
import sys

PIN = os.environ.get("SNESRECOMP_ROOT")
if not PIN:
    sys.exit("SNESRECOMP_ROOT must point at the pinned framework checkout")
sys.path.insert(0, os.path.join(PIN, "recompiler"))
from snes65816 import decode_insn, lorom_offset, MODE_STR  # noqa: E402


def render(insn):
    """Text for one decoded instruction. Operand widths are shown at 16 bits:
    the bytes and lengths in the left column are what settle M/X widths."""
    sfx = MODE_STR.get(insn.mode, "?")
    if sfx == "imp":
        return insn.mnem
    if sfx == "acc":
        return insn.mnem + " A"
    if sfx == "imm":
        return "%s #$%04X" % (insn.mnem, insn.operand)
    if sfx in ("rel", "rel16"):
        return "%s $%04X" % (insn.mnem, insn.operand)
    body = re.sub(r"(abs|dp|long|stk)", "%04X" % insn.operand, sfx)
    return "%s %s" % (insn.mnem, body)


rom_path = sys.argv[5] if len(sys.argv) > 5 else "Shadowrun (USA).sfc"
rom = open(rom_path, "rb").read()
# rom_identity.txt says this is a plain headerless LoROM image.
base = 0

pc = int(sys.argv[1], 16)
n = int(sys.argv[2])
m = int(sys.argv[3]) if len(sys.argv) > 3 else 0
x = int(sys.argv[4]) if len(sys.argv) > 4 else 0
bank = pc >> 16
for _ in range(n):
    file_off = base + lorom_offset(bank, pc & 0xFFFF)
    insn = decode_insn(rom, file_off, pc & 0xFFFF, bank, m, x)
    if insn is None:
        print("$%06X  (undecodable)" % pc)
        break
    raw = "".join("%02X" % b for b in rom[file_off:file_off + insn.length])
    print("$%06X  %-14s %s" % (pc, raw, render(insn)))
    pc += insn.length
