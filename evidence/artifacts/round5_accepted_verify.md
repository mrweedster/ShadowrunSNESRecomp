# round5_accepted_verify.md
#
# what: the shipped tree measured again end to end: generated-set and exe identity, route counters, per-checkpoint state against the control, parity, and a capture of the program that shipped
# how:  cat of tests/out/r4/accepted/accepted_verify.log, the redirect of tests/accepted_verify.sh with PAIR=r5pair BUILD=build-r5pair CONTROL=r5base; its legs run from a scratch anchor under tests/out/r4/accepted/, never in a build dir, so no last_run_report.json used above is overwritten
#
# framework pin: 773285b8210f2254ae87d0a14113980fb36990ad
# generated: 2026-11-08T09:29:56Z (host Darwin arm64)
# source tree: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp

== accepted tree identity (live src/gen vs the shipped exe)
  exe      a0587ed0a0e34687
  manifest aa4a6f28a00afdb2
  accepted_tree: # accepted tree: r5pair
  accepted_tree: 
  accepted_tree: checkout      /Users/wee/Documents/work/ports/ShadowrunSNESRecomp
  accepted_tree: pin           /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-pin
  accepted_tree: archives      /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/r4/gen_r5pair.tar.gz  /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/r4/manifest_r5pair.json.bz2
  accepted_tree: 
  accepted_tree: == framework pin as committed ==
  accepted_tree: snesrecomp=773285b8210f2254ae87d0a14113980fb36990ad
  accepted_tree: 
  accepted_tree: == src/gen vs the variant's archived generated set ==
  accepted_tree:    IDENTICAL: src/gen matches gen_r5pair.tar.gz (20 files)
  accepted_tree: 
  accepted_tree: == program manifest ==
  accepted_tree:    archived  283 nodes (240 aot_eligible, 43 lle_only), 49 roots
  accepted_tree:    live       283 nodes (240 aot_eligible, 43 lle_only), 49 roots
  accepted_tree:    manifest sha256  archived aa4a6f28a00afdb2  live aa4a6f28a00afdb2  MATCH
  accepted_tree: 
  accepted_tree: == the seed block in recomp/symbols.toml, re-derived ==
  accepted_tree:    1 generated block(s), seeds: $80C399 $80AAB3
  accepted_tree:    baseline: 1 generated block(s) removed, 40 [[func]] entries left
  accepted_tree:    re-derived with: tests/gap_seeds.py tier2_capture_round3_combat.json --route combat --round 4 --only '$80C399,$80AAB3' --symbols /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/r4/cfg/live_base.toml --manifest round4_manifest_pre.json.bz2
  accepted_tree:    5cbd4e2c1fc12f99 /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/r4/cfg/shipped_gap_block.toml
  accepted_tree:    ababdc985d11b973 /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/r4/cfg/regen_gap_block.toml
  accepted_tree:    block sha256  shipped 5cbd4e2c1fc12f99  re-derived 5cbd4e2c1fc12f99  MATCH  (45 lines)
  accepted_tree:    the only difference is the blank line gap_seeds.py puts first so that `>>`
  accepted_tree:    appends the block cleanly after the baseline table
  accepted_tree:    baseline entries: 40 (shipped table: 42)
  accepted_tree: 
  accepted_tree: == build tree identity (build-r5pair) ==
  accepted_tree:    manifest: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/r4/r5pair/run_manifest.json
  accepted_tree:      exe    sha256 a0587ed0a0e34687  3,103,776 B
  accepted_tree:      tree   /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/build-r5pair  config=Release embed=OFF gen_objects=18
  accepted_tree:      gen    18 units, 215 promoted functions, 263 dispatch entries, sha256 3f22138eb5d1b401
  accepted_tree:      fw     /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-pin  rev=773285b8210f2254ae87d0a14113980fb36990ad dirty=False
  accepted_tree:    gen_sha256=3f22138eb5d1  gen_units=18  gen_functions=215  gen_dispatch=263  framework=773285b8210f  config=Release  embed_rom=OFF  exe_sha256=a0587ed0a0e3
  accepted_tree: 
  accepted_tree: ACCEPTED TREE OK: src/gen, manifest and the seed block all match the r5pair variant
  accepted_tree exit=0 (0 = the checked-out tree is the accepted variant)
  anchor     /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/r4/accepted/anchor_r5pair  exe a0587ed0a0e34687

== 1. short scripted leg: no capture, and no ROM file-picker
   exit=0 wall=1s  exit: script quit after 60 frames

== 2. combat route on the accepted tree (22 tagged checkpoints)
   exit=0 wall=30s  exit: script quit after 22044 frames
   checkpoints: 264 files, 22 tagged
   provenance: gen_sha256=3f22138eb5d1  gen_units=18  gen_functions=215  gen_dispatch=263  framework=773285b8210f  config=Release  embed_rom=OFF  exe_sha256=a0587ed0a0e3
   interp  90.04%  aot   9.96%  interp_insns 212,826,534  interp_cycles 860,839,515  cpu_cycles 956,096,571  master_cycles 7,878,127,092  frame 22,044

== 3. checkpoint state gate: accepted tree vs the round-4 control run
  # checkpoint-state matrix
  
  Control run: `tests/out/r4/r5base`.  Each cell is one tagged checkpoint, comparing the
  state images both runs took at that frame (`tests/framedump_diff.py cpdump`):
  24 regs.json keys, wram/vram/oam/cgram/sram images, the host framebuffer,
  and the apu/ppuw/dma traces.
  
  | checkpoint | control frame | /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/r4/accepted/r5pair_accepted |
  |---|---|---|
  | H8 | 16188 | apu-only |
  | J1 | 16865 | apu-only |
  | J2 | 17196 | apu-only |
  | J3 | 17317 | apu-only |
  | J4 | 17438 | apu-only |
  | J5 | 17559 | apu-only |
  | J6 | 17680 | apu-only |
  | J7 | 17801 | apu-only |
  | J8 | 17951 | apu-only |
  | J9 | 18101 | apu-only |
  | J10 | 18401 | apu-only |
  | K1 | 18552 | apu-only |
  | K2 | 18703 | apu-only |
  | K3 | 19003 | apu-only |
  | L0 | 19454 | apu-only |
  | L1 | 19761 | apu-only |
  | A0 | 20730 | apu-only |
  | A1 | 20844 | apu-only |
  | A2 | 21144 | apu-only |
  | A3 | 21444 | apu-only |
  | A4 | 21744 | apu-only |
  | A5 | 22044 | apu-only |
  
  The master-clock delta is the variant's clock at that checkpoint minus
  the control's; a seeded body runs the same guest instructions, so a
  state-clean tree shows +0 there.
  
  | variant | checkpoints | clean | apu-only | guest-state differing | regs keys differed | master-clock delta at first/last checkpoint |
  |---|---|---|---|---|---|---|
  | /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/r4/accepted/r5pair_accepted | 22 | 0 | 22 | none | 0 | H8 +0 / A5 +0 |

== 4. parity leg on the probe route: accepted exe vs control exe
   rc=0
          [host +7.966s] exit: script quit after 4575 frames
          [host +7.695s] exit: script quit after 4575 frames
            exe    sha256 79a45fc23cc7f7f9  2,936,800 B
            exe    sha256 a0587ed0a0e34687  3,103,776 B
   identical over 4575 frames

== 5. capture the accepted program's interpreted residue
   exit=0 wall=31s  exit: script quit after 22044 frames
   ingest rc=0   3447609 B  sha 3b619f1d2297a082
   capture identity: program_digest aa4a6f28a00afdb2  build_digest a0587ed0a0e34687  generation_digest bb92a258ee6698fa
   capture totals:   212,826,534 insns / 860,839,515 guest cycles  hot_pcs 8765  discoveries 267

== 6. residue and ranking on the accepted program
   attributed interpreted guest cycles: 860,839,515
   seedable (hot AND sighted):  24,086,298 = 2.80% over 219 (pc,mx) entries
   never sighted at a site:     836,753,217 = 97.20%  <- entry-shape residue
   
   rank pc       mx   site kind hits      cyc        gate status
     1  $80C1C9  M0X0 call  hits=366165     2,196,990  candidate_requires_analysis_and_replay  sites=$80C1B8
     2  $80C1B3  M0X0 call  hits=19305      1,927,350  candidate_requires_analysis_and_replay  sites=$809643
     3  $80F495  M0X0 goto  hits=222972     1,783,776  landing_requires_function_boundary  sites=$80F35A
     4  $80F362  M0X0 goto  hits=188694     1,509,550  landing_requires_function_boundary  sites=$80F35A
     5  $80F4F9  M0X0 call  hits=222972     1,114,860  candidate_requires_analysis_and_replay  sites=$80F4D0
     6  $80ABBC  M0X0 call  hits=247244       988,976  candidate_requires_analysis_and_replay  sites=$80AF81
     7  $80B1DB  M0X0 call  hits=191569       957,845  candidate_requires_analysis_and_replay  sites=$80B8E1
     8  $80F889  M0X0 goto  hits=152670       763,350  landing_requires_function_boundary  sites=$80F35A
     9  $80F37B  M0X0 goto  hits=86461        691,687  landing_requires_function_boundary  sites=$80F35A
    10  $80F6DF  M0X0 goto  hits=135728       678,640  landing_requires_function_boundary  sites=$80F35A
    11  $80F3EA  M0X0 goto  hits=135662       678,310  landing_requires_function_boundary  sites=$80F35A
    12  $80B101  M0X0 call  hits=214381       610,922  candidate_requires_analysis_and_replay  sites=$80B457,$80B46D,$80B47B
    13  $80C3D1  M0X0 goto  hits=92872        464,360  landing_requires_function_boundary  sites=$80F4F9
    14  $80B032  M0X0 call  hits=105303       421,212  candidate_requires_analysis_and_replay  sites=$80AFB6,$80B008
    15  $80AA97  M0X0 call  hits=209289       418,578  candidate_requires_analysis_and_replay  sites=$80B20E,$80B8C1
    16  $80F895  M0X0 goto  hits=75996        379,979  landing_requires_function_boundary  sites=$80F35A
    17  $80803B  M0X0 call  hits=18668        376,425  candidate_requires_analysis_and_replay  sites=$808029
    18  $81846E  M0X0 call  hits=86350        345,400  candidate_requires_analysis_and_replay  sites=$818840
    19  $80B07A  M0X0 call  hits=166857       333,714  candidate_requires_analysis_and_replay  sites=$80AFBB,$80B00D
    20  $80F3BA  M0X0 goto  hits=66310        331,550  landing_requires_function_boundary  sites=$80F35A
    21  $80CA0A  M0X0 goto  hits=73700        294,800  landing_requires_function_boundary  sites=$80F4F9
    22  $80B095  M0X0 goto  hits=67142        268,568  landing_requires_function_boundary  sites=$80B07C
    23  $80F885  M0X0 goto  hits=49939        249,695  landing_requires_function_boundary  sites=$80F35A
    24  $809D8E  M0X0 call  hits=21403        243,380  candidate_requires_analysis_and_replay  sites=$80C149,$80F25D
    25  $80B0A0  M0X0 goto  hits=60343        241,372  landing_requires_function_boundary  sites=$80B07C
    26  $80B05D  M0X0 goto  hits=49963        199,852  landing_requires_function_boundary  sites=$80B039
    27  $80F6F7  M0X0 goto  hits=35436        177,180  landing_requires_function_boundary  sites=$80F35A
    28  $81A910  M0X0 call  hits=19304        154,432  candidate_requires_analysis_and_replay  sites=$809087,$80AD95,$80BA86
    29  $80AF51  M0X0 call  hits=19301        154,408  candidate_requires_analysis_and_replay  sites=$809653
    30  $80B07F  M0X0 goto  hits=37478        149,912  landing_requires_function_boundary  sites=$80B07C
    31  $80F3A1  M0X0 goto  hits=18534        148,272  landing_requires_function_boundary  sites=$80F35A
    32  $80F390  M0X0 goto  hits=18211        145,687  landing_requires_function_boundary  sites=$80F35A
    33  $80F3D2  M0X0 goto  hits=17922        143,376  landing_requires_function_boundary  sites=$80F35A
    34  $80B8AF  M0X0 call  hits=19302        115,812  candidate_requires_analysis_and_replay  sites=$8092B9,$809661
    35  $80B047  M0X0 goto  hits=28166        112,664  landing_requires_function_boundary  sites=$80B039
    36  $818949  M0X0 call  hits=20332        101,660  candidate_requires_analysis_and_replay  sites=$80C12B
    37  $80991D  M0X0 call  hits=20332        101,660  candidate_requires_analysis_and_replay  sites=$80C133
    38  $8180C4  M0X0 call  hits=20332        101,660  candidate_requires_analysis_and_replay  sites=$80C136
    39  $81A8D5  M0X0 call  hits=20332        101,660  candidate_requires_analysis_and_replay  sites=$80C13A
    40  $81A914  M0X0 call  hits=20332        101,660  candidate_requires_analysis_and_replay  sites=$80C13E
   ranked: 215 entries (4 dropped: the program already has them, or they are under --min-cycles), --top 10 seeds the first 10: 12,613,024 ranked cyc = 52.37% of the 24,086,298 cyc seedable slice, 1.47% of the 860,839,515 cyc attributed residue
   $80C1C9  M0X0    2,196,990 cyc    366,165 insns   366,165 gap hits  frames 1766..22043
   $80C1B3  M0X0    1,927,350 cyc    385,470 insns    19,305 gap hits  frames 1765..22043
   $80F495  M0X0    1,783,776 cyc    222,972 insns   222,972 gap hits  frames 1766..22043
   $80F362  M0X0    1,509,550 cyc    188,694 insns   188,694 gap hits  frames 1766..22043
   $80F4F9  M0X0    1,114,860 cyc    222,972 insns   222,972 gap hits  frames 1766..22043
   $80ABBC  M0X0      988,976 cyc    247,244 insns   247,244 gap hits  frames 1765..22043
   $80B1DB  M0X0      957,845 cyc    191,569 insns   191,569 gap hits  frames 1767..22043
   $80F889  M0X0      763,350 cyc    152,670 insns   152,670 gap hits  frames 1766..22043
   $80F37B  M0X0      691,687 cyc     86,461 insns    86,461 gap hits  frames 1766..22043
   $80F6DF  M0X0      678,640 cyc    135,728 insns   135,728 gap hits  frames 1766..22043
   $80F3EA  M0X0      678,310 cyc    135,662 insns   135,662 gap hits  frames 1766..22043
   $80B101  M0X0      610,922 cyc    214,381 insns   214,381 gap hits  frames 2542..20042
   $80C3D1  M0X0      464,360 cyc     92,872 insns    92,872 gap hits  frames 1766..22043
   $80B032  M0X0      421,212 cyc    105,303 insns   105,303 gap hits  frames 1767..17360
   $80AA97  M0X0      418,578 cyc    209,289 insns   209,289 gap hits  frames 1767..22043
   $80F895  M0X0      379,979 cyc     75,996 insns    75,996 gap hits  frames 1766..22042
   $80803B  M0X0      376,425 cyc     53,775 insns    18,668 gap hits  frames 3395..22043
   $81846E  M0X0      345,400 cyc     86,350 insns    86,350 gap hits  frames 1767..22043
   $80B07A  M0X0      333,714 cyc    166,857 insns   166,857 gap hits  frames 1767..17360
   $80F3BA  M0X0      331,550 cyc     66,310 insns    66,310 gap hits  frames 1766..22043
   $80CA0A  M0X0      294,800 cyc     73,700 insns    73,700 gap hits  frames 1766..17835
   $80B095  M0X0      268,568 cyc     67,142 insns    67,142 gap hits  frames 1767..14650
   $80F885  M0X0      249,695 cyc     49,939 insns    49,939 gap hits  frames 1768..22042
   $809D8E  M0X0      243,380 cyc     48,676 insns    21,403 gap hits  frames 498..22043
   $80B0A0  M0X0      241,372 cyc     60,343 insns    60,343 gap hits  frames 1767..16121
   $80B05D  M0X0      199,852 cyc     49,963 insns    49,963 gap hits  frames 1767..14650
   $80F6F7  M0X0      177,180 cyc     35,436 insns    35,436 gap hits  frames 1827..22043
   $81A910  M0X0      154,432 cyc     19,304 insns    19,304 gap hits  frames 1765..22043
   $80AF51  M0X0      154,408 cyc     19,301 insns    19,301 gap hits  frames 1765..22043
   $80B07F  M0X0      149,912 cyc     37,478 insns    37,478 gap hits  frames 1767..14650
   $80F3A1  M0X0      148,272 cyc     18,534 insns    18,534 gap hits  frames 1766..22043
   $80F390  M0X0      145,687 cyc     18,211 insns    18,211 gap hits  frames 1766..22043
   $80F3D2  M0X0      143,376 cyc     17,922 insns    17,922 gap hits  frames 1766..22043
   $80B8AF  M0X0      115,812 cyc     19,302 insns    19,302 gap hits  frames 1765..22043
   $80B047  M0X0      112,664 cyc     28,166 insns    28,166 gap hits  frames 1767..14650
   $818949  M0X0      101,660 cyc     20,332 insns    20,332 gap hits  frames 1712..22043
   $80991D  M0X0      101,660 cyc     20,332 insns    20,332 gap hits  frames 1712..22043
   $8180C4  M0X0      101,660 cyc     20,332 insns    20,332 gap hits  frames 1712..22043
   $81A8D5  M0X0      101,660 cyc     20,332 insns    20,332 gap hits  frames 1712..22043
   $81A914  M0X0      101,660 cyc     20,332 insns    20,332 gap hits  frames 1712..22043
   $81A94A  M0X0      101,660 cyc     20,332 insns    20,332 gap hits  frames 1712..22043
   $808FBA  M0X0      101,660 cyc     20,332 insns    20,332 gap hits  frames 1712..22043
   $80C03B  M0X0      101,660 cyc     20,332 insns    20,332 gap hits  frames 1712..22043
   $81B08D  M0X0      101,660 cyc     20,332 insns    20,332 gap hits  frames 1712..22043
   $80B03C  M0X0      101,156 cyc     25,289 insns    25,289 gap hits  frames 1767..16121
   $808000  M0X0       96,525 cyc     19,305 insns    19,305 gap hits  frames 1765..22043
   $80AF89  M0X0       96,510 cyc     19,302 insns    19,302 gap hits  frames 1765..22043
   $80CC1B  M0X0       96,505 cyc     19,301 insns    19,301 gap hits  frames 1765..22043
   $80DE5E  M0X0       96,505 cyc     19,301 insns    19,301 gap hits  frames 1765..22043
   $80BAA5  M0X0       96,505 cyc     19,301 insns    19,301 gap hits  frames 1765..22043
   $818C2E  M0X0       96,505 cyc     19,301 insns    19,301 gap hits  frames 1765..22043
   $80E23A  M0X0       96,505 cyc     19,301 insns    19,301 gap hits  frames 1765..22043
   $80F6E7  M0X0       92,390 cyc     18,478 insns    18,478 gap hits  frames 3401..22043
   $80DFDE  M0X0       88,590 cyc     17,718 insns    17,718 gap hits  frames 3400..22043
   $80E22C  M0X0       88,565 cyc     17,713 insns    17,713 gap hits  frames 3401..22043
   $80B987  M1X0       77,208 cyc     19,302 insns        12 gap hits  frames 6888..6908
   $80B984  M1X0       77,160 cyc     19,290 insns         1 gap hits  frames 6902..6902
   $80B981  M1X0       77,156 cyc     19,289 insns       338 gap hits  frames 5735..6898
   $80B97E  M1X0       75,804 cyc     18,951 insns         4 gap hits  frames 6887..6903
   $80B97B  M1X0       75,788 cyc     18,947 insns         1 gap hits  frames 6901..6901
   $80B975  M1X0       75,784 cyc     18,946 insns        19 gap hits  frames 3100..6078
   $80B972  M1X0       75,708 cyc     18,927 insns         2 gap hits  frames 5734..6069
   $80B96F  M1X0       75,700 cyc     18,925 insns       303 gap hits  frames 4956..6910
   $80DE91  M0X0       75,480 cyc     15,096 insns    15,096 gap hits  frames 3400..20622
   $80B969  M1X0       74,488 cyc     18,622 insns       145 gap hits  frames 3105..5703
   $80B966  M1X0       73,908 cyc     18,477 insns        69 gap hits  frames 3075..6099
   $80B963  M1X0       73,632 cyc     18,408 insns     2,970 gap hits  frames 1892..6885
   $80CBD7  M0X0       71,020 cyc     17,755 insns    17,755 gap hits  frames 3396..22043
   $80B960  M1X0       61,752 cyc     15,438 insns        60 gap hits  frames 2768..6886
   $80B95D  M1X0       61,512 cyc     15,378 insns        38 gap hits  frames 1882..6878
   $80B95A  M1X0       61,360 cyc     15,340 insns       222 gap hits  frames 1768..6860
   $80C122  M0X0       60,996 cyc     20,332 insns    20,332 gap hits  frames 1712..22043
   $80B957  M1X0       60,472 cyc     15,118 insns        82 gap hits  frames 1822..6922
   $80B954  M1X0       60,144 cyc     15,036 insns        12 gap hits  frames 2735..2767
   $80B951  M1X0       60,096 cyc     15,024 insns       513 gap hits  frames 1893..11486
   $80B94E  M1X0       58,044 cyc     14,511 insns        10 gap hits  frames 2751..14650
   $80B94B  M1X0       58,004 cyc     14,501 insns     4,526 gap hits  frames 2422..11491
   $80B0BD  M0X0       57,906 cyc     19,302 insns    19,302 gap hits  frames 1765..22043
   $80FEDE  M0X0       57,903 cyc     19,301 insns    19,301 gap hits  frames 1765..22043
   $818799  M0X0       57,903 cyc     19,301 insns    19,301 gap hits  frames 1765..22043
   $8180F7  M0X0       57,903 cyc     19,301 insns    19,301 gap hits  frames 1765..22043
   $80B948  M1X0       39,900 cyc      9,975 insns       284 gap hits  frames 2418..2722
   $80B945  M1X0       38,764 cyc      9,691 insns     2,146 gap hits  frames 11450..14645
   $80B942  M1X0       30,180 cyc      7,545 insns        13 gap hits  frames 2434..11496
   $80B93F  M1X0       30,128 cyc      7,532 insns        17 gap hits  frames 1767..12208
   $80B93C  M1X0       30,060 cyc      7,515 insns       701 gap hits  frames 11472..17274
   $80B939  M1X0       27,256 cyc      6,814 insns         5 gap hits  frames 11503..11507
   $80B936  M1X0       27,236 cyc      6,809 insns         6 gap hits  frames 11508..11513
   $80B92D  M1X0       27,212 cyc      6,803 insns        24 gap hits  frames 16002..16681
   $80B92A  M1X0       27,116 cyc      6,779 insns       100 gap hits  frames 16293..17267
   $80B927  M1X0       26,716 cyc      6,679 insns       198 gap hits  frames 15922..22043
   $80B924  M1X0       25,924 cyc      6,481 insns       619 gap hits  frames 15938..22018
   $80B921  M1X0       23,448 cyc      5,862 insns     2,964 gap hits  frames 15914..22034
   $80DF35  M0X0       13,090 cyc      2,618 insns     2,618 gap hits  frames 6535..22043
   $80B91E  M1X0       11,592 cyc      2,898 insns     1,352 gap hits  frames 14677..19860
   $80F383  M0X0        8,528 cyc      1,066 insns     1,066 gap hits  frames 1766..21952
   $80B08A  M0X0        7,576 cyc      1,894 insns     1,894 gap hits  frames 16284..17360
   $80B052  M0X0        7,540 cyc      1,885 insns     1,885 gap hits  frames 16284..17360
   $80F35D  M0X0        6,975 cyc      1,395 insns     1,395 gap hits  frames 1766..22035
   $80B91B  M1X0        6,184 cyc      1,546 insns        57 gap hits  frames 15986..19883
   $80B918  M1X0        5,956 cyc      1,489 insns        50 gap hits  frames 16013..18626
   $80B915  M1X0        5,756 cyc      1,439 insns       125 gap hits  frames 15982..17739
   $80C65D  M0X0        5,360 cyc      1,072 insns     1,072 gap hits  frames 3176..22042
   $80B912  M1X0        5,256 cyc      1,314 insns       510 gap hits  frames 16035..18589
   $80C666  M0X0        4,288 cyc      1,072 insns     1,072 gap hits  frames 3176..22042
   $81A32D  M0X0        4,148 cyc      1,037 insns     1,037 gap hits  frames 17688..22034
   $80F3B4  M0X0        4,100 cyc        820 insns       820 gap hits  frames 16285..22019
   $80B90F  M1X0        3,216 cyc        804 insns        33 gap hits  frames 16031..17749
   $80F36B  M0X0        3,208 cyc        401 insns       401 gap hits  frames 1766..22034
   $80B90C  M1X0        3,084 cyc        771 insns       766 gap hits  frames 16029..18584
   $80F80D  M0X0        2,688 cyc        896 insns       896 gap hits  frames 3398..22034
   $80F6FF  M0X0        2,679 cyc        893 insns       893 gap hits  frames 3176..22035
   $80C530  M0X0        2,652 cyc        884 insns       884 gap hits  frames 1832..22034
   $81DD11  M0X0        2,457 cyc        819 insns       819 gap hits  frames 498..1316
   $80F25A  M0X0        2,457 cyc        819 insns       819 gap hits  frames 498..1316
   $81E7FA  M0X0        2,388 cyc        398 insns       398 gap hits  frames 9..417
   $80CAFB  M0X0        2,264 cyc        566 insns       566 gap hits  frames 1766..17361
   $81E66F  M0X0        2,016 cyc        252 insns       252 gap hits  frames 1351..1602
   $80F3F8  M0X0        1,640 cyc        328 insns       328 gap hits  frames 1766..22042
   $80F8AE  M0X0        1,448 cyc        181 insns       181 gap hits  frames 17699..22035
   $80C4EF  M0X0        1,200 cyc        300 insns       300 gap hits  frames 1832..22034
   $80F3C0  M0X0        1,136 cyc        142 insns       142 gap hits  frames 1766..22034
   $80866F  M0X0        1,000 cyc        200 insns       200 gap hits  frames 17939..18155
   $81E749  M0X1          996 cyc        166 insns       166 gap hits  frames 1437..1602
   $80F40C  M0X0          992 cyc        124 insns       124 gap hits  frames 1766..22034
   $80F8CC  M0X0          976 cyc        122 insns       122 gap hits  frames 1769..22035
   $80F342  M0X0          918 cyc        153 insns       153 gap hits  frames 1766..22035
   $80D12C  M0X0          798 cyc        133 insns       133 gap hits  frames 1766..22035
   $81ED4C  M0X0          756 cyc        252 insns       252 gap hits  frames 1351..1602
   $81D55B  M0X0          756 cyc        252 insns       252 gap hits  frames 1351..1602
   $80F25A  M0X1          756 cyc        252 insns       252 gap hits  frames 1351..1602
   $80F786  M0X0          753 cyc        251 insns       251 gap hits  frames 18105..22042
   $80F3AE  M0X0          600 cyc        120 insns       120 gap hits  frames 16281..22035
   $81A25F  M0X0          596 cyc        149 insns       149 gap hits  frames 17688..22034
   $80F41E  M0X0          590 cyc        118 insns       118 gap hits  frames 1827..22034
   $80F406  M0X0          552 cyc         69 insns        69 gap hits  frames 1766..18617
   $80A9D9  M0X0          492 cyc        123 insns       123 gap hits  frames 1766..22019
   $808BC5  M0X0          488 cyc        122 insns       122 gap hits  frames 17568..22034
   $80A882  M0X0          438 cyc         73 insns        73 gap hits  frames 1766..22019
   $80F488  M0X0          435 cyc         87 insns        87 gap hits  frames 1766..22019
   $80F849  M0X0          372 cyc        124 insns       124 gap hits  frames 17568..22034
   $80F42A  M0X0          279 cyc         35 insns        35 gap hits  frames 1766..18075
   $808EF5  M0X0          276 cyc         69 insns        69 gap hits  frames 17699..22035
   $80C792  M0X0          272 cyc         68 insns        68 gap hits  frames 1822..22008
   $80D15A  M0X0          260 cyc         52 insns        52 gap hits  frames 18646..22032
   $80D10E  M0X0          240 cyc         60 insns        60 gap hits  frames 16427..22008
   $80C6E6  M0X0          235 cyc         47 insns        47 gap hits  frames 16281..21947
   $808497  M0X0          212 cyc         53 insns        53 gap hits  frames 17688..22032
   $808904  M0X0          212 cyc         53 insns        53 gap hits  frames 17688..22032
   $808AB5  M0X0          212 cyc         53 insns        53 gap hits  frames 17688..22032
   $80CF63  M0X0          212 cyc         53 insns        53 gap hits  frames 17688..22034
   $80C33A  M0X0          210 cyc         35 insns        35 gap hits  frames 1766..18075
   $80C366  M0X0          174 cyc         87 insns        87 gap hits  frames 1766..22019
   $80C28D  M0X0          174 cyc         87 insns        87 gap hits  frames 1766..22019
   $80F8BB  M0X0          160 cyc         20 insns        20 gap hits  frames 3398..17837
   $808A43  M0X0          159 cyc         53 insns        53 gap hits  frames 17688..22032
   $80F4FC  M0X0          150 cyc         30 insns        30 gap hits  frames 16281..18075
   $80CBE0  M0X0          132 cyc         33 insns        33 gap hits  frames 1766..17746
   $80AD9F  M0X0           84 cyc         14 insns        14 gap hits  frames 16571..16571
   $80A8BC  M0X0           68 cyc         17 insns        17 gap hits  frames 1893..22035
   $808EFE  M0X0           66 cyc         22 insns        22 gap hits  frames 16467..16571
   $81E5E4  M0X1           60 cyc         20 insns        20 gap hits  frames 1444..1596
   $80F6D3  M0X0           55 cyc         11 insns        11 gap hits  frames 18075..22035
   $80CB83  M0X0           52 cyc         13 insns        13 gap hits  frames 1891..6923
   $80CD78  M0X0           50 cyc         10 insns        10 gap hits  frames 3396..17837
   $80CA9A  M0X0           44 cyc         11 insns        11 gap hits  frames 1891..6923
   $80881C  M0X0           40 cyc          8 insns         8 gap hits  frames 18759..22032
   $80C694  M0X0           39 cyc         13 insns        13 gap hits  frames 1766..17505
   $809D1B  M0X0           36 cyc          9 insns         9 gap hits  frames 1766..17835
   $80C9E5  M0X0           36 cyc          9 insns         9 gap hits  frames 1766..17835
   $80CA84  M0X0           36 cyc          9 insns         9 gap hits  frames 1766..17835
   $808691  M0X0           32 cyc          8 insns         8 gap hits  frames 18759..22032
   $80F6C7  M0X0           30 cyc          6 insns         6 gap hits  frames 16281..16281
   $80D19A  M0X0           30 cyc          5 insns         5 gap hits  frames 16427..21441
   $80A8F0  M0X0           28 cyc          7 insns         7 gap hits  frames 16281..17688
   $81A344  M0X0           28 cyc          7 insns         7 gap hits  frames 18587..19179
   $80BC37  M0X0           24 cyc          4 insns         4 gap hits  frames 6530..20623
   $80B906  M1X0           20 cyc          5 insns         5 gap hits  frames 1765..17834
   $80BC06  M0X0           20 cyc          4 insns         4 gap hits  frames 6530..20623
   $80D1AB  M0X0           20 cyc          5 insns         5 gap hits  frames 16427..21441
   $809471  M0X0           20 cyc          5 insns         5 gap hits  frames 16281..16281
   $80CA19  M0X0           20 cyc          5 insns         5 gap hits  frames 3398..17837
   $808486  M0X0           18 cyc          3 insns         3 gap hits  frames 6852..13748
   $80C68F  M0X0           18 cyc          6 insns         6 gap hits  frames 2445..21401
   $80C9F0  M0X0           16 cyc          4 insns         4 gap hits  frames 1766..17505
   $80CA72  M0X0           16 cyc          4 insns         4 gap hits  frames 17505..17835
   $80D0D5  M0X0           16 cyc          4 insns         4 gap hits  frames 1766..17835
   $80DE48  M0X0           15 cyc          5 insns         5 gap hits  frames 3396..17835
   $808371  M0X0           12 cyc          3 insns         3 gap hits  frames 6852..13748
   $809CFD  M0X0           12 cyc          3 insns         3 gap hits  frames 1766..16582
   $80A8E6  M0X0           12 cyc          3 insns         3 gap hits  frames 16281..17505
   $808521  M0X0           10 cyc          2 insns         2 gap hits  frames 17688..18065
   $8092EF  M0X0            8 cyc          1 insns         1 gap hits  frames 16452..16452
   $80A8AA  M0X0            8 cyc          2 insns         2 gap hits  frames 16281..17505
   $80A8FA  M0X0            8 cyc          2 insns         2 gap hits  frames 16281..16281
   $80D11A  M0X0            8 cyc          2 insns         2 gap hits  frames 16281..16281
   $808FF5  M0X0            6 cyc          2 insns         2 gap hits  frames 16461..16465
   $808F20  M0X0            6 cyc          2 insns         2 gap hits  frames 16461..16464
   $809248  M0X0            6 cyc          1 insns         1 gap hits  frames 16560..16560
   $80A173  M0X0            6 cyc          1 insns         1 gap hits  frames 3395..3395
   $80A654  M0X0            5 cyc          1 insns         1 gap hits  frames 16543..16543
   $80FA5C  M0X0            4 cyc          1 insns         1 gap hits  frames 16457..16457
   $809123  M0X0            4 cyc          1 insns         1 gap hits  frames 16477..16477
   $80918D  M0X0            4 cyc          1 insns         1 gap hits  frames 16543..16543
   $80960B  M0X0            4 cyc          1 insns         1 gap hits  frames 1707..1707
   $80F505  M0X0            4 cyc          2 insns         2 gap hits  frames 16281..16281
   $80CAB0  M0X0            4 cyc          1 insns         1 gap hits  frames 17568..17568
   $80D21D  M0X0            4 cyc          1 insns         1 gap hits  frames 17688..17688
   $808F97  M0X0            3 cyc          1 insns         1 gap hits  frames 16560..16560
   $80AD81  M0X0            3 cyc          1 insns         1 gap hits  frames 16571..16571
   $81886A  M0X0            3 cyc          1 insns         1 gap hits  frames 16452..16452
   $809022  M0X0            3 cyc          1 insns         1 gap hits  frames 16461..16461
   $80905E  M0X0            3 cyc          1 insns         1 gap hits  frames 16465..16465
   $808F3A  M0X0            3 cyc          1 insns         1 gap hits  frames 16466..16466
   $80908C  M1X0            2 cyc          1 insns         1 gap hits  frames 16478..16478

== DONE  (log: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/r4/accepted/accepted_verify.log)
