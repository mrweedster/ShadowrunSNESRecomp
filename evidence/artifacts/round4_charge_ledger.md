# round4_charge_ledger.md
#
# what: the cycle ledger: one route, several trees, every host switch pinned per leg, so the counters subtract
# how:  tests/charge_report.py tests/out/charge base_nf <legs>, over the legs listed in tests/out/r4/charge_ledger_run.log; each leg's switches come from its own <leg>.flags.tsv.  tests/aot_charge.sh writes its legs and flags into tests/out/charge, not into tests/out/r4
#
# framework pin: 773285b8210f2254ae87d0a14113980fb36990ad
# generated: 2026-11-08T08:02:38Z (host Darwin arm64)
# source tree: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp

legs: the 11 legs of $out/charge_ledger_run.log, joined against base_nf

# cycle ledger (tests/out/charge)

Route: tests/scripts/combat.txt.  Control leg: base_nf.

## what each leg was

| leg | binary | exe sha256 | floor | capture | policy (from) | capture program |
|---|---|---|---|---|---|---|
| self_a | build-r4base/ShadowrunSNESRecomp | `1341448773c19617` | nofloor | off |  | `` |
| self_b | build-r4base/ShadowrunSNESRecomp | `1341448773c19617` | nofloor | off |  | `` |
| base_nf | build-r4base/ShadowrunSNESRecomp | `1341448773c19617` | nofloor | off |  | `` |
| base_fl | build-r4base/ShadowrunSNESRecomp | `1341448773c19617` | floor | off |  | `` |
| pair_nf | build-r4pair/ShadowrunSNESRecomp | `2b478e8d26bb27f9` | nofloor | off |  | `` |
| c399_nf | build-s80C399/ShadowrunSNESRecomp | `e841e036e49064de` | nofloor | off |  | `` |
| aab3_nf | build-s80AAB3/ShadowrunSNESRecomp | `df29756f8367716a` | nofloor | off |  | `` |
| abbc_nf | build-s80ABBC/ShadowrunSNESRecomp | `05f8aefb69d18851` | nofloor | off |  | `` |
| b1db_nf | build-s80B1DB/ShadowrunSNESRecomp | `d1fb51a5274b3e8d` | nofloor | off |  | `` |
| pair_fl | build-r4pair/ShadowrunSNESRecomp | `2b478e8d26bb27f9` | floor | off |  | `` |
| b1db_fl | build-s80B1DB/ShadowrunSNESRecomp | `d1fb51a5274b3e8d` | floor | off |  | `` |

## counters

| leg | route end | frames | aot % | interp insns | interp cycles | cpu cycles | master cycles | abandons |
|---|---|---|---|---|---|---|---|---|
| self_a | exit: script quit after 22044 frames | 22044 | 3.8479 | 226,953,466 | 919,307,323 | 956,096,571 | 7,878,127,092 | 0 |
| self_b | exit: script quit after 22044 frames | 22044 | 3.8479 | 226,953,466 | 919,307,323 | 956,096,571 | 7,878,127,092 | 0 |
| base_nf | exit: script quit after 22044 frames | 22044 | 3.8479 | 226,953,466 | 919,307,323 | 956,096,571 | 7,878,127,092 | 0 |
| base_fl | exit: script quit after 22044 frames | 22044 | 3.8479 | 226,953,466 | 919,307,323 | 956,096,571 | 7,878,127,092 | 0 |
| pair_nf | exit: script quit after 22044 frames | 22044 | 9.9631 | 212,826,534 | 860,839,515 | 956,096,571 | 7,878,127,092 | 0 |
| c399_nf | exit: script quit after 22044 frames | 22044 | 5.882 | 221,710,489 | 899,859,432 | 956,096,571 | 7,878,127,092 | 0 |
| aab3_nf | exit: script quit after 22044 frames | 22044 | 7.929 | 218,069,511 | 880,287,406 | 956,096,571 | 7,878,127,092 | 0 |
| abbc_nf | exit: script quit after 22044 frames | 22044 | 5.4765 | 223,269,833 | 903,700,726 | 956,058,833 | 7,878,127,128 | 0 |
| b1db_nf | exit: script quit after 22044 frames | 22044 | 26.4694 | 166,292,287 | 701,658,067 | 954,239,118 | 7,878,127,130 | 0 |
| pair_fl | exit: script quit after 22044 frames | 22044 | 9.9631 | 212,826,534 | 860,839,515 | 956,096,571 | 7,878,127,092 | 0 |
| b1db_fl | exit: script quit after 22044 frames | 22044 | 26.4694 | 166,292,287 | 701,658,067 | 954,239,118 | 7,878,127,130 | 0 |

## deltas against base_nf

| leg | d interp insns | d interp cycles | d cpu cycles | d master cycles |
|---|---|---|---|---|
| self_a | +0 | +0 | +0 | +0 |
| self_b | +0 | +0 | +0 | +0 |
| base_nf | +0 | +0 | +0 | +0 |
| base_fl | +0 | +0 | +0 | +0 |
| pair_nf | -14,126,932 | -58,467,808 | +0 | +0 |
| c399_nf | -5,242,977 | -19,447,891 | +0 | +0 |
| aab3_nf | -8,883,955 | -39,019,917 | +0 | +0 |
| abbc_nf | -3,683,633 | -15,606,597 | -37,738 | +36 |
| b1db_nf | -60,661,179 | -217,649,256 | -1,857,453 | +38 |
| pair_fl | -14,126,932 | -58,467,808 | +0 | +0 |
| b1db_fl | -60,661,179 | -217,649,256 | -1,857,453 | +38 |

The interp-cycles delta is work that stopped being interpreted. The
cpu/master deltas are what it cost or saved overall: a conversion is real
only if the interp delta is large and the cpu/master delta is not.

==== leg headers, exits and counters, as tests/aot_charge.sh printed them
  == leg self_a  build-r4base/ShadowrunSNESRecomp  floor=nofloor capture=off dump=1
     exit=0 wall=30s  exit: script quit after 22044 frames
     frames=22044 abandons=0 interp  96.15%  aot   3.85%  interp_insns 226,953,466  interp_cycles 919,307,323  cpu_cycles 956,096,571  master_cycles 7,878,127,092
  == leg self_b  build-r4base/ShadowrunSNESRecomp  floor=nofloor capture=off dump=1
     exit=0 wall=31s  exit: script quit after 22044 frames
     frames=22044 abandons=0 interp  96.15%  aot   3.85%  interp_insns 226,953,466  interp_cycles 919,307,323  cpu_cycles 956,096,571  master_cycles 7,878,127,092
  == leg base_nf  build-r4base/ShadowrunSNESRecomp  floor=nofloor capture=off dump=0
     exit=0 wall=31s  exit: script quit after 22044 frames
     frames=22044 abandons=0 interp  96.15%  aot   3.85%  interp_insns 226,953,466  interp_cycles 919,307,323  cpu_cycles 956,096,571  master_cycles 7,878,127,092
  == leg base_fl  build-r4base/ShadowrunSNESRecomp  floor=floor capture=off dump=0
     exit=0 wall=31s  exit: script quit after 22044 frames
     frames=22044 abandons=0 interp  96.15%  aot   3.85%  interp_insns 226,953,466  interp_cycles 919,307,323  cpu_cycles 956,096,571  master_cycles 7,878,127,092
  == leg pair_nf  build-r4pair/ShadowrunSNESRecomp  floor=nofloor capture=off dump=1
     exit=0 wall=30s  exit: script quit after 22044 frames
     frames=22044 abandons=0 interp  90.04%  aot   9.96%  interp_insns 212,826,534  interp_cycles 860,839,515  cpu_cycles 956,096,571  master_cycles 7,878,127,092
  == leg c399_nf  build-s80C399/ShadowrunSNESRecomp  floor=nofloor capture=off dump=0
     exit=0 wall=31s  exit: script quit after 22044 frames
     frames=22044 abandons=0 interp  94.12%  aot   5.88%  interp_insns 221,710,489  interp_cycles 899,859,432  cpu_cycles 956,096,571  master_cycles 7,878,127,092
  == leg aab3_nf  build-s80AAB3/ShadowrunSNESRecomp  floor=nofloor capture=off dump=0
     exit=0 wall=31s  exit: script quit after 22044 frames
     frames=22044 abandons=0 interp  92.07%  aot   7.93%  interp_insns 218,069,511  interp_cycles 880,287,406  cpu_cycles 956,096,571  master_cycles 7,878,127,092
  == leg abbc_nf  build-s80ABBC/ShadowrunSNESRecomp  floor=nofloor capture=off dump=1
     exit=0 wall=32s  exit: script quit after 22044 frames
     frames=22044 abandons=0 interp  94.52%  aot   5.48%  interp_insns 223,269,833  interp_cycles 903,700,726  cpu_cycles 956,058,833  master_cycles 7,878,127,128
  == leg b1db_nf  build-s80B1DB/ShadowrunSNESRecomp  floor=nofloor capture=off dump=1
     exit=0 wall=25s  exit: script quit after 22044 frames
     frames=22044 abandons=0 interp  73.53%  aot  26.47%  interp_insns 166,292,287  interp_cycles 701,658,067  cpu_cycles 954,239,118  master_cycles 7,878,127,130
  == leg pair_fl  build-r4pair/ShadowrunSNESRecomp  floor=floor capture=off dump=0
     exit=0 wall=30s  exit: script quit after 22044 frames
     frames=22044 abandons=0 interp  90.04%  aot   9.96%  interp_insns 212,826,534  interp_cycles 860,839,515  cpu_cycles 956,096,571  master_cycles 7,878,127,092
  == leg b1db_fl  build-s80B1DB/ShadowrunSNESRecomp  floor=floor capture=off dump=0
     exit=0 wall=25s  exit: script quit after 22044 frames
     frames=22044 abandons=0 interp  73.53%  aot  26.47%  interp_insns 166,292,287  interp_cycles 701,658,067  cpu_cycles 954,239,118  master_cycles 7,878,127,130
